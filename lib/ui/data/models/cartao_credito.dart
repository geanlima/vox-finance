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

  /// Id do cartão na API (query `cartao_id` em `/api/faturas`). Opcional.
  String? codigoCartaoApi;

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
    this.codigoCartaoApi,
  });

  String get label => '$descricao • **** $ultimos4Digitos';

  factory CartaoCredito.fromMap(Map<String, dynamic> map) {
    return CartaoCredito(
      id: map['id'] as int?,
      descricao: (map['descricao'] ?? '') as String,
      bandeira: (map['bandeira'] ?? '') as String,
      ultimos4Digitos: (map['ultimos4'] ?? '') as String,
      fotoPath: map['foto_path'] as String?,
      diaVencimento: map['dia_vencimento'] as int?,
      diaFechamento: map['dia_fechamento'] as int?,
      tipo: TipoCartao.values[(map['tipo'] as int?) ?? 0],
      controlaFatura: (map['controla_fatura'] as int?) == 1,
      limite: (map['limite'] as num?)?.toDouble(),
      codigoCartaoApi: map['codigo_cartao_api'] as String?,
    );
  }

  // 👉 usado apenas para INSERT
  Map<String, dynamic> toMapInsert() {
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
      'codigo_cartao_api': codigoCartaoApi,
    };
  }

  // 👉 usado apenas para UPDATE (NÃO envia id!)
  Map<String, dynamic> toMapUpdate() {
    return {
      'descricao': descricao,
      'bandeira': bandeira,
      'ultimos4': ultimos4Digitos,
      'foto_path': fotoPath,
      'dia_vencimento': diaVencimento,
      'dia_fechamento': diaFechamento,
      'tipo': tipo.index,
      'controla_fatura': controlaFatura ? 1 : 0,
      'limite': limite,
      'codigo_cartao_api': codigoCartaoApi,
    };
  }
}
