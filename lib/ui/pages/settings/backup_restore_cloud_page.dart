// ignore_for_file: deprecated_member_use, unused_element, control_flow_in_finally

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ ajuste o path conforme seu projeto
import 'package:vox_finance/ui/data/service/backup/backup_manager.dart';

class BackupRestoreCloudPage extends StatefulWidget {
  const BackupRestoreCloudPage({super.key});

  @override
  State<BackupRestoreCloudPage> createState() => _BackupRestoreCloudPageState();
}

class _BackupRestoreCloudPageState extends State<BackupRestoreCloudPage> {
  bool _loading = false;

  DateTime? _ultimaAtualizacao;
  int? _tamanhoBytes;

  String _providerKey = 'google_drive';

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? '';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }

  String _fmtDate(DateTime dt) {
    return DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);
  }

  String get _providerNome =>
      _providerKey == 'google_drive' ? 'Google Drive' : 'Firebase Storage';

  bool get _firebaseIndisponivel =>
      _providerKey == 'firebase_storage'; // hoje pede billing

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _providerKey = await BackupManager.instance.getProviderKey();
      if (mounted) setState(() {});
      await _carregarMetadata();
    } catch (e) {
      _snack('Erro ao inicializar backup: $e');
    }
  }

  Future<void> _setProvider(String key) async {
    setState(() => _loading = true);
    try {
      await BackupManager.instance.setProviderKey(key);
      _providerKey = key;
      await _carregarMetadata();
    } catch (e) {
      _snack('Falha ao trocar provedor: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _carregarMetadata() async {
    if (_uid.isEmpty) return;

    // Se Firebase estiver selecionado e você sabe que não tem billing,
    // já mostra como indisponível sem tentar.
    if (_firebaseIndisponivel) {
      if (!mounted) return;
      setState(() {
        _ultimaAtualizacao = null;
        _tamanhoBytes = null;
      });
      return;
    }

    try {
      final date = await BackupManager.instance.lastUpdate(userId: _uid);

      if (!mounted) return;
      setState(() {
        _ultimaAtualizacao = date;
        _tamanhoBytes = null; // opcional: dá pra buscar depois
      });
    } catch (e) {
      _snack('Erro ao consultar backup: $e');
    }
  }

  Future<void> _fazerBackup() async {
    if (_uid.isEmpty) {
      _snack('Você precisa estar logado para usar backup na nuvem.');
      return;
    }

    if (_firebaseIndisponivel) {
      _snack(
        'Firebase Storage está indisponível sem billing. Use Google Drive.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await BackupManager.instance.backup(userId: _uid);
      await _carregarMetadata();
      _snack('Backup enviado com sucesso!');
    } catch (e) {
      _snack('Falha ao enviar backup: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restaurarBackup() async {
    if (_uid.isEmpty) {
      if (!mounted) return;
      _snack('Você precisa estar logado para restaurar da nuvem.');
      return;
    }

    if (_firebaseIndisponivel) {
      if (!mounted) return;
      _snack(
        'Firebase Storage está indisponível sem billing. Use Google Drive.',
      );
      return;
    }

    // ✅ usa dialogContext para fechar o dialog com segurança
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurar backup'),
          content: Text(
            'Provedor: $_providerNome\n\n'
            'Isso vai substituir o banco local pelo backup da nuvem.\n\n'
            'Tem certeza que deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    // ✅ depois de await, sempre valide
    if (!mounted) return;
    if (ok != true) return;

    setState(() => _loading = true);

    try {
      final restored = await BackupManager.instance.restore(userId: _uid);
      if (!mounted) return;

      await _carregarMetadata();
      if (!mounted) return;

      if (restored) {
        _snack('Backup restaurado! (banco local atualizado)');
      } else {
        _snack('Nenhum backup encontrado para este usuário.');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Falha ao restaurar backup: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Não logado';

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restauração (Nuvem)')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(email),
                subtitle: Text(
                  _uid.isEmpty ? 'Faça login para usar a nuvem' : 'UID: $_uid',
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Provedor de Backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _providerKey,
                      items: const [
                        DropdownMenuItem(
                          value: 'google_drive',
                          child: Text('Google Drive (recomendado)'),
                        ),
                        DropdownMenuItem(
                          value: 'firebase_storage',
                          child: Text('Firebase Storage (precisa billing)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        _setProvider(v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Escolha o provedor',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Backup na nuvem ($_providerNome)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    if (_firebaseIndisponivel)
                      Text(
                        'Firebase Storage está indisponível sem billing.\n'
                        'Selecione Google Drive para usar backup na nuvem.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (_ultimaAtualizacao == null)
                      Text(
                        'Nenhum backup encontrado na nuvem.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Último backup: ${_fmtDate(_ultimaAtualizacao!)}',
                          ),
                          const SizedBox(height: 4),
                          if (_tamanhoBytes != null)
                            Text('Tamanho: ${_fmtBytes(_tamanhoBytes!)}'),
                        ],
                      ),

                    const SizedBox(height: 16),

                    FilledButton.icon(
                      onPressed: _uid.isEmpty ? null : _fazerBackup,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Fazer backup na nuvem'),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed:
                          (_uid.isEmpty ||
                                  _firebaseIndisponivel ||
                                  _ultimaAtualizacao == null)
                              ? null
                              : _restaurarBackup,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Restaurar backup da nuvem'),
                    ),
                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: _uid.isEmpty ? null : _carregarMetadata,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar status'),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
