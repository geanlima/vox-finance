// ignore_for_file: unused_element

import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart'; // ajuste o path se necessário

class MigrationV12Dividas implements DbMigration {
  @override
  int get version => 12;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dividas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT NOT NULL, -- 'ativo' | 'quitado' | 'cancelado'
        credor TEXT NOT NULL,
        descricao TEXT NOT NULL,

        categoria_id INTEGER NULL,
        data_divida TEXT NOT NULL, -- ISO yyyy-mm-dd
        data_pagamento TEXT NULL,  -- ISO yyyy-mm-dd

        ano_ref INTEGER NOT NULL,
        mes_ref INTEGER NOT NULL,

        forma_pagamento_id INTEGER NULL,

        valor_parcela_centavos INTEGER NOT NULL,
        parcelas_total INTEGER NOT NULL,
        parcelas_pendentes INTEGER NOT NULL,

        repetir_1_mes INTEGER NOT NULL DEFAULT 0,

        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dividas_ref ON dividas(ano_ref, mes_ref);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dividas_status ON dividas(status);',
    );
  }
}
