// ignore_for_file: unnecessary_null_comparison, unused_field, no_leading_underscores_for_local_identifiers

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito_calendario.dart';
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

  Future<(int diaFechamento, int diaVencimento)?> getDiasCicloPorReferencia({
    required int idCartao,
    required int anoReferencia,
    required int mesReferencia,
  }) async {
    final db = await _dbService.db;

    // 1) Calendário por mês (prioritário)
    final rows = await db.query(
      'cartao_credito_calendario',
      columns: const ['dia_fechamento', 'dia_vencimento'],
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, anoReferencia, mesReferencia],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final dFech = (rows.first['dia_fechamento'] as num?)?.toInt();
      final dVenc = (rows.first['dia_vencimento'] as num?)?.toInt();
      if (dFech != null && dVenc != null) return (dFech, dVenc);
    }

    // 2) Fallback: cadastro do cartão
    final cartao = await getCartaoCreditoById(idCartao);
    if (cartao == null) return null;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) {
      return null;
    }
    return (cartao.diaFechamento!, cartao.diaVencimento!);
  }

  Future<List<CartaoCreditoCalendario>> listarCalendarioPorCartao(
    int idCartao,
  ) async {
    final db = await _dbService.db;
    final rows = await db.query(
      'cartao_credito_calendario',
      where: 'id_cartao = ?',
      whereArgs: [idCartao],
      orderBy: 'ano DESC, mes DESC',
    );
    return rows.map(CartaoCreditoCalendario.fromMap).toList();
  }

  Future<void> upsertCalendarioMes({
    required int idCartao,
    required int ano,
    required int mes,
    required int diaFechamento,
    required int diaVencimento,
  }) async {
    final db = await _dbService.db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'cartao_credito_calendario',
      columns: const ['id'],
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, ano, mes],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(
        'cartao_credito_calendario',
        {
          'id_cartao': idCartao,
          'ano': ano,
          'mes': mes,
          'dia_fechamento': diaFechamento,
          'dia_vencimento': diaVencimento,
          'criado_em': nowMs,
          'atualizado_em': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final id = (existing.first['id'] as num?)?.toInt();
    if (id == null) return;
    await db.update(
      'cartao_credito_calendario',
      {
        'dia_fechamento': diaFechamento,
        'dia_vencimento': diaVencimento,
        'atualizado_em': nowMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletarCalendarioMes({
    required int idCartao,
    required int ano,
    required int mes,
  }) async {
    final db = await _dbService.db;
    await db.delete(
      'cartao_credito_calendario',
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, ano, mes],
    );
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

  DateTime _calcularVencimentoCartaoParaConta({
    required DateTime dataCompra,
    required int diaFechamento,
    required int diaVencimento,
    required int numeroParcela,
  }) {
    final diaFech = diaFechamento.clamp(
      1,
      DateTime(dataCompra.year, dataCompra.month + 1, 0).day,
    );
    final diaVenc = diaVencimento.clamp(1, 31);

    final fechamentoEsteMesFim = _dataValida(
      dataCompra.year,
      dataCompra.month,
      diaFech,
      23,
      59,
      59,
      999,
    );
    final bool aposFechamento = dataCompra.isAfter(fechamentoEsteMesFim);
    final DateTime refFech = DateTime(
      dataCompra.year,
      dataCompra.month + (aposFechamento ? 1 : 0),
      1,
    );

    final bool vencNoMesSeguinte = diaVenc <= diaFech;
    final int baseOffsetMes = vencNoMesSeguinte ? 1 : 0;
    final int offsetParcela = numeroParcela - 1;

    final int mesVenc = refFech.month + baseOffsetMes + offsetParcela;
    final int anoVenc = refFech.year;

    return _dataValida(anoVenc, mesVenc, diaVenc);
  }

  /// Recalcula:
  /// - vencimentos das parcelas (tabela `conta_pagar`) baseadas no cartão
  /// - faturas do cartão (apagando somente as **não pagas** e gerando novamente)
  ///
  /// Útil quando o usuário altera `dia_fechamento` ou `dia_vencimento`.
  Future<void> regerarParcelasEFaturasAoAlterarDatas({
    required int idCartao,
    required int? novoDiaFechamento,
    required int? novoDiaVencimento,
    int? anoReferencia,
    int? mesReferencia,
    bool incluirPagos = false,
  }) async {
    if (novoDiaFechamento == null || novoDiaVencimento == null) return;
    final db = await _dbService.db;

    // Para preservar pagamentos quando incluir pagos:
    // chave: "ano-mes" -> (pago, data_pagamento_ms, data_vencimento_ms_antiga)
    // Observação: se o vencimento mudar, o pagamento deve ser reaberto.
    final pagamentoAnteriorFatura =
        <String, (bool pago, int? dataPgMs, int? vencMsAntigo)>{};
    final pagamentoAnteriorLanc =
        <String, (bool pago, int? dataPgMs, int? vencMsAntigo)>{};

    await db.transaction((txn) async {
      // 1) Recalcular vencimentos de contas a pagar parceladas no crédito desse cartão
      final gruposRows = await txn.query(
        'conta_pagar',
        columns: const ['grupo_parcelas'],
        where:
            incluirPagos
                ? 'id_cartao = ? AND forma_pagamento = ? AND grupo_parcelas IS NOT NULL AND grupo_parcelas != ""'
                : 'id_cartao = ? AND forma_pagamento = ? AND grupo_parcelas IS NOT NULL AND grupo_parcelas != "" AND (pago IS NULL OR pago = 0)',
        whereArgs: [idCartao, FormaPagamento.credito.index],
        groupBy: 'grupo_parcelas',
      );

      for (final g in gruposRows) {
        final grupo = (g['grupo_parcelas'] as String?)?.trim();
        if (grupo == null || grupo.isEmpty) continue;

        // Compra base: parcela 1 (para calcular a referência do ciclo)
        final baseRows = await txn.query(
          'lancamentos',
          columns: const ['data_hora'],
          where:
              'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND grupo_parcelas = ? AND parcela_numero = 1',
          whereArgs: [idCartao, FormaPagamento.credito.index, grupo],
          limit: 1,
        );
        if (baseRows.isEmpty) continue;
        final baseMs = (baseRows.first['data_hora'] as num?)?.toInt();
        if (baseMs == null) continue;
        final dataCompraBase = DateTime.fromMillisecondsSinceEpoch(baseMs);

        final parcelasConta = await txn.query(
          'conta_pagar',
          columns: const [
            'id',
            'parcela_numero',
            'data_vencimento',
            'pago',
            'data_pagamento',
            'id_lancamento',
          ],
          where:
              incluirPagos
                  ? 'id_cartao = ? AND forma_pagamento = ? AND grupo_parcelas = ?'
                  : 'id_cartao = ? AND forma_pagamento = ? AND grupo_parcelas = ? AND (pago IS NULL OR pago = 0)',
          whereArgs: [idCartao, FormaPagamento.credito.index, grupo],
        );

        for (final p in parcelasConta) {
          final idConta = (p['id'] as num?)?.toInt();
          if (idConta == null) continue;
          final numeroParcela = (p['parcela_numero'] as num?)?.toInt();
          if (numeroParcela == null || numeroParcela <= 0) continue;

          final novoVenc = _calcularVencimentoCartaoParaConta(
            dataCompra: dataCompraBase,
            diaFechamento: novoDiaFechamento,
            diaVencimento: novoDiaVencimento,
            numeroParcela: numeroParcela,
          );
          final novoVencMs =
              DateTime(novoVenc.year, novoVenc.month, novoVenc.day)
                  .millisecondsSinceEpoch;

          final vencAntigoMs = (p['data_vencimento'] as num?)?.toInt();
          final estavaPago = (p['pago'] as int? ?? 0) == 1;
          final reabrir = estavaPago &&
              vencAntigoMs != null &&
              vencAntigoMs != novoVencMs;

          await txn.update(
            'conta_pagar',
            {
              'data_vencimento': novoVencMs,
              if (reabrir) 'pago': 0,
              if (reabrir) 'data_pagamento': null,
            },
            where: 'id = ?',
            whereArgs: [idConta],
          );

          // Importante: não reabre lançamento de cartão aqui.
          // Para cartão, o pagamento é controlado pela conta a pagar/fatura.
        }
      }

      // 2) Apagar faturas não pagas (fatura_cartao + vínculos + lançamento de fatura + conta_pagar vinculada)
      // Se (anoReferencia, mesReferencia) forem informados, limita ao mês selecionado.
      final bool filtrarMes =
          anoReferencia != null &&
          mesReferencia != null &&
          mesReferencia >= 1 &&
          mesReferencia <= 12;

      final fatRows = await txn.query(
        'fatura_cartao',
        columns: const ['id', 'data_vencimento', 'ano', 'mes', 'pago', 'data_pagamento'],
        where:
            filtrarMes
                ? (incluirPagos
                    ? 'id_cartao = ? AND ano = ? AND mes = ?'
                    : 'id_cartao = ? AND (pago IS NULL OR pago = 0) AND ano = ? AND mes = ?')
                : (incluirPagos
                    ? 'id_cartao = ?'
                    : 'id_cartao = ? AND (pago IS NULL OR pago = 0)'),
        whereArgs:
            filtrarMes
                ? [idCartao, anoReferencia, mesReferencia]
                : [idCartao],
      );

      for (final f in fatRows) {
        final idFatura = (f['id'] as num?)?.toInt();
        final vencMs = (f['data_vencimento'] as num?)?.toInt();
        final ano = (f['ano'] as num?)?.toInt();
        final mes = (f['mes'] as num?)?.toInt();
        if (ano != null && mes != null) {
          final key = '$ano-${mes.toString().padLeft(2, '0')}';
          final pago = (f['pago'] as int? ?? 0) == 1;
          final dataPgMs = (f['data_pagamento'] as num?)?.toInt();
          pagamentoAnteriorFatura[key] = (pago, dataPgMs, vencMs);
        }
        if (idFatura != null) {
          await txn.delete(
            'fatura_cartao_lancamento',
            where: 'id_fatura = ?',
            whereArgs: [idFatura],
          );
          await txn.delete(
            'fatura_cartao',
            where: 'id = ?',
            whereArgs: [idFatura],
          );
        }

        if (vencMs == null) continue;

        final lancFat = await txn.query(
          'lancamentos',
          columns: const ['id', 'pago', 'data_pagamento'],
          where:
              incluirPagos
                  ? 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?'
                  : 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ? AND (pago IS NULL OR pago = 0)',
          whereArgs: incluirPagos ? [idCartao, vencMs] : [idCartao, vencMs],
          limit: 1,
        );
        if (lancFat.isEmpty) continue;
        final idLanc = (lancFat.first['id'] as num?)?.toInt();
        if (idLanc == null) continue;

        if (ano != null && mes != null) {
          final key = '$ano-${mes.toString().padLeft(2, '0')}';
          final pago = (lancFat.first['pago'] as int? ?? 0) == 1;
          final dataPgMs = (lancFat.first['data_pagamento'] as num?)?.toInt();
          pagamentoAnteriorLanc[key] = (pago, dataPgMs, vencMs);
        }

        await txn.delete(
          'conta_pagar',
          where: 'id_lancamento = ?',
          whereArgs: [idLanc],
        );
        await txn.delete(
          'lancamentos',
          where: 'id = ?',
          whereArgs: [idLanc],
        );
      }
    });

    // 3) Gerar novamente faturas
    if (anoReferencia != null &&
        mesReferencia != null &&
        mesReferencia >= 1 &&
        mesReferencia <= 12) {
      await gerarFaturaDoCartao(
        idCartao,
        referencia: DateTime(anoReferencia, mesReferencia, 1),
      );

      // Restaura "pago" (se aplicável)
      if (incluirPagos) {
        final key = '$anoReferencia-${mesReferencia.toString().padLeft(2, '0')}';
        await _restaurarPagamentoSeNecessario(
          idCartao: idCartao,
          ano: anoReferencia,
          mes: mesReferencia,
          pagamentoFatura: pagamentoAnteriorFatura[key],
          pagamentoLancamento: pagamentoAnteriorLanc[key],
        );
      }
      return;
    }

    // Padrão: regera tudo a partir das compras existentes
    await gerarFaturasDoCartaoAPartirDosLancamentosExistentes(idCartao);

    if (incluirPagos && pagamentoAnteriorFatura.isNotEmpty) {
      for (final entry in pagamentoAnteriorFatura.entries) {
        final parts = entry.key.split('-');
        if (parts.length != 2) continue;
        final ano = int.tryParse(parts[0]);
        final mes = int.tryParse(parts[1]);
        if (ano == null || mes == null) continue;
        await _restaurarPagamentoSeNecessario(
          idCartao: idCartao,
          ano: ano,
          mes: mes,
          pagamentoFatura: pagamentoAnteriorFatura[entry.key],
          pagamentoLancamento: pagamentoAnteriorLanc[entry.key],
        );
      }
    }
  }

  Future<void> _restaurarPagamentoSeNecessario({
    required int idCartao,
    required int ano,
    required int mes,
    required (bool pago, int? dataPgMs, int? vencMsAntigo)? pagamentoFatura,
    required (bool pago, int? dataPgMs, int? vencMsAntigo)? pagamentoLancamento,
  }) async {
    final db = await _dbService.db;
    final pagoF = pagamentoFatura?.$1 == true;
    final pagoL = pagamentoLancamento?.$1 == true;
    if (!pagoF && !pagoL) return;

    final dataPgMs = pagamentoFatura?.$2 ?? pagamentoLancamento?.$2;
    final vencAntigoMs = pagamentoFatura?.$3 ?? pagamentoLancamento?.$3;

    // Atualiza o lançamento de fatura do período: usa o vencimento gravado na fatura
    final fat = await db.query(
      'fatura_cartao',
      columns: const ['data_vencimento'],
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, ano, mes],
      limit: 1,
    );
    if (fat.isEmpty) return;
    final vencMs = (fat.first['data_vencimento'] as num?)?.toInt();
    if (vencMs == null) return;

    // Se o vencimento mudou, o pagamento anterior não é mais válido → reabre.
    final deveReabrir = vencAntigoMs != null && vencAntigoMs != vencMs;

    // Atualiza fatura_cartao pelo período (ano/mes de referência)
    await db.update(
      'fatura_cartao',
      {
        'pago': deveReabrir ? 0 : 1,
        'data_pagamento': deveReabrir ? null : dataPgMs,
      },
      where: 'id_cartao = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartao, ano, mes],
    );
    final venc = DateTime.fromMillisecondsSinceEpoch(vencMs);
    final (ini, fim) = _rangeDiaMs(venc);

    final lanc = await db.query(
      'lancamentos',
      columns: const ['id'],
      where:
          'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, ini, fim],
      limit: 1,
    );
    if (lanc.isEmpty) return;
    final idLanc = (lanc.first['id'] as num?)?.toInt();
    if (idLanc == null) return;

    await db.update(
      'lancamentos',
      {
        'pago': deveReabrir ? 0 : 1,
        'data_pagamento': deveReabrir ? null : dataPgMs,
      },
      where: 'id = ?',
      whereArgs: [idLanc],
    );

    await db.update(
      'conta_pagar',
      {
        'pago': deveReabrir ? 0 : 1,
        'data_pagamento': deveReabrir ? null : dataPgMs,
      },
      where: 'id_lancamento = ?',
      whereArgs: [idLanc],
    );
  }

  /// Regera faturas do cartão com base nas compras (lancamentos no crédito),
  /// deduplicando por (ano, mes) de referência (mês de fechamento).
  Future<int> gerarFaturasDoCartaoAPartirDosLancamentosExistentes(
    int idCartao,
  ) async {
    final db = await _dbService.db;

    final cartao = await getCartaoCreditoById(idCartao);
    if (cartao == null) return 0;
    final bool ehCreditoLike =
        cartao.tipo == TipoCartao.credito || cartao.tipo == TipoCartao.ambos;
    if (!ehCreditoLike) return 0;
    if (!cartao.controlaFatura) return 0;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) return 0;

    final compras = await db.query(
      'lancamentos',
      columns: const ['data_hora'],
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0',
      whereArgs: [idCartao, FormaPagamento.credito.index],
    );
    if (compras.isEmpty) return 0;

    final diaFech = cartao.diaFechamento!;
    final periodos = <int>{};
    DateTime? ultimaCompra;

    for (final c in compras) {
      final ms = (c['data_hora'] as num?)?.toInt();
      if (ms == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      if (ultimaCompra == null || dt.isAfter(ultimaCompra)) {
        ultimaCompra = dt;
      }

      final ultimoDiaMes = DateTime(dt.year, dt.month + 1, 0).day;
      final fechDia = diaFech.clamp(1, ultimoDiaMes);
      final fechamentoFim = DateTime(dt.year, dt.month, fechDia, 23, 59, 59, 999);
      final ref =
          dt.isAfter(fechamentoFim)
              ? DateTime(dt.year, dt.month + 1, 1)
              : DateTime(dt.year, dt.month, 1);
      periodos.add(ref.year * 100 + ref.month);
    }

    final lista = periodos.toList()..sort();
    for (final p in lista) {
      final ano = p ~/ 100;
      final mes = p % 100;
      await gerarFaturaDoCartao(idCartao, referencia: DateTime(ano, mes, 1));
    }

    // Também garante faturas futuras (valor 0) a partir da última compra.
    if (ultimaCompra != null) {
      await garantirFaturasFuturasAPartirDaCompra(
        idCartao: idCartao,
        dataCompra: ultimaCompra,
        mesesFuturos: 12,
      );
    }

    return lista.length;
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
    final diasCiclo = await getDiasCicloPorReferencia(
      idCartao: idCartao,
      anoReferencia: hoje.year,
      mesReferencia: hoje.month,
    );
    if (diasCiclo == null) return;

    final int diaFechamento =
        diasCiclo.$1.clamp(1, DateTime(hoje.year, hoje.month + 1, 0).day);
    final int diaVencimento = diasCiclo.$2.clamp(1, 31);

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
    // Para descobrir o ciclo da compra, usa o fechamento do MÊS da compra.
    final diasCompraMes = await getDiasCicloPorReferencia(
      idCartao: idCartao,
      anoReferencia: dataCompra.year,
      mesReferencia: dataCompra.month,
    );
    if (diasCompraMes == null) return;

    final compra = DateTime(
      dataCompra.year,
      dataCompra.month,
      dataCompra.day,
      dataCompra.hour,
      dataCompra.minute,
      dataCompra.second,
      dataCompra.millisecond,
    );

    final diaFech = diasCompraMes.$1.clamp(
      1,
      DateTime(compra.year, compra.month + 1, 0).day,
    );

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

    // Agora que sabemos o mês de REFERÊNCIA, pega o fechamento/vencimento daquele mês.
    final diasRef = await getDiasCicloPorReferencia(
      idCartao: idCartao,
      anoReferencia: referenciaFechamento.year,
      mesReferencia: referenciaFechamento.month,
    );
    if (diasRef == null) return;
    final diaVenc = diasRef.$2.clamp(1, 31);

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
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) {
      // pode ainda ter calendário configurado; segue
    }

    DateTime _addMonths(DateTime d, int months) {
      return DateTime(d.year, d.month + months, 1);
    }

    final compra = DateTime(dataCompra.year, dataCompra.month, dataCompra.day);
    // Para descobrir o mês base, usa o fechamento do MÊS da compra.
    final diasCompraMes = await getDiasCicloPorReferencia(
      idCartao: idCartao,
      anoReferencia: compra.year,
      mesReferencia: compra.month,
    );
    if (diasCompraMes == null) return;
    final diaFech = diasCompraMes.$1.clamp(
      1,
      DateTime(compra.year, compra.month + 1, 0).day,
    );

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

      final diasRef = await getDiasCicloPorReferencia(
        idCartao: idCartao,
        anoReferencia: anoAtual,
        mesReferencia: mesAtual,
      );
      if (diasRef == null) continue;
      final int diaFechRef = diasRef.$1.clamp(
        1,
        DateTime(anoAtual, mesAtual + 1, 0).day,
      );
      final int diaVencRef = diasRef.$2.clamp(1, 31);

      // Período do ciclo: do dia seguinte ao fechamento anterior até o dia do fechamento (inclusive).
      int mesAnterior = mesAtual - 1;
      int anoAnterior = anoAtual;
      if (mesAnterior == 0) {
        mesAnterior = 12;
        anoAnterior--;
      }
      final fechamentoAnterior =
          _dataValida(anoAnterior, mesAnterior, diaFechRef);
      final inicioPeriodo = fechamentoAnterior.add(const Duration(days: 1));
      final fimPeriodo =
          _dataValida(anoAtual, mesAtual, diaFechRef, 23, 59, 59, 999);

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
        diaFechamento: diaFechRef,
        diaVencimento: diaVencRef,
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
    final (vencIniMs, vencFimMs) = _rangeDiaMs(venc);

    // 1) Localizar a fatura na tabela fatura_cartao pelo vencimento.
    // Importante: o "mês de referência" pode ser o mês de fechamento (ex.: 04/2026),
    // enquanto o lançamento de fatura cai no mês seguinte (vencimento, ex.: 15/05/2026).
    // Portanto, não é confiável bater por (ano, mes) a partir da data do lançamento.
    final faturaRows = await db.query(
      'fatura_cartao',
      where: 'id_cartao = ? AND data_vencimento >= ? AND data_vencimento <= ?',
      whereArgs: [idCartao, vencIniMs, vencFimMs],
      limit: 1,
    );

    if (faturaRows.isEmpty) {
      return [];
    }

    final int idFatura = faturaRows.first['id'] as int;
    return getLancamentosPorIdFatura(idFatura);
  }
}
