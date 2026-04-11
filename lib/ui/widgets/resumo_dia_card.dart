import 'package:flutter/material.dart';

/// Tamanho e peso únicos para todos os valores (totalizadores) do card.
TextStyle _estiloValorMonetario(Color cor) => TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: cor,
    );

const TextStyle _estiloTituloLinha = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
);

class ResumoDiaCard extends StatelessWidget {
  final bool ehHoje;
  final String dataFormatada;

  /// Despesas do dia exceto parcelas de compras parceladas (avulsas / à vista / 1x).
  final String despesaDoDiaFormatado;

  /// Parcelas de compras com mais de uma parcela (mesmo critério da lista).
  final String comprasParceladasFormatado;

  /// Receitas do dia (lançamentos pagos + renda diária das fontes).
  final String receitaDoDiaFormatado;

  /// Saldo do dia: receitas − (despesa do dia + compras parceladas).
  final String totalDoDiaFormatado;

  /// Se o saldo é ≥ 0 (afeta a cor do [totalDoDiaFormatado]).
  final bool saldoDoDiaNaoNegativo;

  /// (Opcional) Renda diária calculada a partir das fontes de renda
  /// Se null ou vazia, não mostra a linha explicativa.
  final String? rendaDiariaFormatada;

  /// Se for string vazia, não mostra a linha de fatura
  final String totalPagamentoFaturaFormatado;

  final VoidCallback onDiaAnterior;
  final VoidCallback onProximoDia;
  final VoidCallback onSelecionarData;

  final VoidCallback onTapDespesaDoDia;
  final VoidCallback onTapComprasParceladas;
  final VoidCallback onTapReceitaNoDia;
  final VoidCallback onTapTotalDoDia;

  const ResumoDiaCard({
    super.key,
    required this.ehHoje,
    required this.dataFormatada,
    required this.despesaDoDiaFormatado,
    required this.comprasParceladasFormatado,
    required this.receitaDoDiaFormatado,
    required this.totalDoDiaFormatado,
    required this.saldoDoDiaNaoNegativo,
    required this.totalPagamentoFaturaFormatado,
    required this.onDiaAnterior,
    required this.onProximoDia,
    required this.onSelecionarData,
    required this.onTapDespesaDoDia,
    required this.onTapComprasParceladas,
    required this.onTapReceitaNoDia,
    required this.onTapTotalDoDia,
    this.rendaDiariaFormatada,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corSaldo =
        saldoDoDiaNaoNegativo ? Colors.green.shade700 : Colors.deepOrange.shade800;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onDiaAnterior,
                  tooltip: 'Dia anterior',
                ),
                Expanded(
                  child: InkWell(
                    onTap: onSelecionarData,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          ehHoje ? 'Hoje' : 'Dia selecionado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dataFormatada,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onProximoDia,
                  tooltip: 'Próximo dia',
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: onSelecionarData,
                  tooltip: 'Escolher data no calendário',
                ),
              ],
            ),
            const SizedBox(height: 10),

            _LinhaValor(
              label: 'Despesa do Dia',
              valorFormatado: despesaDoDiaFormatado,
              corValor: Colors.redAccent,
              icone: Icons.arrow_downward,
              onTap: onTapDespesaDoDia,
            ),
            const SizedBox(height: 6),
            _LinhaValor(
              label: 'Compras Parceladas',
              valorFormatado: comprasParceladasFormatado,
              corValor: Colors.redAccent.shade200,
              icone: Icons.credit_card,
              onTap: onTapComprasParceladas,
            ),
            const SizedBox(height: 6),
            _LinhaValor(
              label: 'Receita no Dia',
              valorFormatado: receitaDoDiaFormatado,
              corValor: Colors.green,
              icone: Icons.arrow_upward,
              onTap: onTapReceitaNoDia,
            ),

            if (rendaDiariaFormatada != null &&
                rendaDiariaFormatada!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Inclui renda diária: $rendaDiariaFormatada',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Colors.grey.shade400),
            ),

            InkWell(
              onTap: onTapTotalDoDia,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total do Dia',
                        style: _estiloTituloLinha.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          totalDoDiaFormatado,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: _estiloValorMonetario(corSaldo),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (totalPagamentoFaturaFormatado.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    const TextSpan(text: 'Pagamento de fatura: '),
                    TextSpan(
                      text: totalPagamentoFaturaFormatado,
                      style: _estiloValorMonetario(Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinhaValor extends StatelessWidget {
  final String label;
  final String valorFormatado;
  final Color corValor;
  final IconData icone;
  final VoidCallback onTap;

  const _LinhaValor({
    required this.label,
    required this.valorFormatado,
    required this.corValor,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: _estiloTituloLinha.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      valorFormatado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: _estiloValorMonetario(corValor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icone, size: 16, color: corValor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
