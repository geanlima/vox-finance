// ignore_for_file: public_member_api_docs

class CartaoCreditoCalendario {
  final int? id;
  final int idCartao;
  final int ano;
  final int mes;
  final int diaFechamento;
  final int diaVencimento;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  CartaoCreditoCalendario({
    this.id,
    required this.idCartao,
    required this.ano,
    required this.mes,
    required this.diaFechamento,
    required this.diaVencimento,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory CartaoCreditoCalendario.fromMap(Map<String, dynamic> map) {
    return CartaoCreditoCalendario(
      id: map['id'] as int?,
      idCartao: map['id_cartao'] as int,
      ano: map['ano'] as int,
      mes: map['mes'] as int,
      diaFechamento: map['dia_fechamento'] as int,
      diaVencimento: map['dia_vencimento'] as int,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(map['criado_em'] as int),
      atualizadoEm:
          DateTime.fromMillisecondsSinceEpoch(map['atualizado_em'] as int),
    );
  }

  Map<String, Object?> toMapInsert() {
    return {
      'id_cartao': idCartao,
      'ano': ano,
      'mes': mes,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }

  Map<String, Object?> toMapUpdate() {
    return {
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }

  String get periodoKey => '$ano-${mes.toString().padLeft(2, '0')}';
}

