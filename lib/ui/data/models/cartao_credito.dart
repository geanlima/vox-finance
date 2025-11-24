// ignore_for_file: public_member_api_docs

enum TipoCartao { credito, debito, ambos }

class CartaoCredito {
  int? id;
  String descricao;
  String bandeira;
  String ultimos4Digitos;
  String? fotoPath;
  int? diaVencimento;
  int? diaFechamento;
  TipoCartao tipo;
  bool controlaFatura;
  double? limite;

  CartaoCredito({
    this.id,
    required this.descricao,
    required this.bandeira,
    required this.ultimos4Digitos,
    this.fotoPath,
    this.diaVencimento,
    this.diaFechamento,
    this.tipo = TipoCartao.credito,
    this.controlaFatura = true,
    this.limite,
  });

  /// Usado nos dropdowns da Home
  String get label => '$descricao • **** $ultimos4Digitos';

  factory CartaoCredito.fromMap(Map<String, dynamic> map) {
    return CartaoCredito(
      id: map['id'] as int?,

      // se vier null do banco, joga string vazia para não quebrar
      descricao: (map['descricao'] ?? '') as String,
      bandeira: (map['bandeira'] ?? '') as String,
      ultimos4Digitos: (map['ultimos4'] ?? '') as String,

      // campos opcionais
      fotoPath: map['foto_path'] as String?,
      diaVencimento: map['dia_vencimento'] as int?,
      diaFechamento: map['dia_fechamento'] as int?,

      // se ainda não tiver sido preenchido, assume crédito (0)
      tipo: TipoCartao.values[(map['tipo'] as int?) ?? 0],

      // controla_fatura: se for 1 → true, senão false
      controlaFatura: (map['controla_fatura'] as int?) == 1,

      // limite pode vir null
      limite: (map['limite'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'bandeira': bandeira,
      'ultimos4': ultimos4Digitos,
      'foto_path': fotoPath,
      'dia_vencimento': diaVencimento,
      'dia_fechamento': diaFechamento,
      'tipo': tipo.index,
      'controla_fatura': controlaFatura ? 1 : 0,
      'limite': limite,
    };
  }
}
