class PessoaMeDeve {
  int? id;
  String nome;
  DateTime dataEmprestimo;
  double valorTotal;
  double valorRecebido;
  String? observacao;
  bool compraCartao;
  int? idCartao;
  int? parcelasTotal;
  String? grupoReceitas;
  int criadoEm;

  PessoaMeDeve({
    this.id,
    required this.nome,
    required this.dataEmprestimo,
    required this.valorTotal,
    this.valorRecebido = 0,
    this.observacao,
    this.compraCartao = false,
    this.idCartao,
    this.parcelasTotal,
    this.grupoReceitas,
    required this.criadoEm,
  });

  double get valorPendente {
    final p = valorTotal - valorRecebido;
    return p < 0 ? 0 : p;
  }

  bool get quitado => valorPendente <= 0.009;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'data_emprestimo': dataEmprestimo.millisecondsSinceEpoch,
      'valor_total': valorTotal,
      'valor_recebido': valorRecebido,
      'observacao': observacao,
      'compra_cartao': compraCartao ? 1 : 0,
      'id_cartao': idCartao,
      'parcelas_total': parcelasTotal,
      'grupo_receitas': grupoReceitas,
      'criado_em': criadoEm,
    };
  }

  factory PessoaMeDeve.fromMap(Map<String, dynamic> map) {
    return PessoaMeDeve(
      id: map['id'] as int?,
      nome: (map['nome'] ?? '') as String,
      dataEmprestimo: DateTime.fromMillisecondsSinceEpoch(
        (map['data_emprestimo'] as num).toInt(),
      ),
      valorTotal: (map['valor_total'] as num).toDouble(),
      valorRecebido: (map['valor_recebido'] as num?)?.toDouble() ?? 0,
      observacao: map['observacao'] as String?,
      compraCartao: (map['compra_cartao'] ?? 0) == 1,
      idCartao: (map['id_cartao'] as num?)?.toInt(),
      parcelasTotal: (map['parcelas_total'] as num?)?.toInt(),
      grupoReceitas: map['grupo_receitas'] as String?,
      criadoEm: (map['criado_em'] as num).toInt(),
    );
  }
}
