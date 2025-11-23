// ignore_for_file: override_on_non_overriding_member

enum TipoCartao {
  credito,
  debito,
  ambos,
}

class CartaoCredito {
  int? id;
  String descricao;
  String bandeira;
  String ultimos4Digitos;

  // Gerenciamento
  TipoCartao tipo;
  bool controlaFatura;       // 👈 novo no lugar de permiteParcelamento
  double? limite;           // opcional

  // Fechamento e vencimento
  int? diaFechamento;
  int? diaVencimento;

  // Foto do cartão
  String? fotoPath;

  CartaoCredito({
    this.id,
    required this.descricao,
    required this.bandeira,
    required this.ultimos4Digitos,
    this.tipo = TipoCartao.credito,
    this.controlaFatura = true,   // 👈 default: controla fatura
    this.limite,
    this.diaFechamento,
    this.diaVencimento,
    this.fotoPath,
  });

  // ---------- TO MAP ----------
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'bandeira': bandeira,
      'ultimos_4_digitos': ultimos4Digitos,
      'tipo': tipo.index,
      'controla_fatura': controlaFatura ? 1 : 0,  // 👈 mudou aqui
      'limite': limite,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'foto_path': fotoPath,
    };
  }

  // ---------- FROM MAP ----------
  factory CartaoCredito.fromMap(Map<String, Object?> map) {
    return CartaoCredito(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      bandeira: map['bandeira'] as String,
      ultimos4Digitos:
          (map['ultimos_4_digitos'] ?? map['ultimos4'] ?? '') as String,
      tipo: TipoCartao.values[(map['tipo'] ?? 0) as int],
      controlaFatura: (map['controla_fatura'] ?? 1) == 1,   // 👈 mudou aqui
      limite: map['limite'] != null
          ? (map['limite'] as num).toDouble()
          : null,
      diaFechamento: map['dia_fechamento'] as int?,
      diaVencimento: map['dia_vencimento'] as int?,
      fotoPath: map['foto_path'] as String?,
    );
  }

  String get label {
    final t = {
      TipoCartao.credito: 'Crédito',
      TipoCartao.debito: 'Débito',
      TipoCartao.ambos: 'Débito/Crédito',
    }[tipo]!;

    return '$descricao • $t • **** $ultimos4Digitos';
  }
}
