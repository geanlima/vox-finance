import 'package:shared_preferences/shared_preferences.dart';
import 'package:vox_finance/ui/core/enum/tipo_grafico.dart';

class GraficoPreferenciaService {
  static const _chaveTipoGrafico = 'tipo_grafico_preferido';

  Future<TipoGrafico> carregarTipoGrafico() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_chaveTipoGrafico);
    if (key == null) return TipoGrafico.barra; // padrão
    return TipoGraficoExt.fromKey(key);
  }

  Future<void> salvarTipoGrafico(TipoGrafico tipo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveTipoGrafico, tipo.key);
  }
}
