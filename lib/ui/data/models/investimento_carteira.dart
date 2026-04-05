class InvestimentoCarteira {
  final int? id;
  final String nome;
  /// Identificador do layout (ex.: `bluminers`).
  final String layout;
  final DateTime criadoEm;

  const InvestimentoCarteira({
    this.id,
    required this.nome,
    this.layout = 'bluminers',
    required this.criadoEm,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nome': nome,
      'layout': layout,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static InvestimentoCarteira fromMap(Map<String, Object?> map) {
    return InvestimentoCarteira(
      id: map['id'] as int?,
      nome: (map['nome'] as String?) ?? '',
      layout: (map['layout'] as String?) ?? 'bluminers',
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (map['criado_em'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
