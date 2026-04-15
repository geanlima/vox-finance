class MonitoramentoPrecoOfertaHistorico {
  final int? id;
  final int idOferta;
  final double preco;
  final DateTime criadoEm;

  const MonitoramentoPrecoOfertaHistorico({
    this.id,
    required this.idOferta,
    required this.preco,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_oferta': idOferta,
      'preco': preco,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  factory MonitoramentoPrecoOfertaHistorico.fromMap(Map<String, dynamic> m) {
    return MonitoramentoPrecoOfertaHistorico(
      id: (m['id'] as num?)?.toInt(),
      idOferta: (m['id_oferta'] as num).toInt(),
      preco: (m['preco'] as num).toDouble(),
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (m['criado_em'] as num).toInt(),
      ),
    );
  }
}

