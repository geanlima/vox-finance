class MonitoramentoPrecoOferta {
  final int? id;
  final int idMonitoramento;
  final String? loja;
  final String? url;
  final double preco;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const MonitoramentoPrecoOferta({
    this.id,
    required this.idMonitoramento,
    this.loja,
    this.url,
    required this.preco,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  MonitoramentoPrecoOferta copyWith({
    int? id,
    int? idMonitoramento,
    String? loja,
    String? url,
    double? preco,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return MonitoramentoPrecoOferta(
      id: id ?? this.id,
      idMonitoramento: idMonitoramento ?? this.idMonitoramento,
      loja: loja ?? this.loja,
      url: url ?? this.url,
      preco: preco ?? this.preco,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_monitoramento': idMonitoramento,
      'loja': loja,
      'url': url,
      'preco': preco,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }

  factory MonitoramentoPrecoOferta.fromMap(Map<String, dynamic> m) {
    return MonitoramentoPrecoOferta(
      id: (m['id'] as num?)?.toInt(),
      idMonitoramento: (m['id_monitoramento'] as num).toInt(),
      loja: m['loja'] as String?,
      url: m['url'] as String?,
      preco: (m['preco'] as num).toDouble(),
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (m['criado_em'] as num).toInt(),
      ),
      atualizadoEm: DateTime.fromMillisecondsSinceEpoch(
        (m['atualizado_em'] as num).toInt(),
      ),
    );
  }
}

