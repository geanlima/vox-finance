// core/database/migrations/migration_v1.dart
import 'package:sqflite/sqflite.dart';

class MigrationV1 {
  static Future<void> create(Database db) async {
    // CONTAS BANCÁRIAS
    await db.execute('''
      CREATE TABLE conta_bancaria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        banco TEXT,
        agencia TEXT,
        numero TEXT,
        tipo TEXT,
        ativa INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // LANÇAMENTOS
    await db.execute('''
      CREATE TABLE lancamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        valor REAL NOT NULL,
        descricao TEXT NOT NULL,
        forma_pagamento INTEGER NOT NULL,
        data_hora INTEGER NOT NULL,
        pagamento_fatura INTEGER NOT NULL,
        pago INTEGER NOT NULL,
        data_pagamento INTEGER,
        categoria INTEGER NOT NULL,
        grupo_parcelas TEXT,
        parcela_numero INTEGER,
        parcela_total INTEGER,
        id_cartao INTEGER,
        id_conta INTEGER
      );
    ''');

    // CONTAS A PAGAR
    await db.execute('''
      CREATE TABLE conta_pagar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL,
        data_vencimento INTEGER NOT NULL,
        pago INTEGER NOT NULL,
        data_pagamento INTEGER,
        parcela_numero INTEGER,
        parcela_total INTEGER,
        grupo_parcelas TEXT NOT NULL
      );
    ''');

    // CARTÕES DE CRÉDITO
    await db.execute('''
      CREATE TABLE cartao_credito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        bandeira TEXT NOT NULL,
        ultimos4 TEXT NOT NULL,
        foto_path TEXT,
        dia_vencimento INTEGER,
        tipo INTEGER DEFAULT 0,
        controla_fatura INTEGER DEFAULT 1,
        limite REAL,
        dia_fechamento INTEGER
      );
    ''');

    // USUÁRIOS
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        nome TEXT,
        senha TEXT NOT NULL,
        foto_path TEXT,
        criado_em TEXT NOT NULL
      );
    ''');
  }
}
