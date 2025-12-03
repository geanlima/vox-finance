/// Fonte de renda cadastrada (ex: PJ Clínica, Freelas, Aluguel)
class FonteRenda {
  final int? id;
  final String nome;
  final double valorBase; // valor "esperado" dessa fonte
  final bool fixa; // true = valor se repete todo mês
  final int? diaPrevisto; // dia do mês em que costuma cair (1..31)
  final bool ativa;

  const FonteRenda({
    this.id,
    required this.nome,
    required this.valorBase,
    required this.fixa,
    this.diaPrevisto,
    this.ativa = true,
  });

  FonteRenda copyWith({
    int? id,
    String? nome,
    double? valorBase,
    bool? fixa,
    int? diaPrevisto,
    bool? ativa,
  }) {
    return FonteRenda(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      valorBase: valorBase ?? this.valorBase,
      fixa: fixa ?? this.fixa,
      diaPrevisto: diaPrevisto ?? this.diaPrevisto,
      ativa: ativa ?? this.ativa,
    );
  }

  // ==== SQLite helpers ====

  factory FonteRenda.fromMap(Map<String, dynamic> map) {
    return FonteRenda(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      valorBase: (map['valor_base'] as num).toDouble(),
      fixa: (map['fixa'] as int) == 1,
      diaPrevisto: map['dia_previsto'] as int?,
      // se vier null, considera ativa = true
      ativa: (map['ativa'] as int?) != 0,
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
    };
  }
}
