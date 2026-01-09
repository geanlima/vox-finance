import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_config.dart';
import '../service/db_service.dart';

class DatabaseBackupService {
  static Future<File> getDatabaseFile() async {
    final dbPath = await DatabaseConfig.getDatabasePath();
    return File(dbPath);
  }

  /// cria um arquivo de backup (cópia) em Documents
  static Future<File?> criarBackup() async {
    await DbService.instance.close();

    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      await DbService.instance.reopen();
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final backupPath = p.join(dir.path, 'vox_finance_backup_$ts.db');

    final backupFile = await dbFile.copy(backupPath);

    await DbService.instance.reopen();
    return backupFile;
  }

  /// substitui o banco local por um arquivo baixado/importado (de forma atômica)
  static Future<void> restaurarFromFile(File novoBanco) async {
    if (!await novoBanco.exists()) return;

    await DbService.instance.close();

    final dbFile = await getDatabaseFile();
    final tmpPath = '${dbFile.path}.tmp';

    // 1) copia para tmp
    final tmpFile = await novoBanco.copy(tmpPath);

    // (mínimo) valida se baixou/copiou algo
    final len = await tmpFile.length();
    if (len <= 0) {
      try {
        await tmpFile.delete();
      } catch (_) {}
      await DbService.instance.reopen();
      return;
    }

    // 2) substitui o db real
    try {
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    } catch (_) {}

    await tmpFile.rename(dbFile.path);

    await DbService.instance.reopen();
  }
}
