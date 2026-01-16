import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV16CacaPrecos extends DbMigration {
  @override
  int get version => 16;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caca_precos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto TEXT NOT NULL,
        loja TEXT,
        link TEXT,

        preco_avista REAL NOT NULL DEFAULT 0,
        preco_parcelado REAL NOT NULL DEFAULT 0,

        num_parcelas INTEGER NOT NULL DEFAULT 0,
        valor_parcela REAL NOT NULL DEFAULT 0,

        frete REAL NOT NULL DEFAULT 0,

        total_avista REAL NOT NULL DEFAULT 0,
        total_parcelado REAL NOT NULL DEFAULT 0,

        observacoes TEXT,

        escolhido INTEGER NOT NULL DEFAULT 0,

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_caca_precos_escolhido ON caca_precos(escolhido);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_caca_precos_produto ON caca_precos(produto);',
    );
  }
}
