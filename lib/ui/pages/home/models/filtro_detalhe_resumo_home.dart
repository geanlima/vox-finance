/// Qual totalizador do [ResumoDiaCard] abriu o detalhe por forma de pagamento.
enum FiltroDetalheResumoHome {
  /// Despesas não parceladas (avulsas / à vista / 1x).
  despesaAvulsas,

  /// Somente parcelas de compras com mais de uma parcela.
  comprasParceladas,

  /// Receitas lançadas no dia (não inclui renda diária automática).
  receitasLancadas,

  /// Todas as despesas do dia (visão geral dos gastos).
  todosGastos,
}
