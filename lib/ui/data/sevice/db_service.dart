// ignore_for_file: unused_local_variable, duplicate_ignore, unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart'
    show FormaPagamento;

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
      version:
          11, // 👈 V10: cartões com tipo/controla_fatura/limite/dia_fechamento
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
            await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
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

  // ============================================================
  //  G E R A R   F A T U R A   D O   C A R T Ã O   (FECHAMENTO)
  // ============================================================

  Future<void> gerarFaturaDoCartao(int idCartao, {DateTime? referencia}) async {
    final database = await db;
    final hoje = referencia ?? DateTime.now();

    // 1) Busca o cartão
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

    // Só gera fatura se for cartão de crédito/ambos e controlar fatura
    if (!ehCreditoLike) return;
    if (!cartao.controlaFatura) return;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) return;

    final int diaFechamento = cartao.diaFechamento!;
    final int diaVencimento = cartao.diaVencimento!;

    // 2) Calcula período de consumo:
    //    do dia seguinte ao fechamento anterior ATÉ o fechamento atual (inclusive)
    int anoAtual = hoje.year;
    int mesAtual = hoje.month;

    int mesAnterior = mesAtual - 1;
    int anoAnterior = anoAtual;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    // Ex.: fechamento dia 4 -> período 05/mesAnterior até 04/mesAtual
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

    // 3) Busca todos os lançamentos de CRÉDITO desse cartão no período,
    //    que NÃO são pagamento de fatura (pagamento_fatura = 0)
    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );

    if (compras.isEmpty) return;

    // Soma o valor de todas as compras
    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );

    if (total <= 0) return;

    // 4) Data do vencimento desta fatura
    final dataVencimento = DateTime(anoAtual, mesAtual, diaVencimento);
    final dataVencimentoMs = dataVencimento.millisecondsSinceEpoch;

    // Evita criar fatura duplicada: se já existir para este mês, atualiza o valor
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

    // Usa a categoria da primeira compra só para não ficar nulo
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

    // debug opcional
    final check = await database.query('usuarios');
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
  //  C R U D   L A N Ç A M E N T O S
  // ============================================================

  Future<int> salvarLancamento(Lancamento lanc) async {
    final database = await db;

    if (lanc.id == null) {
      // ⚠️ NUNCA envia o id no insert
      final dados = lanc.toMap();
      dados.remove('id');

      final id = await database.insert(
        'lancamentos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      lanc.id = id;
      return id;
    } else {
      // Aqui pode mandar id normalmente (UPDATE)
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

  // ============================================================
  //  L A N Ç A M E N T O S   P A R C E L A D O S
  //   (COM REGRA DE FATURA QUANDO HOUVER CARTÃO)
  // ============================================================

  Future<void> salvarLancamentosParceladosFuturos(
    Lancamento base,
    int qtdParcelas,
  ) async {
    final database = await db;

    // grupo único para essas parcelas
    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataCompra = base.dataHora;
    final bool pagoBase = base.pago;
    final DateTime? dataPagamentoBase =
        pagoBase ? (base.dataPagamento ?? DateTime.now()) : null;

    // ==========================
    // Cálculo das datas de cada parcela
    // → sempre na data da compra + i meses
    //   (forçando dia <= 28 p/ evitar problemas
    //    com meses menores)
    // ==========================
    final List<DateTime> datasParcelas = [];

    for (int i = 0; i < qtdParcelas; i++) {
      int mes = dataCompra.month + i;
      int ano = dataCompra.year + ((mes - 1) ~/ 12);
      mes = ((mes - 1) % 12) + 1;

      final int dia = min(dataCompra.day, 28);
      datasParcelas.add(DateTime(ano, mes, dia));
    }

    // ==========================
    // Gravação das parcelas
    // ==========================
    for (int i = 0; i < qtdParcelas; i++) {
      final DateTime dataParcela = datasParcelas[i];

      final lancParcela = base.copyWith(
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoBase,
        dataPagamento: dataPagamentoBase,
        // aqui NÃO marcamos como pagamento de fatura,
        // é um gasto normal; a fatura será gerada
        // depois pelo botão "Gerar fatura"
        pagamentoFatura: base.pagamentoFatura,
      );

      await database.insert('lancamentos', lancParcela.toMap());

      // se não está pago, também cria entrada em conta_pagar
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
  //  L A N Ç A M E N T O  À  V I S T A   NO   C A R T Ã O
  //   → CRIA LANÇAMENTO PENDENTE NA DATA DA FATURA
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
    dados.remove('id'); // 👈 não manda id no insert

    await database.insert('lancamentos', dados);
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
          cartao.toMapInsert(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        cartao.id = id;

        return id;
      } else {
        final linhas = await database.update(
          'cartao_credito',
          cartao.toMapUpdate(),
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
