import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Future<void> sincronizarAgora(BuildContext context) async {
    final api = await AppParametrosService.instance.getApiBaseUrl();
    if (!context.mounted) return;

    if (api == null || api.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'URL de integração não configurada. Configure em: Configuração → Parâmetros.',
          ),
        ),
      );
      return;
    }

    // Stub: aqui entra o envio/recebimento real.
    // Por enquanto, só simula a sincronização e mostra feedback.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future<void>(() async {
          await Future.delayed(const Duration(milliseconds: 900));
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        });
        return const AlertDialog(
          title: Text('Sincronizando...'),
          content: SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sincronização concluída (${api.trim()}).')),
    );
  }
}

