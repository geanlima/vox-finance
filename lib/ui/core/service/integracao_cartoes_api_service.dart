import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/core/service/integracao_api_urls.dart';
import 'package:vox_finance/ui/data/models/cartao_api_dto.dart';
import 'package:vox_finance/ui/data/models/fatura_api_dto.dart';

class IntegracaoCartoesApiService {
  IntegracaoCartoesApiService._();
  static final IntegracaoCartoesApiService instance = IntegracaoCartoesApiService._();

  static const _timeout = Duration(seconds: 20);

  /// GET `/api/cartoes` — JSON array ou objeto com `items` / `data`.
  Future<List<CartaoApiDto>> listarCartoes() async {
    final baseStr = await AppParametrosService.instance.getApiBaseUrl();
    if (baseStr == null || baseStr.trim().isEmpty) {
      throw StateError('URL não configurada em Parâmetros.');
    }
    final base = Uri.tryParse(baseStr.trim());
    if (base == null) {
      throw StateError('URL inválida.');
    }

    final uri = IntegracaoApiUrls.cartoes(base);
    final r = await http.get(uri, headers: {'accept': 'application/json'}).timeout(_timeout);

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw StateError('HTTP ${r.statusCode} ao buscar cartões.');
    }

    final decoded = jsonDecode(utf8.decode(r.bodyBytes));
    final list = _extrairLista(decoded);
    if (list == null) {
      throw StateError('Formato de resposta inesperado (esperava lista de cartões).');
    }

    final out = <CartaoApiDto>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final dto = CartaoApiDto.fromJson(m);
      if (dto.id.isEmpty || dto.descricao.isEmpty) continue;
      out.add(dto);
    }
    return out;
  }

  /// GET `/api/faturas?cartao_id=&competencia=` — [competencia] no formato `MM/YYYY`.
  ///
  /// Respostas aceitas: array JSON, ou objeto com `faturas` / `items` / `data`,
  /// ou objeto único de fatura, ou objeto com `lancamentos` na raiz (vira uma fatura sintética).
  Future<List<FaturaApiDto>> listarFaturasPorCartaoMes({
    required String idCartaoApi,
    required int ano,
    required int mes,
  }) async {
    final baseStr = await AppParametrosService.instance.getApiBaseUrl();
    if (baseStr == null || baseStr.trim().isEmpty) {
      throw StateError('URL não configurada. Defina em Parâmetros.');
    }
    final base = Uri.tryParse(baseStr.trim());
    if (base == null) {
      throw StateError('URL inválida.');
    }

    final competencia = IntegracaoApiUrls.competenciaMmYyyy(ano, mes);
    final uri = IntegracaoApiUrls.faturas(
      base,
      cartaoId: idCartaoApi,
      competencia: competencia,
    );
    final r = await http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(_timeout);

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw StateError('HTTP ${r.statusCode} ao buscar faturas.');
    }

    final decoded = jsonDecode(utf8.decode(r.bodyBytes));
    return _parseFaturasResponse(decoded);
  }

  List<FaturaApiDto> _parseFaturasResponse(dynamic decoded) {
    final fromList = _extrairListaFaturas(decoded);
    if (fromList != null) {
      return _mapFaturas(fromList);
    }
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final lancs =
          m['lancamentos'] ?? m['movimentos'] ?? m['transacoes'] ?? m['itens'];
      if (lancs is List && lancs.isNotEmpty) {
        return [FaturaApiDto.fromJson(m)];
      }
    }
    return [];
  }

  List<FaturaApiDto> _mapFaturas(List<dynamic> list) {
    final out = <FaturaApiDto>[];
    for (final item in list) {
      if (item is! Map) continue;
      out.add(FaturaApiDto.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  List<dynamic>? _extrairListaFaturas(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      for (final key in [
        'faturas',
        'items',
        'data',
        'results',
        'content',
        'lista',
      ]) {
        final items = m[key];
        if (items is List) return items;
      }
      if (m['id'] != null ||
          m['valor_total'] != null ||
          m['valorTotal'] != null ||
          m['total_fatura'] != null ||
          m['competencia'] != null ||
          m['lancamentos'] != null) {
        return [m];
      }
    }
    return null;
  }

  List<dynamic>? _extrairLista(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final items = m['items'] ?? m['data'] ?? m['cartoes'] ?? m['results'];
      if (items is List) return items;
    }
    return null;
  }
}
