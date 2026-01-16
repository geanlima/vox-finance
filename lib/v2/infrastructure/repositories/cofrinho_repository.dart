import 'package:sqflite/sqflite.dart';

class CofrinhoMensalRow {
  final int ano;
  final int mes; // 1..12
  final double metaMes;
  final double valorGuardado;

  CofrinhoMensalRow({
    required this.ano,
    required this.mes,
    required this.metaMes,
    required this.valorGuardado,
  });

  double get saldo => valorGuardado - metaMes;

  String get status {
    if (valorGuardado <= 0) return 'Aguardando';
    if (valorGuardado >= metaMes) return 'Meta Batida';
    return 'Não Bati';
  }
}

class CofrinhoResumoAno {
  final int ano;
  final double metaAno;
  final double valorGuardado;

  CofrinhoResumoAno({
    required this.ano,
    required this.metaAno,
    required this.valorGuardado,
  });

  double get saldo => valorGuardado - metaAno;

  double get progresso {
    if (metaAno <= 0) return 0;
    final p = valorGuardado / metaAno;
    return p.clamp(0, 1);
  }

  String get status =>
      (valorGuardado >= metaAno) ? 'Meta batida' : 'Em andamento';
}

class CofrinhoRepository {
  final Database db;
  CofrinhoRepository(this.db);

  Future<void> seedAnoSeVazio(int ano, {double metaPadraoMes = 1000}) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(1) FROM cofrinho_mensal WHERE ano = ?',
            [ano],
          ),
        ) ??
        0;

    if (count > 0) return;

    final batch = db.batch();
    for (var mes = 1; mes <= 12; mes++) {
      batch.insert('cofrinho_mensal', {
        'ano': ano,
        'mes': mes,
        'meta_mes': metaPadraoMes,
        'valor_guardado': 0.0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<CofrinhoMensalRow>> listarMensal(int ano) async {
    final rows = await db.query(
      'cofrinho_mensal',
      where: 'ano = ?',
      whereArgs: [ano],
      orderBy: 'mes ASC',
    );

    return rows.map((e) {
      return CofrinhoMensalRow(
        ano: (e['ano'] as int),
        mes: (e['mes'] as int),
        metaMes: (e['meta_mes'] as num).toDouble(),
        valorGuardado: (e['valor_guardado'] as num).toDouble(),
      );
    }).toList();
  }

  Future<void> atualizarMetaMes(int ano, int mes, double metaMes) async {
    await db.update(
      'cofrinho_mensal',
      {'meta_mes': metaMes},
      where: 'ano = ? AND mes = ?',
      whereArgs: [ano, mes],
    );
  }

  Future<void> atualizarValorGuardado(
    int ano,
    int mes,
    double valorGuardado,
  ) async {
    await db.update(
      'cofrinho_mensal',
      {'valor_guardado': valorGuardado},
      where: 'ano = ? AND mes = ?',
      whereArgs: [ano, mes],
    );
  }

  Future<CofrinhoResumoAno?> resumoAno(int ano) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        ano,
        SUM(meta_mes) AS meta_ano,
        SUM(valor_guardado) AS valor_guardado
      FROM cofrinho_mensal
      WHERE ano = ?
      GROUP BY ano
      LIMIT 1;
    ''',
      [ano],
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return CofrinhoResumoAno(
      ano: (r['ano'] as int),
      metaAno: (r['meta_ano'] as num?)?.toDouble() ?? 0.0,
      valorGuardado: (r['valor_guardado'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
