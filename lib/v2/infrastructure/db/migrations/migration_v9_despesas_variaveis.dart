import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV9DespesasVariaveis implements DbMigration {
  @override
  int get version => 9;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS despesas_variaveis (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        categoria_id INTEGER,
        data_gasto_iso TEXT,
        valor_centavos INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'a_pagar',
        ano_ref INTEGER NOT NULL,
        mes_ref INTEGER NOT NULL,
        forma_pagamento_id INTEGER,
        criado_em TEXT NOT NULL DEFAULT (datetime('now')),
        atualizado_em TEXT,
        FOREIGN KEY(categoria_id) REFERENCES categorias(id),
        FOREIGN KEY(forma_pagamento_id) REFERENCES formas_pagamento(id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dv_ano_mes
      ON despesas_variaveis (ano_ref, mes_ref);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dv_cat
      ON despesas_variaveis (categoria_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dv_fp
      ON despesas_variaveis (forma_pagamento_id);
    ''');
  }
}
