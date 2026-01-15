import 'package:sqflite/sqflite.dart';
import '../models/dropdown_item.dart';

class CategoriaTipo {
  static const ganho = 'ganho';
  static const fixa = 'fixa';
  static const variavel = 'variavel';

  static const values = [ganho, fixa, variavel];

  static bool isValid(String v) => values.contains(v);
}

class CategoriaRow {
  final int id;
  final String nome;
  final String tipo; // ganho|fixa|variavel
  final bool ativo;
  final String? emoji;
  final String? corHex;

  const CategoriaRow({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.ativo,
    this.emoji,
    this.corHex,
  });
}

class CategoriaResumoMes {
  final int categoriaId;
  final String nome;
  final String tipo;
  final String? emoji;
  final String? corHex;

  final int limite; // centavos
  final int gasto; // centavos (somente saidas)
  int get saldo => limite - gasto;

  const CategoriaResumoMes({
    required this.categoriaId,
    required this.nome,
    required this.tipo,
    required this.emoji,
    required this.corHex,
    required this.limite,
    required this.gasto,
  });
}

class CategoriasRepository {
  final Database db;
  const CategoriasRepository(this.db);

  // =========================
  // Helpers
  // =========================
  void _assertTipo(String tipo) {
    if (!CategoriaTipo.isValid(tipo)) {
      throw ArgumentError(
        "tipo inválido: '$tipo'. Use: ${CategoriaTipo.values.join(', ')}",
      );
    }
  }

  // =========================
  // Listagens
  // =========================

  Future<List<CategoriaRow>> listarCategorias({
    bool apenasAtivas = true,
    String? tipo, // ganho|fixa|variavel
  }) async {
    if (tipo != null) _assertTipo(tipo);

    String? where;
    final whereArgs = <Object?>[];

    if (apenasAtivas) {
      where = 'ativo = 1';
    }

    if (tipo != null) {
      where = (where == null) ? 'tipo = ?' : '$where AND tipo = ?';
      whereArgs.add(tipo);
    }

    final rows = await db.query(
      'categorias',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((m) {
      return CategoriaRow(
        id: (m['id'] as int),
        nome: (m['nome'] as String),
        tipo: (m['tipo'] as String),
        ativo: (m['ativo'] as int) == 1,
        emoji: (m['emoji'] as String?),
        corHex: (m['cor_hex'] as String?),
      );
    }).toList();
  }

  /// ✅ Para usar em Dropdown (categoriaId + "🛒 Mercado")
  Future<List<DropdownItem>> listarParaDropdown({
    required String tipo,
    bool apenasAtivas = true,
    bool incluirSemCategoria = true,
  }) async {
    _assertTipo(tipo);

    final cats = await listarCategorias(apenasAtivas: apenasAtivas, tipo: tipo);

    final items = <DropdownItem>[];

    if (incluirSemCategoria) {
      items.add(const DropdownItem(0, '🚫 Sem categoria'));
    }

    for (final c in cats) {
      final label = '${c.emoji ?? '🏷️'} ${c.nome}';
      items.add(DropdownItem(c.id, label));
    }

    return items;
  }

  // =========================
  // Limites
  // =========================

  /// ✅ Requer UNIQUE(categoria_id, ano, mes) na tabela categoria_limites
  Future<void> salvarLimiteMes({
    required int categoriaId,
    required int ano,
    required int mes,
    required int limiteCentavos,
  }) async {
    await db.insert('categoria_limites', {
      'categoria_id': categoriaId,
      'ano': ano,
      'mes': mes,
      'limite_centavos': limiteCentavos,
      // deixe o banco gerar se você tiver DEFAULT datetime('now')
      // se não tiver, grave ISO (consistente):
      'criado_em': DateTime.now().toIso8601String(),
      'atualizado_em': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // =========================
  // CRUD
  // =========================

  Future<int> criarCategoria({
    required String nome,
    required String tipo, // ganho|fixa|variavel
    String? emoji,
    String? corHex,
  }) async {
    _assertTipo(tipo);

    return db.insert('categorias', {
      'nome': nome.trim(),
      'tipo': tipo,
      'ativo': 1,
      'emoji': emoji,
      'cor_hex': corHex,
    });
  }

  Future<void> editarCategoria({
    required int id,
    required String nome,
    required String tipo,
    String? emoji,
    String? corHex,
  }) async {
    _assertTipo(tipo);

    await db.update(
      'categorias',
      {'nome': nome.trim(), 'tipo': tipo, 'emoji': emoji, 'cor_hex': corHex},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setAtivo(int id, bool ativo) async {
    await db.update(
      'categorias',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // Seed
  // =========================

  Future<void> seedPadraoSeVazio() async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(1) FROM categorias;'),
        ) ??
        0;

    if (count > 0) return;

    final seeds = <Map<String, Object?>>[
      // Variáveis
      {
        'nome': 'Mercado',
        'tipo': CategoriaTipo.variavel,
        'emoji': '🛒',
        'cor_hex': '#22C55E',
      },
      {
        'nome': 'Delivery',
        'tipo': CategoriaTipo.variavel,
        'emoji': '🍔',
        'cor_hex': '#F97316',
      },
      {
        'nome': 'Transporte',
        'tipo': CategoriaTipo.variavel,
        'emoji': '🚗',
        'cor_hex': '#3B82F6',
      },
      {
        'nome': 'Lazer',
        'tipo': CategoriaTipo.variavel,
        'emoji': '🎮',
        'cor_hex': '#A855F7',
      },

      // Fixas
      {
        'nome': 'Aluguel',
        'tipo': CategoriaTipo.fixa,
        'emoji': '🏠',
        'cor_hex': '#64748B',
      },
      {
        'nome': 'Energia',
        'tipo': CategoriaTipo.fixa,
        'emoji': '💡',
        'cor_hex': '#EAB308',
      },
      {
        'nome': 'Internet',
        'tipo': CategoriaTipo.fixa,
        'emoji': '📶',
        'cor_hex': '#0EA5E9',
      },
      {
        'nome': 'Água',
        'tipo': CategoriaTipo.fixa,
        'emoji': '🚿',
        'cor_hex': '#06B6D4',
      },

      // Ganhos
      {
        'nome': 'Salário',
        'tipo': CategoriaTipo.ganho,
        'emoji': '💰',
        'cor_hex': '#10B981',
      },
      {
        'nome': 'Extras',
        'tipo': CategoriaTipo.ganho,
        'emoji': '🧾',
        'cor_hex': '#84CC16',
      },
    ];

    await db.transaction((txn) async {
      for (final s in seeds) {
        await txn.insert('categorias', {
          'nome': s['nome'],
          'tipo': s['tipo'],
          'ativo': 1,
          'emoji': s['emoji'],
          'cor_hex': s['cor_hex'],
        });
      }
    });
  }

  // =========================
  // Resumo (Limite x Gastos)
  // =========================

  Future<List<CategoriaResumoMes>> resumoPorCategoriaNoMes({
    required int ano,
    required int mes,
  }) async {
    final ym =
        '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}';

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id AS categoria_id,
        c.nome AS nome,
        c.tipo AS tipo,
        c.emoji AS emoji,
        c.cor_hex AS cor_hex,

        COALESCE(l.limite_centavos, 0) AS limite,

        COALESCE((
          SELECT SUM(m.valor_centavos)
          FROM movimentos m
          WHERE m.direcao = 'saida'
            AND m.categoria_id = c.id
            AND substr(m.data, 1, 7) = ?
        ), 0) AS gasto

      FROM categorias c
      LEFT JOIN categoria_limites l
        ON l.categoria_id = c.id AND l.ano = ? AND l.mes = ?
      WHERE c.ativo = 1
      ORDER BY c.nome COLLATE NOCASE ASC
      ''',
      [ym, ano, mes],
    );

    return rows.map((r) {
      return CategoriaResumoMes(
        categoriaId: (r['categoria_id'] as int),
        nome: (r['nome'] as String),
        tipo: (r['tipo'] as String),
        emoji: (r['emoji'] as String?),
        corHex: (r['cor_hex'] as String?),
        limite: (r['limite'] as int?) ?? 0,
        gasto: (r['gasto'] as int?) ?? 0,
      );
    }).toList();
  }
}
