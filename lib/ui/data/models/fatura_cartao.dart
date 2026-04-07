// ignore_for_file: public_member_api_docs

/// Registro em `fatura_cartao` (uma fatura por cartão / mês de referência).
class FaturaCartao {
  int id;
  int idCartao;
  int ano;
  int mes;
  DateTime dataFechamento;
  DateTime dataVencimento;
  double valorTotal;
  bool pago;
  DateTime? dataPagamento;

  FaturaCartao({
    required this.id,
    required this.idCartao,
    required this.ano,
    required this.mes,
    required this.dataFechamento,
    required this.dataVencimento,
    required this.valorTotal,
    required this.pago,
    this.dataPagamento,
  });

  factory FaturaCartao.fromMap(Map<String, dynamic> map) {
    return FaturaCartao(
      id: map['id'] as int,
      idCartao: map['id_cartao'] as int,
      ano: map['ano'] as int,
      mes: map['mes'] as int,
      dataFechamento: DateTime.fromMillisecondsSinceEpoch(
        map['data_fechamento'] as int,
      ),
      dataVencimento: DateTime.fromMillisecondsSinceEpoch(
        map['data_vencimento'] as int,
      ),
      valorTotal: (map['valor_total'] as num).toDouble(),
      pago: (map['pago'] as int? ?? 0) == 1,
      dataPagamento: map['data_pagamento'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['data_pagamento'] as int)
          : null,
    );
  }
}
