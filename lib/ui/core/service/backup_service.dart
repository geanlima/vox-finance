import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vox_finance/ui/data/database/database_backup_service.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  final _storage = FirebaseStorage.instance;

  Reference _refDoUsuario(String uid) {
    return _storage.ref().child('backups').child(uid).child('vox_finance.db');
  }

  /// ☁️ Envia o banco para a nuvem
  Future<void> backupTudo(String uid) async {
    final File? file = await DatabaseBackupService.criarBackup();
    if (file == null) return;

    final ref = _refDoUsuario(uid);

    await ref.putFile(
      file,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
  }

  /// ☁️ Baixa o banco da nuvem e restaura localmente
  Future<bool> restaurarTudo(String uid) async {
    final ref = _refDoUsuario(uid);

    final exists = await _existe(ref);
    if (!exists) return false;

    await DbService.instance.close();

    final dbFile = await DatabaseBackupService.getDatabaseFile();
    final tmpFile = File('${dbFile.path}.tmp');

    // 1) baixa para tmp (seguro)
    await ref.writeToFile(tmpFile);

    // valida mínimo
    final len = await tmpFile.length();
    if (len <= 0) {
      try {
        await tmpFile.delete();
      } catch (_) {}
      await DbService.instance.reopen();
      return false;
    }

    // 2) troca atômica
    try {
      if (await dbFile.exists()) await dbFile.delete();
    } catch (_) {}

    await tmpFile.rename(dbFile.path);

    await DbService.instance.reopen();
    return true;
  }

  Future<bool> _existe(Reference ref) async {
    try {
      await ref.getMetadata();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }
  }

  Future<DateTime?> ultimaAtualizacao(String uid) async {
    final ref = _refDoUsuario(uid);
    try {
      final meta = await ref.getMetadata();
      return meta.updated;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }
}
