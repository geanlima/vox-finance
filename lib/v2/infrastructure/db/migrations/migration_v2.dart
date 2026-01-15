import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV2 implements DbMigration {
  @override
  int get version => 2;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // Só adiciona se ainda não existir
    final cols = await db.rawQuery("PRAGMA table_info(movimentos)");
    final hasTags = cols.any((c) => c['name'] == 'tags');
    if (!hasTags) {
      await db.execute('ALTER TABLE movimentos ADD COLUMN tags TEXT;');
    }
  }
}
