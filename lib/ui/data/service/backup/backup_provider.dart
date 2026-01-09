abstract class BackupProvider {
  String get key; // ex: 'google_drive', 'firebase_storage'
  String get nome; // ex: 'Google Drive'

  Future<void> backupTudo({required String userId});
  Future<bool> restaurarTudo({required String userId});
  Future<DateTime?> ultimaAtualizacao({required String userId});
}
