import 'package:shared_preferences/shared_preferences.dart';
import 'package:vox_finance/ui/data/service/backup/firebase_storage_backup_service.dart';
import 'package:vox_finance/ui/data/service/backup/google_drive_backup_service.dart';
import 'backup_provider.dart';

class BackupManager {
  static const _prefKey = 'backup_provider';

  BackupManager._();
  static final instance = BackupManager._();

  Future<String> getProviderKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? 'google_drive'; // padrão
  }

  Future<void> setProviderKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key);
  }

  Future<BackupProvider> _provider() async {
    final key = await getProviderKey();

    if (key == 'firebase_storage') {
      // Se quiser, você pode "detectar" se Firebase Storage está habilitado.
      // Como hoje pede billing, você pode deixar indisponível por feature flag.
      return FirebaseStorageBackupService.instance;
    }

    return GoogleDriveBackupService.instance;
  }

  Future<void> backup({required String userId}) async {
    final p = await _provider();
    await p.backupTudo(userId: userId);
  }

  Future<bool> restore({required String userId}) async {
    final p = await _provider();
    return p.restaurarTudo(userId: userId);
  }

  Future<DateTime?> lastUpdate({required String userId}) async {
    final p = await _provider();
    return p.ultimaAtualizacao(userId: userId);
  }
}
