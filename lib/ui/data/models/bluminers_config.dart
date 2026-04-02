class BluminersConfig {
  final int id;
  final double saldoInicialInvestido;
  final double saldoInicialDisponivel;
  final double aporteMensal;
  final double? meta;
  final DateTime criadoEm;

  const BluminersConfig({
    this.id = 1,
    required this.saldoInicialInvestido,
    required this.saldoInicialDisponivel,
    required this.aporteMensal,
    required this.meta,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saldo_inicial': saldoInicialInvestido,
      'saldo_inicial_disponivel': saldoInicialDisponivel,
      'aporte_mensal': aporteMensal,
      'meta': meta,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static BluminersConfig fromMap(Map<String, dynamic> map) {
    return BluminersConfig(
      id: (map['id'] as int?) ?? 1,
      saldoInicialInvestido: (map['saldo_inicial'] as num?)?.toDouble() ?? 0,
      saldoInicialDisponivel:
          (map['saldo_inicial_disponivel'] as num?)?.toDouble() ?? 0,
      aporteMensal: (map['aporte_mensal'] as num?)?.toDouble() ?? 0,
      meta: (map['meta'] as num?)?.toDouble(),
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (map['criado_em'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

