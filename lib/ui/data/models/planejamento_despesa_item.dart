class PlanejamentoDespesaItem {
  static const Object _copyIdLancUnset = Object();
  static const Object _copyIdContaPagarUnset = Object();
  static const Object _copyDataVincCpUnset = Object();
  static const Object _copyValorTotalUnset = Object();

  final int? id;
  final int planejamentoId;
  final String descricao;
  final double valor;
  final int? idCategoriaPersonalizada;
  final int? idSubcategoriaPersonalizada;
  final DateTime? dataReferencia;
  /// Vencimento usado ao vincular contas a pagar (parcelas). Se nulo, usa [dataReferencia] ou início do planejamento.
  final DateTime? dataVinculoContasPagar;
  /// Valor total da compra (ex.: parcelado), opcional — [valor] pode ser o da parcela ou previsto.
  final double? valorTotal;
  final int ordem;
  final DateTime criadoEm;

  /// Lançamento gerado ou vinculado a este item (opcional).
  final int? idLancamento;

  /// Conta a pagar (ex.: parcela) vinculada a este item — exclusivo com [idLancamento].
  final int? idContaPagar;

  const PlanejamentoDespesaItem({
    this.id,
    required this.planejamentoId,
    required this.descricao,
    required this.valor,
    this.idCategoriaPersonalizada,
    this.idSubcategoriaPersonalizada,
    this.dataReferencia,
    this.dataVinculoContasPagar,
    this.valorTotal,
    required this.ordem,
    required this.criadoEm,
    this.idLancamento,
    this.idContaPagar,
  });

  factory PlanejamentoDespesaItem.fromMap(Map<String, dynamic> m) {
    final dr = m['data_referencia'];
    final dvc = m['data_vinculo_contas_pagar'];
    final vt = m['valor_total'];
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
      dataVinculoContasPagar:
          dvc == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(dvc as int),
      valorTotal: (vt as num?)?.toDouble(),
      ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(m['criado_em'] as int),
      idLancamento: (m['id_lancamento'] as num?)?.toInt(),
      idContaPagar: (m['id_conta_pagar'] as num?)?.toInt(),
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
      'data_vinculo_contas_pagar':
          dataVinculoContasPagar?.millisecondsSinceEpoch,
      'valor_total': valorTotal,
      'ordem': ordem,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'id_lancamento': idLancamento,
      'id_conta_pagar': idContaPagar,
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
    Object? dataVinculoContasPagar = _copyDataVincCpUnset,
    Object? valorTotal = _copyValorTotalUnset,
    int? ordem,
    DateTime? criadoEm,
    Object? idLancamento = _copyIdLancUnset,
    Object? idContaPagar = _copyIdContaPagarUnset,
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
      dataVinculoContasPagar:
          identical(dataVinculoContasPagar, _copyDataVincCpUnset)
              ? this.dataVinculoContasPagar
              : dataVinculoContasPagar as DateTime?,
      valorTotal:
          identical(valorTotal, _copyValorTotalUnset)
              ? this.valorTotal
              : valorTotal as double?,
      ordem: ordem ?? this.ordem,
      criadoEm: criadoEm ?? this.criadoEm,
      idLancamento:
          identical(idLancamento, _copyIdLancUnset)
              ? this.idLancamento
              : idLancamento as int?,
      idContaPagar:
          identical(idContaPagar, _copyIdContaPagarUnset)
              ? this.idContaPagar
              : idContaPagar as int?,
    );
  }
}
