class MetricaLimite {
  final int? id;
  final bool ativo;

  /// 'mensal' | 'semanal'
  final String periodoTipo;
  final int ano;
  final int? mes;
  final int? semana;

  final int idCategoriaPersonalizada;
  final int? idSubcategoriaPersonalizada;

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
    required this.periodoTipo,
    required this.ano,
    this.mes,
    this.semana,
    required this.idCategoriaPersonalizada,
    this.idSubcategoriaPersonalizada,
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
      periodoTipo: (map['periodo_tipo'] ?? 'mensal') as String,
      ano: (map['ano'] as num).toInt(),
      mes: (map['mes'] as num?)?.toInt(),
      semana: (map['semana'] as num?)?.toInt(),
      idCategoriaPersonalizada: (map['id_categoria_personalizada'] as num).toInt(),
      idSubcategoriaPersonalizada:
          (map['id_subcategoria_personalizada'] as num?)?.toInt(),
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
      'periodo_tipo': periodoTipo,
      'ano': ano,
      'mes': mes,
      'semana': semana,
      'id_categoria_personalizada': idCategoriaPersonalizada,
      'id_subcategoria_personalizada': idSubcategoriaPersonalizada,
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

