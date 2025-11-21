import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

class Lancamento {
  int? id;
  double valor;
  String descricao;
  FormaPagamento formaPagamento;
  DateTime dataHora;
  bool pagamentoFatura;
  bool pago = true;
  DateTime? dataPagamento;
  Categoria categoria;
  String? grupoParcelas;
  int? parcelaNumero;
  int? parcelaTotal;

  /// 👇 novo: cartão de crédito usado (pode ser null)
  int? idCartao;

  Lancamento({
    this.id,
    required this.valor,
    required this.descricao,
    required this.formaPagamento,
    required this.dataHora,
    this.pagamentoFatura = false,
    this.pago = true,
    this.dataPagamento,
    required this.categoria,
    this.grupoParcelas,
    this.parcelaNumero,
    this.parcelaTotal,
    this.idCartao, // 👈 novo
  });

  Lancamento copyWith({
    int? id,
    double? valor,
    String? descricao,
    FormaPagamento? formaPagamento,
    DateTime? dataHora,
    bool? pagamentoFatura,
    bool? pago,
    DateTime? dataPagamento,
    Categoria? categoria,
    String? grupoParcelas,
    int? parcelaNumero,
    int? parcelaTotal,
    int? idCartao,
  }) {
    return Lancamento(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      descricao: descricao ?? this.descricao,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      dataHora: dataHora ?? this.dataHora,
      pagamentoFatura: pagamentoFatura ?? this.pagamentoFatura,
      pago: pago ?? this.pago,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      categoria: categoria ?? this.categoria,
      grupoParcelas: grupoParcelas ?? this.grupoParcelas,
      parcelaNumero: parcelaNumero ?? this.parcelaNumero,
      parcelaTotal: parcelaTotal ?? this.parcelaTotal,
      idCartao: idCartao ?? this.idCartao, // 👈 novo
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'valor': valor,
      'descricao': descricao,
      'forma_pagamento': formaPagamento.index,
      'data_hora': dataHora.millisecondsSinceEpoch,
      'pagamento_fatura': pagamentoFatura ? 1 : 0,
      'pago': pago ? 1 : 0,
      'data_pagamento': dataPagamento?.millisecondsSinceEpoch,
      'categoria': categoria.index,
      'grupo_parcelas': grupoParcelas,
      'parcela_numero': parcelaNumero,
      'parcela_total': parcelaTotal,
      'id_cartao': idCartao, // 👈 novo campo no banco
    };
  }

  factory Lancamento.fromMap(Map<String, Object?> map) {
    return Lancamento(
      id: map['id'] as int?,
      valor: (map['valor'] as num).toDouble(),
      descricao: map['descricao'] as String,
      formaPagamento: FormaPagamento.values[(map['forma_pagamento'] as int)],
      dataHora: DateTime.fromMillisecondsSinceEpoch(map['data_hora'] as int),
      pagamentoFatura: (map['pagamento_fatura'] as int) == 1,
      pago: (map['pago'] as int) == 1,
      dataPagamento:
          map['data_pagamento'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                map['data_pagamento'] as int,
              ),
      categoria: Categoria.values[(map['categoria'] as int)],
      grupoParcelas: map['grupo_parcelas'] as String?,
      parcelaNumero: map['parcela_numero'] as int?,
      parcelaTotal: map['parcela_total'] as int?,
      idCartao: map['id_cartao'] as int?, // 👈 novo
    );
  }
}
