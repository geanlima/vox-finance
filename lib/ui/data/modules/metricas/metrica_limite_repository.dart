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

  Future<ConsumoMetrica> calcularConsumo({
    required MetricaLimite metrica,
    required DateTime referenciaPeriodo,
  }) async {
    final db = await _db;

    final (inicio, fim) = intervaloPeriodo(
      periodoTipo: metrica.periodoTipo,
      referencia: referenciaPeriodo,
    );

    final bool metricaCredito =
        metrica.formaPagamento == 0; // FormaPagamento.credito.index (V1)

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

