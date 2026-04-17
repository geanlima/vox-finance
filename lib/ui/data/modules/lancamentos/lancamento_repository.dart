// lib/ui/data/modules/lancamentos/lancamento_repository.dart
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/renda_mensal_resumo.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class TotaisDia {
  final double totalDespesas;
  final double totalReceitas;

  TotaisDia({required this.totalDespesas, required this.totalReceitas});
}

class LancamentoRepository {
  final DbService _dbService = DbService.instance;
  Future<Database> get _db async => _dbService.db;
  final CartaoCreditoRepository _cartaoRepo = CartaoCreditoRepository();

  // 🔒 PADRÃO DO BANCO (AJUSTE SE PRECISAR)
  static const int tipoDespesaDb = 1;
  /// Índice de [TipoMovimento.receita] no banco (0).
  static const int tipoReceitaDb = 0;

  // ----------------- Helpers -----------------

  double _toDouble(Object? v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ----------------- CRUD -----------------

  Future<List<Lancamento>> getDespesasFixasByDay(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    return (await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? AND data_hora < ?
      AND tipo_movimento = ?
      AND tipo_despesa = ?
    ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoDespesaDb,
        1, // FIXA (ajuste conforme seu mapeamento)
      ],
      orderBy: 'data_hora DESC',
    )).map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<void> deletarPorGrupo(String grupoParcelas) async {
    final db = await _db;
    final lancsAntes = await getParcelasPorGrupo(grupoParcelas);
    await db.delete(
      'lancamentos',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupoParcelas],
    );

    // Recalcula as faturas afetadas pelas parcelas removidas (se eram compras no crédito).
    final vistos = <String>{};
    for (final l in lancsAntes) {
      if (l.pagamentoFatura) continue;
      if (l.formaPagamento != FormaPagamento.credito) continue;
      final idCartao = l.idCartao;
      if (idCartao == null) continue;
      final key =
          '$idCartao:${l.dataHora.year}-${l.dataHora.month}-${l.dataHora.day}';
      if (vistos.contains(key)) continue;
      vistos.add(key);
      await _cartaoRepo.gerarFaturaDoCartaoParaCompra(
        idCartao: idCartao,
        dataCompra: l.dataHora,
      );
    }
  }

  Future<Lancamento?> getById(int id) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Lancamento.fromMap(result.first);
  }

  /// Vários lançamentos por id (ex.: vínculo conta_pagar.id_lancamento).
  Future<Map<int, Lancamento>> getByIds(Set<int> ids) async {
    if (ids.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'lancamentos',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
    return {
      for (final r in rows)
        if (r['id'] is int) (r['id'] as int): Lancamento.fromMap(r),
    };
  }

  Future<int> salvar(Lancamento lanc) async {
    final db = await _db;

    if (lanc.id == null) {
      final dados = lanc.toMap()..remove('id');
      final id = await db.insert(
        'lancamentos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      lanc.id = id;
      await _atualizarFaturaSeNecessario(lanc);
      return id;
    } else {
      final antes = await getById(lanc.id!);
      final rows = await db.update(
        'lancamentos',
        lanc.toMap(),
        where: 'id = ?',
        whereArgs: [lanc.id],
      );
      await _sincronizarContaPagarVinculada(lanc);

      // Se o lançamento era uma compra no crédito, recalcula a fatura do ciclo "antigo"
      // (ex.: trocou cartão/forma/data/valor).
      if (antes != null &&
          !antes.pagamentoFatura &&
          antes.formaPagamento == FormaPagamento.credito &&
          antes.idCartao != null) {
        await _cartaoRepo.gerarFaturaDoCartaoParaCompra(
          idCartao: antes.idCartao!,
          dataCompra: antes.dataHora,
        );
      }
      await _atualizarFaturaSeNecessario(lanc);
      return rows;
    }
  }

  Future<void> _sincronizarContaPagarVinculada(Lancamento lanc) async {
    final id = lanc.id;
    if (id == null) return;
    final db = await _db;

    // Atualiza a conta a pagar vinculada ao lançamento (se existir).
    // Não mexe em data_vencimento aqui porque pode seguir regras do cartão.
    await db.update(
      'conta_pagar',
      {
        'descricao': lanc.descricao,
        'valor': lanc.valor,
        'forma_pagamento': lanc.formaPagamento.index,
        'id_cartao': lanc.idCartao,
        'id_conta': lanc.idConta,
      },
      where: 'id_lancamento = ?',
      whereArgs: [id],
    );
  }

  Future<void> _atualizarFaturaSeNecessario(Lancamento lanc) async {
    // Gera/atualiza fatura do cartão a cada compra no crédito.
    // Evita loop: o próprio lançamento de "pagamento de fatura" não deve disparar recálculo.
    if (lanc.pagamentoFatura) return;
    if (lanc.formaPagamento != FormaPagamento.credito) return;
    final idCartao = lanc.idCartao;
    if (idCartao == null) return;

    // Recalcula a fatura do ciclo correto (fechamento→fechamento) para esta compra.
    // Ex.: fechamento dia 08. Compra em 03/05 pertence ao ciclo que começou em 08/04
    // e vence em 15/05 (portanto precisa recalcular o "mês de fechamento" 04).
    await _cartaoRepo.gerarFaturaDoCartaoParaCompra(
      idCartao: idCartao,
      dataCompra: lanc.dataHora,
    );

    // Também garante as faturas futuras (mesmo sem compras) para facilitar o planejamento.
    await _cartaoRepo.garantirFaturasFuturasAPartirDaCompra(
      idCartao: idCartao,
      dataCompra: lanc.dataHora,
      mesesFuturos: 12,
    );
  }

  /// Salva o lançamento e replica forma/cartão/conta nos demais lançamentos
  /// do mesmo grupo (compra parcelada) e nas contas a pagar vinculadas.
  Future<void> salvarESincronizarPagamentoNoGrupoParcelado(
    Lancamento lanc,
  ) async {
    final id = lanc.id;
    final grupo = lanc.grupoParcelas;
    final total = lanc.parcelaTotal ?? 0;
    if (id == null || grupo == null || grupo.isEmpty || total <= 1) {
      await salvar(lanc);
      return;
    }

    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'lancamentos',
        lanc.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      final patch = <String, Object?>{
        'forma_pagamento': lanc.formaPagamento.index,
        'id_cartao': lanc.idCartao,
        'id_conta': lanc.idConta,
      };

      await txn.update(
        'lancamentos',
        patch,
        where: 'grupo_parcelas = ? AND id != ?',
        whereArgs: [grupo, id],
      );

      final idsRows = await txn.query(
        'lancamentos',
        columns: ['id'],
        where: 'grupo_parcelas = ?',
        whereArgs: [grupo],
      );
      for (final r in idsRows) {
        final idL = r['id'] as int?;
        if (idL == null) continue;
        await txn.update(
          'conta_pagar',
          patch,
          where: 'id_lancamento = ?',
          whereArgs: [idL],
        );
      }
    });

    await _atualizarFaturaSeNecessario(lanc);
  }

  Future<void> deletar(int id) async {
    final db = await _db;

    final antes = await getById(id);

    // 1) Apaga a parcela de contas a pagar vinculada a este lançamento
    await db.delete('conta_pagar', where: 'id_lancamento = ?', whereArgs: [id]);

    // 2) Apaga o lançamento em si
    await db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);

    // 3) Se era compra no crédito, recalcula a fatura do ciclo correspondente.
    if (antes != null &&
        !antes.pagamentoFatura &&
        antes.formaPagamento == FormaPagamento.credito &&
        antes.idCartao != null) {
      await _cartaoRepo.gerarFaturaDoCartaoParaCompra(
        idCartao: antes.idCartao!,
        dataCompra: antes.dataHora,
      );
    }
  }

  // ----------------- Consultas por data -----------------

  Future<TotaisDia> getTotaisPorDia(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN tipo_movimento = ? THEN valor ELSE 0 END) AS total_despesas,
        SUM(CASE WHEN tipo_movimento = ? THEN valor ELSE 0 END) AS total_receitas
      FROM lancamentos
      WHERE data_hora >= ? AND data_hora < ?
      ''',
      [
        tipoDespesaDb,
        tipoReceitaDb,
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
      ],
    );

    final row = result.isNotEmpty ? result.first : <String, Object?>{};

    return TotaisDia(
      totalDespesas: _toDouble(row['total_despesas']),
      totalReceitas: _toDouble(row['total_receitas']),
    );
  }

  Future<List<Lancamento>> getByDay(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora < ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora DESC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<List<Lancamento>> getByPeriodo(DateTime inicio, DateTime fim) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora <= ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  // ----------------- Futuro -----------------

  Future<List<Lancamento>> getFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'data_hora > ? AND data_hora <= ?',
      whereArgs: [
        DateTime.now().millisecondsSinceEpoch,
        dataLimite.millisecondsSinceEpoch,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((map) => Lancamento.fromMap(map)).toList();
  }

  Future<List<Lancamento>> getDespesasByPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? AND data_hora <= ?
      AND tipo_movimento = ?
    ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoDespesaDb,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<List<Lancamento>> getDespesasByDay(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? AND data_hora < ?
      AND tipo_movimento = ?
    ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoDespesaDb,
      ],
      orderBy: 'data_hora DESC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<double> getTotalFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT SUM(valor) AS total
      FROM lancamentos
      WHERE data_hora > ? AND data_hora <= ?
      ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        dataLimite.millisecondsSinceEpoch,
      ],
    );

    return _toDouble(result.first['total']);
  }

  // ----------------- Pago -----------------

  Future<void> marcarComoPago(int id, bool pago) async {
    final db = await _db;

    await db.update(
      'lancamentos',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ----------------- Parcelas -----------------

  Future<List<Lancamento>> getParcelasPorGrupo(String grupo) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<void> salvarParceladosFuturos(
    Lancamento base,
    int qtdParcelas, {
    CartaoCredito? cartao,
  }) async {
    final db = await _db;

    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataCompra = base.dataHora;

    // ⭐ Buscar diaVencimento do cartão (para contas a pagar)
    int? diaVencimentoCartao = cartao?.diaVencimento;
    int? diaFechamentoCartao = cartao?.diaFechamento;
    if (diaVencimentoCartao == null && base.idCartao != null) {
      final cartaoRepo = CartaoCreditoRepository();
      final cartaoDb = await cartaoRepo.getCartaoCreditoById(base.idCartao!);
      diaVencimentoCartao = cartaoDb?.diaVencimento;
      diaFechamentoCartao = cartaoDb?.diaFechamento;
    }

    // ✅ Melhor prática: transação (evita salvar metade se der erro)
    await db.transaction((txn) async {
      for (int i = 0; i < qtdParcelas; i++) {
        final numeroParcela = i + 1;

        // LANÇAMENTO: data compra + (n-1) meses
        DateTime dataLancamento = _calcularDataLancamento(
          dataCompra: dataCompra,
          numeroParcela: numeroParcela,
        );

        // CONTA A PAGAR: vencimento no dia do cartão
        DateTime dataVencimentoConta;
        if (diaVencimentoCartao != null && diaFechamentoCartao != null) {
          dataVencimentoConta = _calcularVencimentoCartaoParaConta(
            dataCompra: dataCompra,
            diaFechamento: diaFechamentoCartao,
            diaVencimento: diaVencimentoCartao,
            numeroParcela: numeroParcela,
          );

          dataVencimentoConta = _garantirDataValida(
            dataVencimentoConta.year,
            dataVencimentoConta.month,
            dataVencimentoConta.day,
          );
        } else {
          dataVencimentoConta = dataCompra.add(
            Duration(days: 30 * numeroParcela),
          );
        }

        // 1) Lancamento
        final bool pagoParcela = base.pago; // vem da tela
        final DateTime? dataPg =
            pagoParcela ? (base.dataPagamento ?? DateTime.now()) : null;

        final lancParcela = base.copyWith(
          id: null,
          valor: valorParcela,
          dataHora: dataLancamento,
          grupoParcelas: grupo,
          parcelaNumero: numeroParcela,
          parcelaTotal: qtdParcelas,
          pago: pagoParcela,
          dataPagamento: dataPg,
        );

        final dadosLanc = lancParcela.toMap()..remove('id');
        final int idLancamento = await txn.insert('lancamentos', dadosLanc);

        // 2) conta a pagar (espelha forma/conta/cartão do lançamento)
        final conta = ContaPagar(
          id: null,
          descricao: lancParcela.descricao,
          valor: valorParcela,
          dataVencimento: dataVencimentoConta,
          pago: false,
          dataPagamento: null,
          parcelaNumero: numeroParcela,
          parcelaTotal: qtdParcelas,
          grupoParcelas: grupo,
          idLancamento: idLancamento,
          formaPagamento: lancParcela.formaPagamento,
          idCartao: lancParcela.idCartao,
          idConta: lancParcela.idConta,
        );

        final dadosConta = conta.toMap()..remove('id');
        await txn.insert('conta_pagar', dadosConta);
      }
    });

    // Após salvar parcelas no crédito, garante a fatura atualizada para TODOS os meses
    // que receberam parcelas (cada parcela entra em um ciclo de fechamento diferente).
    if (base.formaPagamento == FormaPagamento.credito &&
        base.idCartao != null &&
        grupo.isNotEmpty) {
      final parcelas = await getParcelasPorGrupo(grupo);
      for (final p in parcelas) {
        if (p.pagamentoFatura) continue;
        if (p.formaPagamento != FormaPagamento.credito) continue;
        if (p.idCartao == null) continue;
        await _cartaoRepo.gerarFaturaDoCartaoParaCompra(
          idCartao: p.idCartao!,
          dataCompra: p.dataHora,
        );
      }
      return;
    }

    // Fallback: parcela única / outras formas
    await _atualizarFaturaSeNecessario(base);
  }

  DateTime _calcularVencimentoCartaoParaConta({
    required DateTime dataCompra,
    required int diaFechamento,
    required int diaVencimento,
    required int numeroParcela,
  }) {
    // Vencimento deve sempre cair no dia configurado no cartão (diaVencimento).
    // Se o mês não tiver esse dia (ex.: 31 em fevereiro), ajusta para o último dia do mês.
    final dia = diaVencimento.clamp(1, 31);

    // Regra do cartão (fechamento + vencimento):
    // - Compra até o dia de fechamento (inclusive) entra na fatura que **fecha** neste mês;
    //   o pagamento (dia de vencimento) cai no **mês seguinte** (ex.: fecha 20/02 → vence 01/03).
    // - Compra **depois** do fechamento entra na próxima fatura; o 1º vencimento fica
    //   **dois** meses à frente do mês da compra no calendário (ex.: compra 25/02, fecha 20 →1º venc. 01/04).
    final fechamentoEsteMes = _garantirDataValida(
      dataCompra.year,
      dataCompra.month,
      diaFechamento.clamp(1, 31),
    );

    final bool aposFechamento = dataCompra.isAfter(fechamentoEsteMes);
    final int baseOffset = aposFechamento ? 2 : 1;
    final int offsetMes = baseOffset + (numeroParcela - 1);

    return _garantirDataValida(
      dataCompra.year,
      dataCompra.month + offsetMes,
      dia,
    );
  }

  DateTime _calcularDataLancamento({
    required DateTime dataCompra,
    required int numeroParcela,
  }) {
    if (numeroParcela == 1) return dataCompra;

    return DateTime(
      dataCompra.year,
      dataCompra.month + (numeroParcela - 1),
      dataCompra.day,
      dataCompra.hour,
      dataCompra.minute,
      dataCompra.second,
      dataCompra.millisecond,
    );
  }

  DateTime _garantirDataValida(int ano, int mes, int dia) {
    while (mes > 12) {
      mes -= 12;
      ano += 1;
    }

    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final diaAjustado = dia.clamp(1, ultimoDia);

    return DateTime(ano, mes, diaAjustado);
  }

  // -------------------------------------------------
  // RESUMO MENSAL DE RECEITAS (Minha Renda)
  // -------------------------------------------------

  Future<List<RendaMensalResumo>> getResumoRendaMensal() async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%Y', datetime(data_hora/1000, 'unixepoch')) AS INTEGER) AS ano,
        CAST(strftime('%m', datetime(data_hora/1000, 'unixepoch')) AS INTEGER) AS mes,
        SUM(valor) AS total
      FROM lancamentos
      WHERE tipo_movimento = ?
      GROUP BY ano, mes
      ORDER BY ano DESC, mes DESC;
      ''',
      [tipoReceitaDb],
    );

    return result.map((row) {
      return RendaMensalResumo(
        ano: (row['ano'] as num).toInt(),
        mes: (row['mes'] as num).toInt(),
        total: (row['total'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<Lancamento>> getReceitasDoMes(int ano, int mes) async {
    final db = await _db;

    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);

    final result = await db.query(
      'lancamentos',
      where: '''
        data_hora >= ?
        AND data_hora < ?
        AND tipo_movimento = ?
      ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoReceitaDb,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }
}
