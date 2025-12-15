// core/database/migrations/migration_v1.dart
import 'package:sqflite/sqflite.dart';

class MigrationV1 {
  static Future<void> create(Database db) async {
    // =========================
    // CONTAS BANCÁRIAS
    // =========================
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

    // =========================
    // LANÇAMENTOS
    // já com id_cartao, id_conta, tipo_movimento, id_categoria_personalizada
    // =========================
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
        id_conta INTEGER,
        tipo_movimento INTEGER NOT NULL DEFAULT 1,
        id_categoria_personalizada INTEGER
      );
    ''');

    // =========================
    // CONTAS A PAGAR
    // já com forma_pagamento, id_cartao, id_conta, id_lancamento
    // =========================
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
        grupo_parcelas TEXT NOT NULL,
        forma_pagamento INTEGER,
        id_cartao INTEGER,
        id_conta INTEGER,
        id_lancamento INTEGER
      );
    ''');

    // =========================
    // CARTÕES DE CRÉDITO
    // já com tipo, permite_parcelamento, controla_fatura, limite, dia_fechamento
    // =========================
    await db.execute('''
      CREATE TABLE cartao_credito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        bandeira TEXT NOT NULL,
        ultimos4 TEXT NOT NULL,
        foto_path TEXT,
        dia_vencimento INTEGER,
        tipo INTEGER DEFAULT 0,
        permite_parcelamento INTEGER DEFAULT 1,
        controla_fatura INTEGER DEFAULT 1,
        limite REAL,
        dia_fechamento INTEGER
      );
    ''');

    // =========================
    // USUÁRIOS
    // =========================
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

    // =========================
    // FONTES_RENDA
    // já com valor_base, fixa, dia_previsto, ativa, incluir_na_renda_diaria
    // =========================
    await db.execute('''
      CREATE TABLE fontes_renda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor_base REAL NOT NULL DEFAULT 0,
        fixa INTEGER NOT NULL DEFAULT 1,
        dia_previsto INTEGER,
        ativa INTEGER NOT NULL DEFAULT 1,
        incluir_na_renda_diaria INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // =========================
    // DESTINOS_RENDA
    // já com ativo
    // =========================
    await db.execute('''
      CREATE TABLE destinos_renda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_fonte INTEGER NOT NULL,
        nome TEXT NOT NULL,
        percentual REAL NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (id_fonte) REFERENCES fontes_renda (id)
      );
    ''');

    // =========================
    // CATEGORIAS_PERSONALIZADAS
    // =========================
    await db.execute('''
      CREATE TABLE categorias_personalizadas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo_movimento INTEGER NOT NULL,
        cor TEXT
      );
    ''');

    // =========================
    // FATURA_CARTAO
    // =========================
    await db.execute('''
      CREATE TABLE fatura_cartao (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cartao INTEGER NOT NULL,
        ano INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        data_fechamento INTEGER NOT NULL,
        data_vencimento INTEGER NOT NULL,
        valor_total REAL NOT NULL,
        pago INTEGER NOT NULL DEFAULT 0,
        data_pagamento INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE fatura_cartao_lancamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_fatura INTEGER NOT NULL,
        id_lancamento INTEGER NOT NULL
      );
    ''');
  }
}
