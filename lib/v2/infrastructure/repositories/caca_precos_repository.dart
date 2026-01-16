import 'package:sqflite/sqflite.dart';

class CacaPrecoRow {
  final int id;
  final String produto;
  final String? loja;
  final String? link;

  final double precoAvista;
  final double precoParcelado;

  final int numParcelas;
  final double valorParcela;

  final double frete;

  final double totalAvista;
  final double totalParcelado;

  final String? observacoes;
  final bool escolhido;

  final String createdAt;
  final String? updatedAt;

  const CacaPrecoRow({
    required this.id,
    required this.produto,
    required this.loja,
    required this.link,
    required this.precoAvista,
    required this.precoParcelado,
    required this.numParcelas,
    required this.valorParcela,
    required this.frete,
    required this.totalAvista,
    required this.totalParcelado,
    required this.observacoes,
    required this.escolhido,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CacaPrecoRow.fromMap(Map<String, Object?> m) {
    double d(Object? v) =>
        (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    return CacaPrecoRow(
      id: i(m['id']),
      produto: (m['produto'] as String?) ?? '',
      loja: m['loja'] as String?,
      link: m['link'] as String?,
      precoAvista: d(m['preco_avista']),
      precoParcelado: d(m['preco_parcelado']),
      numParcelas: i(m['num_parcelas']),
      valorParcela: d(m['valor_parcela']),
      frete: d(m['frete']),
      totalAvista: d(m['total_avista']),
      totalParcelado: d(m['total_parcelado']),
      observacoes: m['observacoes'] as String?,
      escolhido: i(m['escolhido']) == 1,
      createdAt: (m['created_at'] as String?) ?? '',
      updatedAt: m['updated_at'] as String?,
    );
  }

  String get decisaoLabel => escolhido ? 'Escolhido' : 'Não escolhido';
}

class CacaPrecosRepository {
  static const table = 'caca_precos';

  final Database _db;
  CacaPrecosRepository(this._db);

  double _n(double v) => v.isNaN || v.isInfinite ? 0.0 : v;

  Map<String, Object?> _calcTotais({
    required double precoAvista,
    required double precoParcelado,
    required int numParcelas,
    required double valorParcela,
    required double frete,
  }) {
    final pa = _n(precoAvista);
    final pp = _n(precoParcelado);
    final np = numParcelas < 0 ? 0 : numParcelas;
    final vp = _n(valorParcela);
    final fr = _n(frete);

    final totalAvista = pa + fr;
    final totalParcelado = (np * vp) + fr;

    return {
      'preco_avista': pa,
      'preco_parcelado': pp,
      'num_parcelas': np,
      'valor_parcela': vp,
      'frete': fr,
      'total_avista': totalAvista,
      'total_parcelado': totalParcelado,
    };
  }

  Future<List<CacaPrecoRow>> listar({String? produto}) async {
    final where =
        (produto != null && produto.trim().isNotEmpty)
            ? 'produto LIKE ?'
            : null;
    final args = (where != null) ? ['%${produto!.trim()}%'] : null;

    final rows = await _db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: 'escolhido DESC, produto ASC, id DESC',
    );

    return rows.map(CacaPrecoRow.fromMap).toList();
  }

  Future<int> inserir({
    required String produto,
    String? loja,
    String? link,
    double precoAvista = 0,
    double precoParcelado = 0,
    int numParcelas = 0,
    double valorParcela = 0,
    double frete = 0,
    String? observacoes,
    bool escolhido = false,
  }) async {
    final calc = _calcTotais(
      precoAvista: precoAvista,
      precoParcelado: precoParcelado,
      numParcelas: numParcelas,
      valorParcela: valorParcela,
      frete: frete,
    );

    return _db.insert(table, {
      'produto': produto.trim(),
      'loja': (loja?.trim().isEmpty ?? true) ? null : loja!.trim(),
      'link': (link?.trim().isEmpty ?? true) ? null : link!.trim(),
      ...calc,
      'observacoes':
          (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
      'escolhido': escolhido ? 1 : 0,
      // created_at tem default no SQL
      'updated_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> atualizar({
    required int id,
    required String produto,
    String? loja,
    String? link,
    double precoAvista = 0,
    double precoParcelado = 0,
    int numParcelas = 0,
    double valorParcela = 0,
    double frete = 0,
    String? observacoes,
  }) async {
    final calc = _calcTotais(
      precoAvista: precoAvista,
      precoParcelado: precoParcelado,
      numParcelas: numParcelas,
      valorParcela: valorParcela,
      frete: frete,
    );

    await _db.update(
      table,
      {
        'produto': produto.trim(),
        'loja': (loja?.trim().isEmpty ?? true) ? null : loja!.trim(),
        'link': (link?.trim().isEmpty ?? true) ? null : link!.trim(),
        ...calc,
        'observacoes':
            (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remover(int id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// ✅ 1 escolhido por PRODUTO
  Future<void> setEscolhido(int id, bool escolhido) async {
    if (!escolhido) {
      await _db.update(
        table,
        {'escolhido': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return;
    }

    final row = await _db.query(
      table,
      columns: ['produto'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) return;

    final produto = (row.first['produto'] as String?) ?? '';

    await _db.transaction((txn) async {
      await txn.update(
        table,
        {'escolhido': 0},
        where: 'produto = ?',
        whereArgs: [produto],
      );
      await txn.update(
        table,
        {'escolhido': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
