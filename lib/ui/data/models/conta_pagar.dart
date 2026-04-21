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
  FormaPagamento? formaPagamento;
  int? idCartao;
  int? idConta;
  int? idLancamento;

  /// Data de referência da compra / cabeçalho do grupo (≠ vencimento das parcelas).
  /// Usada no planejamento para vincular ao grupo; se nula, usa-se o 1º vencimento.
  DateTime? dataCabecalho;

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
    this.idLancamento,
    this.dataCabecalho,
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
      'forma_pagamento': formaPagamento?.index,
      'id_cartao': idCartao,
      'id_conta': idConta,
      'id_lancamento': idLancamento,
      'data_cabecalho': dataCabecalho?.millisecondsSinceEpoch,
    };
  }

  factory ContaPagar.fromMap(Map<String, dynamic> map) {
    final dc = map['data_cabecalho'];
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
      idLancamento:
          (map['id_lancamento'] ?? map['id_Lancamento']) as int?,
      dataCabecalho:
          dc == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(dc as int),
    );
  }
}

/// Grupo de contas a pagar para exibir no vínculo com planejamento (data cabeçalho + total).
class ContaPagarGrupoPlanejamento {
  ContaPagarGrupoPlanejamento({
    required this.grupoParcelas,
    required this.descricao,
    required this.valorTotal,
    required this.quantidadeParcelas,
    required this.dataCabecalho,
    required this.primeiroVencimento,
  });

  final String grupoParcelas;
  final String descricao;
  final double valorTotal;
  final int quantidadeParcelas;
  final DateTime dataCabecalho;
  final DateTime primeiroVencimento;
}
