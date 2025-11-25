class ContaBancaria {
  int? id;
  String descricao;
  String? banco;
  String? agencia;
  String? numero;
  String? tipo; // ex: 'corrente', 'poupanca'
  bool ativa;

  ContaBancaria({
    this.id,
    required this.descricao,
    this.banco,
    this.agencia,
    this.numero,
    this.tipo,
    this.ativa = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'banco': banco,
      'agencia': agencia,
      'numero': numero,
      'tipo': tipo,
      'ativa': ativa ? 1 : 0,
    };
  }

  factory ContaBancaria.fromMap(Map<String, dynamic> map) {
    return ContaBancaria(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      banco: map['banco'] as String?,
      agencia: map['agencia'] as String?,
      numero: map['numero'] as String?,
      tipo: map['tipo'] as String?,
      ativa: (map['ativa'] as int? ?? 1) == 1,
    );
  }
}
