import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';

class ConsumoMetrica {
  final double total;
  final double limite;
  final double percentual; // 0..100+

  const ConsumoMetrica({
    required this.total,
    required this.limite,
    required this.percentual,
  });
}

class MetricaLimiteRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  int semanaDoAno(DateTime d) {
    // semana começando na segunda; simples e estável para o app
    final day = DateTime(d.year, d.month, d.day);
    final weekday = day.weekday; // 1..7
    final monday = day.subtract(Duration(days: weekday - 1));
    final firstDay = DateTime(d.year, 1, 1);
    final firstWeekday = firstDay.weekday;
    final firstMonday = firstDay.subtract(Duration(days: firstWeekday - 1));
    final diff = monday.difference(firstMonday).inDays;
    return (diff ~/ 7) + 1;
  }

  DateTime _primeiraSegundaDoAno(int ano) {
    final firstDay = DateTime(ano, 1, 1);
    final firstWeekday = firstDay.weekday; // 1..7
    return firstDay.subtract(Duration(days: firstWeekday - 1));
  }

  /// Retorna uma data de referência (segunda-feira) para uma semana do ano.
  /// Usa a mesma regra simplificada de [semanaDoAno] (semanas iniciam na segunda).
  DateTime referenciaDaSemana({
    required int ano,
    required int semana,
  }) {
    final base = _primeiraSegundaDoAno(ano);
    return base.add(Duration(days: (semana - 1) * 7));
  }

  /// Intervalo de uma semana específica do ano.
  (DateTime inicio, DateTime fim) intervaloDaSemana({
    required int ano,
    required int semana,
  }) {
    final inicio = referenciaDaSemana(ano: ano, semana: semana);
    final fim = inicio.add(const Duration(days: 7)).subtract(
      const Duration(milliseconds: 1),
    );
    return (inicio, fim);
  }

  Future<List<MetricaLimite>> listarPorPeriodo({
    required String periodoTipo,
    required int ano,
    int? mes,
    int? semana,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'metricas_limites',
      where: 'periodo_tipo = ? AND ano = ? AND mes IS ? AND semana IS ?',
      whereArgs: [periodoTipo, ano, mes, semana],
      orderBy: 'id_categoria_personalizada, id_subcategoria_personalizada',
    );
    return rows.map((m) => MetricaLimite.fromMap(m)).toList();
  }

  /// Lista métricas do período atual (mensal do mês atual + semanal da semana atual).
  /// Útil para telas de análise/seleção sem ter que varrer o banco todo.
  Future<List<MetricaLimite>> listarDoPeriodoAtual(DateTime agora) async {
    final mensal = await listarPorPeriodo(
      periodoTipo: 'mensal',
      ano: agora.year,
      mes: agora.month,
      semana: null,
    );
    final semanal = await listarPorPeriodo(
      periodoTipo: 'semanal',
      ano: agora.year,
      mes: null,
      semana: semanaDoAno(agora),
    );
    return [...mensal, ...semanal];
  }

  (int ano, int mes) _sub1Month(int ano, int mes) {
    if (mes == 1) return (ano - 1, 12);
    return (ano, mes - 1);
  }

  /// Gera (no melhor esforço) as métricas do mês atual a partir das métricas
  /// marcadas como recorrentes no mês anterior.
  ///
  /// Regra:
  /// - só considera métricas com `periodo_tipo = 'mensal'` e `recorrente = 1`
  /// - clona do mês anterior -> mês atual
  /// - usa `INSERT OR IGNORE` para não sobrescrever ajustes feitos no mês atual
  Future<void> gerarRecorrentesDoMesAtualSeNecessario(DateTime agora) async {
    final db = await _db;

    final (anoBase, mesBase) = _sub1Month(agora.year, agora.month);
    final anoAlvo = agora.year;
    final mesAlvo = agora.month;

    final baseRows = await db.query(
      'metricas_limites',
      where: "periodo_tipo = 'mensal' AND recorrente = 1 AND ano = ? AND mes = ?",
      whereArgs: [anoBase, mesBase],
    );

    if (baseRows.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();
    for (final r in baseRows) {
      final base = Map<String, dynamic>.from(r);
      base.remove('id');

      base['ano'] = anoAlvo;
      base['mes'] = mesAlvo;
      base['semana'] = null;

      // mantemos recorrente=1 para continuar gerando nos meses seguintes
      base['recorrente'] = 1;

      // timestamps
      base['criado_em'] = nowMs;
      base['atualizado_em'] = nowMs;

      batch.insert(
        'metricas_limites',
        base,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<int> salvar(MetricaLimite m) async {
    final db = await _db;
    final now = DateTime.now();
    final map = m.toMap();

    if (m.id == null) {
      map.remove('id');
      map['criado_em'] = now.millisecondsSinceEpoch;
      map['atualizado_em'] = now.millisecondsSinceEpoch;
      return db.insert(
        'metricas_limites',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      map['atualizado_em'] = now.millisecondsSinceEpoch;
      return db.update(
        'metricas_limites',
        map..remove('criado_em'),
        where: 'id = ?',
        whereArgs: [m.id],
      );
    }
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('metricas_limites', where: 'id = ?', whereArgs: [id]);
  }

  /// Retorna intervalo [inicio, fim] inclusivo baseado em uma data de referência.
  (DateTime inicio, DateTime fim) intervaloPeriodo({
    required String periodoTipo,
    required DateTime referencia,
  }) {
    if (periodoTipo == 'semanal') {
      // Semana começando na segunda
      final weekday = referencia.weekday; // 1=Mon..7=Sun
      final inicio = DateTime(
        referencia.year,
        referencia.month,
        referencia.day,
      ).subtract(Duration(days: weekday - 1));
      final fim = inicio.add(const Duration(days: 7)).subtract(
        const Duration(milliseconds: 1),
      );
      return (inicio, fim);
    }

    final inicio = DateTime(referencia.year, referencia.month, 1);
    final fim = DateTime(referencia.year, referencia.month + 1, 1).subtract(
      const Duration(milliseconds: 1),
    );
    return (inicio, fim);
  }

  DateTime _dataValida(int ano, int mes, int dia, [int h = 0, int m = 0, int s = 0, int ms = 0]) {
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final d = dia.clamp(1, ultimoDia);
    return DateTime(ano, mes, d, h, m, s, ms);
  }

  /// Intervalo do ciclo da fatura (fechamento→fechamento) para o cartão.
  /// Ex.: fechamento dia 08 no mês 04/2026 => 09/03/2026 .. 08/04/2026 23:59:59.999
  (DateTime inicio, DateTime fim) intervaloCicloFatura({
    required int anoReferencia,
    required int mesReferencia,
    required int diaFechamento,
  }) {
    int mesAnterior = mesReferencia - 1;
    int anoAnterior = anoReferencia;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    final fechamentoAnterior = _dataValida(anoAnterior, mesAnterior, diaFechamento);
    final inicio = fechamentoAnterior.add(const Duration(days: 1));
    final fim = _dataValida(anoReferencia, mesReferencia, diaFechamento, 23, 59, 59, 999);
    return (inicio, fim);
  }

  (int ano, int mes) _add1Month(int ano, int mes) {
    if (mes == 12) return (ano + 1, 1);
    return (ano, mes + 1);
  }

  Future<ConsumoMetrica> calcularConsumo({
    required MetricaLimite metrica,
    required DateTime referenciaPeriodo,
  }) async {
    final db = await _db;

    final bool metricaCredito =
        metrica.formaPagamento == 0; // FormaPagamento.credito.index (V1)

    // Para crédito em período mensal, calculamos pelo ciclo de fatura (fechamento→fechamento),
    // respeitando o cadastro do cartão (dia de fechamento). Para "todos os cartões",
    // somamos o ciclo de cada um.
    final bool usarCicloFatura = metricaCredito && metrica.periodoTipo == 'mensal';

    final anoSelecionado = metrica.ano;
    final mesSelecionado = metrica.mes ?? referenciaPeriodo.month;

    if (usarCicloFatura) {
      // Descobre cartões a considerar
      final idsCartao = <int>[];
      if (metrica.idCartao != null) {
        idsCartao.add(metrica.idCartao!);
      } else {
        final cartoes = await db.query(
          'cartao_credito',
          columns: const ['id'],
          where: 'id IS NOT NULL',
        );
        for (final c in cartoes) {
          final id = (c['id'] as num?)?.toInt();
          if (id != null) idsCartao.add(id);
        }
      }

      double total = 0.0;

      for (final idCartao in idsCartao) {
        final row = await db.query(
          'cartao_credito',
          columns: const ['dia_fechamento', 'dia_vencimento'],
          where: 'id = ?',
          whereArgs: [idCartao],
          limit: 1,
        );
        final diaFech =
            (row.isEmpty ? null : (row.first['dia_fechamento'] as num?)?.toInt());
        final diaVenc =
            (row.isEmpty ? null : (row.first['dia_vencimento'] as num?)?.toInt());
        if (diaFech == null) {
          // Sem fechamento configurado: fallback para o mês calendário.
          final (iniMes, fimMes) = intervaloPeriodo(
            periodoTipo: 'mensal',
            referencia: DateTime(anoSelecionado, mesSelecionado, 1),
          );
          total += await _sumLancamentos(
            db: db,
            metrica: metrica,
            inicio: iniMes,
            fim: fimMes,
            forceCartaoId: idCartao,
            // ciclo de fatura sempre soma compras (não pagamento de fatura)
            forcePagamentoFaturaZero: true,
          );
          continue;
        }

        // Regra para casar com a fatura mostrada na Home (vencimento no mês seguinte ao "mês selecionado"):
        // - Se vencimento <= fechamento, a fatura vence no mês seguinte ao mês de FECHAMENTO.
        //   Então, para Abr/2026 (mês selecionado), o fechamento está em Abr/2026.
        // - Se vencimento > fechamento, a fatura vence no MESMO mês do fechamento.
        //   Então, para Abr/2026 (mês selecionado), o fechamento está em Mai/2026.
        final bool vencNoMesSeguinte =
            (diaVenc != null) && (diaVenc <= diaFech);
        final (anoFech, mesFech) = vencNoMesSeguinte
            ? (anoSelecionado, mesSelecionado)
            : _add1Month(anoSelecionado, mesSelecionado);

        final (ini, fim) = intervaloCicloFatura(
          anoReferencia: anoFech,
          mesReferencia: mesFech,
          diaFechamento: diaFech,
        );

        total += await _sumLancamentos(
          db: db,
          metrica: metrica,
          inicio: ini,
          fim: fim,
          forceCartaoId: idCartao,
          // ciclo de fatura sempre soma compras (não pagamento de fatura)
          forcePagamentoFaturaZero: true,
          // precisa bater com o valor da fatura (pagamento_fatura=1) que é gerado
          // somando compras do ciclo sem aplicar filtros de "pago" ou tipo_movimento.
          ignorePagoAndTipoMovimento: true,
        );
      }

      final limite = metrica.limiteValor;
      final pct = limite <= 0 ? 0.0 : (total / limite) * 100.0;
      return ConsumoMetrica(total: total, limite: limite, percentual: pct);
    }

    final (inicio, fim) = intervaloPeriodo(
      periodoTipo: metrica.periodoTipo,
      referencia: referenciaPeriodo,
    );

    // Base: despesas do período (tipo_movimento = despesa (1))
    final where = <String>[
      'data_hora >= ? AND data_hora <= ?',
      'tipo_movimento = ?',
      if (metrica.idCategoriaPersonalizada > 0)
        'id_categoria_personalizada = ?',
      if (metrica.idSubcategoriaPersonalizada != null)
        'id_subcategoria_personalizada = ?',
      if (metrica.formaPagamento != null) 'forma_pagamento = ?',
      if (metrica.idCartao != null) 'id_cartao = ?',
      if (metrica.idConta != null) 'id_conta = ?',
      if (metricaCredito)
        (metrica.ignorarPagamentoFatura
            ? 'pagamento_fatura = 0' // compras do cartão (evita duplicar com a fatura)
            : 'pagamento_fatura = 1') // apenas o lançamento de fatura (quando o usuário registra só a fatura)
      else if (metrica.ignorarPagamentoFatura)
        'pagamento_fatura = 0',
      if (metrica.considerarSomentePagos) 'pago = 1',
      if (!metrica.incluirFuturos) 'data_hora <= ?',
    ];

    final args = <Object?>[
      inicio.millisecondsSinceEpoch,
      fim.millisecondsSinceEpoch,
      1, // despesa (mantém comportamento do V1)
      if (metrica.idCategoriaPersonalizada > 0) metrica.idCategoriaPersonalizada,
      if (metrica.idSubcategoriaPersonalizada != null)
        metrica.idSubcategoriaPersonalizada,
      if (metrica.formaPagamento != null) metrica.formaPagamento,
      if (metrica.idCartao != null) metrica.idCartao,
      if (metrica.idConta != null) metrica.idConta,
      if (!metrica.incluirFuturos) DateTime.now().millisecondsSinceEpoch,
    ];

    final result = await db.rawQuery(
      '''
      SELECT SUM(valor) AS total
      FROM lancamentos
      WHERE ${where.join(' AND ')}
      ''',
      args,
    );

    final total = ((result.first['total'] as num?) ?? 0).toDouble();
    final limite = metrica.limiteValor;
    final pct = limite <= 0 ? 0.0 : (total / limite) * 100.0;

    return ConsumoMetrica(total: total, limite: limite, percentual: pct);
  }

  /// Soma despesas no intervalo [inicio, fim] aplicando os mesmos filtros
  /// que a métrica usa no `calcularConsumo()` (categoria/forma/cartão/conta,
  /// pago/futuros/pagamento de fatura).
  ///
  /// Observação: aqui o intervalo é explícito, então NÃO aplicamos a regra de
  /// ciclo de fatura (fechamento→fechamento). Isso é intencional para análises
  /// por subperíodos (semana/dia) dentro de um mês.
  Future<double> somarGastosNoIntervalo({
    required MetricaLimite metrica,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final db = await _db;
    final bool metricaCredito = metrica.formaPagamento == 0;

    final where = <String>[
      'data_hora >= ? AND data_hora <= ?',
      'tipo_movimento = ?',
      if (metrica.idCategoriaPersonalizada > 0)
        'id_categoria_personalizada = ?',
      if (metrica.idSubcategoriaPersonalizada != null)
        'id_subcategoria_personalizada = ?',
      if (metrica.formaPagamento != null) 'forma_pagamento = ?',
      if (metrica.idCartao != null) 'id_cartao = ?',
      if (metrica.idConta != null) 'id_conta = ?',
      if (metricaCredito)
        (metrica.ignorarPagamentoFatura ? 'pagamento_fatura = 0' : 'pagamento_fatura = 1')
      else if (metrica.ignorarPagamentoFatura)
        'pagamento_fatura = 0',
      if (metrica.considerarSomentePagos) 'pago = 1',
      if (!metrica.incluirFuturos) 'data_hora <= ?',
    ];

    final args = <Object?>[
      inicio.millisecondsSinceEpoch,
      fim.millisecondsSinceEpoch,
      1,
      if (metrica.idCategoriaPersonalizada > 0) metrica.idCategoriaPersonalizada,
      if (metrica.idSubcategoriaPersonalizada != null)
        metrica.idSubcategoriaPersonalizada,
      if (metrica.formaPagamento != null) metrica.formaPagamento,
      if (metrica.idCartao != null) metrica.idCartao,
      if (metrica.idConta != null) metrica.idConta,
      if (!metrica.incluirFuturos) DateTime.now().millisecondsSinceEpoch,
    ];

    final result = await db.rawQuery(
      '''
      SELECT SUM(valor) AS total
      FROM lancamentos
      WHERE ${where.join(' AND ')}
      ''',
      args,
    );
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<double> _sumLancamentos({
    required Database db,
    required MetricaLimite metrica,
    required DateTime inicio,
    required DateTime fim,
    required int forceCartaoId,
    required bool forcePagamentoFaturaZero,
    bool ignorePagoAndTipoMovimento = false,
  }) async {
    final where = <String>[
      'data_hora >= ? AND data_hora <= ?',
      if (!ignorePagoAndTipoMovimento) 'tipo_movimento = ?',
      if (metrica.idCategoriaPersonalizada > 0)
        'id_categoria_personalizada = ?',
      if (metrica.idSubcategoriaPersonalizada != null)
        'id_subcategoria_personalizada = ?',
      if (metrica.formaPagamento != null) 'forma_pagamento = ?',
      'id_cartao = ?',
      if (metrica.idConta != null) 'id_conta = ?',
      if (forcePagamentoFaturaZero) 'pagamento_fatura = 0',
      if (!ignorePagoAndTipoMovimento && metrica.considerarSomentePagos)
        'pago = 1',
      if (!ignorePagoAndTipoMovimento && !metrica.incluirFuturos)
        'data_hora <= ?',
    ];

    final args = <Object?>[
      inicio.millisecondsSinceEpoch,
      fim.millisecondsSinceEpoch,
      if (!ignorePagoAndTipoMovimento) 1,
      if (metrica.idCategoriaPersonalizada > 0) metrica.idCategoriaPersonalizada,
      if (metrica.idSubcategoriaPersonalizada != null)
        metrica.idSubcategoriaPersonalizada,
      if (metrica.formaPagamento != null) metrica.formaPagamento,
      forceCartaoId,
      if (metrica.idConta != null) metrica.idConta,
      if (!ignorePagoAndTipoMovimento && !metrica.incluirFuturos)
        DateTime.now().millisecondsSinceEpoch,
    ];

    final result = await db.rawQuery(
      '''
      SELECT SUM(valor) AS total
      FROM lancamentos
      WHERE ${where.join(' AND ')}
      ''',
      args,
    );
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<bool> jaDisparouAlerta({
    required int metricaId,
    required String periodoChave,
    required int nivel,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'metricas_alertas_disparados',
      where: 'metrica_id = ? AND periodo_chave = ? AND nivel = ?',
      whereArgs: [metricaId, periodoChave, nivel],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> registrarAlerta({
    required int metricaId,
    required String periodoChave,
    required int nivel,
  }) async {
    final db = await _db;
    await db.insert(
      'metricas_alertas_disparados',
      {
        'metrica_id': metricaId,
        'periodo_chave': periodoChave,
        'nivel': nivel,
        'disparado_em': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

