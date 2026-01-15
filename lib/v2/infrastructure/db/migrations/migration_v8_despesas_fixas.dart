import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV8DespesasFixas implements DbMigration {
  @override
  int get version => 8;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS despesas_fixas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor_centavos INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'a_pagar',
        ano_ref INTEGER NOT NULL,
        mes_ref INTEGER NOT NULL,
        categoria_id INTEGER,
        forma_pagamento_id INTEGER,
        data_pagamento_iso TEXT,
        repetir_1_mes INTEGER NOT NULL DEFAULT 0,
        ajustar_data_pagamento INTEGER NOT NULL DEFAULT 0,
        dia_renovacao INTEGER,
        recibo_path TEXT,
        criado_em TEXT NOT NULL DEFAULT (datetime('now')),
        atualizado_em TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_despesasfixas_ano_mes
      ON despesas_fixas(ano_ref, mes_ref);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_despesasfixas_status
      ON despesas_fixas(status);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_despesasfixas_categoria
      ON despesas_fixas(categoria_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_despesasfixas_forma_pag
      ON despesas_fixas(forma_pagamento_id);
    ''');
  }
}
