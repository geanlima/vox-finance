// core/database/migrations/migrations_v2_v15.dart
import 'package:sqflite/sqflite.dart';

class MigrationV2toV15 {
  /// Executa todas as migrações da 2 em diante,
  /// dependendo do [oldVersion] até [newVersion].
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // =========================
    // V4: id_cartao + cartao_credito
    // =========================
    if (oldVersion < 4) {
      await _addColumnSafe(db, 'lancamentos', 'id_cartao', 'INTEGER');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cartao_credito (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descricao TEXT NOT NULL,
          bandeira TEXT NOT NULL,
          ultimos4 TEXT NOT NULL
        );
      ''');
    }

    // =========================
    // V6: foto_path + dia_vencimento no cartão
    // =========================
    if (oldVersion < 6) {
      await _addColumnSafe(db, 'cartao_credito', 'foto_path', 'TEXT');
      await _addColumnSafe(db, 'cartao_credito', 'dia_vencimento', 'INTEGER');
    }

    // =========================
    // V7: tabela USUARIOS
    // =========================
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usuarios (
          id INTEGER PRIMARY KEY,
          email TEXT NOT NULL,
          nome TEXT,
          senha TEXT NOT NULL,
          foto_path TEXT,
          criado_em TEXT NOT NULL
        );
      ''');
    }

    // =========================
    // V8: foto_path em usuários antigos
    // =========================
    if (oldVersion < 8) {
      await _addColumnSafe(db, 'usuarios', 'foto_path', 'TEXT');
    }

    // =========================
    // V9: tipo, permite_parcelamento, limite, dia_fechamento (cartão)
    // =========================
    if (oldVersion < 9) {
      await _addColumnSafe(db, 'cartao_credito', 'tipo', 'INTEGER DEFAULT 0');
      await _addColumnSafe(
        db,
        'cartao_credito',
        'permite_parcelamento',
        'INTEGER DEFAULT 1',
      );
      await _addColumnSafe(db, 'cartao_credito', 'limite', 'REAL');
      await _addColumnSafe(db, 'cartao_credito', 'dia_fechamento', 'INTEGER');
    }

    // =========================
    // V10: controla_fatura
    // =========================
    if (oldVersion < 10) {
      await _addColumnSafe(
        db,
        'cartao_credito',
        'controla_fatura',
        'INTEGER DEFAULT 1',
      );

      try {
        await db.execute('''
          UPDATE cartao_credito
          SET controla_fatura = permite_parcelamento
          WHERE controla_fatura IS NULL
             OR (controla_fatura = 0 AND permite_parcelamento = 1);
        ''');
      } catch (_) {}
    }

    // =========================
    // V11: conta_bancaria + id_conta em lancamentos
    // =========================
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conta_bancaria (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descricao TEXT NOT NULL,
          banco TEXT,
          agencia TEXT,
          numero TEXT,
          tipo TEXT,
          ativa INTEGER NOT NULL DEFAULT 1
        );
      ''');

      await _addColumnSafe(db, 'lancamentos', 'id_conta', 'INTEGER');
    }

    // =========================
    // V13: normaliza nome da coluna 'ultimos4'
    // =========================
    if (oldVersion < 13) {
      try {
        final info = await db.rawQuery('PRAGMA table_info(cartao_credito);');

        final temUltimos4 = info.any(
          (col) => (col['name'] as String).toLowerCase() == 'ultimos4',
        );

        const possiveisAntigos = [
          'ultimo_4_digitos',
          'ultimo_4_digito',
          'ultimos_4_digito',
          'ultimos_4_digitos',
          'ultimos4_digitos',
          'ultimos_4',
          'ultimos_digitos',
        ];

        String? colunaAntiga;
        for (final col in info) {
          final nome = (col['name'] as String).toLowerCase();
          if (possiveisAntigos.contains(nome)) {
            colunaAntiga = col['name'] as String;
            break;
          }
        }

        if (!temUltimos4 && colunaAntiga != null) {
          await db.execute(
            'ALTER TABLE cartao_credito '
            'RENAME COLUMN $colunaAntiga TO ultimos4;',
          );
        }
      } catch (_) {}
    }

    // =========================
    // V14 / V15: garante id_conta em lancamentos
    // =========================
    if (oldVersion < 15) {
      await _addColumnSafe(db, 'lancamentos', 'id_conta', 'INTEGER');
    }

    // =========================
    // V16: id_lancamento em conta_pagar
    // =========================
    if (oldVersion < 16) {
      await _addColumnSafe(db, 'conta_pagar', 'id_lancamento', 'INTEGER');
    }

    // =========================
    // V17: tabelas de fatura de cartão
    // =========================
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fatura_cartao (
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
        CREATE TABLE IF NOT EXISTS fatura_cartao_lancamento (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_fatura INTEGER NOT NULL,
          id_lancamento INTEGER NOT NULL
        );
      ''');
    }

    // =========================
    // V18: tipo_movimento em lancamentos
    // =========================
    if (oldVersion < 18) {
      await _addColumnSafe(
        db,
        'lancamentos',
        'tipo_movimento',
        'INTEGER NOT NULL DEFAULT 1',
      );
    }

    // =========================
    // V19: fontes_renda / destinos_renda
    // =========================
    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fontes_renda (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          valor_base REAL NOT NULL DEFAULT 0,
          fixa INTEGER NOT NULL DEFAULT 1,
          dia_previsto INTEGER,
          ativa INTEGER NOT NULL DEFAULT 1,
          incluir_na_renda_diaria INTEGER NOT NULL DEFAULT 0
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS destinos_renda (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_fonte INTEGER NOT NULL,
          nome TEXT NOT NULL,
          percentual REAL NOT NULL,
          ativo INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (id_fonte) REFERENCES fontes_renda (id)
        );
      ''');
    }

    // =========================
    // V20: ajusta bancos antigos de fontes_renda
    // =========================
    if (oldVersion < 20) {
      await _addColumnSafe(
        db,
        'fontes_renda',
        'valor_base',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnSafe(
        db,
        'fontes_renda',
        'fixa',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnSafe(db, 'fontes_renda', 'dia_previsto', 'INTEGER');
      await _addColumnSafe(
        db,
        'fontes_renda',
        'ativa',
        'INTEGER NOT NULL DEFAULT 1',
      );

      try {
        await db.execute('''
          UPDATE fontes_renda
          SET valor_base = valor_mensal
          WHERE (valor_base IS NULL OR valor_base = 0)
            AND valor_mensal IS NOT NULL;
        ''');
      } catch (_) {}
    }

    // =========================
    // V21: garante 'ativo' em destinos_renda
    // =========================
    if (oldVersion < 21) {
      await _addColumnSafe(
        db,
        'destinos_renda',
        'ativo',
        'INTEGER NOT NULL DEFAULT 1',
      );
    }

    // =========================
    // V22: flag incluir_na_renda_diaria em fontes_renda
    // =========================
    if (oldVersion < 22) {
      await _addColumnSafe(
        db,
        'fontes_renda',
        'incluir_na_renda_diaria',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }

    // =========================
    // V23: categorias_personalizadas
    // =========================
    if (oldVersion < 23) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categorias_personalizadas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          tipo_movimento INTEGER NOT NULL,
          cor TEXT
        );
      ''');
    }

    // =========================
    // V24: id_categoria_personalizada em lancamentos
    // =========================
    if (oldVersion < 24) {
      await _addColumnSafe(
        db,
        'lancamentos',
        'id_categoria_personalizada',
        'INTEGER',
      );
    }

    // =========================
    // V25: forma_pagamento em conta_pagar
    // =========================
    if (oldVersion < 25) {
      await _addColumnSafe(db, 'conta_pagar', 'forma_pagamento', 'INTEGER');
    }

    // =========================
    // V26: id_cartao e id_conta em conta_pagar
    // =========================
    if (oldVersion < 26) {
      await _addColumnSafe(db, 'conta_pagar', 'id_cartao', 'INTEGER');
      await _addColumnSafe(db, 'conta_pagar', 'id_conta', 'INTEGER');
    }

    // =========================
    // V27: tipo_despesa em lancamentos (1=fixed, 2=variable)
    // =========================
    if (oldVersion < 27) {
      await _addColumnSafe(
        db,
        'lancamentos',
        'tipo_despesa',
        'INTEGER NOT NULL DEFAULT 2',
      );

  // (Opcional) Se quiser “pago” e “pagamento_fatura” não mexer, não precisa.
  // Se quiser tentar classificar automaticamente algumas coisas pelo texto, eu recomendo NÃO fazer agora.
}

    // =========================
    // V28: despesas fixas (V1)
    // =========================
    if (oldVersion < 28) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS despesas_fixas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descricao TEXT NOT NULL,
          valor REAL NOT NULL,
          dia_vencimento INTEGER NOT NULL,
          forma_pagamento INTEGER,
          ativo INTEGER NOT NULL DEFAULT 1,
          gerar_automatico INTEGER NOT NULL DEFAULT 1,
          criado_em INTEGER NOT NULL
        );
      ''');
    }

    // =========================
    // V29: investimentos (Bluminers)
    // =========================
    if (oldVersion < 29) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investimento_bluminers_config (
          id INTEGER PRIMARY KEY,
          saldo_inicial REAL NOT NULL DEFAULT 0,
          saldo_inicial_disponivel REAL NOT NULL DEFAULT 0,
          aporte_mensal REAL NOT NULL DEFAULT 0,
          meta REAL,
          criado_em INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS investimento_bluminers_movimentos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data INTEGER NOT NULL,
          tipo INTEGER NOT NULL,
          carteira INTEGER NOT NULL DEFAULT 0,
          valor REAL NOT NULL,
          observacao TEXT,
          origem TEXT,
          id_origem INTEGER,
          criado_em INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS investimento_bluminers_rentabilidade (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data INTEGER NOT NULL,
          percentual REAL NOT NULL,
          rendimento_valor REAL NOT NULL DEFAULT 0,
          criado_em INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_bluminers_rent_data
        ON investimento_bluminers_rentabilidade (data);
      ''');
    }

    // =========================
    // V30: Bluminers (2 saldos: investido x disponível)
    // =========================
    if (oldVersion < 30) {
      await _addColumnSafe(
        db,
        'investimento_bluminers_config',
        'saldo_inicial_disponivel',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnSafe(
        db,
        'investimento_bluminers_movimentos',
        'carteira',
        'INTEGER NOT NULL DEFAULT 0',
      );

      // carteira=1 para movimentos antigos de saque (tipo=1) e rendimento (tipo=2)
      try {
        await db.execute('''
          UPDATE investimento_bluminers_movimentos
          SET carteira = 1
          WHERE tipo IN (1, 2);
        ''');
      } catch (_) {}
    }

    // =========================
    // V31: lembretes (Home)
    // =========================
    if (oldVersion < 31) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lembretes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          titulo TEXT NOT NULL,
          descricao TEXT,
          data_hora INTEGER NOT NULL,
          concluido INTEGER NOT NULL DEFAULT 0,
          criado_em INTEGER NOT NULL
        );
      ''');
    }

    // =========================
    // V32: carteiras de investimento + Bluminers por carteira
    // =========================
    if (oldVersion < 32) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investimento_carteiras (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          layout TEXT NOT NULL DEFAULT 'bluminers',
          criado_em INTEGER NOT NULL
        );
      ''');

      final cnt = await db.rawQuery('SELECT COUNT(*) AS c FROM investimento_carteiras');
      final n = (cnt.first['c'] as int?) ?? 0;
      if (n == 0) {
        await db.insert('investimento_carteiras', {
          'id': 1,
          'nome': 'Carteira principal',
          'layout': 'bluminers',
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        });
      }

      await _addColumnSafe(
        db,
        'investimento_bluminers_movimentos',
        'id_carteira',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnSafe(
        db,
        'investimento_bluminers_rentabilidade',
        'id_carteira',
        'INTEGER NOT NULL DEFAULT 1',
      );

      try {
        await db.execute('DROP INDEX IF EXISTS idx_bluminers_rent_data');
      } catch (_) {}

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_bluminers_rent_carteira_data
        ON investimento_bluminers_rentabilidade (id_carteira, data);
      ''');

      await _migrateBluminersConfigV32(db);
    }

    // =========================
    // V33: código do cartão na API (GET /api/faturas?cartao_id=)
    // =========================
    if (oldVersion < 33) {
      await _addColumnSafe(db, 'cartao_credito', 'codigo_cartao_api', 'TEXT');
    }

    // =========================
    // V34: Subcategorias personalizadas (FK para categorias_personalizadas)
    // =========================
    if (oldVersion < 34) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subcategorias_personalizadas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_categoria_personalizada INTEGER NOT NULL,
          nome TEXT NOT NULL,
          criado_em INTEGER NOT NULL,
          UNIQUE(id_categoria_personalizada, nome)
        );
      ''');

      // FK (melhor esforço): não quebra se o SQLite estiver com foreign_keys off
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_subcat_cat
          ON subcategorias_personalizadas (id_categoria_personalizada);
        ''');
      } catch (_) {}

      await _addColumnSafe(
        db,
        'lancamentos',
        'id_subcategoria_personalizada',
        'INTEGER',
      );

      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_lanc_subcat
          ON lancamentos (id_subcategoria_personalizada);
        ''');
      } catch (_) {}
    }

    // =========================
    // PÓS-MIGRAÇÃO: garante colunas críticas
    // =========================
    await _addColumnSafe(
      db,
      'lancamentos',
      'tipo_movimento',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnSafe(db, 'lancamentos', 'id_conta', 'INTEGER');
    await _addColumnSafe(db, 'lancamentos', 'id_cartao', 'INTEGER');
    await _addColumnSafe(
      db,
      'lancamentos',
      'id_categoria_personalizada',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'lancamentos',
      'id_subcategoria_personalizada',
      'INTEGER',
    );
    await _addColumnSafe(db, 'cartao_credito', 'codigo_cartao_api', 'TEXT');
    await _addColumnSafe(db, 'conta_pagar', 'id_lancamento', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'forma_pagamento', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'id_cartao', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'id_conta', 'INTEGER');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS despesas_fixas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL,
        dia_vencimento INTEGER NOT NULL,
        forma_pagamento INTEGER,
        ativo INTEGER NOT NULL DEFAULT 1,
        gerar_automatico INTEGER NOT NULL DEFAULT 1,
        criado_em INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_config (
        id INTEGER PRIMARY KEY,
        saldo_inicial REAL NOT NULL DEFAULT 0,
        saldo_inicial_disponivel REAL NOT NULL DEFAULT 0,
        aporte_mensal REAL NOT NULL DEFAULT 0,
        meta REAL,
        criado_em INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_movimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data INTEGER NOT NULL,
        tipo INTEGER NOT NULL,
        carteira INTEGER NOT NULL DEFAULT 0,
        valor REAL NOT NULL,
        observacao TEXT,
        origem TEXT,
        id_origem INTEGER,
        criado_em INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_rentabilidade (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data INTEGER NOT NULL,
        percentual REAL NOT NULL,
        rendimento_valor REAL NOT NULL DEFAULT 0,
        criado_em INTEGER NOT NULL
      );
    ''');

    await _addColumnSafe(
      db,
      'investimento_bluminers_movimentos',
      'id_carteira',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnSafe(
      db,
      'investimento_bluminers_rentabilidade',
      'id_carteira',
      'INTEGER NOT NULL DEFAULT 1',
    );
    try {
      await db.execute('DROP INDEX IF EXISTS idx_bluminers_rent_data');
    } catch (_) {}
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bluminers_rent_carteira_data
      ON investimento_bluminers_rentabilidade (id_carteira, data);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_carteiras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        layout TEXT NOT NULL DEFAULT 'bluminers',
        criado_em INTEGER NOT NULL
      );
    ''');
    try {
      final cc = await db.rawQuery('SELECT COUNT(*) AS n FROM investimento_carteiras');
      if (((cc.first['n'] as int?) ?? 0) == 0) {
        await db.insert('investimento_carteiras', {
          'id': 1,
          'nome': 'Carteira principal',
          'layout': 'bluminers',
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (_) {}

    await _migrateBluminersConfigV32(db);

    await _addColumnSafe(
      db,
      'investimento_bluminers_config',
      'saldo_inicial_disponivel',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnSafe(
      db,
      'investimento_bluminers_movimentos',
      'carteira',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lembretes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descricao TEXT,
        data_hora INTEGER NOT NULL,
        concluido INTEGER NOT NULL DEFAULT 0,
        criado_em INTEGER NOT NULL
      );
    ''');
  }

  /// Ajustes que você fazia no `onOpen` (garantir tabelas/colunas).
  static Future<void> ensureTables(Database db) async {
    // USUÁRIOS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        nome TEXT,
        senha TEXT NOT NULL,
        foto_path TEXT,
        criado_em TEXT NOT NULL
      );
    ''');

    await _addColumnSafe(db, 'usuarios', 'senha', 'TEXT');
    await _addColumnSafe(db, 'usuarios', 'foto_path', 'TEXT');

    // CONTA_BANCARIA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conta_bancaria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        banco TEXT,
        agencia TEXT,
        numero TEXT,
        tipo TEXT,
        ativa INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // FONTES_RENDA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fontes_renda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor_base REAL NOT NULL DEFAULT 0,
        fixa INTEGER NOT NULL DEFAULT 1,
        dia_previsto INTEGER,
        ativa INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await _addColumnSafe(
      db,
      'fontes_renda',
      'incluir_na_renda_diaria',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // LEMBRETES
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lembretes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descricao TEXT,
        data_hora INTEGER NOT NULL,
        concluido INTEGER NOT NULL DEFAULT 0,
        criado_em INTEGER NOT NULL
      );
    ''');

    // INVESTIMENTO — CARTEIRAS (layout Bluminers, etc.)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_carteiras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        layout TEXT NOT NULL DEFAULT 'bluminers',
        criado_em INTEGER NOT NULL
      );
    ''');
    try {
      final c = await db.rawQuery('SELECT COUNT(*) AS n FROM investimento_carteiras');
      if (((c.first['n'] as int?) ?? 0) == 0) {
        await db.insert('investimento_carteiras', {
          'id': 1,
          'nome': 'Carteira principal',
          'layout': 'bluminers',
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (_) {}

    // DESTINOS_RENDA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS destinos_renda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_fonte INTEGER NOT NULL,
        nome TEXT NOT NULL,
        percentual REAL NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (id_fonte) REFERENCES fontes_renda (id)
      );
    ''');

    await _addColumnSafe(
      db,
      'destinos_renda',
      'ativo',
      'INTEGER NOT NULL DEFAULT 1',
    );

    // CATEGORIAS_PERSONALIZADAS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias_personalizadas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo_movimento INTEGER NOT NULL,
        cor TEXT
      );
    ''');

    // FATURA_CARTAO
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fatura_cartao (
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
      CREATE TABLE IF NOT EXISTS fatura_cartao_lancamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_fatura INTEGER NOT NULL,
        id_lancamento INTEGER NOT NULL
      );
    ''');

    // Lancamentos / conta_pagar
    await _addColumnSafe(
      db,
      'lancamentos',
      'tipo_movimento',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnSafe(db, 'lancamentos', 'id_conta', 'INTEGER');
    await _addColumnSafe(db, 'lancamentos', 'id_cartao', 'INTEGER');
    await _addColumnSafe(db, 'cartao_credito', 'codigo_cartao_api', 'TEXT');
    await _addColumnSafe(db, 'conta_pagar', 'id_lancamento', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'forma_pagamento', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'id_cartao', 'INTEGER');
    await _addColumnSafe(db, 'conta_pagar', 'id_conta', 'INTEGER');
    await _addColumnSafe(
      db,
      'lancamentos',
      'id_categoria_personalizada',
      'INTEGER',
    );

    // 🔹 POPULA CATEGORIAS PADRÃO (apenas se tabela estiver vazia)
    await _seedCategoriasPadrao(db);

    // INVESTIMENTOS - BLUMINERS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_config (
        id INTEGER PRIMARY KEY,
        saldo_inicial REAL NOT NULL DEFAULT 0,
        saldo_inicial_disponivel REAL NOT NULL DEFAULT 0,
        aporte_mensal REAL NOT NULL DEFAULT 0,
        meta REAL,
        criado_em INTEGER NOT NULL
      );
    ''');

    await _addColumnSafe(
      db,
      'investimento_bluminers_config',
      'saldo_inicial_disponivel',
      'REAL NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_movimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data INTEGER NOT NULL,
        tipo INTEGER NOT NULL,
        carteira INTEGER NOT NULL DEFAULT 0,
        valor REAL NOT NULL,
        observacao TEXT,
        origem TEXT,
        id_origem INTEGER,
        criado_em INTEGER NOT NULL
      );
    ''');

    await _addColumnSafe(
      db,
      'investimento_bluminers_movimentos',
      'carteira',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investimento_bluminers_rentabilidade (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data INTEGER NOT NULL,
        percentual REAL NOT NULL,
        rendimento_valor REAL NOT NULL DEFAULT 0,
        criado_em INTEGER NOT NULL
      );
    ''');

    await _addColumnSafe(
      db,
      'investimento_bluminers_movimentos',
      'id_carteira',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnSafe(
      db,
      'investimento_bluminers_rentabilidade',
      'id_carteira',
      'INTEGER NOT NULL DEFAULT 1',
    );
    try {
      await db.execute('DROP INDEX IF EXISTS idx_bluminers_rent_data');
    } catch (_) {}
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bluminers_rent_carteira_data
      ON investimento_bluminers_rentabilidade (id_carteira, data);
    ''');
    await _migrateBluminersConfigV32(db);
  }

  static Future<void> _migrateBluminersConfigV32(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(investimento_bluminers_config);');
      if (info.isEmpty) return;
      final names = info.map((c) => c['name'] as String).toSet();
      if (names.contains('id_carteira')) return;

      final oldRows = await db.query('investimento_bluminers_config');
      await db.execute('''
        CREATE TABLE investimento_bluminers_config_v32 (
          id_carteira INTEGER PRIMARY KEY NOT NULL,
          saldo_inicial REAL NOT NULL DEFAULT 0,
          saldo_inicial_disponivel REAL NOT NULL DEFAULT 0,
          aporte_mensal REAL NOT NULL DEFAULT 0,
          meta REAL,
          criado_em INTEGER NOT NULL
        );
      ''');

      if (oldRows.isEmpty) {
        await db.insert('investimento_bluminers_config_v32', {
          'id_carteira': 1,
          'saldo_inicial': 0,
          'saldo_inicial_disponivel': 0,
          'aporte_mensal': 0,
          'meta': null,
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final m = oldRows.first;
        final oldId = (m['id'] as int?) ?? 1;
        await db.insert('investimento_bluminers_config_v32', {
          'id_carteira': oldId,
          'saldo_inicial': m['saldo_inicial'],
          'saldo_inicial_disponivel': m['saldo_inicial_disponivel'] ?? 0,
          'aporte_mensal': m['aporte_mensal'] ?? 0,
          'meta': m['meta'],
          'criado_em': m['criado_em'] ?? DateTime.now().millisecondsSinceEpoch,
        });
      }
      await db.execute('DROP TABLE investimento_bluminers_config');
      await db.execute(
        'ALTER TABLE investimento_bluminers_config_v32 RENAME TO investimento_bluminers_config',
      );
    } catch (e) {
      // ignore: avoid_print
      print('migrate bluminers config v32: $e');
    }
  }

  /// Helper genérico para "ALTER TABLE ADD COLUMN" com segurança.
  static Future<void> _addColumnSafe(
    Database db,
    String table,
    String column,
    String columnDef,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table);');
      final exists = info.any(
        (col) => (col['name'] as String).toLowerCase() == column.toLowerCase(),
      );
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $columnDef;');
      }
    } catch (_) {
      // se der erro (ex: tabela não existe ainda), ignoramos silenciosamente
    }
  }

  /// 🔥 SEED de categorias padrão na tabela categorias_personalizadas
  static Future<void> _seedCategoriasPadrao(Database db) async {
    try {
      // Verifica se já existe categoria
      final result = await db.rawQuery('''
        SELECT COUNT(*) AS total 
        FROM categorias_personalizadas
      ''');

      final total = (result.first['total'] as int?) ?? 0;
      if (total > 0) return;

      final batch = db.batch();

      final inserts = [
        'Alimentação',
        'Educação',
        'Família',
        'Finanças Pessoais',
        'Impostos e Taxas',
        'Lazer e Entretenimento',
        'Moradia',
        'Outros',
        'Presentes e Doações',
        'Saúde',
        'Seguros',
        'Tecnologia',
        'Transporte',
        'Vestuário',
      ];

      for (final nome in inserts) {
        batch.insert('categorias_personalizadas', {
          'nome': nome,
          'tipo_movimento': 1, // padrão = despesa
          'cor': null,
        });
      }

      await batch.commit(noResult: true);

      // ignore: avoid_print
      print('✔ Categorias padrão inseridas com sucesso.');
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao inserir categorias padrão: $e');
    }
  }
}
