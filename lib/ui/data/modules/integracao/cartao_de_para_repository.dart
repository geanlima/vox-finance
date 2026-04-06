import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Mapeamento id do cartão na API → id local em `cartao_credito`.
class CartaoDeParaRepository {
  static const _k = 'app_depara_cartao_api_para_local';

  Future<Map<String, int>> obter() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, int>{};
    for (final e in decoded.entries) {
      final v = e.value;
      if (v is int) {
        out[e.key.toString()] = v;
      } else if (v is num) {
        out[e.key.toString()] = v.toInt();
      }
    }
    return out;
  }

  Future<void> salvar(Map<String, int> mapa) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(mapa));
  }

  Future<void> definir(String idApi, int? idLocal) async {
    final m = await obter();
    if (idLocal == null) {
      m.remove(idApi);
    } else {
      m[idApi] = idLocal;
    }
    await salvar(m);
  }

  /// Id local associado ao cartão da API, se houver.
  Future<int?> idLocalParaApi(String idApi) async {
    final m = await obter();
    return m[idApi];
  }
}
