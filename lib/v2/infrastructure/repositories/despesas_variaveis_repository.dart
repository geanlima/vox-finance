import 'package:sqflite/sqflite.dart';

class DespesaVariavelRow {
  final int id;
  final String descricao;
  final int valorCentavos;
  final String status;

  final int anoRef;
  final int mesRef;

  final int? categoriaId;
  final int? formaPagamentoId;

  // ✅ pode ser nulo no banco
  final String? dataGastoIso;

  final String? catNome;
  final String? catEmoji;
  final String? fpNome;

  DespesaVariavelRow({
    required this.id,
    required this.descricao,
    required this.valorCentavos,
    required this.status,
    required this.anoRef,
    required this.mesRef,
    required this.dataGastoIso,
    this.categoriaId,
    this.formaPagamentoId,
    this.catNome,
    this.catEmoji,
    this.fpNome,
  });

  factory DespesaVariavelRow.fromMap(Map<String, dynamic> m) {
    return DespesaVariavelRow(
      id: (m['id'] as int),
      descricao: (m['descricao'] as String?) ?? '',
      valorCentavos: (m['valor_centavos'] as int?) ?? 0,
      status: (m['status'] as String?) ?? 'a_pagar',
      anoRef: (m['ano_ref'] as int?) ?? 0,
      mesRef: (m['mes_ref'] as int?) ?? 0,
      dataGastoIso: m['data_gasto_iso'] as String?,
      categoriaId: m['categoria_id'] as int?,
      formaPagamentoId: m['forma_pagamento_id'] as int?,
      catNome: m['cat_nome'] as String?,
      catEmoji: m['cat_emoji'] as String?,
      fpNome: m['fp_nome'] as String?,
    );
  }
}

class DespesasVariaveisRepository {
  final Database db;
  DespesasVariaveisRepository(this.db);

  Future<List<DespesaVariavelRow>> listarNoMes(int ano, int mes) async {
    final res = await db.rawQuery(
      '''
      SELECT d.*,
             c.nome AS cat_nome,
             c.emoji AS cat_emoji,
             f.nome AS fp_nome
      FROM despesas_variaveis d
      LEFT JOIN categorias c ON c.id = d.categoria_id
      LEFT JOIN formas_pagamento f ON f.id = d.forma_pagamento_id
      WHERE d.ano_ref = ? AND d.mes_ref = ?
      ORDER BY d.status ASC, d.data_gasto_iso DESC, d.id DESC
      ''',
      [ano, mes],
    );

    return res.map(DespesaVariavelRow.fromMap).toList();
  }

  Future<int> totalNoMes(int ano, int mes) async {
    final r = await db.rawQuery(
      '''
      SELECT SUM(valor_centavos) total
      FROM despesas_variaveis
      WHERE ano_ref = ? AND mes_ref = ?
      ''',
      [ano, mes],
    );
    return (r.first['total'] as int?) ?? 0;
  }

  Future<int> inserir({
    required String descricao,
    required int valorCentavos,
    required DateTime dataGasto,
    required String status,
    required int anoRef,
    required int mesRef,
    int? categoriaId,
    int? formaPagamentoId,
  }) async {
    final iso =
        '${dataGasto.year.toString().padLeft(4, '0')}-'
        '${dataGasto.month.toString().padLeft(2, '0')}-'
        '${dataGasto.day.toString().padLeft(2, '0')}';

    return db.insert('despesas_variaveis', {
      'descricao': descricao,
      'valor_centavos': valorCentavos,
      'status': status,
      'ano_ref': anoRef,
      'mes_ref': mesRef,
      'categoria_id': categoriaId,
      'forma_pagamento_id': formaPagamentoId,
      'data_gasto_iso': iso,
      'atualizado_em': null,
    });
  }

  Future<void> atualizarStatus(int id, String status) async {
    await db.update(
      'despesas_variaveis',
      {'status': status, 'atualizado_em': "datetime('now')"},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    await db.delete('despesas_variaveis', where: 'id = ?', whereArgs: [id]);
  }
}
