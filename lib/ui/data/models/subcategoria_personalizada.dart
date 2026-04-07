class SubcategoriaPersonalizada {
  final int? id;
  final int idCategoriaPersonalizada;
  final String nome;

  /// Mantém compatibilidade com a lista de categorias por tipo (despesa/receita)
  final int? tipoMovimentoCategoria;

  SubcategoriaPersonalizada({
    this.id,
    required this.idCategoriaPersonalizada,
    required this.nome,
    this.tipoMovimentoCategoria,
  });

  factory SubcategoriaPersonalizada.fromMap(Map<String, dynamic> map) {
    return SubcategoriaPersonalizada(
      id: map['id'] as int?,
      idCategoriaPersonalizada:
          (map['id_categoria_personalizada'] as num).toInt(),
      nome: (map['nome'] ?? '') as String,
      tipoMovimentoCategoria: (map['tipo_movimento_categoria'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_categoria_personalizada': idCategoriaPersonalizada,
      'nome': nome,
    };
  }
}

