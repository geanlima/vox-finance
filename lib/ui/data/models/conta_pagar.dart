// lib/ui/data/models/conta_pagar.dart
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

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

  // 🔹 Novos campos
  FormaPagamento? formaPagamento;
  int? idCartao;
  int? idConta;

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
    this.formaPagamento,
    this.idCartao,
    this.idConta,
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

      // 🔹 novos campos no banco
      'forma_pagamento': formaPagamento?.index,
      'id_cartao': idCartao,
      'id_conta': idConta,
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

      // 🔹 leitura segura dos novos campos
      formaPagamento:
          map['forma_pagamento'] != null
              ? FormaPagamento.values[map['forma_pagamento'] as int]
              : null,
      idCartao: map['id_cartao'] as int?,
      idConta: map['id_conta'] as int?,
    );
  }
}
