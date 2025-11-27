// ignore_for_file: unused_local_variable, unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart'
    show FormaPagamento;
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';

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
      version: 16, // ⬅️ aumentei para 13 por causa do ajuste de 'ultimos4'
      onCreate: (db, version) async {
        await _criarTabelasV9(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ---- V4: id_cartao em lancamentos + tabela cartao_credito básica ----
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

        // ---- V6: foto_path + dia_vencimento no cartão ----
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

        // ---- V7: tabela USUARIOS ----
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

        // ---- V8: adiciona foto_path em bancos antigos (se faltar) ----
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
          } catch (e) {}
        }

        // ---- V9: tipo, permite_parcelamento, limite, dia_fechamento ----
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

        // ---- V10: controla_fatura ----
        if (oldVersion < 10) {
          try {
            await db.execute(
              'ALTER TABLE cartao_credito ADD COLUMN controla_fatura INTEGER DEFAULT 1;',
            );
          } catch (e) {}

          // copia valor antigo de permite_parcelamento, se existir
          try {
            await db.execute('''
              UPDATE cartao_credito
              SET controla_fatura = permite_parcelamento
              WHERE controla_fatura IS NULL
                 OR (controla_fatura = 0 AND permite_parcelamento = 1);
            ''');
          } catch (e) {}
        }

        // ---- V11: conta_bancaria + id_conta em lancamentos ----
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

          try {
            await db.execute(
              'ALTER TABLE lancamentos ADD COLUMN id_conta INTEGER;',
            );
          } catch (e) {}
        }

        // ---- V13: normaliza nome da coluna 'ultimos4' em cartao_credito ----
        if (oldVersion < 13) {
          try {
            final info = await db.rawQuery(
              'PRAGMA table_info(cartao_credito);',
            );

            bool temUltimos4 = info.any(
              (col) => (col['name'] as String).toLowerCase() == 'ultimos4',
            );

            // possíveis nomes antigos
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
                colunaAntiga = nome;
                break;
              }
            }

            if (!temUltimos4 && colunaAntiga != null) {
              await db.execute(
                'ALTER TABLE cartao_credito '
                'RENAME COLUMN $colunaAntiga TO ultimos4;',
              );
            }
          } catch (e) {
            // se der erro (sqlite antigo ou coluna já renomeada), ignora
          }
        }

        // ---- V14: garante que a coluna id_conta exista em lancamentos ----
        if (oldVersion < 14) {
          try {
            final infoLanc = await db.rawQuery(
              'PRAGMA table_info(lancamentos);',
            );

            final temIdConta = infoLanc.any(
              (col) => (col['name'] as String).toLowerCase() == 'id_conta',
            );

            if (!temIdConta) {
              await db.execute(
                'ALTER TABLE lancamentos ADD COLUMN id_conta INTEGER;',
              );
            }
          } catch (e) {
            // ignora erro pra não quebrar abertura
          }
        }

        // ---- V15: caso alguém já tenha ido pra 14 sem o bloco acima ----
        if (oldVersion < 15) {
          try {
            final infoLanc = await db.rawQuery(
              'PRAGMA table_info(lancamentos);',
            );

            final temIdConta = infoLanc.any(
              (col) => (col['name'] as String).toLowerCase() == 'id_conta',
            );

            if (!temIdConta) {
              await db.execute(
                'ALTER TABLE lancamentos ADD COLUMN id_conta INTEGER;',
              );
            }
          } catch (e) {}
        }

        // ---- V16: forma_pagamento, id_cartao, id_conta em conta_pagar ----
        if (oldVersion < 16) {
          try {
            await db.execute(
              'ALTER TABLE conta_pagar ADD COLUMN forma_pagamento INTEGER;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE conta_pagar ADD COLUMN id_cartao INTEGER;',
            );
          } catch (e) {}

          try {
            await db.execute(
              'ALTER TABLE conta_pagar ADD COLUMN id_conta INTEGER;',
            );
          } catch (e) {}
        }
      },
      onOpen: (db) async {
        // Garante que a tabela USUARIOS exista
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

        // Garante colunas de usuarios
        try {
          await db.execute('ALTER TABLE usuarios ADD COLUMN senha TEXT;');
        } catch (e) {}
        try {
          await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
        } catch (e) {}

        // ✅ Garante que a tabela CONTA_BANCARIA exista em QUALQUER VERSÃO
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
        // Só um checkzinho que você já tinha
        final res = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cartao_credito';",
        );
        // print(res);
      },
    );

    return _db!;
  }

  // ============================================================
  //  C R I A Ç Ã O   I N I C I A L   D A S   T A B E L A S
  // ============================================================

  Future<void> _criarTabelasV9(Database db) async {
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
        grupo_parcelas TEXT NOT NULL,
        forma_pagamento INTEGER,
        id_cartao INTEGER,
        id_conta INTEGER
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

  String mesNome(int mes) {
    const meses = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return meses[mes];
  }

  // ============================================================
  //  CRUD  C O N T A   B A N C Á R I A
  // ============================================================

  Future<int> salvarContaBancaria(ContaBancaria conta) async {
    final database = await db;
    final dados = conta.toMap();

    if (conta.id == null) {
      dados.remove('id');
      final id = await database.insert(
        'conta_bancaria',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      conta.id = id;
      return id;
    } else {
      return await database.update(
        'conta_bancaria',
        dados,
        where: 'id = ?',
        whereArgs: [conta.id],
      );
    }
  }

  Future<List<ContaBancaria>> getContasBancarias({
    bool apenasAtivas = false,
  }) async {
    final database = await db;

    final result = await database.query(
      'conta_bancaria',
      where: apenasAtivas ? 'ativa = 1' : null,
      orderBy: 'descricao ASC',
    );

    return result.map((e) => ContaBancaria.fromMap(e)).toList();
  }

  Future<void> deletarContaBancaria(int id) async {
    final database = await db;
    await database.delete('conta_bancaria', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  //  CRUD  U S U Á R I O   L O C A L
  // ============================================================

  Future<void> salvarUsuario(Usuario usuario) async {
    final database = await db;

    await database.insert(
      'usuarios',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Usuario?> loginUsuario(String email, String senha) async {
    final database = await db;

    final result = await database.query(
      'usuarios',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Usuario.fromMap(result.first);
  }

  Future<Usuario?> obterUsuario() async {
    final database = await db;

    final result = await database.query('usuarios', limit: 1);
    if (result.isEmpty) return null;

    return Usuario.fromMap(result.first);
  }

  Future<void> limparUsuario() async {
    final database = await db;
    await database.delete('usuarios');
  }

  // ============================================================
  //  CRUD  L A N Ç A M E N T O S
  // ============================================================

  Future<int> salvarLancamento(Lancamento lanc) async {
    final database = await db;

    final bool ehFaturaPagaDeCartao =
        lanc.pagamentoFatura && lanc.pago && lanc.idCartao != null;

    final DateTime dataPagamentoEfetiva = lanc.dataPagamento ?? DateTime.now();

    int idGeradoOuAtualizado;

    if (lanc.id == null) {
      final dados = lanc.toMap();
      dados.remove('id');

      final id = await database.insert(
        'lancamentos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      lanc.id = id;
      idGeradoOuAtualizado = id;
    } else {
      await database.update(
        'lancamentos',
        lanc.toMap(),
        where: 'id = ?',
        whereArgs: [lanc.id],
      );
      idGeradoOuAtualizado = lanc.id!;
    }

    // 🔹 Regra especial: se é pagamento de fatura de cartão e já está pago,
    // quita as contas a pagar associadas a esse cartão.
    if (ehFaturaPagaDeCartao) {
      await _quitarContasPagarDoCartaoAteData(
        database: database,
        idCartao: lanc.idCartao!,
        dataLimite: dataPagamentoEfetiva,
      );
    }

    return idGeradoOuAtualizado;
  }

  Future<void> deletarLancamento(int id) async {
    final database = await db;
    await database.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

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

  Future<double> getTotalLancamentosFuturosAte(DateTime limite) async {
    final lista = await getLancamentosFuturosAte(limite);
    return lista.fold<double>(0.0, (acc, l) => acc + l.valor);
  }

  Future<void> marcarLancamentoComoPago(int id, bool pago) async {
    final database = await db;

    // Busca o lançamento atual pra saber se é fatura de cartão
    final result = await database.query(
      'lancamentos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return;

    final lanc = Lancamento.fromMap(result.first);

    final agora = DateTime.now();

    await database.update(
      'lancamentos',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? agora.millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Se marcou como pago e é fatura de cartão -> quita contas a pagar
    if (pago && lanc.pagamentoFatura && lanc.idCartao != null) {
      await _quitarContasPagarDoCartaoAteData(
        database: database,
        idCartao: lanc.idCartao!,
        dataLimite: agora,
      );
    }
  }

  Future<void> _quitarContasPagarDoCartaoAteData({
    required Database database,
    required int idCartao,
    required DateTime dataLimite,
  }) async {
    // Data limite até o final do dia
    final fimDia =
        DateTime(
          dataLimite.year,
          dataLimite.month,
          dataLimite.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;

    final agoraMs = DateTime.now().millisecondsSinceEpoch;

    await database.update(
      'conta_pagar',
      {'pago': 1, 'data_pagamento': agoraMs},
      where:
          'forma_pagamento = ? AND id_cartao = ? AND pago = 0 AND data_vencimento <= ?',
      whereArgs: [FormaPagamento.credito.index, idCartao, fimDia],
    );
  }

  // ============================================================
  //  CRUD  C O N T A S   A   P A G A R
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

    final List<DateTime> datasParcelas = [];

    for (int i = 0; i < qtdParcelas; i++) {
      int mes = dataCompra.month + i;
      int ano = dataCompra.year + ((mes - 1) ~/ 12);
      mes = ((mes - 1) % 12) + 1;

      final int dia = min(dataCompra.day, 28);
      datasParcelas.add(DateTime(ano, mes, dia));
    }

    for (int i = 0; i < qtdParcelas; i++) {
      final DateTime dataParcela = datasParcelas[i];

      // Lançamento da parcela
      final lancParcela = base.copyWith(
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoBase,
        dataPagamento: dataPagamentoBase,
        pagamentoFatura: base.pagamentoFatura,
      );

      await database.insert('lancamentos', lancParcela.toMap());

      // 👉 Conta a pagar SEMPRE nasce pendente
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
        // liga com a origem
        formaPagamento: base.formaPagamento,
        idCartao: base.idCartao,
        idConta: base.idConta,
      );

      await database.insert('conta_pagar', conta.toMap());
    }
  }

  // ============================================================
  //  L A N Ç A M E N T O  À  V I S T A   N O   C A R T Ã O
  // ============================================================

  Future<void> salvarLancamentoDaFatura(Lancamento base) async {
    final database = await db;

    if (base.idCartao == null) return;

    final result = await database.query(
      'cartao_credito',
      where: 'id = ?',
      whereArgs: [base.idCartao],
      limit: 1,
    );

    if (result.isEmpty) return;

    final cartao = CartaoCredito.fromMap(result.first);

    final bool ehCreditoLike =
        cartao.tipo == TipoCartao.credito || cartao.tipo == TipoCartao.ambos;

    if (!ehCreditoLike) return;
    if (!cartao.controlaFatura) return;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) return;

    final dataCompra = base.dataHora;
    int ano = dataCompra.year;
    int mes = dataCompra.month;

    if (dataCompra.day > cartao.diaFechamento!) {
      mes++;
      if (mes > 12) {
        mes = 1;
        ano++;
      }
    }

    final dataFatura = DateTime(ano, mes, cartao.diaVencimento!);

    final existente = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND pagamento_fatura = 1 AND pago = 0 AND data_hora = ?',
      whereArgs: [base.idCartao, dataFatura.millisecondsSinceEpoch],
      limit: 1,
    );

    if (existente.isNotEmpty) {
      final existenteLanc = Lancamento.fromMap(existente.first);
      final novoValor = existenteLanc.valor + base.valor;

      await database.update(
        'lancamentos',
        {'valor': novoValor},
        where: 'id = ?',
        whereArgs: [existenteLanc.id],
      );
      return;
    }

    final lancFatura = Lancamento(
      valor: base.valor,
      descricao: '${base.descricao} (Pagamento de fatura)',
      formaPagamento: FormaPagamento.credito,
      dataHora: dataFatura,
      pagamentoFatura: true,
      categoria: base.categoria,
      pago: false,
      idCartao: base.idCartao,
    );

    final dados = lancFatura.toMap();
    dados.remove('id');

    await database.insert('lancamentos', dados);
  }

  // ============================================================
  //  CONTA_PAGAR - EXCLUIR POR GRUPO
  // ============================================================

  Future<void> deletarContasPagarPorGrupo(String grupoParcelas) async {
    final database = await db;

    await database.delete(
      'conta_pagar',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupoParcelas],
    );
  }

  // ============================================================
  //  G E R A R   F A T U R A   D O   C A R T Ã O   (FECHAMENTO)
  // ============================================================

  Future<void> gerarFaturaDoCartao(int idCartao, {DateTime? referencia}) async {
    final database = await db;
    final hoje = referencia ?? DateTime.now();

    final res = await database.query(
      'cartao_credito',
      where: 'id = ?',
      whereArgs: [idCartao],
      limit: 1,
    );
    if (res.isEmpty) return;

    final cartao = CartaoCredito.fromMap(res.first);

    final bool ehCreditoLike =
        cartao.tipo == TipoCartao.credito || cartao.tipo == TipoCartao.ambos;

    if (!ehCreditoLike) return;
    if (!cartao.controlaFatura) return;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) return;

    final int diaFechamento = cartao.diaFechamento!;
    final int diaVencimento = cartao.diaVencimento!;

    int anoAtual = hoje.year;
    int mesAtual = hoje.month;

    int mesAnterior = mesAtual - 1;
    int anoAnterior = anoAtual;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    final inicioPeriodo = DateTime(anoAnterior, mesAnterior, diaFechamento + 1);
    final fimPeriodo = DateTime(
      anoAtual,
      mesAtual,
      diaFechamento,
      23,
      59,
      59,
      999,
    );

    final inicioMs = inicioPeriodo.millisecondsSinceEpoch;
    final fimMs = fimPeriodo.millisecondsSinceEpoch;

    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );

    if (compras.isEmpty) return;

    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );

    if (total <= 0) return;

    final dataVencimento = DateTime(anoAtual, mesAtual, diaVencimento);
    final dataVencimentoMs = dataVencimento.millisecondsSinceEpoch;

    final faturaExistente = await database.query(
      'lancamentos',
      where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?',
      whereArgs: [idCartao, dataVencimentoMs],
      limit: 1,
    );

    if (faturaExistente.isNotEmpty) {
      final idFatura = faturaExistente.first['id'] as int;
      await database.update(
        'lancamentos',
        {'valor': total},
        where: 'id = ?',
        whereArgs: [idFatura],
      );
      return;
    }

    final primeiraCompra = Lancamento.fromMap(compras.first);

    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

    final lancFatura = Lancamento(
      valor: total,
      descricao: descricaoFatura,
      formaPagamento: FormaPagamento.credito,
      dataHora: dataVencimento,
      pagamentoFatura: true,
      categoria: primeiraCompra.categoria,
      pago: false,
      dataPagamento: null,
      idCartao: idCartao,
    );

    await database.insert('lancamentos', lancFatura.toMap());
  }

  // ============================================================
  //  CRUD  C A R T Õ E S   D E   C R É D I T O
  // ============================================================

  Future<int> salvarCartaoCredito(CartaoCredito cartao) async {
    final database = await db;

    try {
      if (cartao.id == null) {
        final id = await database.insert(
          'cartao_credito',
          cartao.toMapInsert(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        cartao.id = id;
        return id;
      } else {
        return await database.update(
          'cartao_credito',
          cartao.toMapUpdate(),
          where: 'id = ?',
          whereArgs: [cartao.id],
        );
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
