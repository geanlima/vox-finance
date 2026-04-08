// ignore_for_file: public_member_api_docs

class IntegracaoFaturaCache {
  final int? id;
  final String sourceKey;

  final int idCartaoLocal;
  final String codigoCartaoApi;
  final int ano;
  final int mes;

  final String? faturaApiId;
  final String? descricao;
  final double valorTotal;
  final DateTime? dataVencimento;
  final DateTime? dataFechamento;
  final bool? pago;
  final DateTime importadoEm;

  /// Quando a fatura foi "fechada" no app (gera lançamento de pagamento).
  final DateTime? fechadaEm;

  /// ID do lançamento local criado para representar a fatura (pagamento_fatura=1).
  final int? idLancamentoFatura;

  const IntegracaoFaturaCache({
    this.id,
    required this.sourceKey,
    required this.idCartaoLocal,
    required this.codigoCartaoApi,
    required this.ano,
    required this.mes,
    this.faturaApiId,
    this.descricao,
    required this.valorTotal,
    this.dataVencimento,
    this.dataFechamento,
    this.pago,
    required this.importadoEm,
    this.fechadaEm,
    this.idLancamentoFatura,
  });

  factory IntegracaoFaturaCache.fromMap(Map<String, dynamic> m) {
    return IntegracaoFaturaCache(
      id: m['id'] as int?,
      sourceKey: (m['source_key'] ?? '') as String,
      idCartaoLocal: (m['id_cartao_local'] as num).toInt(),
      codigoCartaoApi: (m['codigo_cartao_api'] ?? '') as String,
      ano: (m['ano'] as num).toInt(),
      mes: (m['mes'] as num).toInt(),
      faturaApiId: m['fatura_api_id'] as String?,
      descricao: m['descricao'] as String?,
      valorTotal: (m['valor_total'] as num).toDouble(),
      dataVencimento:
          m['data_vencimento'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(m['data_vencimento'] as int),
      dataFechamento:
          m['data_fechamento'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(m['data_fechamento'] as int),
      pago:
          m['pago'] == null
              ? null
              : ((m['pago'] as int) == 1),
      importadoEm: DateTime.fromMillisecondsSinceEpoch(m['importado_em'] as int),
      fechadaEm:
          m['fechada_em'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(m['fechada_em'] as int),
      idLancamentoFatura: (m['id_lancamento_fatura'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_key': sourceKey,
      'id_cartao_local': idCartaoLocal,
      'codigo_cartao_api': codigoCartaoApi,
      'ano': ano,
      'mes': mes,
      'fatura_api_id': faturaApiId,
      'descricao': descricao,
      'valor_total': valorTotal,
      'data_vencimento': dataVencimento?.millisecondsSinceEpoch,
      'data_fechamento': dataFechamento?.millisecondsSinceEpoch,
      'pago': pago == null ? null : (pago! ? 1 : 0),
      'importado_em': importadoEm.millisecondsSinceEpoch,
      'fechada_em': fechadaEm?.millisecondsSinceEpoch,
      'id_lancamento_fatura': idLancamentoFatura,
    };
  }
}

class IntegracaoFaturaCacheItem {
  final int? id;
  final int idFaturaCache;
  final int? idLancamentoLocal;
  final String? itemApiId;
  final String descricao;
  final double valor;
  final DateTime? dataHora;
  final String? categoria;

  const IntegracaoFaturaCacheItem({
    this.id,
    required this.idFaturaCache,
    this.idLancamentoLocal,
    this.itemApiId,
    required this.descricao,
    required this.valor,
    this.dataHora,
    this.categoria,
  });

  factory IntegracaoFaturaCacheItem.fromMap(Map<String, dynamic> m) {
    return IntegracaoFaturaCacheItem(
      id: m['id'] as int?,
      idFaturaCache: (m['id_fatura_cache'] as num).toInt(),
      idLancamentoLocal: (m['id_lancamento_local'] as num?)?.toInt(),
      itemApiId: m['item_api_id'] as String?,
      descricao: (m['descricao'] ?? '') as String,
      valor: (m['valor'] as num).toDouble(),
      dataHora:
          m['data_hora'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(m['data_hora'] as int),
      categoria: m['categoria'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_fatura_cache': idFaturaCache,
      'id_lancamento_local': idLancamentoLocal,
      'item_api_id': itemApiId,
      'descricao': descricao,
      'valor': valor,
      'data_hora': dataHora?.millisecondsSinceEpoch,
      'categoria': categoria,
    };
  }
}

