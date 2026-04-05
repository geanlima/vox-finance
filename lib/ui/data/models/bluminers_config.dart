class BluminersConfig {
  final int idCarteira;
  final double saldoInicialInvestido;
  final double saldoInicialDisponivel;
  final double aporteMensal;
  final double? meta;
  final DateTime criadoEm;

  const BluminersConfig({
    required this.idCarteira,
    required this.saldoInicialInvestido,
    required this.saldoInicialDisponivel,
    required this.aporteMensal,
    required this.meta,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_carteira': idCarteira,
      'saldo_inicial': saldoInicialInvestido,
      'saldo_inicial_disponivel': saldoInicialDisponivel,
      'aporte_mensal': aporteMensal,
      'meta': meta,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static BluminersConfig fromMap(Map<String, dynamic> map) {
    final idCarteira =
        (map['id_carteira'] as int?) ?? (map['id'] as int?) ?? 1;
    return BluminersConfig(
      idCarteira: idCarteira,
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
