import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/sync_service.dart';

class SyncIconButton extends StatelessWidget {
  const SyncIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sincronizar',
      icon: const Icon(Icons.sync),
      onPressed: () => SyncService.instance.sincronizarAgora(context),
    );
  }
}

