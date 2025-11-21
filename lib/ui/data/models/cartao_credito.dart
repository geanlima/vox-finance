// ignore_for_file: override_on_non_overriding_member

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

  // ----------- TO MAP (SALVAR NO BANCO) -----------
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'bandeira': bandeira,
      // 👇 Nome EXATO no banco SQLite do seu celular
      'ultimos_4_digitos': ultimos4Digitos,
    };
  }

  // ----------- FROM MAP (LER DO BANCO) -----------
  factory CartaoCredito.fromMap(Map<String, Object?> map) {
    return CartaoCredito(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      bandeira: map['bandeira'] as String,

      // 👇 Compatível com banco novo e algum banco antigo
      ultimos4Digitos: (map['ultimos_4_digitos'] ?? map['ultimos4']) as String,
    );
  }

  // ----------- LABEL PARA DROPDOWN / LISTA -----------
  String get label => '$descricao • $bandeira • **** $ultimos4Digitos';
}
