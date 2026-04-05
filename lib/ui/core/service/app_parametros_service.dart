import 'package:shared_preferences/shared_preferences.dart';

/// Parâmetros gerais do app (preferências).
///
/// **Data de início de uso**: lançamentos e fechamentos anteriores a essa data
/// podem ser ignorados (ex.: despesas fixas), para quem começou a usar o app
/// a partir de um dia definido.
class AppParametrosService {
  AppParametrosService._();
  static final AppParametrosService instance = AppParametrosService._();

  static const _kDataInicioUsoMs = 'app_data_inicio_uso_ms';

  /// Primeiro dia em que o uso “oficial” começa (hora zerada, data local).
  Future<DateTime?> getDataInicioUso() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kDataInicioUsoMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setDataInicioUso(DateTime data) async {
    final p = await SharedPreferences.getInstance();
    final d = DateTime(data.year, data.month, data.day);
    await p.setInt(_kDataInicioUsoMs, d.millisecondsSinceEpoch);
  }

  Future<void> limparDataInicioUso() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDataInicioUsoMs);
  }

  /// O mês de [referencia] (esperado dia 1) termina antes da data de início.
  static bool mesReferenciaInteiroAntesDaDataInicio(
    DateTime referencia,
    DateTime dataInicio,
  ) {
    final inicio = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    final ultimoDiaMes = DateTime(referencia.year, referencia.month + 1, 0);
    return ultimoDiaMes.isBefore(inicio);
  }

  static bool deveIgnorarVencimento(DateTime vencimento, DateTime dataInicio) {
    final v = DateTime(vencimento.year, vencimento.month, vencimento.day);
    final i = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    return v.isBefore(i);
  }
}
