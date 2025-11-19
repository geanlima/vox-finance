// lib/ui/data/models/conta_pagar.dart
class ContaPagar {
  int? id;
  String descricao;
  double valor;
  DateTime dataVencimento;
  bool pago;
  DateTime? dataPagamento;
  int? parcelaNumero;
  int? parcelaTotal;
  String grupoParcelas;

  ContaPagar({
    this.id,
    required this.descricao,
    required this.valor,
    required this.dataVencimento,
    this.pago = false,
    this.dataPagamento,
    this.parcelaNumero,
    this.parcelaTotal,
    required this.grupoParcelas,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'data_vencimento': dataVencimento.millisecondsSinceEpoch,
      'pago': pago ? 1 : 0,
      'data_pagamento': dataPagamento?.millisecondsSinceEpoch,
      'parcela_numero': parcelaNumero,
      'parcela_total': parcelaTotal,
      'grupo_parcelas': grupoParcelas,
    };
  }

  factory ContaPagar.fromMap(Map<String, dynamic> map) {
    return ContaPagar(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      valor: (map['valor'] as num).toDouble(),
      dataVencimento: DateTime.fromMillisecondsSinceEpoch(
        map['data_vencimento'] as int,
      ),
      pago: (map['pago'] as int) == 1,
      dataPagamento:
          map['data_pagamento'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                map['data_pagamento'] as int,
              )
              : null,
      parcelaNumero: map['parcela_numero'] as int?,
      parcelaTotal: map['parcela_total'] as int?,
      grupoParcelas: map['grupo_parcelas'] as String,
    );
  }
}
