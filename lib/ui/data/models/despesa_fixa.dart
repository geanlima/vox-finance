import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

class DespesaFixa {
  final int? id;
  final String descricao;
  final double valor;
  final int diaVencimento;
  final FormaPagamento? formaPagamento;
  final bool ativo;
  final bool gerarAutomatico;
  final DateTime criadoEm;

  const DespesaFixa({
    this.id,
    required this.descricao,
    required this.valor,
    required this.diaVencimento,
    required this.formaPagamento,
    required this.ativo,
    required this.gerarAutomatico,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'dia_vencimento': diaVencimento,
      'forma_pagamento': formaPagamento?.index,
      'ativo': ativo ? 1 : 0,
      'gerar_automatico': gerarAutomatico ? 1 : 0,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  factory DespesaFixa.fromMap(Map<String, dynamic> map) {
    final fp = map['forma_pagamento'] as int?;
    return DespesaFixa(
      id: map['id'] as int?,
      descricao: (map['descricao'] as String?) ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      diaVencimento: (map['dia_vencimento'] as int?) ?? 1,
      formaPagamento:
          (fp != null && fp >= 0 && fp < FormaPagamento.values.length)
              ? FormaPagamento.values[fp]
              : null,
      ativo: (map['ativo'] as int? ?? 1) == 1,
      gerarAutomatico: (map['gerar_automatico'] as int? ?? 1) == 1,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (map['criado_em'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

