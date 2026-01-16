import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV13PessoasDevedoras implements DbMigration {
  @override
  int get version => 13;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pessoas_devedoras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        nome_devedor TEXT NOT NULL,
        descricao TEXT NOT NULL,        -- "O que?"
        combinado TEXT NULL,

        data_emprestimo TEXT NOT NULL,  -- yyyy-MM-dd

        valor_total_centavos INTEGER NOT NULL,
        valor_pago_centavos INTEGER NOT NULL DEFAULT 0,

        status TEXT NOT NULL,           -- pendente | pago

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pessoas_status ON pessoas_devedoras(status);',
    );
  }
}
