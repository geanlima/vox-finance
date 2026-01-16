import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart'; // se você já criou este arquivo (recomendado). Se não, ajuste para onde está seu DbMigration.

class MigrationV15DesejosCompras implements DbMigration {
  @override
  int get version => 15;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS desejos_compras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto TEXT NOT NULL,
        categoria TEXT,
        valor REAL NOT NULL DEFAULT 0,
        prioridade INTEGER NOT NULL DEFAULT 2, -- 1=Essencial, 2=Importante, 3=Desejo
        link_compra TEXT,
        comprado INTEGER NOT NULL DEFAULT 0, -- 0=false, 1=true
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_desejos_compras_comprado ON desejos_compras(comprado);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_desejos_compras_prioridade ON desejos_compras(prioridade);',
    );
  }
}
