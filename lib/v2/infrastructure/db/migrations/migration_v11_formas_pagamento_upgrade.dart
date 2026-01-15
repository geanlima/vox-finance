import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV11FormasPagamentoUpgrade implements DbMigration {
  @override
  int get version => 11;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // SQLite não tem "ADD COLUMN IF NOT EXISTS", então fazemos try/catch
    Future<void> add(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // coluna já existe -> ignora
      }
    }

    await add(
      "ALTER TABLE formas_pagamento ADD COLUMN tipo TEXT NOT NULL DEFAULT 'outros';",
    );
    await add(
      "ALTER TABLE formas_pagamento ADD COLUMN principal INTEGER NOT NULL DEFAULT 0;",
    );
    await add("ALTER TABLE formas_pagamento ADD COLUMN alias TEXT;");
    await add(
      "ALTER TABLE formas_pagamento ADD COLUMN limite_centavos INTEGER;",
    );
    await add(
      "ALTER TABLE formas_pagamento ADD COLUMN dia_fechamento INTEGER;",
    );
    await add(
      "ALTER TABLE formas_pagamento ADD COLUMN dia_vencimento INTEGER;",
    );
  }
}
