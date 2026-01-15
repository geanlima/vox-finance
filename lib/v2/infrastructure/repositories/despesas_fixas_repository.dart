import 'package:sqflite/sqflite.dart';

class DespesaFixaRow {
  final int id;
  final String descricao;
  final int valorCentavos;
  final String status;

  final int anoRef;
  final int mesRef;

  final int? categoriaId;
  final int? formaPagamentoId;
  final String? dataPagamentoIso;

  // extras do seu print (campos que já existem na migration v8)
  final int repetir1Mes; // 0/1
  final int ajustarDataPagamento; // 0/1
  final int? diaRenovacao;
  final String? reciboPath;

  // joins (para mostrar no card)
  final String? catNome;
  final String? catEmoji;
  final String? fpNome;

  DespesaFixaRow({
    required this.id,
    required this.descricao,
    required this.valorCentavos,
    required this.status,
    required this.anoRef,
    required this.mesRef,
    required this.categoriaId,
    required this.formaPagamentoId,
    required this.dataPagamentoIso,
    required this.repetir1Mes,
    required this.ajustarDataPagamento,
    required this.diaRenovacao,
    required this.reciboPath,
    required this.catNome,
    required this.catEmoji,
    required this.fpNome,
  });

  factory DespesaFixaRow.fromMap(Map<String, dynamic> m) => DespesaFixaRow(
    id: m['id'] as int,
    descricao: (m['descricao'] as String?) ?? '',
    valorCentavos: (m['valor_centavos'] as int?) ?? 0,
    status: (m['status'] as String?) ?? 'a_pagar',
    anoRef: (m['ano_ref'] as int?) ?? 0,
    mesRef: (m['mes_ref'] as int?) ?? 0,
    categoriaId: m['categoria_id'] as int?,
    formaPagamentoId: m['forma_pagamento_id'] as int?,
    dataPagamentoIso: m['data_pagamento_iso'] as String?,
    repetir1Mes: (m['repetir_1_mes'] as int?) ?? 0,
    ajustarDataPagamento: (m['ajustar_data_pagamento'] as int?) ?? 0,
    diaRenovacao: m['dia_renovacao'] as int?,
    reciboPath: m['recibo_path'] as String?,
    catNome: m['cat_nome'] as String?,
    catEmoji: m['cat_emoji'] as String?,
    fpNome: m['fp_nome'] as String?,
  );
}

class DespesasFixasRepository {
  final Database db;
  DespesasFixasRepository(this.db);

  Future<List<DespesaFixaRow>> listarNoMes(int ano, int mes) async {
    final res = await db.rawQuery(
      '''
      SELECT d.*,
             c.nome  AS cat_nome,
             c.emoji AS cat_emoji,
             f.nome  AS fp_nome
      FROM despesas_fixas d
      LEFT JOIN categorias c ON c.id = d.categoria_id
      LEFT JOIN formas_pagamento f ON f.id = d.forma_pagamento_id
      WHERE d.ano_ref = ? AND d.mes_ref = ?
      ORDER BY d.status ASC,
               COALESCE(d.data_pagamento_iso,'9999-12-31') ASC,
               d.id DESC
      ''',
      [ano, mes],
    );

    return res.map(DespesaFixaRow.fromMap).toList();
  }

  Future<int> totalNoMes(int ano, int mes) async {
    final res = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(valor_centavos), 0) AS total
      FROM despesas_fixas
      WHERE ano_ref = ? AND mes_ref = ?
      ''',
      [ano, mes],
    );

    final v = res.first['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<int> inserir({
    required String descricao,
    required int valorCentavos,
    required int anoRef,
    required int mesRef,
    required String status,
    String? dataPagamentoIso,
    int? categoriaId,
    int? formaPagamentoId,
    int repetir1Mes = 0,
    int ajustarDataPagamento = 0,
    int? diaRenovacao,
    String? reciboPath,
  }) async {
    return db.insert('despesas_fixas', {
      'descricao': descricao,
      'valor_centavos': valorCentavos,
      'status': status,
      'ano_ref': anoRef,
      'mes_ref': mesRef,

      'data_pagamento_iso': dataPagamentoIso,
      'categoria_id': categoriaId,
      'forma_pagamento_id': formaPagamentoId,

      'repetir_1_mes': repetir1Mes,
      'ajustar_data_pagamento': ajustarDataPagamento,
      'dia_renovacao': diaRenovacao,
      'recibo_path': reciboPath,

      'atualizado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> marcarComoPago(int id, DateTime data) async {
    final iso =
        '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

    await db.update(
      'despesas_fixas',
      {
        'status': 'pago',
        'data_pagamento_iso': iso,
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> marcarComoAPagar(int id) async {
    await db.update(
      'despesas_fixas',
      {
        'status': 'a_pagar',
        'data_pagamento_iso': null,
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    await db.delete('despesas_fixas', where: 'id = ?', whereArgs: [id]);
  }
}
