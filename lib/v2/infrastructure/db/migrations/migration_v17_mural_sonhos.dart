import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV17MuralSonhos extends DbMigration {
  @override
  int get version => 17;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mural_sonhos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,

        imagem_path TEXT,                -- caminho local (ou url futura)
        valor_objetivo REAL NOT NULL DEFAULT 0,

        ano_prazo INTEGER NOT NULL DEFAULT 0,  -- ex: 2026, 2028
        prazo_tipo INTEGER NOT NULL DEFAULT 2, -- 1 curto / 2 medio / 3 longo

        status INTEGER NOT NULL DEFAULT 0,     -- 0 nao bati / 1 bati

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
      );
    ''');

    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_mural_sonhos_ano ON mural_sonhos(ano_prazo);",
    );
    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_mural_sonhos_status ON mural_sonhos(status);",
    );
  }
}