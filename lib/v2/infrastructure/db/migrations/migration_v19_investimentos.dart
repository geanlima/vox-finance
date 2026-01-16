import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV19Investimentos extends DbMigration {
  @override
  int get version => 19;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        tipo INTEGER NOT NULL DEFAULT 1,
        instituicao TEXT,
        ativo TEXT NOT NULL,
        categoria TEXT,

        valor_aplicado REAL NOT NULL DEFAULT 0,
        quantidade REAL NOT NULL DEFAULT 0,
        preco_medio REAL NOT NULL DEFAULT 0,

        data_aporte TEXT,
        vencimento TEXT,

        rentabilidade_tipo INTEGER NOT NULL DEFAULT 0,
        rentabilidade_valor REAL NOT NULL DEFAULT 0,

        observacoes TEXT,

        ativo_flag INTEGER NOT NULL DEFAULT 1,

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS ix_investimentos_tipo
      ON investimentos(tipo);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS ix_investimentos_ativo_flag
      ON investimentos(ativo_flag);
    ''');
  }
}
