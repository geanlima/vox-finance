import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/core/service/integracao_api_urls.dart';
import 'package:vox_finance/ui/data/models/cartao_api_dto.dart';

class IntegracaoCartoesApiService {
  IntegracaoCartoesApiService._();
  static final IntegracaoCartoesApiService instance = IntegracaoCartoesApiService._();

  static const _timeout = Duration(seconds: 20);

  /// GET `/api/cartoes` — JSON array ou objeto com `items` / `data`.
  Future<List<CartaoApiDto>> listarCartoes() async {
    final baseStr = await AppParametrosService.instance.getApiBaseUrl();
    if (baseStr == null || baseStr.trim().isEmpty) {
      throw StateError('URL da API não configurada.');
    }
    final base = Uri.tryParse(baseStr.trim());
    if (base == null) {
      throw StateError('URL da API inválida.');
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
