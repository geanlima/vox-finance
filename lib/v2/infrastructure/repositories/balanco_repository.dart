import 'package:sqflite/sqflite.dart';

class BalancoMesRow {
  final int ano;
  final int mes; // 1-12

  final int ganhos; // centavos
  final int gastosFixos;
  final int gastosVariaveis;

  final int gastosTotal; // ✅ novo (saídas totais)
  final int saldo; // ✅ novo (ganhos - gastosTotal)

  final int parcelas; // por enquanto 0
  final int dividas; // por enquanto 0

  const BalancoMesRow({
    required this.ano,
    required this.mes,
    required this.ganhos,
    required this.gastosFixos,
    required this.gastosVariaveis,
    required this.gastosTotal,
    required this.saldo,
    required this.parcelas,
    required this.dividas,
  });

  /// Mantemos compatível com seu uso atual (balanco)
  int get balanco => saldo - (parcelas + dividas);
}

class BalancoAnoResumo {
  final int ano;
  final int ganhos;
  final int gastosFixos;
  final int gastosVariaveis;
  final int gastosTotal;
  final int saldo;

  const BalancoAnoResumo({
    required this.ano,
    required this.ganhos,
    required this.gastosFixos,
    required this.gastosVariaveis,
    required this.gastosTotal,
    required this.saldo,
  });
}

class BalancoRepository {
  final Database db;
  const BalancoRepository(this.db);

  Future<BalancoAnoResumo> resumoAno(int ano) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN m.direcao = 'entrada' THEN m.valor_centavos ELSE 0 END) AS ganhos,

        SUM(CASE WHEN m.direcao = 'saida' AND c.tipo = 'fixa'
          THEN m.valor_centavos ELSE 0 END) AS gastos_fixos,

        SUM(CASE WHEN m.direcao = 'saida' AND c.tipo = 'variavel'
          THEN m.valor_centavos ELSE 0 END) AS gastos_variaveis,

        SUM(CASE WHEN m.direcao = 'saida'
          THEN m.valor_centavos ELSE 0 END) AS gastos_total,

        (
          SUM(CASE WHEN m.direcao = 'entrada' THEN m.valor_centavos ELSE 0 END)
          -
          SUM(CASE WHEN m.direcao = 'saida' THEN m.valor_centavos ELSE 0 END)
        ) AS saldo

      FROM movimentos m
      LEFT JOIN categorias c ON c.id = m.categoria_id
      WHERE substr(m.data, 1, 4) = ?
      ''',
      [ano.toString()],
    );

    final r = rows.isNotEmpty ? rows.first : <String, Object?>{};
    final ganhos = (r['ganhos'] as int?) ?? 0;
    final fixos = (r['gastos_fixos'] as int?) ?? 0;
    final variaveis = (r['gastos_variaveis'] as int?) ?? 0;
    final total = (r['gastos_total'] as int?) ?? 0;
    final saldo = (r['saldo'] as int?) ?? (ganhos - total);

    return BalancoAnoResumo(
      ano: ano,
      ganhos: ganhos,
      gastosFixos: fixos,
      gastosVariaveis: variaveis,
      gastosTotal: total,
      saldo: saldo,
    );
  }

  Future<List<BalancoMesRow>> listarAno(int ano) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        CAST(substr(m.data, 1, 4) AS INTEGER) AS ano,
        CAST(substr(m.data, 6, 2) AS INTEGER) AS mes,

        SUM(CASE WHEN m.direcao = 'entrada' THEN m.valor_centavos ELSE 0 END) AS ganhos,

        SUM(CASE WHEN m.direcao = 'saida' AND c.tipo = 'fixa'
          THEN m.valor_centavos ELSE 0 END) AS gastos_fixos,

        SUM(CASE WHEN m.direcao = 'saida' AND c.tipo = 'variavel'
          THEN m.valor_centavos ELSE 0 END) AS gastos_variaveis,

        SUM(CASE WHEN m.direcao = 'saida'
          THEN m.valor_centavos ELSE 0 END) AS gastos_total,

        (
          SUM(CASE WHEN m.direcao = 'entrada' THEN m.valor_centavos ELSE 0 END)
          -
          SUM(CASE WHEN m.direcao = 'saida' THEN m.valor_centavos ELSE 0 END)
        ) AS saldo

      FROM movimentos m
      LEFT JOIN categorias c ON c.id = m.categoria_id
      WHERE substr(m.data, 1, 4) = ?
      GROUP BY substr(m.data, 1, 7)
      ORDER BY mes ASC
      ''',
      [ano.toString()],
    );

    // monta os 12 meses, preenchendo faltantes com 0
    final map = <int, BalancoMesRow>{};

    for (final r in rows) {
      final mes = (r['mes'] as int?) ?? 1;
      final ganhos = (r['ganhos'] as int?) ?? 0;
      final fixos = (r['gastos_fixos'] as int?) ?? 0;
      final variaveis = (r['gastos_variaveis'] as int?) ?? 0;
      final total = (r['gastos_total'] as int?) ?? (fixos + variaveis);
      final saldo = (r['saldo'] as int?) ?? (ganhos - total);

      map[mes] = BalancoMesRow(
        ano: ano,
        mes: mes,
        ganhos: ganhos,
        gastosFixos: fixos,
        gastosVariaveis: variaveis,
        gastosTotal: total,
        saldo: saldo,
        parcelas: 0,
        dividas: 0,
      );
    }

    return List.generate(12, (i) {
      final mes = i + 1;
      return map[mes] ??
          BalancoMesRow(
            ano: ano,
            mes: mes,
            ganhos: 0,
            gastosFixos: 0,
            gastosVariaveis: 0,
            gastosTotal: 0,
            saldo: 0,
            parcelas: 0,
            dividas: 0,
          );
    });
  }
}
