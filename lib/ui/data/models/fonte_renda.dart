class FonteRenda {
  final int? id;
  final String nome;
  final double valorBase;
  final bool fixa;
  final int? diaPrevisto;
  final bool ativa;

  // 👇 NOVO
  final bool incluirNaRendaDiaria;

  FonteRenda({
    this.id,
    required this.nome,
    required this.valorBase,
    required this.fixa,
    this.diaPrevisto,
    required this.ativa,
    this.incluirNaRendaDiaria = false,
  });

  FonteRenda copyWith({
    int? id,
    String? nome,
    double? valorBase,
    bool? fixa,
    int? diaPrevisto,
    bool? ativa,
    bool? incluirNaRendaDiaria,
  }) {
    return FonteRenda(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      valorBase: valorBase ?? this.valorBase,
      fixa: fixa ?? this.fixa,
      diaPrevisto: diaPrevisto ?? this.diaPrevisto,
      ativa: ativa ?? this.ativa,
      incluirNaRendaDiaria:
          incluirNaRendaDiaria ?? this.incluirNaRendaDiaria,
    );
  }

  factory FonteRenda.fromMap(Map<String, dynamic> map) {
    return FonteRenda(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      valorBase: (map['valor_base'] as num?)?.toDouble() ?? 0.0,
      fixa: (map['fixa'] as int? ?? 1) == 1,
      diaPrevisto: map['dia_previsto'] as int?,
      ativa: (map['ativa'] as int? ?? 1) == 1,
      incluirNaRendaDiaria:
          (map['incluir_na_renda_diaria'] as int? ?? 0) == 1, // 👈 NOVO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'valor_base': valorBase,
      'fixa': fixa ? 1 : 0,
      'dia_previsto': diaPrevisto,
      'ativa': ativa ? 1 : 0,
      'incluir_na_renda_diaria': incluirNaRendaDiaria ? 1 : 0, // 👈 NOVO
    };
  }
}
