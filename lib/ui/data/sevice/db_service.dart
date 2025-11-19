import 'dart:async';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';

class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();

  factory DbService() => instance;

  Database? _db;

  // ============================================================
  //  A C E S S O   A O   B A N C O
  // ============================================================

  Future<Database> get db async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'vox_finance.db');

    _db = await openDatabase(
      path,
      version: 2, // aumente se mudar o schema
      onCreate: (db, version) async {
        await _criarTabelas(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Em produção o ideal é migrar com ALTER TABLE.
        await db.execute('DROP TABLE IF EXISTS lancamentos;');
        await db.execute('DROP TABLE IF EXISTS conta_pagar;');
        await _criarTabelas(db);
      },
    );

    return _db!;
  }

  Future<void> _criarTabelas(Database db) async {
    // --------- TABELA DE LANÇAMENTOS ---------
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
        parcela_total INTEGER
      );
    ''');

    // --------- TABELA DE CONTAS A PAGAR ---------
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
  }

  // ============================================================
  //  C R U D   L A N Ç A M E N T O S
  // ============================================================

  Future<int> salvarLancamento(Lancamento lanc) async {
    final database = await db;

    if (lanc.id == null) {
      final id = await database.insert(
        'lancamentos',
        lanc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      lanc.id = id;
      return id;
    } else {
      return await database.update(
        'lancamentos',
        lanc.toMap(),
        where: 'id = ?',
        whereArgs: [lanc.id],
      );
    }
  }

  Future<void> deletarLancamento(int id) async {
    final database = await db;
    await database.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

  /// Lançamentos de 1 dia específico
  Future<List<Lancamento>> getLancamentosByDay(DateTime dia) async {
    final database = await db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await database.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora < ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora DESC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  /// Lançamentos em um período (inclusive início e fim)
  Future<List<Lancamento>> getLancamentosByPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final database = await db;

    final result = await database.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora <= ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<List<Lancamento>> getLancamentosFuturosAte(DateTime limite) async {
    final database = await db;

    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day)
        .add(const Duration(days: 1));

    final fim = DateTime(limite.year, limite.month, limite.day)
        .add(const Duration(days: 1));

    final result = await database.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora < ? AND pago = 0',
      whereArgs: [amanha.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );

    final todos = result.map((e) => Lancamento.fromMap(e)).toList();

    // ==== AGRUPAMENTO POR GRUPO_PARCELAS ====
    final Map<String, List<Lancamento>> grupos = {};

    for (final lanc in todos) {
      // se não tiver grupo, usa um identificador próprio
      final key = lanc.grupoParcelas ?? 'SINGLE_${lanc.id}';
      grupos.putIfAbsent(key, () => []).add(lanc);
    }

    final List<Lancamento> agregados = [];

    grupos.forEach((key, lista) {
      if (lista.length == 1 && lista.first.grupoParcelas == null) {
        // não é parcelado → volta como está
        agregados.add(lista.first);
      } else {
        // é parcelado → soma valor e usa a menor data
        final primeiro = lista.first;
        final total = lista.fold<double>(0.0, (acc, l) => acc + l.valor);
        final menorData = lista
            .map((l) => l.dataHora)
            .reduce((a, b) => a.isBefore(b) ? a : b);

        agregados.add(
          primeiro.copyWith(
            valor: total,
            dataHora: menorData,
            grupoParcelas: primeiro.grupoParcelas ?? key,
            // pago fica false se qualquer parcela estiver pendente
            pago: lista.every((l) => l.pago),
          ),
        );
      }
    });

    // ordena por data
    agregados.sort((a, b) => a.dataHora.compareTo(b.dataHora));

    return agregados;
  }

  Future<List<Lancamento>> getParcelasPorGrupoLancamento(String grupo) async {
    final database = await db;

    final result = await database.query(
      'lancamentos',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }


  /// Soma o valor de todos os lançamentos futuros até o limite
  Future<double> getTotalLancamentosFuturosAte(DateTime limite) async {
    final lista = await getLancamentosFuturosAte(limite);
    return lista.fold<double>(0.0, (acc, l) => acc + l.valor);
  }


  /// Marca / desmarca um lançamento como pago
  Future<void> marcarLancamentoComoPago(int id, bool pago) async {
    final database = await db;

    await database.update(
      'lancamentos',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  //  C R U D   C O N T A S   A   P A G A R
  // ============================================================

  Future<int> salvarContaPagar(ContaPagar conta) async {
    final database = await db;

    if (conta.id == null) {
      final id = await database.insert(
        'conta_pagar',
        conta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      conta.id = id;
      return id;
    } else {
      return await database.update(
        'conta_pagar',
        conta.toMap(),
        where: 'id = ?',
        whereArgs: [conta.id],
      );
    }
  }

  /// Todas as contas (pagas ou não), ordenadas por vencimento
  Future<List<ContaPagar>> getContasPagar() async {
    final database = await db;
    final result = await database.query(
      'conta_pagar',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  /// Apenas contas não pagas, ordenadas por vencimento
  Future<List<ContaPagar>> getContasPagarPendentes() async {
    final database = await db;
    final result = await database.query(
      'conta_pagar',
      where: 'pago = 0',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  /// Todas as parcelas de um mesmo grupo de parcelas
  Future<List<ContaPagar>> getParcelasPorGrupo(String grupo) async {
    final database = await db;
    final result = await database.query(
      'conta_pagar',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      orderBy: 'parcela_numero ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  /// Marca / desmarca uma parcela como paga
  Future<void> marcarParcelaComoPaga(int id, bool pago) async {
    final database = await db;
    await database.update(
      'conta_pagar',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> salvarLancamentosParceladosFuturos(
    Lancamento base,
    int qtdParcelas,
  ) async {
    final database = await db;

    // grupo único para todas as parcelas
    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    // valor de cada parcela
    final double valorParcela = base.valor / qtdParcelas;

    final DateTime dataBase = base.dataHora;

    for (int i = 0; i < qtdParcelas; i++) {
      // 👇 cada parcela com diferença de 1 mês (≈ 30 dias)
      // 0 => mês base, 1 => +1 mês, 2 => +2 meses...
      final DateTime dataParcela = DateTime(
        dataBase.year,
        dataBase.month + i,
        min(dataBase.day, 28), // evita problemas com meses de 28/30/31
      );

      final lancParcela = base.copyWith(
        id: null, // sempre novo registro
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: false,
        dataPagamento: null,
      );

      await database.insert('lancamentos', lancParcela.toMap());
    }
  }
}
