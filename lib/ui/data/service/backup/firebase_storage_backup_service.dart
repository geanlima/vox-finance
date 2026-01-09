import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../database/database_backup_service.dart';
import '../db_service.dart';
import 'backup_provider.dart';

class FirebaseStorageBackupService implements BackupProvider {
  FirebaseStorageBackupService._();
  static final instance = FirebaseStorageBackupService._();

  @override
  String get key => 'firebase_storage';

  @override
  String get nome => 'Firebase Storage';

  final _storage = FirebaseStorage.instance;

  Reference _ref(String uid) => _storage.ref('backups/$uid/vox_finance.db');

  @override
  Future<void> backupTudo({required String userId}) async {
    final file = await DatabaseBackupService.criarBackup();
    if (file == null) return;

    await _ref(userId).putFile(file);
  }

  @override
  Future<bool> restaurarTudo({required String userId}) async {
    final ref = _ref(userId);

    try {
      await ref.getMetadata();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }

    await DbService.instance.close();

    final dbFile = await DatabaseBackupService.getDatabaseFile();
    final tmp = File('${dbFile.path}.tmp');

    await ref.writeToFile(tmp);

    if (!await tmp.exists() || await tmp.length() == 0) {
      await DbService.instance.reopen();
      return false;
    }

    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    await tmp.rename(dbFile.path);
    await DbService.instance.reopen();
    return true;
  }

  @override
  Future<DateTime?> ultimaAtualizacao({required String userId}) async {
    final meta = await _ref(userId).getMetadata();
    return meta.updated;
  }
}
