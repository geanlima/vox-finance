// ignore_for_file: unnecessary_null_comparison

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class CartaoCreditoRepository {
  final DbService _dbService;
  final ContaPagarRepository _contaPagarRepo;

  CartaoCreditoRepository({
    DbService? dbService,
    ContaPagarRepository? contaPagarRepo,
  }) : _dbService = dbService ?? DbService(),
       _contaPagarRepo = contaPagarRepo ?? ContaPagarRepository();

  // ============================================================
  //  G E R A R   F A T U R A   D O   C A R T Ã O   (FECHAMENTO)
  // ============================================================

  Future<void> gerarFaturaDoCartao(int idCartao, {DateTime? referencia}) async {
    final database = await _dbService.db;
    final hoje = referencia ?? DateTime.now();

    // 1) Buscar cartão
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

    // 2) Período de compras que entram na fatura
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

    // 3) Buscar lançamentos (compras) que compõem essa fatura
    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );

    if (compras.isEmpty) return;

    // 4) Somar total da fatura
    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );

    if (total <= 0) return;

    final dataVencimento = DateTime(anoAtual, mesAtual, diaVencimento);

    // Lista com os IDs dos lançamentos que compõem a fatura (lado N)
    final idsLancamentos = compras.map<int>((row) => row['id'] as int).toList();

    // 5) Gera/atualiza o LANCAMENTO da fatura (o que aparece na grid)
    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

    int idLancamentoFatura;

    // Verifica se já existe lançamento de fatura para esse vencimento
    final dataVencimentoMs = dataVencimento.millisecondsSinceEpoch;
    final faturaExistente = await database.query(
      'lancamentos',
      where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?',
      whereArgs: [idCartao, dataVencimentoMs],
      limit: 1,
    );

    if (faturaExistente.isNotEmpty) {
      // Atualiza o lançamento já existente
      idLancamentoFatura = faturaExistente.first['id'] as int;

      await database.update(
        'lancamentos',
        {
          'valor': total,
          'descricao': descricaoFatura,
          'pago': 0, // volta a ser pendente
          'data_pagamento': null,
        },
        where: 'id = ?',
        whereArgs: [idLancamentoFatura],
      );
    } else {
      // Cria um novo lançamento de fatura
      final primeiraCompra = Lancamento.fromMap(compras.first);

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

      final dados = lancFatura.toMap();
      dados['pago'] = 0;
      dados['data_pagamento'] = null;

      idLancamentoFatura = await database.insert(
        'lancamentos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 6) Gera/atualiza o registro na tabela FATURA_CARTAO (lado 1)
    final idFatura = await salvarFaturaCartao(
      idCartao: idCartao,
      anoReferencia: anoAtual,
      mesReferencia: mesAtual,
      dataFechamento: fimPeriodo,
      dataVencimento: dataVencimento,
      valorTotal: total,
      pago: false,
      dataPagamento: null,
    );

    // 7) Gera os vínculos 1:N na FATURA_CARTAO_LANCAMENTO (lado N)
    await salvarFaturaCartaoLancamentos(
      idFatura: idFatura,
      idsLancamentos: idsLancamentos,
      substituirVinculos: true,
    );
  }

  // ============================================================
  //  CRUD  C A R T Õ E S   D E   C R É D I T O
  // ============================================================

  Future<int> salvarCartaoCredito(CartaoCredito cartao) async {
    final database = await _dbService.db;

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
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CartaoCredito>> getCartoesCredito() async {
    final database = await _dbService.db;
    try {
      final result = await database.query(
        'cartao_credito',
        orderBy: 'descricao ASC',
      );
      return result.map((e) => CartaoCredito.fromMap(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CartaoCredito?> getCartaoCreditoById(int id) async {
    final database = await _dbService.db;
    try {
      final result = await database.query(
        'cartao_credito',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return CartaoCredito.fromMap(result.first);
    } catch (e) {
      return null;
    }
  }

  Future<void> deletarCartaoCredito(int id) async {
    final database = await _dbService.db;
    await database.delete('cartao_credito', where: 'id = ?', whereArgs: [id]);
  }

  /// Salva/atualiza a fatura do cartão na tabela `fatura_cartao`
  /// (1 registro por cartão/mês).
  ///
  /// Se já existir uma fatura para (id_cartao, ano, mes), atualiza.
  /// Retorna SEMPRE o id da fatura.
  Future<int> salvarFaturaCartao({
    required int idCartao,
    required int anoReferencia,
    required int mesReferencia,
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    required double valorTotal,
    bool pago = false,
    DateTime? dataPagamento,
  }) async {
    final database = await _dbService.db;

    final fechamentoMs = dataFechamento.millisecondsSinceEpoch;
    final vencimentoMs = dataVencimento.millisecondsSinceEpoch;
    final pagamentoMs = dataPagamento?.millisecondsSinceEpoch;

    final existing = await database.query(
      'fatura_cartao',
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, anoReferencia, mesReferencia],
      limit: 1,
    );

    final dados = <String, Object?>{
      'id_cartao': idCartao,
      'ano': anoReferencia,
      'mes': mesReferencia,
      'data_fechamento': fechamentoMs,
      'data_vencimento': vencimentoMs,
      'valor_total': valorTotal,
      'pago': pago ? 1 : 0,
      'data_pagamento': pagamentoMs,
    };

    if (existing.isEmpty) {
      final id = await database.insert(
        'fatura_cartao',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    } else {
      final idFatura = existing.first['id'] as int;
      await database.update(
        'fatura_cartao',
        dados,
        where: 'id = ?',
        whereArgs: [idFatura],
      );
      return idFatura;
    }
  }

  /// Cria vínculos 1:N entre a fatura e os lançamentos na tabela
  /// `fatura_cartao_lancamento`.
  ///
  /// - idFatura: id do registro em fatura_cartao (lado 1)
  /// - idsLancamentos: lista de IDs da tabela lancamentos (lado N)
  ///
  /// Se [substituirVinculos] = true, apaga tudo da fatura antes
  /// de inserir novamente (recalcula a fatura do zero).
  Future<void> salvarFaturaCartaoLancamentos({
    required int idFatura,
    required List<int> idsLancamentos,
    bool substituirVinculos = true,
  }) async {
    final database = await _dbService.db;

    // Se for recalcular a fatura, limpa os vínculos antigos:
    if (substituirVinculos) {
      await database.delete(
        'fatura_cartao_lancamento',
        where: 'id_fatura = ?',
        whereArgs: [idFatura],
      );
    }

    // Insere um vínculo para cada lançamento (1 fatura -> N lançamentos)
    final batch = database.batch();

    for (final idLanc in idsLancamentos) {
      batch.insert('fatura_cartao_lancamento', {
        'id_fatura': idFatura,
        'id_lancamento': idLanc,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  /// Retorna os lançamentos (compras) associados a uma fatura de cartão.
  ///
  /// É esperado que [faturaLancamento] seja o lançamento que representa
  /// a fatura (pagamento_fatura = 1) na tabela `lancamentos`.
  Future<List<Lancamento>> getLancamentosDaFatura(
    Lancamento faturaLancamento,
  ) async {
    final db = await _dbService.db;

    // Precisa ter cartão e data (vencimento da fatura)
    if (faturaLancamento.idCartao == null ||
        faturaLancamento.dataHora == null) {
      return [];
    }

    final int idCartao = faturaLancamento.idCartao!;
    final DateTime data = faturaLancamento.dataHora;
    final int ano = data.year;
    final int mes = data.month;

    // 1) Localizar a fatura na tabela fatura_cartao
    final faturaRows = await db.query(
      'fatura_cartao',
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, ano, mes],
      limit: 1,
    );

    if (faturaRows.isEmpty) {
      return [];
    }

    final int idFatura = faturaRows.first['id'] as int;

    // 2) Buscar vínculos na fatura_cartao_lancamento
    final vinculos = await db.query(
      'fatura_cartao_lancamento',
      where: 'id_fatura = ?',
      whereArgs: [idFatura],
    );

    if (vinculos.isEmpty) return [];

    final idsLanc =
        vinculos.map<int>((row) => row['id_lancamento'] as int).toList();

    // 3) Buscar os lançamentos correspondentes na tabela lancamentos
    final placeholders = List.filled(idsLanc.length, '?').join(',');

    final lancRows = await db.query(
      'lancamentos',
      where: 'id IN ($placeholders)',
      whereArgs: idsLanc,
      orderBy: 'data_hora ASC',
    );

    return lancRows.map((e) => Lancamento.fromMap(e)).toList();
  }
}
