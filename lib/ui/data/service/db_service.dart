// ignore_for_file: unused_local_variable, unused_catch_stack, empty_catches, unused_element

import 'dart:async';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart'
    show FormaPagamento;
import 'package:vox_finance/ui/data/database/database_initializer.dart';
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
    _db ??= await DatabaseInitializer.initialize();
    return _db!;
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

    if (lanc.id == null) {
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
