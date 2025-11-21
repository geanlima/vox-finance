class CartaoCredito {
  int? id;
  String descricao;
  String bandeira;
  String ultimos4Digitos;

  CartaoCredito({
    this.id,
    required this.descricao,
    required this.bandeira,
    required this.ultimos4Digitos,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'bandeira': bandeira,
      // 👇 nome da coluna IGUAL ao da tabela: ultimos4
      'ultimos4': ultimos4Digitos,
    };
  }

  factory CartaoCredito.fromMap(Map<String, Object?> map) {
    return CartaoCredito(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      bandeira: map['bandeira'] as String,
      // 👇 idem aqui
      ultimos4Digitos: map['ultimos4'] as String,
    );
  }

  /// Para exibir em dropdown / lista
  String get label => '$descricao • $bandeira • **** $ultimos4Digitos';
}
