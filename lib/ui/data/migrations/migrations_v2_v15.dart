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
    // V36: REPARO - se a tabela subcategorias_personalizadas estiver "global"
    // (sem id_categoria_personalizada), reconstrói para o schema 1:N.
    // =========================
    if (oldVersion < 36) {
      try {
        final info = await db.rawQuery(
          'PRAGMA table_info(subcategorias_personalizadas);',
        );
        if (info.isNotEmpty) {
          final cols = info.map((c) => c['name'] as String).toSet();
          final temColCategoria = cols.contains('id_categoria_personalizada');

          if (!temColCategoria) {
            // Escolhe uma categoria padrão (fallback) caso não exista vínculo.
            final catRows = await db.rawQuery(
              'SELECT id FROM categorias_personalizadas ORDER BY id LIMIT 1;',
            );
            final defaultCatId =
                catRows.isNotEmpty ? (catRows.first['id'] as int) : 1;

            // Tabela nova no formato antigo
            await db.execute('''
              CREATE TABLE subcategorias_personalizadas_v36 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_categoria_personalizada INTEGER NOT NULL,
                nome TEXT NOT NULL,
                criado_em INTEGER NOT NULL,
                UNIQUE(id_categoria_personalizada, nome)
              );
            ''');

            // Detecta se existe a tabela de vínculo antiga
            final vincExists = await db.rawQuery('''
              SELECT name
              FROM sqlite_master
              WHERE type='table' AND name='categorias_subcategorias'
              LIMIT 1;
            ''');

            if (vincExists.isNotEmpty) {
              // Migra usando o vínculo (pega a primeira categoria por subcategoria)
              await db.execute('''
                INSERT OR IGNORE INTO subcategorias_personalizadas_v36
                  (id, id_categoria_personalizada, nome, criado_em)
                SELECT
                  s.id,
                  COALESCE(
                    (SELECT MIN(cs.id_categoria_personalizada)
                     FROM categorias_subcategorias cs
                     WHERE cs.id_subcategoria_personalizada = s.id),
                    $defaultCatId
                  ) AS id_categoria_personalizada,
                  s.nome,
                  COALESCE(s.criado_em, ${DateTime.now().millisecondsSinceEpoch})
                FROM subcategorias_personalizadas s;
              ''');
            } else {
              // Migra sem vínculo: atribui categoria padrão
              await db.execute('''
                INSERT OR IGNORE INTO subcategorias_personalizadas_v36
                  (id, id_categoria_personalizada, nome, criado_em)
                SELECT
                  s.id,
                  $defaultCatId,
                  s.nome,
                  COALESCE(s.criado_em, ${DateTime.now().millisecondsSinceEpoch})
                FROM subcategorias_personalizadas s;
              ''');
            }

            // Troca tabelas
            await db.execute('DROP TABLE subcategorias_personalizadas;');
            await db.execute(
              'ALTER TABLE subcategorias_personalizadas_v36 RENAME TO subcategorias_personalizadas;',
            );

            // Recria índice
            try {
              await db.execute('''
                CREATE INDEX IF NOT EXISTS idx_subcat_cat
                ON subcategorias_personalizadas (id_categoria_personalizada);
              ''');
            } catch (_) {}
          }
        }
      } catch (_) {
        // não interrompe upgrade
      }
    }

    // =========================
    // V37: Métricas (limites por categoria/subcategoria) + avisos
    // =========================
    if (oldVersion < 37) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS metricas_limites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ativo INTEGER NOT NULL DEFAULT 1,

          -- período: 'mensal' ou 'semanal'
          periodo_tipo TEXT NOT NULL,
          ano INTEGER NOT NULL,
          mes INTEGER,
          semana INTEGER,

          id_categoria_personalizada INTEGER NOT NULL,
          id_subcategoria_personalizada INTEGER,

          limite_valor REAL NOT NULL,

          -- parâmetros de cálculo
          considerar_somente_pagos INTEGER NOT NULL DEFAULT 1,
          incluir_futuros INTEGER NOT NULL DEFAULT 0,
          ignorar_pagamento_fatura INTEGER NOT NULL DEFAULT 1,

          -- alertas (percentual de consumo do limite)
          alerta_pct1 INTEGER NOT NULL DEFAULT 80,
          alerta_pct2 INTEGER NOT NULL DEFAULT 100,

          criado_em INTEGER NOT NULL,
          atualizado_em INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS uq_metricas_periodo_cat_sub
        ON metricas_limites (
          periodo_tipo,
          ano,
          COALESCE(mes, -1),
          COALESCE(semana, -1),
          id_categoria_personalizada,
          COALESCE(id_subcategoria_personalizada, -1)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_metricas_cat
        ON metricas_limites (id_categoria_personalizada);
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_metricas_subcat
        ON metricas_limites (id_subcategoria_personalizada);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS metricas_alertas_disparados (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          metrica_id INTEGER NOT NULL,
          periodo_chave TEXT NOT NULL,
          nivel INTEGER NOT NULL, -- 1 ou 2
          disparado_em INTEGER NOT NULL,
          UNIQUE(metrica_id, periodo_chave, nivel)
        );
      ''');
    }

    // =========================
    // V38: Cache local de faturas da integração (evita consultar API sempre)
    // =========================
    if (oldVersion < 38) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS integracao_faturas_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_key TEXT NOT NULL,

          id_cartao_local INTEGER NOT NULL,
          codigo_cartao_api TEXT NOT NULL,
          ano INTEGER NOT NULL,
          mes INTEGER NOT NULL,

          fatura_api_id TEXT,
          descricao TEXT,
          valor_total REAL NOT NULL,
          data_vencimento INTEGER,
          data_fechamento INTEGER,
          pago INTEGER,

          importado_em INTEGER NOT NULL,

          UNIQUE(source_key)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_int_faturas_cartao_periodo
        ON integracao_faturas_cache (id_cartao_local, ano, mes);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS integracao_faturas_cache_itens (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_fatura_cache INTEGER NOT NULL,
          item_api_id TEXT,
          descricao TEXT NOT NULL,
          valor REAL NOT NULL,
          data_hora INTEGER,
          categoria TEXT,

          FOREIGN KEY (id_fatura_cache) REFERENCES integracao_faturas_cache(id)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_int_faturas_itens_fatura
        ON integracao_faturas_cache_itens (id_fatura_cache);
      ''');
    }

    // =========================
    // V39: Consolidação - vínculo item(importado) -> lançamento(local)
    // =========================
    if (oldVersion < 39) {
      await _addColumnSafe(
        db,
        'integracao_faturas_cache_itens',
        'id_lancamento_local',
        'INTEGER',
      );
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_int_faturas_itens_lanc
          ON integracao_faturas_cache_itens (id_lancamento_local);
        ''');
      } catch (_) {}
    }

    // =========================
    // V40: Fechamento de fatura salva (gera lançamento de pagamento)
    // =========================
    if (oldVersion < 40) {
      await _addColumnSafe(
        db,
        'integracao_faturas_cache',
        'fechada_em',
        'INTEGER',
      );
      await _addColumnSafe(
        db,
        'integracao_faturas_cache',
        'id_lancamento_fatura',
        'INTEGER',
      );
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_int_faturas_fechada
          ON integracao_faturas_cache (fechada_em);
        ''');
      } catch (_) {}
    }

    // =========================
    // V41: Monitoramento de preços
    // =========================
    if (oldVersion < 41) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monitoramento_precos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          produto TEXT NOT NULL,
          preco REAL NOT NULL,
          loja TEXT,
          url TEXT,
          criado_em INTEGER NOT NULL,
          atualizado_em INTEGER NOT NULL
        );
      ''');
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_produto
          ON monitoramento_precos (produto);
        ''');
      } catch (_) {}
    }

    // =========================
    // V42: Foto no monitoramento de preços
    // =========================
    if (oldVersion < 42) {
      await _addColumnSafe(db, 'monitoramento_precos', 'foto_path', 'TEXT');
    }

    // =========================
    // V43: Lojas/ofertas por produto (monitoramento)
    // =========================
    if (oldVersion < 43) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monitoramento_precos_ofertas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_monitoramento INTEGER NOT NULL,
          loja TEXT,
          url TEXT,
          preco REAL NOT NULL,
          criado_em INTEGER NOT NULL,
          atualizado_em INTEGER NOT NULL
        );
      ''');
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_ofertas_monitoramento
          ON monitoramento_precos_ofertas (id_monitoramento);
        ''');
      } catch (_) {}

      // Migração leve: se já existir (da versão antiga) loja/url/preco no produto,
      // cria 1 oferta inicial para não perder informação.
      try {
        final produtos = await db.query(
          'monitoramento_precos',
          columns: ['id', 'loja', 'url', 'preco', 'criado_em', 'atualizado_em'],
        );
        for (final p in produtos) {
          final id = (p['id'] as num?)?.toInt();
          if (id == null) continue;
          final loja = (p['loja'] as String?)?.trim();
          final url = (p['url'] as String?)?.trim();
          final preco = (p['preco'] as num?)?.toDouble() ?? 0.0;
          final temAlgumDado =
              preco > 0 || (loja != null && loja.isNotEmpty) || (url != null && url.isNotEmpty);
          if (!temAlgumDado) continue;

          await db.insert(
            'monitoramento_precos_ofertas',
            {
              'id_monitoramento': id,
              'loja': (loja != null && loja.isNotEmpty) ? loja : null,
              'url': (url != null && url.isNotEmpty) ? url : null,
              'preco': preco > 0 ? preco : 0.0,
              'criado_em': (p['criado_em'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
              'atualizado_em': (p['atualizado_em'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (_) {}
    }

    // =========================
    // V44: Histórico de preços (por loja/oferta)
    // =========================
    if (oldVersion < 44) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monitoramento_precos_ofertas_historico (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_oferta INTEGER NOT NULL,
          preco REAL NOT NULL,
          criado_em INTEGER NOT NULL
        );
      ''');
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_hist_oferta
          ON monitoramento_precos_ofertas_historico (id_oferta, criado_em);
        ''');
      } catch (_) {}

      // seed: cria um ponto inicial para cada oferta existente
      try {
        final ofertas = await db.query(
          'monitoramento_precos_ofertas',
          columns: ['id', 'preco', 'criado_em', 'atualizado_em'],
        );
        for (final o in ofertas) {
          final idOferta = (o['id'] as num?)?.toInt();
          if (idOferta == null) continue;
          final preco = (o['preco'] as num?)?.toDouble() ?? 0.0;
          final whenMs =
              (o['atualizado_em'] as num?)?.toInt() ??
              (o['criado_em'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch;
          await db.insert(
            'monitoramento_precos_ofertas_historico',
            {'id_oferta': idOferta, 'preco': preco, 'criado_em': whenMs},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (_) {}
    }

    // =========================
    // V45: Planejamento de gastos (viagem, evento, churrasco, etc.)
    // =========================
    if (oldVersion < 45) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planejamentos_despesa (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          titulo TEXT NOT NULL,
          local TEXT,
          data_inicio INTEGER NOT NULL,
          data_fim INTEGER NOT NULL,
          notas TEXT,
          criado_em INTEGER NOT NULL,
          atualizado_em INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planejamentos_despesa_itens (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          planejamento_id INTEGER NOT NULL,
          descricao TEXT NOT NULL,
          valor REAL NOT NULL DEFAULT 0,
          id_categoria_personalizada INTEGER,
          id_subcategoria_personalizada INTEGER,
          data_referencia INTEGER,
          ordem INTEGER NOT NULL DEFAULT 0,
          criado_em INTEGER NOT NULL,
          FOREIGN KEY (planejamento_id) REFERENCES planejamentos_despesa (id) ON DELETE CASCADE
        );
      ''');
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_planej_desp_itens_planejamento
          ON planejamentos_despesa_itens (planejamento_id, ordem);
        ''');
      } catch (_) {}
    }

    // =========================
    // V46: Vínculo item planejamento → lançamento
    // =========================
    if (oldVersion < 46) {
      await _addColumnSafe(
        db,
        'planejamentos_despesa_itens',
        'id_lancamento',
        'INTEGER',
      );
    }

    // =========================
    // V47: Pessoas que me devem (empréstimos a receber)
    // =========================
    if (oldVersion < 47) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pessoas_me_devem (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          data_emprestimo INTEGER NOT NULL,
          valor_total REAL NOT NULL,
          valor_recebido REAL NOT NULL DEFAULT 0,
          observacao TEXT,
          criado_em INTEGER NOT NULL
        );
      ''');
    }

    // =========================
    // V48: Métricas por forma de pagamento/cartão
    // =========================
    if (oldVersion < 48) {
      await _addColumnSafe(db, 'metricas_limites', 'forma_pagamento', 'INTEGER');
      await _addColumnSafe(db, 'metricas_limites', 'id_cartao', 'INTEGER');
      await _addColumnSafe(db, 'metricas_limites', 'id_conta', 'INTEGER');

      // Recria índice único para permitir múltiplas métricas
      // no mesmo período/categoria, mas com filtros diferentes (ex.: por cartão).
      try {
        await db.execute('DROP INDEX IF EXISTS uq_metricas_periodo_cat_sub;');
      } catch (_) {}

      try {
        await db.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS uq_metricas_periodo_cat_sub
          ON metricas_limites (
            periodo_tipo,
            ano,
            COALESCE(mes, -1),
            COALESCE(semana, -1),
            id_categoria_personalizada,
            COALESCE(id_subcategoria_personalizada, -1),
            COALESCE(forma_pagamento, -1),
            COALESCE(id_cartao, -1),
            COALESCE(id_conta, -1)
          );
        ''');
      } catch (_) {}

      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_metricas_forma_pagamento
          ON metricas_limites (forma_pagamento);
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_metricas_id_cartao
          ON metricas_limites (id_cartao);
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_metricas_id_conta
          ON metricas_limites (id_conta);
        ''');
      } catch (_) {}
    }

    // =========================
    // V49: Métricas por tipo (despesa/receita) e base (categoria/forma)
    // =========================
    if (oldVersion < 49) {
      await _addColumnSafe(
        db,
        'metricas_limites',
        'tipo_movimento',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnSafe(
        db,
        'metricas_limites',
        'escopo',
        "TEXT NOT NULL DEFAULT 'categoria'",
      );

      // Recria índice único incluindo tipo_movimento + escopo
      try {
        await db.execute('DROP INDEX IF EXISTS uq_metricas_periodo_cat_sub;');
      } catch (_) {}

      try {
        await db.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS uq_metricas_periodo_cat_sub
          ON metricas_limites (
            periodo_tipo,
            ano,
            COALESCE(mes, -1),
            COALESCE(semana, -1),
            tipo_movimento,
            escopo,
            id_categoria_personalizada,
            COALESCE(id_subcategoria_personalizada, -1),
            COALESCE(forma_pagamento, -1),
            COALESCE(id_cartao, -1),
            COALESCE(id_conta, -1)
          );
        ''');
      } catch (_) {}
    }

    // =========================
    // V50: Pessoas que me devem — compra no cartão (gera receitas parceladas)
    // =========================
    if (oldVersion < 50) {
      await _addColumnSafe(
        db,
        'pessoas_me_devem',
        'compra_cartao',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnSafe(db, 'pessoas_me_devem', 'id_cartao', 'INTEGER');
      await _addColumnSafe(db, 'pessoas_me_devem', 'parcelas_total', 'INTEGER');
      await _addColumnSafe(db, 'pessoas_me_devem', 'grupo_receitas', 'TEXT');
    }

    // =========================
    // V51: Item de planejamento → conta a pagar (ex.: parcela)
    // =========================
    if (oldVersion < 51) {
      await _addColumnSafe(
        db,
        'planejamentos_despesa_itens',
        'id_conta_pagar',
        'INTEGER',
      );
    }

    // =========================
    // V52: Planejamento item — data/valor para vincular contas a pagar
    // =========================
    if (oldVersion < 52) {
      await _addColumnSafe(
        db,
        'planejamentos_despesa_itens',
        'data_vinculo_contas_pagar',
        'INTEGER',
      );
      await _addColumnSafe(
        db,
        'planejamentos_despesa_itens',
        'valor_total',
        'REAL',
      );
    }

    // =========================
    // V53: Conta a pagar — data do cabeçalho (referência da compra)
    // =========================
    if (oldVersion < 53) {
      await _addColumnSafe(db, 'conta_pagar', 'data_cabecalho', 'INTEGER');
    }

    // =========================
    // V54: categorias padrão de receita (seed antigo só criava despesas)
    // =========================
    if (oldVersion < 54) {
      await _seedReceitasPadraoSeNecessario(db);
    }

    // =========================
    // V55: Métricas — flag de recorrência mensal
    // =========================
    if (oldVersion < 55) {
      await _addColumnSafe(
        db,
        'metricas_limites',
        'recorrente',
        'INTEGER NOT NULL DEFAULT 0',
      );
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
    await _addColumnSafe(db, 'conta_pagar', 'data_cabecalho', 'INTEGER');
    await _addColumnSafe(
      db,
      'metricas_limites',
      'recorrente',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'id_lancamento',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'id_conta_pagar',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'data_vinculo_contas_pagar',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'valor_total',
      'REAL',
    );
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

    // MONITORAMENTO DE PREÇOS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monitoramento_precos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto TEXT NOT NULL,
        preco REAL NOT NULL,
        loja TEXT,
        url TEXT,
        foto_path TEXT,
        criado_em INTEGER NOT NULL,
        atualizado_em INTEGER NOT NULL
      );
    ''');
    await _addColumnSafe(db, 'monitoramento_precos', 'foto_path', 'TEXT');
    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_produto
        ON monitoramento_precos (produto);
      ''');
    } catch (_) {}

    // MONITORAMENTO — OFERTAS (lojas)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monitoramento_precos_ofertas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_monitoramento INTEGER NOT NULL,
        loja TEXT,
        url TEXT,
        preco REAL NOT NULL,
        criado_em INTEGER NOT NULL,
        atualizado_em INTEGER NOT NULL
      );
    ''');
    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_ofertas_monitoramento
        ON monitoramento_precos_ofertas (id_monitoramento);
      ''');
    } catch (_) {}

    // MONITORAMENTO — HISTÓRICO
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monitoramento_precos_ofertas_historico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_oferta INTEGER NOT NULL,
        preco REAL NOT NULL,
        criado_em INTEGER NOT NULL
      );
    ''');
    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_monitoramento_precos_hist_oferta
        ON monitoramento_precos_ofertas_historico (id_oferta, criado_em);
      ''');
    } catch (_) {}

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
    await _addColumnSafe(db, 'conta_pagar', 'data_cabecalho', 'INTEGER');
    await _addColumnSafe(
      db,
      'lancamentos',
      'id_categoria_personalizada',
      'INTEGER',
    );

    // 🔹 POPULA CATEGORIAS PADRÃO (apenas se tabela estiver vazia)
    await _seedCategoriasPadrao(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS planejamentos_despesa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        local TEXT,
        data_inicio INTEGER NOT NULL,
        data_fim INTEGER NOT NULL,
        notas TEXT,
        criado_em INTEGER NOT NULL,
        atualizado_em INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planejamentos_despesa_itens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planejamento_id INTEGER NOT NULL,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL DEFAULT 0,
        id_categoria_personalizada INTEGER,
        id_subcategoria_personalizada INTEGER,
        data_referencia INTEGER,
        ordem INTEGER NOT NULL DEFAULT 0,
        criado_em INTEGER NOT NULL,
        FOREIGN KEY (planejamento_id) REFERENCES planejamentos_despesa (id) ON DELETE CASCADE
      );
    ''');
    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_planej_desp_itens_planejamento
        ON planejamentos_despesa_itens (planejamento_id, ordem);
      ''');
    } catch (_) {}

    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'id_lancamento',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'id_conta_pagar',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'data_vinculo_contas_pagar',
      'INTEGER',
    );
    await _addColumnSafe(
      db,
      'planejamentos_despesa_itens',
      'valor_total',
      'REAL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pessoas_me_devem (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        data_emprestimo INTEGER NOT NULL,
        valor_total REAL NOT NULL,
        valor_recebido REAL NOT NULL DEFAULT 0,
        observacao TEXT,
        criado_em INTEGER NOT NULL
      );
    ''');

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

      const receitas = [
        'Salário',
        'Freelance',
        'Vendas e serviços',
        'Investimentos',
        'Outras receitas',
      ];
      for (final nome in receitas) {
        batch.insert('categorias_personalizadas', {
          'nome': nome,
          'tipo_movimento': 0, // receita
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

  /// Garante algumas categorias de receita quando o banco já tinha só despesas no seed.
  static Future<void> _seedReceitasPadraoSeNecessario(Database db) async {
    try {
      final result = await db.rawQuery('''
        SELECT COUNT(*) AS c
        FROM categorias_personalizadas
        WHERE tipo_movimento = 0
      ''');
      final count = (result.first['c'] as int?) ?? 0;
      if (count > 0) return;

      final batch = db.batch();
      const receitas = [
        'Salário',
        'Freelance',
        'Vendas e serviços',
        'Investimentos',
        'Outras receitas',
      ];
      for (final nome in receitas) {
        batch.insert('categorias_personalizadas', {
          'nome': nome,
          'tipo_movimento': 0,
          'cor': null,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao inserir categorias padrão de receita: $e');
    }
  }
}
