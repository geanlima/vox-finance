import 'dart:async';

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

  /// Lançamentos futuros (não pagos) até uma data limite
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
}
