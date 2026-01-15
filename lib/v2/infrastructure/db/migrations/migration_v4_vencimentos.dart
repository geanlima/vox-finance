import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV4Vencimentos implements DbMigration {
  @override
  int get version => 4;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vencimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        data TEXT NOT NULL,              -- yyyy-MM-dd
        valor_centavos INTEGER,          -- opcional
        observacao TEXT,
        pago INTEGER NOT NULL DEFAULT 0,
        recorrencia TEXT NOT NULL DEFAULT 'nenhuma', -- 'nenhuma' | 'mensal'
        origem_id INTEGER,               -- para recorrência (liga itens gerados)
        criado_em TEXT NOT NULL
      );
    ''');
  }
}
