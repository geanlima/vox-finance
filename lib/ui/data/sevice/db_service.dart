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
      version: 10, // 👈 V10: cartões com tipo/controla_fatura/limite/dia_fechamento
      onCreate: (db, version) async {
        await _criarTabelasV9(db);
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
              ultimos4 TEXT NOT NULL
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
              foto_path TEXT,
              criado_em TEXT NOT NULL
            );
          ''');
        }

        // ---- UPGRADE PARA V8 (foto_path em bancos antigos que já tinham usuarios) ----
        if (oldVersion < 8) {
          try {
            await db.execute(
              'ALTER TABLE usuarios ADD COLUMN foto_path TEXT;',
            );
          } catch (e) {
            // se já existir, ignora
          }
        }

        // ---- UPGRADE PARA V9 (tipo, permite_parcelamento, limite, dia_fechamento no cartão) ----
        // Mantemos "permite_parcelamento" só para poder copiar o valor depois.
        if (oldVersion < 9) {
          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN tipo INTEGER DEFAULT 0;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN permite_parcelamento INTEGER DEFAULT 1;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN limite REAL;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN dia_fechamento INTEGER;',
            );
          } catch (e) {}
        }

        // ---- UPGRADE PARA V10 (controla_fatura) ----
        if (oldVersion < 10) {
          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN controla_fatura INTEGER DEFAULT 1;',
            );
          } catch (e) {}

          // tenta copiar o valor antigo de permite_parcelamento, se existir
          try {
            await db.execute('''
              UPDATE cartao_credito
              SET controla_fatura = permite_parcelamento
              WHERE controla_fatura IS NULL
                 OR (controla_fatura = 0 AND permite_parcelamento = 1);
            ''');
          } catch (e) {
            // se a coluna permite_parcelamento não existir, ignora
          }
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
            foto_path TEXT,
            criado_em TEXT NOT NULL
          );
        ''');

        // Garante que as colunas existam mesmo em bancos antigos
        try {
          await db.execute('ALTER TABLE usuarios ADD COLUMN senha TEXT;');
        } catch (e) {}
        try {
          await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
        } catch (e) {}

        // Só um checkzinho que você já tinha
        final res = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cartao_credito';",
        );
        // print(res);
      },
    );

    return _db!;
  }

  // Cria tudo já no formato da versão 9/10 (instalação nova)
  Future<void> _criarTabelasV9(Database db) async {
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
        ultimos4 TEXT NOT NULL,
        foto_path TEXT,
        dia_vencimento INTEGER,
        tipo INTEGER DEFAULT 0,
        controla_fatura INTEGER DEFAULT 1,
        limite REAL,
        dia_fechamento INTEGER
      );
    ''');

    // --------- TABELA DE USUÁRIOS ---------
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
        final menorData =
            lista.map((l) => l.dataHora).reduce((a, b) => a.isBefore(b) ? a : b);

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

  // ============================================================
  //  L A N Ç A M E N T O S   P A R C E L A D O S
  //   (COM REGRA DE FATURA QUANDO HOUVER CARTÃO)
  // ============================================================

  Future<void> salvarLancamentosParceladosFuturos(
    Lancamento base,
    int qtdParcelas,
  ) async {
    final database = await db;

    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataCompra = base.dataHora;
    final bool pagoBase = base.pago;
    final DateTime? dataPagamentoBase =
        pagoBase ? (base.dataPagamento ?? DateTime.now()) : null;

    // 🔍 tenta carregar o cartão, se houver
    CartaoCredito? cartao;
    if (base.idCartao != null) {
      try {
        final res = await database.query(
          'cartao_credito',
          where: 'id = ?',
          whereArgs: [base.idCartao],
          limit: 1,
        );
        if (res.isNotEmpty) {
          cartao = CartaoCredito.fromMap(res.first);
        }
      } catch (e) {
        cartao = null;
      }
    }

    // Regra: só aplicamos lógica de fatura se:
    // - existe cartão
    // - controla_fatura = true
    // - tipo = crédito ou ambos
    // - dia_fechamento e dia_vencimento preenchidos
    final bool usarRegraFatura = cartao != null &&
        cartao!.controlaFatura &&
        (cartao!.tipo == TipoCartao.credito ||
            cartao!.tipo == TipoCartao.ambos) &&
        cartao!.diaFechamento != null &&
        cartao!.diaVencimento != null;

    // ==========================
    // Cálculo das datas de cada parcela
    // ==========================
    final List<DateTime> datasParcelas = [];

    if (usarRegraFatura) {
      // 1) Decide em qual fatura cai a primeira parcela
      int ano = dataCompra.year;
      int mes = dataCompra.month;
      final int diaCompra = dataCompra.day;
      final int diaFechamento = cartao!.diaFechamento!;
      final int diaVencimento = cartao!.diaVencimento!;

      // Se passou do fechamento, vai para a fatura do próximo mês
      if (diaCompra > diaFechamento) {
        mes++;
        if (mes > 12) {
          mes = 1;
          ano++;
        }
      }

      // Primeira parcela vence no dia do vencimento da fatura calculada
      DateTime primeiraVenc = DateTime(ano, mes, diaVencimento);
      datasParcelas.add(primeiraVenc);

      // Demais parcelas: vencimento do mesmo dia nos meses seguintes
      for (int i = 1; i < qtdParcelas; i++) {
        int mesParc = primeiraVenc.month + i;
        int anoParc = primeiraVenc.year + ((mesParc - 1) ~/ 12);
        mesParc = ((mesParc - 1) % 12) + 1;

        datasParcelas.add(DateTime(anoParc, mesParc, diaVencimento));
      }
    } else {
      // 🔁 Comportamento antigo: data base + i meses,
      // forçando dia <= 28 para evitar problemas de mês
      for (int i = 0; i < qtdParcelas; i++) {
        int mes = dataCompra.month + i;
        int ano = dataCompra.year + ((mes - 1) ~/ 12);
        mes = ((mes - 1) % 12) + 1;

        final int dia = min(dataCompra.day, 28);
        datasParcelas.add(DateTime(ano, mes, dia));
      }
    }

    // ==========================
    // Gravação das parcelas
    // ==========================
    for (int i = 0; i < qtdParcelas; i++) {
      final DateTime dataParcela = datasParcelas[i];

      // Regra: se estiver usando fatura, todas as parcelas começam pendentes
      final bool pagoParcela = usarRegraFatura ? false : pagoBase;
      final DateTime? dataPagamentoParcela =
          usarRegraFatura ? null : dataPagamentoBase;

      final lancParcela = base.copyWith(
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoParcela,
        dataPagamento: dataPagamentoParcela,
      );

      await database.insert('lancamentos', lancParcela.toMap());

      // Se NÃO está usando regra de fatura, mantém comportamento antigo:
      // cria registro em conta_pagar para a parcela futura (se não estiver paga)
      if (!usarRegraFatura && !pagoBase) {
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

        return id;
      } else {
        final linhas = await database.update(
          'cartao_credito',
          cartao.toMap(),
          where: 'id = ?',
          whereArgs: [cartao.id],
        );
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

  Future<CartaoCredito?> getCartaoCreditoById(int id) async {
    final database = await db;
    try {
      final result = await database.query(
        'cartao_credito',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return CartaoCredito.fromMap(result.first);
    } catch (e, s) {
      return null;
    }
  }

  Future<void> deletarCartaoCredito(int id) async {
    final database = await db;
    await database.delete('cartao_credito', where: 'id = ?', whereArgs: [id]);
  }
}
