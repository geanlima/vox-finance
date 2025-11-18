import 'package:shared_preferences/shared_preferences.dart';
import 'package:vox_finance/ui/core/enum/grafico_visao_inicial.dart';

class PreferenciasService {
  static const _chaveVisao = 'grafico_visao_inicial';

  static Future<void> salvarVisao(GraficoVisaoInicial visao) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_chaveVisao, visao.index);
  }

  static Future<GraficoVisaoInicial> carregarVisao() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getInt(_chaveVisao);
    if (valor == null) return GraficoVisaoInicial.ano;
    return GraficoVisaoInicial.values[valor];
  }
}
