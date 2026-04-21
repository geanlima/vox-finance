class MetricaLimite {
  final int? id;
  final bool ativo;

  /// Base do limite: 'categoria' (categoria/subcategoria) ou 'forma' (forma de pagamento/cartão)
  final String escopo;

  /// 'mensal' | 'semanal'
  final String periodoTipo;
  final int ano;
  final int? mes;
  final int? semana;

  final int idCategoriaPersonalizada;
  final int? idSubcategoriaPersonalizada;

  /// Filtro opcional por forma de pagamento (mesmo código salvo em `lancamentos.forma_pagamento`)
  /// Ex.: FormaPagamento.credito.index
  final int? formaPagamento;

  /// Filtro opcional por cartão (para despesas no crédito/débito onde `lancamentos.id_cartao` é usado)
  final int? idCartao;

  /// Filtro opcional por conta/forma (onde `lancamentos.id_conta` é usado)
  final int? idConta;

  final double limiteValor;

  final bool considerarSomentePagos;
  final bool incluirFuturos;
  final bool ignorarPagamentoFatura;

  final int alertaPct1;
  final int alertaPct2;

  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const MetricaLimite({
    this.id,
    required this.ativo,
    required this.escopo,
    required this.periodoTipo,
    required this.ano,
    this.mes,
    this.semana,
    required this.idCategoriaPersonalizada,
    this.idSubcategoriaPersonalizada,
    this.formaPagamento,
    this.idCartao,
    this.idConta,
    required this.limiteValor,
    required this.considerarSomentePagos,
    required this.incluirFuturos,
    required this.ignorarPagamentoFatura,
    required this.alertaPct1,
    required this.alertaPct2,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory MetricaLimite.fromMap(Map<String, dynamic> map) {
    return MetricaLimite(
      id: map['id'] as int?,
      ativo: (map['ativo'] ?? 1) == 1,
      escopo: (map['escopo'] ?? 'categoria') as String,
      periodoTipo: (map['periodo_tipo'] ?? 'mensal') as String,
      ano: (map['ano'] as num).toInt(),
      mes: (map['mes'] as num?)?.toInt(),
      semana: (map['semana'] as num?)?.toInt(),
      idCategoriaPersonalizada: (map['id_categoria_personalizada'] as num).toInt(),
      idSubcategoriaPersonalizada:
          (map['id_subcategoria_personalizada'] as num?)?.toInt(),
      formaPagamento: (map['forma_pagamento'] as num?)?.toInt(),
      idCartao: (map['id_cartao'] as num?)?.toInt(),
      idConta: (map['id_conta'] as num?)?.toInt(),
      limiteValor: (map['limite_valor'] as num).toDouble(),
      considerarSomentePagos: (map['considerar_somente_pagos'] ?? 1) == 1,
      incluirFuturos: (map['incluir_futuros'] ?? 0) == 1,
      ignorarPagamentoFatura: (map['ignorar_pagamento_fatura'] ?? 1) == 1,
      alertaPct1: ((map['alerta_pct1'] ?? 80) as num).toInt(),
      alertaPct2: ((map['alerta_pct2'] ?? 100) as num).toInt(),
      criadoEm: DateTime.fromMillisecondsSinceEpoch(map['criado_em'] as int),
      atualizadoEm:
          DateTime.fromMillisecondsSinceEpoch(map['atualizado_em'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ativo': ativo ? 1 : 0,
      'escopo': escopo,
      'periodo_tipo': periodoTipo,
      'ano': ano,
      'mes': mes,
      'semana': semana,
      'id_categoria_personalizada': idCategoriaPersonalizada,
      'id_subcategoria_personalizada': idSubcategoriaPersonalizada,
      'forma_pagamento': formaPagamento,
      'id_cartao': idCartao,
      'id_conta': idConta,
      'limite_valor': limiteValor,
      'considerar_somente_pagos': considerarSomentePagos ? 1 : 0,
      'incluir_futuros': incluirFuturos ? 1 : 0,
      'ignorar_pagamento_fatura': ignorarPagamentoFatura ? 1 : 0,
      'alerta_pct1': alertaPct1,
      'alerta_pct2': alertaPct2,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }
}

