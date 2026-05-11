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
  static const _kApiBaseUrl = 'app_api_base_url';
  static const _kIaChatApiBaseUrl = 'app_ia_chat_api_base_url';
  static const _kUltimaSyncBancoApiMs = 'app_ultima_sync_banco_api_ms';
  static const _kUltimoAvisoSyncBancoAtrasadoMs =
      'app_ultimo_aviso_sync_banco_atrasado_ms';

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

  /// URL base da API para integração (ex.: https://api.meudominio.com).
  Future<String?> getApiBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kApiBaseUrl);
    if (raw == null) return null;
    final v = raw.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> setApiBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    final v = url.trim();
    await p.setString(_kApiBaseUrl, v);
  }

  Future<void> limparApiBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kApiBaseUrl);
  }

  /// URL base do FinTrack IA (`POST /api/Chat`), definida em **Parâmetros**.
  /// `null` quando ainda não foi salva.
  Future<String?> getIaChatApiBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kIaChatApiBaseUrl);
    if (raw == null) return null;
    final v = raw.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> setIaChatApiBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kIaChatApiBaseUrl, url.trim());
  }

  /// Remove a URL salva em Parâmetros (FinTrack IA).
  Future<void> limparIaChatApiBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kIaChatApiBaseUrl);
  }

  /// Última vez em que o upload do SQLite para a API de manutenção concluiu com sucesso.
  Future<DateTime?> getUltimaSincronizacaoBancoApi() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kUltimaSyncBancoApiMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> registrarUltimaSincronizacaoBancoApiComSucesso() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _kUltimaSyncBancoApiMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Última exibição do lembrete “há mais de 24h sem sincronizar” (evita spam).
  Future<DateTime?> getUltimoAvisoSyncBancoAtrasado() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kUltimoAvisoSyncBancoAtrasadoMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setUltimoAvisoSyncBancoAtrasado(DateTime instante) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _kUltimoAvisoSyncBancoAtrasadoMs,
      instante.millisecondsSinceEpoch,
    );
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
