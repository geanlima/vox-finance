class InvestimentoCdiConfig {
  final int idCarteira;
  final double limiteFaixa;
  /// CDI atual anual (%) (ex.: 14,79). Usado como base para aplicar percentuais.
  final double cdiBaseAnual;
  /// % do CDI aplicado até o limite (ex.: 100, 110, 120).
  final double pctAteLimite;
  /// % do CDI aplicado acima do limite.
  final double pctAcimaLimite;
  /// Conta bancária do app que receberá os lançamentos de rendimento (lancamentos.id_conta).
  final int? idContaBancaria;
  /// Saldo base (principal) para simular rendimento diário.
  final double saldoBase;
  /// Se true, ignora CDI teórico e usa taxa diária fixa calibrada.
  final bool usarTaxaFixa;
  /// Taxa diária fixa (decimal). Ex.: 0.000433 = 0,0433% ao dia.
  final double taxaDiariaFixa;
  /// Aporte fixo que entra na base do cálculo diário: (saldo + aporte) * taxa.
  final double aporteFixo;
  final bool considerarFimSemana;
  final bool considerarFeriados;
  final DateTime criadoEm;

  const InvestimentoCdiConfig({
    required this.idCarteira,
    required this.limiteFaixa,
    required this.cdiBaseAnual,
    required this.pctAteLimite,
    required this.pctAcimaLimite,
    required this.idContaBancaria,
    required this.saldoBase,
    required this.usarTaxaFixa,
    required this.taxaDiariaFixa,
    required this.aporteFixo,
    required this.considerarFimSemana,
    required this.considerarFeriados,
    required this.criadoEm,
  });

  Map<String, Object?> toMap() {
    return {
      'id_carteira': idCarteira,
      'limite_faixa': limiteFaixa,
      'cdi_base_anual': cdiBaseAnual,
      'pct_ate_limite': pctAteLimite,
      'pct_acima_limite': pctAcimaLimite,
      'id_conta_bancaria': idContaBancaria,
      'saldo_base': saldoBase,
      'usar_taxa_fixa': usarTaxaFixa ? 1 : 0,
      'taxa_diaria_fixa': taxaDiariaFixa,
      'aporte_fixo': aporteFixo,
      'considerar_fim_semana': considerarFimSemana ? 1 : 0,
      'considerar_feriados': considerarFeriados ? 1 : 0,
      'criado_em': criadoEm.millisecondsSinceEpoch,
    };
  }

  static InvestimentoCdiConfig fromMap(Map<String, Object?> map) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    // campos novos
    final base = d(map['cdi_base_anual']);
    final pctAte = d(map['pct_ate_limite']);
    final pctAcima = d(map['pct_acima_limite']);

    // compat antigos
    final cdiLegacy = d(map['cdi_anual']);
    final ateLegacy = d(map['cdi_anual_ate_limite']);
    final acimaLegacy = d(map['cdi_anual_acima_limite']);
    return InvestimentoCdiConfig(
      idCarteira: i(map['id_carteira']),
      limiteFaixa: d(map['limite_faixa']),
      cdiBaseAnual: base > 0 ? base : cdiLegacy,
      pctAteLimite:
          pctAte > 0
              ? pctAte
              : (cdiLegacy > 0 && ateLegacy > 0 ? (ateLegacy / cdiLegacy) * 100 : 0),
      pctAcimaLimite:
          pctAcima > 0
              ? pctAcima
              : (cdiLegacy > 0 && acimaLegacy > 0 ? (acimaLegacy / cdiLegacy) * 100 : 0),
      idContaBancaria: map['id_conta_bancaria'] as int?,
      saldoBase: d(map['saldo_base']),
      usarTaxaFixa: i(map['usar_taxa_fixa']) == 1,
      taxaDiariaFixa: d(map['taxa_diaria_fixa']),
      aporteFixo: d(map['aporte_fixo']),
      considerarFimSemana: i(map['considerar_fim_semana']) == 1,
      considerarFeriados: i(map['considerar_feriados']) == 1,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(i(map['criado_em'])),
    );
  }
}

