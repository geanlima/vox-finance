import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';

class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();

  factory DbService() => instance;

  Database? _db;

  Future<Database> get db async {
    _db ??= await DatabaseInitializer.initialize();
    return _db!;
  }

  /// ✅ Força o SQLite (WAL) a consolidar alterações no arquivo .db
  Future<void> checkpoint() async {
    final d = _db;
    if (d != null && d.isOpen) {
      try {
        await d.execute('PRAGMA wal_checkpoint(FULL);');
      } catch (_) {
        // se não estiver em WAL ou der erro, ignora
      }
    }
  }

  Future<void> close() async {
    final d = _db;
    if (d != null && d.isOpen) {
      // ✅ garante consistência antes de copiar o arquivo
      await checkpoint();

      await d.close();
      _db = null;
    }
  }

  Future<void> reopen() async {
    _db = await DatabaseInitializer.initialize();
  }
}
