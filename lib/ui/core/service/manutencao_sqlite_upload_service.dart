import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/core/service/integracao_api_urls.dart';
import 'package:vox_finance/ui/data/database/database_backup_service.dart';

/// Linha de progresso / log enviada pela API (SSE `data:` com `nivel` + `mensagem`).
class SqliteImportacaoLog {
  const SqliteImportacaoLog({
    required this.nivel,
    required this.mensagem,
    this.tabela,
    this.registros,
    this.timestamp,
  });

  final String nivel;
  final String mensagem;
  final String? tabela;
  final int? registros;
  final String? timestamp;

  String get linhaResumida {
    final ts = timestamp != null ? '[$timestamp] ' : '';
    return '$ts$mensagem';
  }
}

/// Resultado final após `data: {"tipo":"resultado",...}` e `[DONE]`.
class SqliteImportacaoResultado {
  const SqliteImportacaoResultado({
    required this.sucesso,
    required this.totalRegistros,
    required this.registrosPorTabela,
    required this.erros,
    required this.logs,
    this.tempoSegundos,
  });

  final bool sucesso;
  final int totalRegistros;
  final Map<String, int> registrosPorTabela;
  final List<String> erros;
  final List<SqliteImportacaoLog> logs;
  final double? tempoSegundos;

  String get resumoLinha {
    final t =
        tempoSegundos != null
            ? ' em ${tempoSegundos!.toStringAsFixed(1)}s'
            : '';
    if (!sucesso) {
      final e =
          erros.isEmpty
              ? 'Falha na migração.'
              : erros.take(3).join(' · ');
      return 'Migração não concluída: $e';
    }
    return '$totalRegistros registro(s) migrado(s)$t.';
  }
}

/// Envia uma cópia consistente do SQLite do app para a API de manutenção.
class ManutencaoSqliteUploadService {
  ManutencaoSqliteUploadService._();
  static final ManutencaoSqliteUploadService instance =
      ManutencaoSqliteUploadService._();

  static const _timeout = Duration(minutes: 3);

  /// POST `multipart/form-data` com o campo [arquivo] (Swagger).
  ///
  /// Usa a **URL base do FinTrack IA** (Parâmetros → FinTrack IA — chat); o path
  /// `api/Manutencao/importar-sqlite` é acrescentado por [IntegracaoApiUrls].
  ///
  /// A resposta é **SSE**: eventos com `nivel`/`mensagem` e, ao final,
  /// `{"tipo":"resultado","dados":{...}}` e `[DONE]`.
  ///
  /// [onLog] é chamado para cada evento de progresso (opcional, ex.: UI).
  Future<SqliteImportacaoResultado> importarSqliteParaApi({
    void Function(SqliteImportacaoLog log)? onLog,
  }) async {
    final baseStr = await AppParametrosService.instance.getIaChatApiBaseUrl();
    if (baseStr == null || baseStr.trim().isEmpty) {
      throw StateError(
        'Configure a URL do FinTrack IA em Parâmetros para sincronizar o banco.',
      );
    }
    final base = Uri.tryParse(baseStr.trim());
    if (base == null) {
      throw StateError('URL do FinTrack IA inválida.');
    }

    final uri = IntegracaoApiUrls.manutencaoImportarSqlite(base);
    final backup = await DatabaseBackupService.criarBackup();
    if (backup == null) {
      throw StateError('Não foi possível preparar uma cópia do banco de dados.');
    }

    try {
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'arquivo',
          backup.path,
          filename: p.basename(backup.path),
        ),
      );

      final streamed = await request.send().timeout(_timeout);

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final bodyBytes = await streamed.stream.toBytes();
        final body = utf8.decode(bodyBytes, allowMalformed: true);
        final snippet =
            body.length > 400 ? '${body.substring(0, 400)}…' : body;
        throw StateError(
          'Servidor respondeu HTTP ${streamed.statusCode}${snippet.isEmpty ? '' : ': $snippet'}',
        );
      }

      final resultado = await _consumirSseMigracao(
        streamed.stream,
        onLog: onLog,
      ).timeout(_timeout);

      if (!resultado.sucesso || resultado.erros.isNotEmpty) {
        final msg =
            resultado.erros.isEmpty
                ? resultado.resumoLinha
                : resultado.erros.join('\n');
        throw StateError(msg);
      }

      await AppParametrosService.instance
          .registrarUltimaSincronizacaoBancoApiComSucesso();

      return resultado;
    } finally {
      try {
        if (await backup.exists()) await backup.delete();
      } catch (_) {}
    }
  }

  static Future<SqliteImportacaoResultado> _consumirSseMigracao(
    Stream<List<int>> byteStream, {
    void Function(SqliteImportacaoLog log)? onLog,
  }) async {
    final logs = <SqliteImportacaoLog>[];
    SqliteImportacaoResultado? finalResultado;

    var buffer = '';
    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer += chunk;
      var idx = buffer.indexOf('\n');
      while (idx >= 0) {
        final rawLine = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 1);
        idx = buffer.indexOf('\n');

        final line = rawLine.trimRight();
        if (line.isEmpty) continue;

        _processarLinhaSse(line, logs, onLog, (r) => finalResultado = r);
      }
    }

    final tail = buffer.trim();
    if (tail.isNotEmpty) {
      _processarLinhaSse(tail, logs, onLog, (r) => finalResultado = r);
    }

    final concluido = finalResultado;
    if (concluido != null) {
      return concluido;
    }

    if (logs.isEmpty) {
      throw StateError(
        'Resposta da API em formato inesperado (nenhum evento SSE reconhecido).',
      );
    }

    return SqliteImportacaoResultado(
      sucesso: false,
      totalRegistros: 0,
      registrosPorTabela: const {},
      erros: const ['Resposta sem bloco final de resultado (tipo resultado).'],
      logs: List<SqliteImportacaoLog>.from(logs),
      tempoSegundos: null,
    );
  }

  static void _processarLinhaSse(
    String line,
    List<SqliteImportacaoLog> logs,
    void Function(SqliteImportacaoLog log)? onLog,
    void Function(SqliteImportacaoResultado r) setResultado,
  ) {
    if (!line.startsWith('data: ')) return;
    final dados = line.substring(6).trim();
    if (dados == '[DONE]' || dados.isEmpty) return;
    final parsed = _parseDataPayload(dados, logs, onLog);
    if (parsed != null) setResultado(parsed);
  }

  /// Interpreta um payload `data: ...`. Atualiza [logs] e retorna resultado se for o evento final.
  static SqliteImportacaoResultado? _parseDataPayload(
    String dados,
    List<SqliteImportacaoLog> logs,
    void Function(SqliteImportacaoLog log)? onLog,
  ) {
    dynamic v;
    try {
      v = jsonDecode(dados);
    } catch (_) {
      return null;
    }
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);

    if (m['tipo']?.toString() == 'resultado' && m['dados'] is Map) {
      final d = Map<String, dynamic>.from(m['dados'] as Map);
      final sucesso = d['sucesso'] == true;
      final total =
          d['totalRegistros'] is num
              ? (d['totalRegistros'] as num).toInt()
              : int.tryParse('${d['totalRegistros']}') ?? 0;
      final tempo =
          d['tempoSegundos'] is num
              ? (d['tempoSegundos'] as num).toDouble()
              : double.tryParse('${d['tempoSegundos']}');

      final porTabela = <String, int>{};
      final rawMap = d['registrosPorTabela'];
      if (rawMap is Map) {
        for (final e in rawMap.entries) {
          final k = e.key.toString();
          final val = e.value;
          final n =
              val is num
                  ? val.toInt()
                  : int.tryParse(val?.toString() ?? '') ?? 0;
          porTabela[k] = n;
        }
      }

      final erros = <String>[];
      final rawErros = d['erros'];
      if (rawErros is List) {
        for (final e in rawErros) {
          if (e != null) erros.add(e.toString());
        }
      }

      return SqliteImportacaoResultado(
        sucesso: sucesso,
        totalRegistros: total,
        registrosPorTabela: porTabela,
        erros: erros,
        logs: List<SqliteImportacaoLog>.from(logs),
        tempoSegundos: tempo,
      );
    }

    if (m.containsKey('nivel') && m.containsKey('mensagem')) {
      final log = SqliteImportacaoLog(
        nivel: m['nivel']?.toString() ?? '',
        mensagem: m['mensagem']?.toString() ?? '',
        tabela: m['tabela']?.toString(),
        registros:
            m['registros'] == null
                ? null
                : m['registros'] is num
                ? (m['registros'] as num).toInt()
                : int.tryParse(m['registros'].toString()),
        timestamp: m['timestamp']?.toString(),
      );
      logs.add(log);
      onLog?.call(log);
    }

    return null;
  }
}
