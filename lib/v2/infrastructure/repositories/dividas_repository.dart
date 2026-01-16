import 'package:sqflite/sqflite.dart';

class DividaRow {
  final int id;

  final String status; // ativo | quitado | cancelado
  final String credor;
  final String descricao;

  final int? categoriaId;
  final int? formaPagamentoId;

  final String dataDividaIso; // yyyy-MM-dd
  final String? dataPagamentoIso; // yyyy-MM-dd (quando quitou)

  final int anoRef;
  final int mesRef;

  final int valorParcelaCentavos;
  final int parcelasTotal;
  final int parcelasPendentes;

  final int repetir1Mes; // 0|1

  DividaRow({
    required this.id,
    required this.status,
    required this.credor,
    required this.descricao,
    required this.categoriaId,
    required this.formaPagamentoId,
    required this.dataDividaIso,
    required this.dataPagamentoIso,
    required this.anoRef,
    required this.mesRef,
    required this.valorParcelaCentavos,
    required this.parcelasTotal,
    required this.parcelasPendentes,
    required this.repetir1Mes,
  });

  bool get isQuitado => status == 'quitado';
  bool get repetirUmMes => repetir1Mes == 1;

  factory DividaRow.fromMap(Map<String, dynamic> map) => DividaRow(
        id: map['id'] as int,
        status: (map['status'] as String?) ?? 'ativo',
        credor: (map['credor'] as String?) ?? '',
        descricao: (map['descricao'] as String?) ?? '',
        categoriaId: map['categoria_id'] as int?,
        formaPagamentoId: map['forma_pagamento_id'] as int?,
        dataDividaIso: (map['data_divida'] as String?) ?? '1970-01-01',
        dataPagamentoIso: map['data_pagamento'] as String?,
        anoRef: (map['ano_ref'] as int?) ?? 0,
        mesRef: (map['mes_ref'] as int?) ?? 0,
        valorParcelaCentavos: (map['valor_parcela_centavos'] as int?) ?? 0,
        parcelasTotal: (map['parcelas_total'] as int?) ?? 1,
        parcelasPendentes: (map['parcelas_pendentes'] as int?) ?? 0,
        repetir1Mes: (map['repetir_1_mes'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'status': status,
        'credor': credor,
        'descricao': descricao,
        'categoria_id': categoriaId,
        'forma_pagamento_id': formaPagamentoId,
        'data_divida': dataDividaIso,
        'data_pagamento': dataPagamentoIso,
        'ano_ref': anoRef,
        'mes_ref': mesRef,
        'valor_parcela_centavos': valorParcelaCentavos,
        'parcelas_total': parcelasTotal,
        'parcelas_pendentes': parcelasPendentes,
        'repetir_1_mes': repetir1Mes,
      };
}

class DividasRepository {
  final Database db;

  DividasRepository(this.db);

  // =========================
  // READ
  // =========================

  Future<List<DividaRow>> listarNoMes(
    int ano,
    int mes, {
    bool somenteAtivas = false,
  }) async {
    final where = StringBuffer('ano_ref = ? AND mes_ref = ?');
    final args = <Object>[ano, mes];

    if (somenteAtivas) {
      where.write(" AND status = 'ativo'");
    }

    final res = await db.query(
      'dividas',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'data_divida DESC, id DESC',
    );

    return res.map(DividaRow.fromMap).toList();
  }

  /// Soma do pendente do mês:
  /// valor_parcela_centavos * parcelas_pendentes (somente não quitadas)
  Future<int> totalPendenteNoMes(int ano, int mes) async {
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_parcela_centavos * parcelas_pendentes), 0) AS total
      FROM dividas
      WHERE ano_ref = ? AND mes_ref = ?
        AND status != 'quitado'
    ''', [ano, mes]);

    final v = res.first['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<DividaRow?> porId(int id) async {
    final res = await db.query(
      'dividas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return DividaRow.fromMap(res.first);
  }

  // =========================
  // CREATE
  // =========================

  Future<int> inserir({
    required String credor,
    required String descricao,
    required int valorParcelaCentavos,
    required int parcelasTotal,
    required int parcelasPendentes,
    required DateTime dataDivida,
    required String status, // ativo | quitado | cancelado
    int? categoriaId,
    int? formaPagamentoId,
    bool repetir1Mes = false,
  }) async {
    final iso = _toIso(dataDivida);

    final map = <String, Object?>{
      'status': status,
      'credor': credor,
      'descricao': descricao,
      'categoria_id': categoriaId,
      'forma_pagamento_id': formaPagamentoId,
      'data_divida': iso,
      'data_pagamento': null,
      'ano_ref': dataDivida.year,
      'mes_ref': dataDivida.month,
      'valor_parcela_centavos': valorParcelaCentavos,
      'parcelas_total': parcelasTotal,
      'parcelas_pendentes': parcelasPendentes,
      'repetir_1_mes': repetir1Mes ? 1 : 0,
    };

    return db.insert('dividas', map);
  }

  // =========================
  // UPDATE
  // =========================

  Future<void> atualizar({
    required int id,
    String? status,
    String? credor,
    String? descricao,
    int? categoriaId,
    int? formaPagamentoId,
    DateTime? dataDivida,
    int? valorParcelaCentavos,
    int? parcelasTotal,
    int? parcelasPendentes,
    bool? repetir1Mes,
  }) async {
    final patch = <String, Object?>{};

    if (status != null) patch['status'] = status;
    if (credor != null) patch['credor'] = credor;
    if (descricao != null) patch['descricao'] = descricao;

    if (categoriaId != null || categoriaId == null) {
      // se você quiser permitir limpar, passe explicitamente null
      patch['categoria_id'] = categoriaId;
    }
    if (formaPagamentoId != null || formaPagamentoId == null) {
      patch['forma_pagamento_id'] = formaPagamentoId;
    }

    if (dataDivida != null) {
      patch['data_divida'] = _toIso(dataDivida);
      patch['ano_ref'] = dataDivida.year;
      patch['mes_ref'] = dataDivida.month;
    }

    if (valorParcelaCentavos != null) {
      patch['valor_parcela_centavos'] = valorParcelaCentavos;
    }
    if (parcelasTotal != null) patch['parcelas_total'] = parcelasTotal;
    if (parcelasPendentes != null) patch['parcelas_pendentes'] = parcelasPendentes;
    if (repetir1Mes != null) patch['repetir_1_mes'] = repetir1Mes ? 1 : 0;

    if (patch.isEmpty) return;

    await db.update(
      'dividas',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> atualizarStatus(int id, String status) async {
    await db.update(
      'dividas',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Paga 1 parcela:
  /// - decrementa parcelas_pendentes
  /// - se zerar, marca quitado e preenche data_pagamento
  Future<void> pagarUmaParcela(int id) async {
    final res = await db.query(
      'dividas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return;

    final row = res.first;

    final statusAtual = (row['status'] as String?) ?? 'ativo';
    final pend = (row['parcelas_pendentes'] as int?) ?? 0;

    if (statusAtual == 'cancelado') return;
    if (pend <= 0) return;

    final novoPend = pend - 1;
    final novoStatus = (novoPend == 0) ? 'quitado' : statusAtual;

    final patch = <String, Object?>{
      'parcelas_pendentes': novoPend,
      'status': novoStatus,
    };

    if (novoPend == 0) {
      patch['data_pagamento'] = _todayIso();
    }

    await db.update(
      'dividas',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reverte 1 pagamento (volta 1 parcela)
  Future<void> desfazerPagamentoUmaParcela(int id) async {
    final res = await db.query(
      'dividas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return;

    final row = res.first;

    final statusAtual = (row['status'] as String?) ?? 'ativo';
    final pend = (row['parcelas_pendentes'] as int?) ?? 0;
    final total = (row['parcelas_total'] as int?) ?? 1;

    if (statusAtual == 'cancelado') return;
    if (pend >= total) return;

    final novoPend = pend + 1;

    await db.update(
      'dividas',
      {
        'parcelas_pendentes': novoPend,
        'status': 'ativo',
        'data_pagamento': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // DELETE
  // =========================

  Future<void> deletar(int id) async {
    await db.delete('dividas', where: 'id = ?', whereArgs: [id]);
  }

  // =========================
  // HELPERS
  // =========================

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _todayIso() => _toIso(DateTime.now());

  /// Útil se você quiser reutilizar no UI:
  int parseMoneyToCents(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll('R\$', '').replaceAll(' ', '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s) ?? 0.0;
    return (v * 100).round();
  }
}
