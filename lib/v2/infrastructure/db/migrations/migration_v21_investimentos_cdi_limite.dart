import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV21InvestimentosCdiLimite extends DbMigration {
  @override
  int get version => 21;

  Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final r = await db.rawQuery("PRAGMA table_info($table);");
    return r.any((e) => e['name'] == column);
  }

  @override
  Future<void> up(DatabaseExecutor db) async {
    if (!await _columnExists(db, 'investimentos', 'cdi_limite_faixa')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN cdi_limite_faixa REAL NOT NULL DEFAULT 10000;',
      );
    }
  }
}

