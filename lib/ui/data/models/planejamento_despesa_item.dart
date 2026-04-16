class PlanejamentoDespesaItem {
  static const Object _copyIdLancUnset = Object();

  final int? id;
  final int planejamentoId;
  final String descricao;
  final double valor;
  final int? idCategoriaPersonalizada;
  final int? idSubcategoriaPersonalizada;
  final DateTime? dataReferencia;
  final int ordem;
  final DateTime criadoEm;

  /// Lançamento gerado ou vinculado a este item (opcional).
  final int? idLancamento;

  const PlanejamentoDespesaItem({
    this.id,
    required this.planejamentoId,
    required this.descricao,
    required this.valor,
    this.idCategoriaPersonalizada,
    this.idSubcategoriaPersonalizada,
    this.dataReferencia,
    required this.ordem,
    required this.criadoEm,
    this.idLancamento,
  });

  factory PlanejamentoDespesaItem.fromMap(Map<String, dynamic> m) {
    final dr = m['data_referencia'];
    return PlanejamentoDespesaItem(
      id: m['id'] as int?,
      planejamentoId: (m['planejamento_id'] as num).toInt(),
      descricao: (m['descricao'] as String?) ?? '',
      valor: ((m['valor'] as num?) ?? 0).toDouble(),
      idCategoriaPersonalizada: (m['id_categoria_personalizada'] as num?)?.toInt(),
      idSubcategoriaPersonalizada:
          (m['id_subcategoria_personalizada'] as num?)?.toInt(),
      dataReferencia:
          dr == null ? null : DateTime.fromMillisecondsSinceEpoch(dr as int),
      ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(m['criado_em'] as int),
      idLancamento: (m['id_lancamento'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'planejamento_id': planejamentoId,
      'descricao': descricao,
      'valor': valor,
      'id_categoria_personalizada': idCategoriaPersonalizada,
      'id_subcategoria_personalizada': idSubcategoriaPersonalizada,
      'data_referencia': dataReferencia?.millisecondsSinceEpoch,
      'ordem': ordem,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'id_lancamento': idLancamento,
    };
  }

  PlanejamentoDespesaItem copyWith({
    int? id,
    int? planejamentoId,
    String? descricao,
    double? valor,
    int? idCategoriaPersonalizada,
    int? idSubcategoriaPersonalizada,
    DateTime? dataReferencia,
    int? ordem,
    DateTime? criadoEm,
    Object? idLancamento = _copyIdLancUnset,
  }) {
    return PlanejamentoDespesaItem(
      id: id ?? this.id,
      planejamentoId: planejamentoId ?? this.planejamentoId,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      idCategoriaPersonalizada:
          idCategoriaPersonalizada ?? this.idCategoriaPersonalizada,
      idSubcategoriaPersonalizada:
          idSubcategoriaPersonalizada ?? this.idSubcategoriaPersonalizada,
      dataReferencia: dataReferencia ?? this.dataReferencia,
      ordem: ordem ?? this.ordem,
      criadoEm: criadoEm ?? this.criadoEm,
      idLancamento:
          identical(idLancamento, _copyIdLancUnset)
              ? this.idLancamento
              : idLancamento as int?,
    );
  }
}
