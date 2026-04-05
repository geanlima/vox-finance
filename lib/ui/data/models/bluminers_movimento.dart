enum BluminersMovimentoTipo { aporte, saque, rendimento, ajuste }

enum BluminersCarteira { investido, disponivel }

class BluminersMovimento {
  final int? id;
  final int idCarteira;
  final DateTime data;
  final BluminersMovimentoTipo tipo;
  final BluminersCarteira carteira;
  final double valor;
  final String? observacao;
  final String? origem; // ex: 'rentabilidade'
  final int? idOrigem;
  final DateTime criadoEm;

  const BluminersMovimento({
    this.id,
    this.idCarteira = 1,
    required this.data,
    required this.tipo,
    required this.carteira,
    required this.valor,
    this.observacao,
    this.origem,
    this.idOrigem,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_carteira': idCarteira,
      'data': DateTime(data.year, data.month, data.day).millisecondsSinceEpoch,
      'tipo': tipo.index,
      'carteira': carteira.index,
      'valor': valor,
      'observacao': observacao,
      'origem': origem,
      'id_origem': idOrigem,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static BluminersMovimento fromMap(Map<String, dynamic> map) {
    final tipo = BluminersMovimentoTipo.values[(map['tipo'] as int?) ?? 0];
    final carteiraIdx = (map['carteira'] as int?) ??
        // compat: bancos antigos (sem coluna carteira)
        ((tipo == BluminersMovimentoTipo.rendimento ||
                    tipo == BluminersMovimentoTipo.saque)
                ? BluminersCarteira.disponivel.index
                : BluminersCarteira.investido.index);

    return BluminersMovimento(
      id: map['id'] as int?,
      idCarteira: (map['id_carteira'] as int?) ?? 1,
      data: DateTime.fromMillisecondsSinceEpoch(map['data'] as int),
      tipo: tipo,
      carteira: BluminersCarteira.values[carteiraIdx],
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      observacao: map['observacao'] as String?,
      origem: map['origem'] as String?,
      idOrigem: map['id_origem'] as int?,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (map['criado_em'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

