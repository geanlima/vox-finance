class Lembrete {
  int? id;
  final String titulo;
  final String? descricao;
  final DateTime dataHora;
  final bool concluido;
  final DateTime criadoEm;

  Lembrete({
    this.id,
    required this.titulo,
    this.descricao,
    required this.dataHora,
    this.concluido = false,
    required this.criadoEm,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'data_hora': dataHora.millisecondsSinceEpoch,
      'concluido': concluido ? 1 : 0,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static Lembrete fromMap(Map<String, Object?> map) {
    return Lembrete(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      descricao: map['descricao'] as String?,
      dataHora: DateTime.fromMillisecondsSinceEpoch(map['data_hora'] as int),
      concluido: (map['concluido'] as int? ?? 0) == 1,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(map['criado_em'] as int),
    );
  }
}

