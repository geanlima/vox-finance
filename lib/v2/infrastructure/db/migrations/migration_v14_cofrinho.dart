import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart'; // ajuste o caminho se necessário (onde está o DbMigration)

class MigrationV14Cofrinho implements DbMigration {
  @override
  int get version => 14;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cofrinho_mensal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ano INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        meta_mes REAL NOT NULL DEFAULT 0,
        valor_guardado REAL NOT NULL DEFAULT 0,
        UNIQUE (ano, mes)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cofrinho_ano ON cofrinho_mensal(ano);',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cofrinho_ano_mes ON cofrinho_mensal(ano, mes);',
    );
  }
}
