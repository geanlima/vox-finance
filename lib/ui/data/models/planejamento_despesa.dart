class PlanejamentoDespesa {
  final int? id;
  final String titulo;
  final String? local;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String? notas;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const PlanejamentoDespesa({
    this.id,
    required this.titulo,
    this.local,
    required this.dataInicio,
    required this.dataFim,
    this.notas,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory PlanejamentoDespesa.fromMap(Map<String, dynamic> m) {
    return PlanejamentoDespesa(
      id: m['id'] as int?,
      titulo: (m['titulo'] as String?) ?? '',
      local: m['local'] as String?,
      dataInicio: DateTime.fromMillisecondsSinceEpoch(m['data_inicio'] as int),
      dataFim: DateTime.fromMillisecondsSinceEpoch(m['data_fim'] as int),
      notas: m['notas'] as String?,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(m['criado_em'] as int),
      atualizadoEm: DateTime.fromMillisecondsSinceEpoch(m['atualizado_em'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titulo': titulo,
      'local': local,
      'data_inicio': dataInicio.millisecondsSinceEpoch,
      'data_fim': dataFim.millisecondsSinceEpoch,
      'notas': notas,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }

  PlanejamentoDespesa copyWith({
    int? id,
    String? titulo,
    String? local,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? notas,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return PlanejamentoDespesa(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      local: local ?? this.local,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      notas: notas ?? this.notas,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
