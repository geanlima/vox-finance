import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/core/service/notifications_service.dart';

/// Avisa (notificação local) quando faz mais de 24h desde o último upload do
/// SQLite para a API, desde que exista **URL do FinTrack IA** em Parâmetros e
/// já tenha havido pelo menos uma sincronização bem-sucedida antes.
class SincronizacaoBancoApiLembreteService {
  SincronizacaoBancoApiLembreteService._();
  static final SincronizacaoBancoApiLembreteService instance =
      SincronizacaoBancoApiLembreteService._();

  static const _intervaloSemSync = Duration(days: 1);
  static const _intervaloEntreAvisos = Duration(days: 1);

  /// Chame ao abrir o FinTrack IA (ex.: `addPostFrameCallback` no chat).
  Future<void> verificarENotificarSeNecessario() async {
    final api = await AppParametrosService.instance.getIaChatApiBaseUrl();
    if (api == null || api.trim().isEmpty) return;

    final ultima =
        await AppParametrosService.instance.getUltimaSincronizacaoBancoApi();
    if (ultima == null) return;

    final agora = DateTime.now();
    if (agora.difference(ultima) < _intervaloSemSync) return;

    final ultimoAviso =
        await AppParametrosService.instance.getUltimoAvisoSyncBancoAtrasado();
    if (ultimoAviso != null &&
        agora.difference(ultimoAviso) < _intervaloEntreAvisos) {
      return;
    }

    await NotificationService.init();
    await NotificationService.requestAndroidPostNotificationsPermission();
    await NotificationService.showSyncBancoApiAtrasado();
    await AppParametrosService.instance.setUltimoAvisoSyncBancoAtrasado(agora);
  }
}
