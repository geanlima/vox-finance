import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_config.dart';
import '../service/db_service.dart';

class DatabaseBackupService {
  static Future<File> getDatabaseFile() async {
    final dbPath = await DatabaseConfig.getDatabasePath();
    return File(dbPath);
  }

  /// Nome sugerido para exportação: `vox_finance_` + data e hora + `.db`.
  /// Ex.: `vox_finance_2026-05-01_14-30-45.db`
  ///
  /// O conteúdo é o **banco SQLite completo** do app (`VACUUM INTO`): lançamentos,
  /// cadastros (categorias, contas, cartões, despesas fixas, investimentos, etc.)
  /// — tudo que está em [DatabaseConfig.dbName], em um único arquivo.
  static String nomeArquivoBackupComDataHora([DateTime? instante]) {
    final t = instante ?? DateTime.now();
    String z(int n) => n.toString().padLeft(2, '0');
    final y = t.year.toString().padLeft(4, '0');
    return 'vox_finance_$y-${z(t.month)}-${z(t.day)}_'
        '${z(t.hour)}-${z(t.minute)}-${z(t.second)}.db';
  }

  /// Caminho seguro para usar em `VACUUM INTO '...'` (Windows / aspas).
  static String _sqlVacuumPath(String fsPath) {
    final normalized = fsPath.replaceAll('\\', '/');
    return normalized.replaceAll("'", "''");
  }

  static Future<bool> _arquivoSqliteSaudavel(File f) async {
    if (!await f.exists() || await f.length() == 0) return false;
    Database? db;
    try {
      db = await openDatabase(f.path, readOnly: true);
      final rows = await db.rawQuery('PRAGMA quick_check;');
      if (rows.isEmpty) return false;
      for (final row in rows) {
        for (final v in row.values) {
          if (v == null) return false;
          if (v.toString().toLowerCase() != 'ok') return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// cria um arquivo de backup (cópia) em Documents
  static Future<File?> criarBackup() async {
    await DbService.instance.close();

    try {
      final dbFile = await getDatabaseFile();
      if (!await dbFile.exists()) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();

      final backupPath = p.join(
        dir.path,
        nomeArquivoBackupComDataHora(),
      );
      final sqlPath = _sqlVacuumPath(backupPath);
      File backupFile;
      try {
        // ✅ Garante que tudo (inclusive WAL) vá para um único arquivo.
        final db = await openDatabase(dbFile.path);
        try {
          try {
            await db.execute('PRAGMA wal_checkpoint(FULL);');
          } catch (_) {}

          // `VACUUM INTO` cria um backup consistente em um arquivo novo.
          await db.execute("VACUUM INTO '$sqlPath';");
        } finally {
          await db.close();
        }
        backupFile = File(backupPath);
      } catch (_) {
        // fallback: cópia simples (pode perder alterações se estiver em WAL)
        backupFile = await dbFile.copy(backupPath);
      }

      return backupFile;
    } finally {
      await DbService.instance.reopen();
    }
  }

  /// Gera uma cópia consistente em pasta temporária, valida com [PRAGMA quick_check]
  /// e só devolve o arquivo se estiver íntegro (não deixa o app sem banco reaberto).
  ///
  /// Uso típico: compartilhar por WhatsApp / salvar nos arquivos do aparelho.
  static Future<File?> exportarParaCompartilhamento() async {
    await DbService.instance.close();

    try {
      final dbFile = await getDatabaseFile();
      if (!await dbFile.exists()) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final backupPath = p.join(
        tempDir.path,
        nomeArquivoBackupComDataHora(),
      );
      final sqlPath = _sqlVacuumPath(backupPath);

      File? out;
      try {
        final db = await openDatabase(dbFile.path);
        try {
          try {
            await db.execute('PRAGMA wal_checkpoint(FULL);');
          } catch (_) {}

          await db.execute("VACUUM INTO '$sqlPath';");
        } finally {
          await db.close();
        }
        final f = File(backupPath);
        if (await f.exists() && await f.length() > 0) {
          out = f;
        }
      } catch (_) {
        try {
          final db = await openDatabase(dbFile.path);
          try {
            try {
              await db.execute('PRAGMA wal_checkpoint(FULL);');
            } catch (_) {}
          } finally {
            await db.close();
          }
        } catch (_) {}

        try {
          final f = await dbFile.copy(backupPath);
          if (await f.exists() && await f.length() > 0) {
            out = f;
          }
        } catch (_) {
          out = null;
        }
      }

      if (out != null && !await _arquivoSqliteSaudavel(out)) {
        try {
          await out.delete();
        } catch (_) {}
        out = null;
      }

      return out;
    } finally {
      await DbService.instance.reopen();
    }
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
