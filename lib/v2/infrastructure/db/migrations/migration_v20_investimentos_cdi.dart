import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV20InvestimentosCdi extends DbMigration {
  @override
  int get version => 20;

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
    // Novos campos para layout CDI (faixas + conta corrente + dias não úteis).
    // ALTER TABLE no SQLite adiciona colunas; não dá para adicionar constraint complexa aqui.

    if (!await _columnExists(db, 'investimentos', 'cdi_pct_ate_10k')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN cdi_pct_ate_10k REAL NOT NULL DEFAULT 0;',
      );
    }
    if (!await _columnExists(db, 'investimentos', 'cdi_pct_acima_10k')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN cdi_pct_acima_10k REAL NOT NULL DEFAULT 0;',
      );
    }
    if (!await _columnExists(db, 'investimentos', 'conta_corrente')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN conta_corrente TEXT;',
      );
    }
    if (!await _columnExists(db, 'investimentos', 'considerar_fim_semana')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN considerar_fim_semana INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (!await _columnExists(db, 'investimentos', 'considerar_feriados')) {
      await db.execute(
        'ALTER TABLE investimentos ADD COLUMN considerar_feriados INTEGER NOT NULL DEFAULT 0;',
      );
    }
  }
}

