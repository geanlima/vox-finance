class BluminersRentabilidade {
  final int? id;
  final int idCarteira;
  final DateTime data;
  final double percentual;
  final double rendimentoValor;
  final DateTime criadoEm;

  const BluminersRentabilidade({
    this.id,
    this.idCarteira = 1,
    required this.data,
    required this.percentual,
    required this.rendimentoValor,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_carteira': idCarteira,
      'data': DateTime(data.year, data.month, data.day).millisecondsSinceEpoch,
      'percentual': percentual,
      'rendimento_valor': rendimentoValor,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static BluminersRentabilidade fromMap(Map<String, dynamic> map) {
    return BluminersRentabilidade(
      id: map['id'] as int?,
      idCarteira: (map['id_carteira'] as int?) ?? 1,
      data: DateTime.fromMillisecondsSinceEpoch(map['data'] as int),
      percentual: (map['percentual'] as num?)?.toDouble() ?? 0,
      rendimentoValor: (map['rendimento_valor'] as num?)?.toDouble() ?? 0,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (map['criado_em'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

