import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV10Parcelamentos implements DbMigration {
  @override
  int get version => 10;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parcelamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        -- colunas do seu print
        data_compra_iso TEXT NOT NULL,          -- "Data da compra" (yyyy-MM-dd)
        descricao TEXT NOT NULL,                -- "Descrição"
        categoria_id INTEGER,                   -- "Categoria"

        numero_parcela INTEGER NOT NULL,        -- "N Parcela" 1..N
        total_parcelas INTEGER NOT NULL,        -- para referência do parcelamento
        valor_parcela_centavos INTEGER NOT NULL DEFAULT 0, -- "Valor da parcela"

        status TEXT NOT NULL DEFAULT 'a_pagar', -- "Status" a_pagar|pago
        data_pagamento_iso TEXT,                -- "Pagamento" (quando pago)

        ano_ref INTEGER NOT NULL,               -- "Mês de referência"
        mes_ref INTEGER NOT NULL,

        forma_pagamento_id INTEGER,             -- "Forma de pagamento"
        duplicar_parcela INTEGER NOT NULL DEFAULT 0, -- "Duplicar parcela" (0/1)

        criado_em TEXT NOT NULL DEFAULT (datetime('now')),
        atualizado_em TEXT,

        FOREIGN KEY(categoria_id) REFERENCES categorias(id),
        FOREIGN KEY(forma_pagamento_id) REFERENCES formas_pagamento(id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parc_ano_mes
      ON parcelamentos (ano_ref, mes_ref);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parc_fp
      ON parcelamentos (forma_pagamento_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parc_cat
      ON parcelamentos (categoria_id);
    ''');
  }
}
