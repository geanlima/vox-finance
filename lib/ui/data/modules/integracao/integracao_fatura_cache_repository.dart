import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/fatura_api_dto.dart';
import 'package:vox_finance/ui/data/models/integracao_fatura_cache.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class IntegracaoFaturaCacheRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();
  final _lancRepo = LancamentoRepository();

  String buildSourceKey({
    required int idCartaoLocal,
    required int ano,
    required int mes,
    required FaturaApiDto f,
  }) {
    final venc = f.dataVencimento?.toIso8601String() ?? '';
    final fech = f.dataFechamento?.toIso8601String() ?? '';
    final payload = jsonEncode({
      'cartao': idCartaoLocal,
      'ano': ano,
      'mes': mes,
      'apiId': f.id ?? '',
      'venc': venc,
      'fech': fech,
      'total': f.valorTotal,
      'desc': f.descricao ?? '',
    });
    return sha1.convert(utf8.encode(payload)).toString();
  }

  Future<IntegracaoFaturaCache?> getBySourceKey(String sourceKey) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntegracaoFaturaCache.fromMap(rows.first);
  }

  Future<IntegracaoFaturaCache?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntegracaoFaturaCache.fromMap(rows.first);
  }

  Future<List<IntegracaoFaturaCache>> listarPorCartaoPeriodo({
    required int idCartaoLocal,
    required int ano,
    required int mes,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id_cartao_local = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartaoLocal, ano, mes],
      orderBy: 'importado_em DESC',
    );
    return rows.map((r) => IntegracaoFaturaCache.fromMap(r)).toList();
  }

  Future<List<IntegracaoFaturaCache>> listarPorCartao({
    required int idCartaoLocal,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id_cartao_local = ?',
      whereArgs: [idCartaoLocal],
      orderBy: 'ano DESC, mes DESC, importado_em DESC',
    );
    return rows.map((r) => IntegracaoFaturaCache.fromMap(r)).toList();
  }

  Future<List<IntegracaoFaturaCacheItem>> listarItens(int idFaturaCache) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache_itens',
      where: 'id_fatura_cache = ?',
      whereArgs: [idFaturaCache],
      orderBy: 'data_hora ASC, id ASC',
    );
    return rows.map((r) => IntegracaoFaturaCacheItem.fromMap(r)).toList();
  }

  Future<void> vincularItemComLancamento({
    required int idItem,
    required int? idLancamentoLocal,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache_itens',
      {'id_lancamento_local': idLancamentoLocal},
      where: 'id = ?',
      whereArgs: [idItem],
    );
  }

  Future<void> marcarFaturaComoFechada({
    required int idFaturaCache,
    required int idLancamentoFatura,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache',
      {
        'fechada_em': DateTime.now().millisecondsSinceEpoch,
        'id_lancamento_fatura': idLancamentoFatura,
      },
      where: 'id = ?',
      whereArgs: [idFaturaCache],
    );
  }

  Future<void> reabrirFatura({
    required int idFaturaCache,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache',
      {
        'fechada_em': null,
        'id_lancamento_fatura': null,
      },
      where: 'id = ?',
      whereArgs: [idFaturaCache],
    );
  }

  Future<List<Lancamento>> listarLancamentosCandidatos({
    required int idCartaoLocal,
    required int ano,
    required int mes,
  }) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1).subtract(const Duration(milliseconds: 1));
    final lista = await _lancRepo.getByPeriodo(inicio, fim);
    return lista
        .where(
          (l) =>
              l.idCartao == idCartaoLocal &&
              l.pagamentoFatura == false &&
              l.formaPagamento.toString().contains('credito'),
        )
        .toList();
  }

  /// Auto-match por valor (e proximidade de data, se houver).
  /// Não sobrescreve vínculos existentes a menos que [overwrite] = true.
  Future<int> autoAssociarItens({
    required IntegracaoFaturaCache fatura,
    required bool overwrite,
  }) async {
    final idFaturaCache = fatura.id;
    if (idFaturaCache == null) return 0;

    final itens = await listarItens(idFaturaCache);
    final lancs = await listarLancamentosCandidatos(
      idCartaoLocal: fatura.idCartaoLocal,
      ano: fatura.ano,
      mes: fatura.mes,
    );

    final usados = <int>{};
    for (final it in itens) {
      final lid = it.idLancamentoLocal;
      if (lid != null) usados.add(lid);
    }

    int vinculados = 0;
    const tol = 0.009;

    for (final it in itens) {
      if (it.id == null) continue;
      if (!overwrite && it.idLancamentoLocal != null) continue;

      final candidatos = lancs
          .where((l) => (l.valor - it.valor).abs() <= tol && l.id != null)
          .where((l) => !usados.contains(l.id!))
          .toList();

      if (candidatos.isEmpty) continue;

      Lancamento escolhido = candidatos.first;
      final dtItem = it.dataHora;
      if (dtItem != null) {
        candidatos.sort((a, b) {
          final da = (a.dataHora.difference(dtItem).inMinutes).abs();
          final db = (b.dataHora.difference(dtItem).inMinutes).abs();
          return da.compareTo(db);
        });
        escolhido = candidatos.first;
      }

      await vincularItemComLancamento(
        idItem: it.id!,
        idLancamentoLocal: escolhido.id!,
      );
      usados.add(escolhido.id!);
      vinculados += 1;
    }

    return vinculados;
  }

  /// Salva a fatura e seus itens.
  /// Se [overwrite] for true e existir registro com o mesmo source_key, substitui.
  Future<int> salvarFaturaFromApi({
    required int idCartaoLocal,
    required String codigoCartaoApi,
    required int ano,
    required int mes,
    required FaturaApiDto f,
    required bool overwrite,
  }) async {
    final db = await _db;
    final sourceKey = buildSourceKey(
      idCartaoLocal: idCartaoLocal,
      ano: ano,
      mes: mes,
      f: f,
    );

    return db.transaction<int>((txn) async {
      final existing = await txn.query(
        'integracao_faturas_cache',
        where: 'source_key = ?',
        whereArgs: [sourceKey],
        limit: 1,
      );

      int? idCache;
      if (existing.isNotEmpty) {
        idCache = existing.first['id'] as int;
        if (!overwrite) {
          return idCache;
        }
        await txn.delete(
          'integracao_faturas_cache_itens',
          where: 'id_fatura_cache = ?',
          whereArgs: [idCache],
        );
        await txn.update(
          'integracao_faturas_cache',
          {
            'codigo_cartao_api': codigoCartaoApi,
            'ano': ano,
            'mes': mes,
            'fatura_api_id': f.id,
            'descricao': f.descricao,
            'valor_total': f.valorTotal,
            'data_vencimento': f.dataVencimento?.millisecondsSinceEpoch,
            'data_fechamento': f.dataFechamento?.millisecondsSinceEpoch,
            'pago': f.pago == null ? null : (f.pago! ? 1 : 0),
            'importado_em': DateTime.now().millisecondsSinceEpoch,
            // Se reimportar, consideramos que precisa "refechar" se desejar.
            'fechada_em': null,
            'id_lancamento_fatura': null,
          },
          where: 'id = ?',
          whereArgs: [idCache],
        );
      } else {
        idCache = await txn.insert(
          'integracao_faturas_cache',
          {
            'source_key': sourceKey,
            'id_cartao_local': idCartaoLocal,
            'codigo_cartao_api': codigoCartaoApi,
            'ano': ano,
            'mes': mes,
            'fatura_api_id': f.id,
            'descricao': f.descricao,
            'valor_total': f.valorTotal,
            'data_vencimento': f.dataVencimento?.millisecondsSinceEpoch,
            'data_fechamento': f.dataFechamento?.millisecondsSinceEpoch,
            'pago': f.pago == null ? null : (f.pago! ? 1 : 0),
            'importado_em': DateTime.now().millisecondsSinceEpoch,
            'fechada_em': null,
            'id_lancamento_fatura': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final batch = txn.batch();
      for (final it in f.lancamentos) {
        batch.insert(
          'integracao_faturas_cache_itens',
          {
            'id_fatura_cache': idCache,
            'item_api_id': it.id,
            'descricao': it.descricao,
            'valor': it.valor,
            'data_hora': it.dataHora?.millisecondsSinceEpoch,
            'categoria': it.categoria,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      return idCache;
    });
  }

  Future<void> deletarFaturaCache(int idFaturaCache) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'integracao_faturas_cache_itens',
        where: 'id_fatura_cache = ?',
        whereArgs: [idFaturaCache],
      );
      await txn.delete(
        'integracao_faturas_cache',
        where: 'id = ?',
        whereArgs: [idFaturaCache],
      );
    });
  }
}

