import 'package:sqflite/sqflite.dart';

class ParcelaRow {
  final int id;

  final String dataCompraIso;
  final String descricao;
  final int valorParcelaCentavos;

  final String status; // a_pagar | pago
  final String? dataPagamentoIso;

  final int anoRef;
  final int mesRef;

  final int numeroParcela;
  final int totalParcelas;

  final int? categoriaId;
  final int? formaPagamentoId;

  final bool duplicarParcela;

  final String? catNome;
  final String? catEmoji;
  final String? fpNome;

  const ParcelaRow({
    required this.id,
    required this.dataCompraIso,
    required this.descricao,
    required this.valorParcelaCentavos,
    required this.status,
    required this.dataPagamentoIso,
    required this.anoRef,
    required this.mesRef,
    required this.numeroParcela,
    required this.totalParcelas,
    required this.categoriaId,
    required this.formaPagamentoId,
    required this.duplicarParcela,
    required this.catNome,
    required this.catEmoji,
    required this.fpNome,
  });

  factory ParcelaRow.fromMap(Map<String, dynamic> m) => ParcelaRow(
    id: m['id'] as int,
    dataCompraIso: m['data_compra_iso'] as String,
    descricao: m['descricao'] as String,
    valorParcelaCentavos: m['valor_parcela_centavos'] as int,
    status: m['status'] as String,
    dataPagamentoIso: m['data_pagamento_iso'] as String?,
    anoRef: m['ano_ref'] as int,
    mesRef: m['mes_ref'] as int,
    numeroParcela: m['numero_parcela'] as int,
    totalParcelas: m['total_parcelas'] as int,
    categoriaId: m['categoria_id'] as int?,
    formaPagamentoId: m['forma_pagamento_id'] as int?,
    duplicarParcela: (m['duplicar_parcela'] as int? ?? 0) == 1,
    catNome: m['cat_nome'] as String?,
    catEmoji: m['cat_emoji'] as String?,
    fpNome: m['fp_nome'] as String?,
  );
}

class ParcelamentosRepository {
  final Database db;
  const ParcelamentosRepository(this.db);

  Future<List<ParcelaRow>> listarNoMes(int ano, int mes) async {
    final res = await db.rawQuery(
      '''
      SELECT p.*,
             c.nome AS cat_nome,
             c.emoji AS cat_emoji,
             f.nome AS fp_nome
      FROM parcelamentos p
      LEFT JOIN categorias c ON c.id = p.categoria_id
      LEFT JOIN formas_pagamento f ON f.id = p.forma_pagamento_id
      WHERE p.ano_ref = ? AND p.mes_ref = ?
      ORDER BY p.status ASC,
               COALESCE(p.data_pagamento_iso,'9999-12-31') ASC,
               p.id DESC
      ''',
      [ano, mes],
    );
    return res.map(ParcelaRow.fromMap).toList();
  }

  Future<int> totalNoMes(int ano, int mes) async {
    final r = await db.rawQuery(
      '''
      SELECT SUM(valor_parcela_centavos) total
      FROM parcelamentos
      WHERE ano_ref = ? AND mes_ref = ?
      ''',
      [ano, mes],
    );
    return (r.first['total'] as int?) ?? 0;
  }

  Future<int> inserir({
    required String dataCompraIso,
    required String descricao,
    required int valorParcelaCentavos,
    required String status,
    required int anoRef,
    required int mesRef,
    required int numeroParcela,
    required int totalParcelas,
    int? categoriaId,
    int? formaPagamentoId,
    bool duplicarParcela = false,
    String? dataPagamentoIso,
  }) async {
    return db.insert('parcelamentos', {
      'data_compra_iso': dataCompraIso,
      'descricao': descricao,
      'categoria_id': categoriaId,
      'valor_parcela_centavos': valorParcelaCentavos,
      'status': status,
      'data_pagamento_iso': dataPagamentoIso,
      'ano_ref': anoRef,
      'mes_ref': mesRef,
      'numero_parcela': numeroParcela,
      'total_parcelas': totalParcelas,
      'forma_pagamento_id': formaPagamentoId,
      'duplicar_parcela': duplicarParcela ? 1 : 0,
      'atualizado_em': null,
    });
  }

  Future<void> atualizarStatus(
    int id,
    String status, {
    String? dataPagamentoIso,
  }) async {
    await db.update(
      'parcelamentos',
      {
        'status': status,
        'data_pagamento_iso': dataPagamentoIso,
        'atualizado_em': "datetime('now')",
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setDuplicarParcela(int id, bool v) async {
    await db.update(
      'parcelamentos',
      {'duplicar_parcela': v ? 1 : 0, 'atualizado_em': "datetime('now')"},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    await db.delete('parcelamentos', where: 'id = ?', whereArgs: [id]);
  }
}
