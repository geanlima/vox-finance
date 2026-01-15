import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV3NotasRapidas implements DbMigration {
  @override
  int get version => 3;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notas_rapidas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texto TEXT NOT NULL,
        concluida INTEGER NOT NULL DEFAULT 0,
        ordem INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT NOT NULL
      );
    ''');
  }
}
