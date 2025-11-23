// ignore_for_file: unused_local_variable, duplicate_ignore, unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/usuario.dart'; // 👈 modelo do usuário local

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
      version: 7, // 👈 subimos para 7 (inclui tabela usuarios)
      onCreate: (db, version) async {
        await _criarTabelasV7(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ---- UPGRADE PARA V4 (id_cartao + tabela cartao_credito básica) ----
        if (oldVersion < 4) {
          try {
            await db.execute(
              'ALTER TABLE lancamentos ADD COLUMN id_cartao INTEGER;',
            );
          } catch (e) {}

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cartao_credito (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              descricao TEXT NOT NULL,
              bandeira TEXT NOT NULL,
              ultimos_4_digitos TEXT NOT NULL
            );
          ''');
        }

        // ---- UPGRADE PARA V6 (foto + dia_vencimento no cartão) ----
        if (oldVersion < 6) {
          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN foto_path TEXT;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN dia_vencimento INTEGER;',
            );
          } catch (e) {}
        }

        // ---- UPGRADE PARA V7 (tabela USUARIOS) ----
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS usuarios (
              id INTEGER PRIMARY KEY,
              email TEXT NOT NULL,
              nome TEXT,
              senha TEXT NOT NULL,
              criado_em TEXT NOT NULL
            );
          ''');
        }
      },
      onOpen: (db) async {
        // Garante que a tabela USUARIOS exista (sem apagar nada)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY,
            email TEXT NOT NULL,
            nome TEXT,
            senha TEXT NOT NULL,
            criado_em TEXT NOT NULL
          );
        ''');

        // Garante que a coluna SENHA exista mesmo em bancos antigos
        try {
          await db.execute("ALTER TABLE usuarios ADD COLUMN senha TEXT;");
        } catch (e) {
          // se já existe, ignora
        }

        // Só um checkzinho que você já tinha
        final res = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cartao_credito';",
        );
      },
    );

    return _db!;
  }

  // Cria tudo já no formato da versão 7 (instalação nova)
  Future<void> _criarTabelasV7(Database db) async {
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
        parcela_total INTEGER,
        id_cartao INTEGER
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

    // --------- TABELA DE CARTÕES DE CRÉDITO ---------
    await db.execute('''
      CREATE TABLE cartao_credito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        bandeira TEXT NOT NULL,
        ultimos_4_digitos TEXT NOT NULL,
        foto_path TEXT,
        dia_vencimento INTEGER
      );
    ''');

    // --------- TABELA DE USUÁRIOS ---------
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        nome TEXT,
        senha TEXT NOT NULL,
        criado_em TEXT NOT NULL
      );
    ''');
  }

  // ============================================================
  //  C R U D   U S U Á R I O   L O C A L
  // ============================================================

  Future<void> salvarUsuario(Usuario usuario) async {
    final database = await db;

    final id = await database.insert(
      'usuarios',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Usuário salvo/atualizado. RowId: $id');

    // debug opcional
    final check = await database.query('usuarios');
    print('📌 Conteúdo da tabela usuarios: $check');
  }

  Future<Usuario?> loginUsuario(String email, String senha) async {
    final database = await db;

    print('🔍 Login - buscando usuário $email');

    final result = await database.query(
      'usuarios',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );

    print('📌 Resultado login usuarios: $result');

    if (result.isEmpty) return null;

    return Usuario.fromMap(result.first);
  }

  Future<Usuario?> obterUsuario() async {
    final database = await db;

    final result = await database.query(
      'usuarios',
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Usuario.fromMap(result.first);
  }

  Future<void> limparUsuario() async {
    final database = await db;
    await database.delete('usuarios');
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
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);

    final fim = DateTime(
      limite.year,
      limite.month,
      limite.day,
    ).add(const Duration(days: 1)); // limite exclusivo

    final result = await database.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora < ? AND pago = 0',
      whereArgs: [
        inicioHoje.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
      ],
      orderBy: 'data_hora ASC',
    );

    final todos = result.map((e) => Lancamento.fromMap(e)).toList();

    // ==== AGRUPAMENTO POR GRUPO_PARCELAS ====
    final Map<String, List<Lancamento>> grupos = {};

    for (final lanc in todos) {
      final key = lanc.grupoParcelas ?? 'SINGLE_${lanc.id}';
      grupos.putIfAbsent(key, () => []).add(lanc);
    }

    final List<Lancamento> agregados = [];

    grupos.forEach((key, lista) {
      if (lista.length == 1 && lista.first.grupoParcelas == null) {
        agregados.add(lista.first);
      } else {
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
            pago: lista.every((l) => l.pago),
          ),
        );
      }
    });

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

  Future<List<ContaPagar>> getContasPagar() async {
    final database = await db;
    final result = await database.query(
      'conta_pagar',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<List<ContaPagar>> getContasPagarPendentes() async {
    final database = await db;
    final result = await database.query(
      'conta_pagar',
      where: 'pago = 0',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

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

    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataBase = base.dataHora;
    final bool pagoBase = base.pago;
    final DateTime? dataPagamentoBase =
        pagoBase ? (base.dataPagamento ?? DateTime.now()) : null;

    for (int i = 0; i < qtdParcelas; i++) {
      final DateTime dataParcela = DateTime(
        dataBase.year,
        dataBase.month + i,
        min(dataBase.day, 28),
      );

      final lancParcela = base.copyWith(
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoBase,
        dataPagamento: dataPagamentoBase,
      );

      await database.insert('lancamentos', lancParcela.toMap());

      if (!pagoBase) {
        final conta = ContaPagar(
          id: null,
          descricao: lancParcela.descricao,
          valor: valorParcela,
          dataVencimento: dataParcela,
          pago: false,
          dataPagamento: null,
          parcelaNumero: i + 1,
          parcelaTotal: qtdParcelas,
          grupoParcelas: grupo,
        );

        await database.insert('conta_pagar', conta.toMap());
      }
    }
  }

  // ============================================================
  //  CRUD Cartões de crédito
  // ============================================================

  Future<int> salvarCartaoCredito(CartaoCredito cartao) async {
    final database = await db;

    try {
      if (cartao.id == null) {
        final id = await database.insert(
          'cartao_credito',
          cartao.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        cartao.id = id;

        final check = await database.query('cartao_credito');

        return id;
      } else {
        final linhas = await database.update(
          'cartao_credito',
          cartao.toMap(),
          where: 'id = ?',
          whereArgs: [cartao.id],
        );

        final check = await database.query('cartao_credito');
        return linhas;
      }
    } catch (e, s) {
      rethrow;
    }
  }

  Future<List<CartaoCredito>> getCartoesCredito() async {
    final database = await db;
    try {
      final result = await database.query(
        'cartao_credito',
        orderBy: 'descricao ASC',
      );
      return result.map((e) => CartaoCredito.fromMap(e)).toList();
    } catch (e, s) {
      rethrow;
    }
  }

  Future<void> deletarCartaoCredito(int id) async {
    final database = await db;
    await database.delete('cartao_credito', where: 'id = ?', whereArgs: [id]);
  }
}
