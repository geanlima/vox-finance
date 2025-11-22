// ignore_for_file: override_on_non_overriding_member

class CartaoCredito {
  int? id;
  String descricao;
  String bandeira;
  String ultimos4Digitos;

  // 👇 Novos campos
  String? fotoPath; // Caminho da foto do cartão
  int? diaVencimento; // Dia do vencimento (1–31)

  CartaoCredito({
    this.id,
    required this.descricao,
    required this.bandeira,
    required this.ultimos4Digitos,
    this.fotoPath,
    this.diaVencimento,
  });

  // ----------- TO MAP (SALVAR NO BANCO) -----------
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'bandeira': bandeira,

      // 👇 Nome EXATO da coluna do seu SQLite
      'ultimos_4_digitos': ultimos4Digitos,

      // 👇 Novos campos no banco
      'foto_path': fotoPath,
      'dia_vencimento': diaVencimento,
    };
  }

  // ----------- FROM MAP (LER DO BANCO) -----------
  factory CartaoCredito.fromMap(Map<String, Object?> map) {
    return CartaoCredito(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      bandeira: map['bandeira'] as String,

      // 👇 Compatível com banco antigo
      ultimos4Digitos: (map['ultimos_4_digitos'] ?? map['ultimos4']) as String,

      // 👇 Campos novos (null-safe)
      fotoPath: map['foto_path'] as String?,
      diaVencimento: map['dia_vencimento'] as int?,
    );
  }

  // ----------- LABEL PARA LISTAGEM / DROPDOWN -----------
  String get label =>
      '$descricao • $bandeira • $diaVencimento • **** $ultimos4Digitos';
}
