import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV7Ganhos implements DbMigration {
  @override
  int get version => 7;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ganhos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor_centavos INTEGER NOT NULL,
        data_iso TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pendente','recebido')),
        ano_ref INTEGER NOT NULL,
        mes_ref INTEGER NOT NULL,
        criado_em TEXT NOT NULL DEFAULT (datetime('now')),
        atualizado_em TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ganhos_ano_mes
      ON ganhos (ano_ref, mes_ref);
    ''');
  }
}
