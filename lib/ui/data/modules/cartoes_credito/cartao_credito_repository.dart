// ignore_for_file: unnecessary_null_comparison, unused_field, no_leading_underscores_for_local_identifiers

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/fatura_geracao_opcao.dart';
import 'package:vox_finance/ui/data/models/fatura_cartao.dart';
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

  DateTime _dataValida(int ano, int mes, int dia, [int h = 0, int m = 0, int s = 0, int ms = 0]) {
    final ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
    final d = dia.clamp(1, ultimoDiaMes);
    return DateTime(ano, mes, d, h, m, s, ms);
  }

  (int inicioMs, int fimMs) _rangeDiaMs(DateTime d) {
    final ini = DateTime(d.year, d.month, d.day);
    final fim = ini.add(const Duration(days: 1)).subtract(
      const Duration(milliseconds: 1),
    );
    return (ini.millisecondsSinceEpoch, fim.millisecondsSinceEpoch);
  }

  /// Regra do vencimento:
  /// - Se o dia de vencimento for menor/igual ao dia de fechamento, o vencimento cai no mês seguinte.
  /// - Caso contrário, cai no mesmo mês do fechamento.
  DateTime _dataVencimentoPorReferencia({
    required int anoFechamento,
    required int mesFechamento,
    required int diaFechamento,
    required int diaVencimento,
  }) {
    final vencNoMesSeguinte = diaVencimento <= diaFechamento;
    final mesVenc = vencNoMesSeguinte ? (mesFechamento + 1) : mesFechamento;
    final anoVenc = vencNoMesSeguinte && mesFechamento == 12 ? (anoFechamento + 1) : anoFechamento;
    return _dataValida(anoVenc, mesVenc, diaVencimento);
  }

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

    final int diaFechamento =
        cartao.diaFechamento!.clamp(1, DateTime(hoje.year, hoje.month + 1, 0).day);
    final int diaVencimento = cartao.diaVencimento!.clamp(1, 31);

    int anoAtual = hoje.year;
    int mesAtual = hoje.month;

    // 2) Período de compras que entram na fatura
    // Regra correta: do dia SEGUINTE ao fechamento anterior até o dia do fechamento (inclusive).
    // Ex.: fechamento 08/05 => período 09/04..08/05 e vencimento 15/05.
    int mesAnterior = mesAtual - 1;
    int anoAnterior = anoAtual;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    final fechamentoAnterior = _dataValida(anoAnterior, mesAnterior, diaFechamento);
    final inicioPeriodo = fechamentoAnterior.add(const Duration(days: 1));
    final fimPeriodo = _dataValida(anoAtual, mesAtual, diaFechamento, 23, 59, 59, 999);

    final inicioMs = inicioPeriodo.millisecondsSinceEpoch;
    final fimMs = fimPeriodo.millisecondsSinceEpoch;

    // 3) Buscar lançamentos (compras) que compõem essa fatura
    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );
    if (compras.isEmpty) {
      await _upsertFaturaSemCompras(
        database: database,
        cartao: cartao,
        idCartao: idCartao,
        anoReferencia: anoAtual,
        mesReferencia: mesAtual,
        dataFechamento: fimPeriodo,
        dataVencimento: _dataVencimentoPorReferencia(
          anoFechamento: anoAtual,
          mesFechamento: mesAtual,
          diaFechamento: diaFechamento,
          diaVencimento: diaVencimento,
        ),
      );
      return;
    }

    // 4) Somar total da fatura
    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );

    if (total <= 0) return;

    // Vencimento pode cair no mês seguinte (ex.: fechamento 20, vencimento 01).
    final dataVencimento = _dataVencimentoPorReferencia(
      anoFechamento: anoAtual,
      mesFechamento: mesAtual,
      diaFechamento: diaFechamento,
      diaVencimento: diaVencimento,
    );

    // Lista com os IDs dos lançamentos que compõem a fatura (lado N)
    final idsLancamentos = compras.map<int>((row) => row['id'] as int).toList();

    // 5) Gera/atualiza o LANCAMENTO da fatura (o que aparece na grid)
    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

    int idLancamentoFatura;

    // Verifica se já existe lançamento de fatura para esse vencimento
    final (vencIniMs, vencFimMs) = _rangeDiaMs(dataVencimento);
    final faturaExistente = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, vencIniMs, vencFimMs],
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
          // normaliza data_hora para o dia do vencimento (evita duplicar por horário)
          'data_hora': DateTime(
            dataVencimento.year,
            dataVencimento.month,
            dataVencimento.day,
          ).millisecondsSinceEpoch,
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

    await _contaPagarRepo.upsertContaPagarDaFatura(
      idLancamento: idLancamentoFatura,
      descricao: descricaoFatura,
      valor: total,
      dataVencimento: dataVencimento,
      idCartao: idCartao,
    );

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

  /// Gera/atualiza a fatura correspondente a uma **compra** realizada na data [dataCompra].
  ///
  /// Regra:
  /// - compra até o dia de fechamento (inclusive) entra na fatura que fecha no mesmo mês da compra
  /// - compra após o fechamento entra na fatura que fecha no mês seguinte
  Future<void> gerarFaturaDoCartaoParaCompra({
    required int idCartao,
    required DateTime dataCompra,
  }) async {
    final database = await _dbService.db;
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

    final compra = DateTime(
      dataCompra.year,
      dataCompra.month,
      dataCompra.day,
      dataCompra.hour,
      dataCompra.minute,
      dataCompra.second,
      dataCompra.millisecond,
    );

    final diaFech = cartao.diaFechamento!.clamp(1, DateTime(compra.year, compra.month + 1, 0).day);
    final diaVenc = cartao.diaVencimento!.clamp(1, 31);

    // Determina o mês/ano de fechamento da fatura que contém esta compra.
    // Regra correta: se a compra acontecer após o dia do fechamento (fim do dia),
    // ela entra no mês de fechamento seguinte.
    final fechamentoEsteMesFim = _dataValida(
      compra.year,
      compra.month,
      diaFech,
      23,
      59,
      59,
      999,
    );
    final bool aposFechamento = compra.isAfter(fechamentoEsteMesFim);
    final DateTime referenciaFechamento =
        aposFechamento
            ? DateTime(compra.year, compra.month + 1, 1)
            : DateTime(compra.year, compra.month, 1);

    final int anoAtual = referenciaFechamento.year;
    final int mesAtual = referenciaFechamento.month;

    int mesAnterior = mesAtual - 1;
    int anoAnterior = anoAtual;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    final fechamentoAnterior = _dataValida(anoAnterior, mesAnterior, diaFech);
    final inicioPeriodo = fechamentoAnterior.add(const Duration(days: 1));
    final fimPeriodo = _dataValida(anoAtual, mesAtual, diaFech, 23, 59, 59, 999);
    final inicioMs = inicioPeriodo.millisecondsSinceEpoch;
    final fimMs = fimPeriodo.millisecondsSinceEpoch;

    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );
    if (compras.isEmpty) {
      await _upsertFaturaSemCompras(
        database: database,
        cartao: cartao,
        idCartao: idCartao,
        anoReferencia: anoAtual,
        mesReferencia: mesAtual,
        dataFechamento: fimPeriodo,
        dataVencimento: _dataVencimentoPorReferencia(
          anoFechamento: anoAtual,
          mesFechamento: mesAtual,
          diaFechamento: diaFech,
          diaVencimento: diaVenc,
        ),
      );
      return;
    }

    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );
    if (total <= 0) return;

    final dataVencimento = _dataVencimentoPorReferencia(
      anoFechamento: anoAtual,
      mesFechamento: mesAtual,
      diaFechamento: diaFech,
      diaVencimento: diaVenc,
    );
    final idsLancamentos = compras.map<int>((row) => row['id'] as int).toList();

    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

    int idLancamentoFatura;
    final (vencIniMs2, vencFimMs2) = _rangeDiaMs(dataVencimento);
    final faturaExistente = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, vencIniMs2, vencFimMs2],
      limit: 1,
    );

    if (faturaExistente.isNotEmpty) {
      idLancamentoFatura = faturaExistente.first['id'] as int;
      await database.update(
        'lancamentos',
        {
          'valor': total,
          'descricao': descricaoFatura,
          'data_hora': DateTime(
            dataVencimento.year,
            dataVencimento.month,
            dataVencimento.day,
          ).millisecondsSinceEpoch,
          'pago': 0,
          'data_pagamento': null,
        },
        where: 'id = ?',
        whereArgs: [idLancamentoFatura],
      );
    } else {
      final primeiraCompra = Lancamento.fromMap(compras.first);
      final lancFatura = Lancamento(
        valor: total,
        descricao: descricaoFatura,
        formaPagamento: FormaPagamento.credito,
        dataHora: DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day),
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

    await _contaPagarRepo.upsertContaPagarDaFatura(
      idLancamento: idLancamentoFatura,
      descricao: descricaoFatura,
      valor: total,
      dataVencimento: DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day),
      idCartao: idCartao,
    );

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

    await salvarFaturaCartaoLancamentos(
      idFatura: idFatura,
      idsLancamentos: idsLancamentos,
      substituirVinculos: true,
    );
  }

  /// Garante que existam lançamentos de fatura (pagamento_fatura=1) para os próximos meses,
  /// mesmo que ainda não existam compras no período.
  ///
  /// - Cria o lançamento da fatura no vencimento (valor 0) quando não houver compras.
  /// - Quando houver compras, o fluxo normal de geração recalcula e atualiza valores/vínculos.
  Future<void> garantirFaturasFuturasAPartirDaCompra({
    required int idCartao,
    required DateTime dataCompra,
    int mesesFuturos = 12,
  }) async {
    if (mesesFuturos < 0) return;
    final db = await _dbService.db;

    final res = await db.query(
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

    DateTime _addMonths(DateTime d, int months) {
      return DateTime(d.year, d.month + months, 1);
    }

    final compra = DateTime(dataCompra.year, dataCompra.month, dataCompra.day);
    final diaFech = cartao.diaFechamento!
        .clamp(1, DateTime(compra.year, compra.month + 1, 0).day);
    final diaVenc = cartao.diaVencimento!.clamp(1, 31);

    // Determina o mês de fechamento do ciclo que contém a compra.
    final fechamentoEsteMesFim = _dataValida(
      compra.year,
      compra.month,
      diaFech,
      23,
      59,
      59,
      999,
    );
    final bool aposFechamento = compra.isAfter(fechamentoEsteMesFim);
    final DateTime refFechamentoBase =
        aposFechamento
            ? DateTime(compra.year, compra.month + 1, 1)
            : DateTime(compra.year, compra.month, 1);

    for (int i = 0; i <= mesesFuturos; i++) {
      final ref = _addMonths(refFechamentoBase, i);
      final anoAtual = ref.year;
      final mesAtual = ref.month;

      // Período do ciclo: do dia seguinte ao fechamento anterior até o dia do fechamento (inclusive).
      int mesAnterior = mesAtual - 1;
      int anoAnterior = anoAtual;
      if (mesAnterior == 0) {
        mesAnterior = 12;
        anoAnterior--;
      }
      final fechamentoAnterior = _dataValida(anoAnterior, mesAnterior, diaFech);
      final inicioPeriodo = fechamentoAnterior.add(const Duration(days: 1));
      final fimPeriodo = _dataValida(anoAtual, mesAtual, diaFech, 23, 59, 59, 999);

      final compras = await db.query(
        'lancamentos',
        columns: const ['id', 'valor'],
        where: '''
id_cartao = ?
AND forma_pagamento = ?
AND pagamento_fatura = 0
AND data_hora >= ?
AND data_hora <= ?
''',
        whereArgs: [
          idCartao,
          FormaPagamento.credito.index,
          inicioPeriodo.millisecondsSinceEpoch,
          fimPeriodo.millisecondsSinceEpoch,
        ],
      );

      // Se houver compras, recalcula pelo fluxo normal (atualiza valor/vínculos).
      if (compras.isNotEmpty) {
        await gerarFaturaDoCartao(idCartao, referencia: ref);
        continue;
      }

      // Caso não haja compras: ainda assim garante o "lançamento de fatura" (valor 0).
      final dataVencimento = _dataVencimentoPorReferencia(
        anoFechamento: anoAtual,
        mesFechamento: mesAtual,
        diaFechamento: diaFech,
        diaVencimento: diaVenc,
      );
      final dataVencMs = DateTime(
        dataVencimento.year,
        dataVencimento.month,
        dataVencimento.day,
      ).millisecondsSinceEpoch;

      final (vencIniMs3, vencFimMs3) = _rangeDiaMs(dataVencimento);
      final existeLanc = await db.query(
        'lancamentos',
        columns: const ['id'],
        where:
            'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ? AND data_hora <= ?',
        whereArgs: [idCartao, vencIniMs3, vencFimMs3],
        limit: 1,
      );

      final descricaoFatura =
          'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

      int idLancamentoFatura;
      if (existeLanc.isNotEmpty) {
        idLancamentoFatura = (existeLanc.first['id'] as num).toInt();
        await db.update(
          'lancamentos',
          {
            'valor': 0.0,
            'descricao': descricaoFatura,
            'data_hora': dataVencMs,
            'pago': 0,
            'data_pagamento': null,
          },
          where: 'id = ?',
          whereArgs: [idLancamentoFatura],
        );
      } else {
        final lanc = Lancamento(
          valor: 0.0,
          descricao: descricaoFatura,
          formaPagamento: FormaPagamento.credito,
          dataHora: DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day),
          pagamentoFatura: true,
          pago: false,
          dataPagamento: null,
          idCartao: idCartao,
        );
        final dados = lanc.toMap();
        dados['pago'] = 0;
        dados['data_pagamento'] = null;
        idLancamentoFatura = await db.insert(
          'lancamentos',
          dados,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Cria/atualiza a fatura_cartao com valor 0 e vínculos vazios.
      final idFatura = await salvarFaturaCartao(
        idCartao: idCartao,
        anoReferencia: anoAtual,
        mesReferencia: mesAtual,
        dataFechamento: fimPeriodo,
        dataVencimento: dataVencimento,
        valorTotal: 0.0,
        pago: false,
        dataPagamento: null,
      );
      await salvarFaturaCartaoLancamentos(
        idFatura: idFatura,
        idsLancamentos: const [],
        substituirVinculos: true,
      );

      await _contaPagarRepo.upsertContaPagarDaFatura(
        idLancamento: idLancamentoFatura,
        descricao: descricaoFatura,
        valor: 0.0,
        dataVencimento: DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day),
        idCartao: idCartao,
      );
    }
  }

  Future<void> _upsertFaturaSemCompras({
    required Database database,
    required CartaoCredito cartao,
    required int idCartao,
    required int anoReferencia,
    required int mesReferencia,
    required DateTime dataFechamento,
    required DateTime dataVencimento,
  }) async {
    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesReferencia.toString().padLeft(2, '0')}/$anoReferencia';

    final dataVencMs = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    ).millisecondsSinceEpoch;

    // 1) Garante o lançamento de fatura (valor 0)
    final (vencIniMs4, vencFimMs4) = _rangeDiaMs(dataVencimento);
    final faturaExistente = await database.query(
      'lancamentos',
      columns: const ['id'],
      where:
          'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, vencIniMs4, vencFimMs4],
      limit: 1,
    );

    int idLancamentoFatura;
    if (faturaExistente.isNotEmpty) {
      idLancamentoFatura = (faturaExistente.first['id'] as num).toInt();
      await database.update(
        'lancamentos',
        {
          'valor': 0.0,
          'descricao': descricaoFatura,
          'data_hora': dataVencMs,
          'pago': 0,
          'data_pagamento': null,
        },
        where: 'id = ?',
        whereArgs: [idLancamentoFatura],
      );
    } else {
      final lancFatura = Lancamento(
        valor: 0.0,
        descricao: descricaoFatura,
        formaPagamento: FormaPagamento.credito,
        dataHora: DateTime(
          dataVencimento.year,
          dataVencimento.month,
          dataVencimento.day,
        ),
        pagamentoFatura: true,
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

    await _contaPagarRepo.upsertContaPagarDaFatura(
      idLancamento: idLancamentoFatura,
      descricao: descricaoFatura,
      valor: 0.0,
      dataVencimento: DateTime(
        dataVencimento.year,
        dataVencimento.month,
        dataVencimento.day,
      ),
      idCartao: idCartao,
    );

    // 2) Garante a fatura_cartao com valor 0 e vínculos vazios
    final idFatura = await salvarFaturaCartao(
      idCartao: idCartao,
      anoReferencia: anoReferencia,
      mesReferencia: mesReferencia,
      dataFechamento: dataFechamento,
      dataVencimento: dataVencimento,
      valorTotal: 0.0,
      pago: false,
      dataPagamento: null,
    );
    await salvarFaturaCartaoLancamentos(
      idFatura: idFatura,
      idsLancamentos: const [],
      substituirVinculos: true,
    );
  }

  /// Gera faturas (pagamento_fatura=1 + fatura_cartao) para lançamentos já existentes,
  /// recalculando por ciclo de fechamento (deduplicado por mês de fechamento).
  Future<int> gerarFaturasDosLancamentosExistentes() async {
    final db = await _dbService.db;

    final cartoesRows = await db.query(
      'cartao_credito',
      columns: ['id', 'dia_fechamento', 'dia_vencimento', 'tipo', 'controla_fatura'],
    );
    if (cartoesRows.isEmpty) return 0;

    int geradas = 0;

    for (final r in cartoesRows) {
      final idCartao = (r['id'] as num?)?.toInt();
      if (idCartao == null) continue;

      final tipoIdx = (r['tipo'] as num?)?.toInt() ?? 0;
      final tipo =
          (tipoIdx >= 0 && tipoIdx < TipoCartao.values.length) ? TipoCartao.values[tipoIdx] : TipoCartao.credito;
      final bool ehCreditoLike = tipo == TipoCartao.credito || tipo == TipoCartao.ambos;
      if (!ehCreditoLike) continue;

      final rawControla = r['controla_fatura'];
      final controla = rawControla == null ? true : ((rawControla as int?) == 1);
      if (!controla) continue;

      final int? diaFech = (r['dia_fechamento'] as num?)?.toInt();
      final int? diaVenc = (r['dia_vencimento'] as num?)?.toInt();
      if (diaFech == null || diaVenc == null) continue;

      final compras = await db.query(
        'lancamentos',
        columns: ['data_hora'],
        where: 'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0',
        whereArgs: [idCartao, FormaPagamento.credito.index],
      );
      if (compras.isEmpty) continue;

      final periodos = <int>{};
      for (final c in compras) {
        final ms = (c['data_hora'] as num?)?.toInt();
        if (ms == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final ultimoDiaMes = DateTime(dt.year, dt.month + 1, 0).day;
        final fechDia = diaFech.clamp(1, ultimoDiaMes);
        final fechamento = DateTime(dt.year, dt.month, fechDia, 23, 59, 59, 999);
        final ref = dt.isAfter(fechamento) ? DateTime(dt.year, dt.month + 1, 1) : DateTime(dt.year, dt.month, 1);
        periodos.add(ref.year * 100 + ref.month);
      }

      final lista = periodos.toList()..sort();
      for (final p in lista) {
        final ano = p ~/ 100;
        final mes = p % 100;
        await gerarFaturaDoCartao(idCartao, referencia: DateTime(ano, mes, 1));
        geradas += 1;
      }
    }

    return geradas;
  }

  Future<List<FaturaGeracaoOpcao>> listarOpcoesGeracaoFaturas() async {
    final db = await _dbService.db;

    final cartoes = await getCartoesCredito();
    final cartoesValidos =
        cartoes
            .where((c) => c.id != null)
            .where(
              (c) =>
                  (c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos) &&
                  c.controlaFatura &&
                  c.diaFechamento != null &&
                  c.diaVencimento != null,
            )
            .toList();

    final opcoes = <FaturaGeracaoOpcao>[];
    final seen = <String>{};

    for (final c in cartoesValidos) {
      final idCartao = c.id!;
      final diaFech = c.diaFechamento!;

      final rows = await db.query(
        'lancamentos',
        columns: const ['data_hora'],
        where: 'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0',
        whereArgs: [idCartao, FormaPagamento.credito.index],
      );
      if (rows.isEmpty) continue;

      for (final r in rows) {
        final ms = (r['data_hora'] as num?)?.toInt();
        if (ms == null) continue;
        final compra = DateTime.fromMillisecondsSinceEpoch(ms);
        final ultimoDiaMes = DateTime(compra.year, compra.month + 1, 0).day;
        final fechDia = diaFech.clamp(1, ultimoDiaMes);
        final fechamentoFim = DateTime(
          compra.year,
          compra.month,
          fechDia,
          23,
          59,
          59,
          999,
        );
        final bool aposFechamento = compra.isAfter(fechamentoFim);
        final ref =
            aposFechamento
                ? DateTime(compra.year, compra.month + 1, 1)
                : DateTime(compra.year, compra.month, 1);

        final venc = _dataVencimentoPorReferencia(
          anoFechamento: ref.year,
          mesFechamento: ref.month,
          diaFechamento: diaFech,
          diaVencimento: c.diaVencimento!.clamp(1, 31),
        );
        final opt = FaturaGeracaoOpcao(
          idCartao: idCartao,
          cartaoLabel: c.label,
          anoReferencia: ref.year,
          mesReferencia: ref.month,
          anoVencimento: venc.year,
          mesVencimento: venc.month,
        );
        if (seen.contains(opt.key)) continue;
        seen.add(opt.key);
        opcoes.add(opt);
      }
    }

    opcoes.sort((a, b) {
      final ka = a.anoReferencia * 100 + a.mesReferencia;
      final kb = b.anoReferencia * 100 + b.mesReferencia;
      if (ka != kb) return ka.compareTo(kb);
      return a.cartaoLabel.compareTo(b.cartaoLabel);
    });

    return opcoes;
  }

  Future<int> gerarFaturasSelecionadas({
    required List<FaturaGeracaoOpcao> selecionadas,
    bool overwrite = true,
  }) async {
    if (selecionadas.isEmpty) return 0;
    final db = await _dbService.db;

    int geradas = 0;
    for (final opt in selecionadas) {
      if (overwrite) {
        await _apagarFaturaPeriodo(
          db: db,
          idCartao: opt.idCartao,
          anoReferencia: opt.anoReferencia,
          mesReferencia: opt.mesReferencia,
        );
      }
      await gerarFaturaDoCartao(
        opt.idCartao,
        referencia: DateTime(opt.anoReferencia, opt.mesReferencia, 1),
      );
      geradas += 1;
    }
    return geradas;
  }

  Future<void> _apagarFaturaPeriodo({
    required Database db,
    required int idCartao,
    required int anoReferencia,
    required int mesReferencia,
  }) async {
    // 1) Remove fatura_cartao e vínculos
    final fatRows = await db.query(
      'fatura_cartao',
      columns: const ['id', 'data_vencimento'],
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, anoReferencia, mesReferencia],
      limit: 1,
    );
    int? vencMs;
    if (fatRows.isNotEmpty) {
      final idFat = (fatRows.first['id'] as num).toInt();
      vencMs = (fatRows.first['data_vencimento'] as num?)?.toInt();
      await db.delete(
        'fatura_cartao_lancamento',
        where: 'id_fatura = ?',
        whereArgs: [idFat],
      );
      await db.delete(
        'fatura_cartao',
        where: 'id = ?',
        whereArgs: [idFat],
      );
    }

    // 2) Remove o lançamento de fatura (pagamento_fatura) e a conta_pagar vinculada
    if (vencMs != null) {
      final lancFat = await db.query(
        'lancamentos',
        columns: const ['id'],
        where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?',
        whereArgs: [idCartao, vencMs],
        limit: 1,
      );
      if (lancFat.isNotEmpty) {
        final idLanc = (lancFat.first['id'] as num).toInt();
        await db.delete(
          'conta_pagar',
          where: 'id_lancamento = ?',
          whereArgs: [idLanc],
        );
        await db.delete(
          'lancamentos',
          where: 'id = ?',
          whereArgs: [idLanc],
        );
      }
    }
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

  /// Faturas salvas para o cartão (referência ano/mês), mais recentes primeiro.
  Future<List<FaturaCartao>> listarFaturasPorCartao(int idCartao) async {
    final db = await _dbService.db;
    final rows = await db.query(
      'fatura_cartao',
      where: 'id_cartao = ?',
      whereArgs: [idCartao],
      orderBy: 'ano DESC, mes DESC',
    );
    return rows.map(FaturaCartao.fromMap).toList();
  }

  /// Lançamentos (compras) vinculados à fatura pelo id em `fatura_cartao`.
  Future<List<Lancamento>> getLancamentosPorIdFatura(int idFatura) async {
    final db = await _dbService.db;

    final vinculos = await db.query(
      'fatura_cartao_lancamento',
      where: 'id_fatura = ?',
      whereArgs: [idFatura],
    );

    if (vinculos.isEmpty) return [];

    final idsLanc =
        vinculos.map<int>((row) => row['id_lancamento'] as int).toList();

    final placeholders = List.filled(idsLanc.length, '?').join(',');

    final lancRows = await db.query(
      'lancamentos',
      where: 'id IN ($placeholders)',
      whereArgs: idsLanc,
      orderBy: 'data_hora ASC',
    );

    return lancRows.map((e) => Lancamento.fromMap(e)).toList();
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
    final DateTime venc = faturaLancamento.dataHora;
    final int vencMs = DateTime(venc.year, venc.month, venc.day)
        .millisecondsSinceEpoch;

    // 1) Localizar a fatura na tabela fatura_cartao pelo vencimento.
    // Importante: o "mês de referência" pode ser o mês de fechamento (ex.: 04/2026),
    // enquanto o lançamento de fatura cai no mês seguinte (vencimento, ex.: 15/05/2026).
    // Portanto, não é confiável bater por (ano, mes) a partir da data do lançamento.
    final faturaRows = await db.query(
      'fatura_cartao',
      where: 'id_cartao = ? AND data_vencimento = ?',
      whereArgs: [idCartao, vencMs],
      limit: 1,
    );

    if (faturaRows.isEmpty) {
      return [];
    }

    final int idFatura = faturaRows.first['id'] as int;
    return getLancamentosPorIdFatura(idFatura);
  }
}
