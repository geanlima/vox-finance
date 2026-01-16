import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class MigrationV18DesafioFinanceiro extends DbMigration {
  @override
  int get version => 18;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS desafio_financeiro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        mes INTEGER NOT NULL, -- 1..12
        ano INTEGER NOT NULL, -- ex 2026

        desafio TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,        -- 0 nao_iniciado / 1 em_andamento / 2 concluido
        meta_atingida INTEGER NOT NULL DEFAULT 0, -- 0 nao / 1 sim

        observacoes TEXT,

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_desafio_financeiro_mes_ano
      ON desafio_financeiro(mes, ano);
    ''');
  }
}
