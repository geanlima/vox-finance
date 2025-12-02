import 'package:flutter/material.dart';

class ResumoDiaCard extends StatelessWidget {
  final bool ehHoje;
  final String dataFormatada;
  final String totalGastoFormatado;

  /// Se for string vazia, não mostra a linha de fatura
  final String totalPagamentoFaturaFormatado;
  final VoidCallback onDiaAnterior;
  final VoidCallback onProximoDia;
  final VoidCallback onSelecionarData;
  final VoidCallback onTapTotal;

  const ResumoDiaCard({
    super.key,
    required this.ehHoje,
    required this.dataFormatada,
    required this.totalGastoFormatado,
    required this.totalPagamentoFaturaFormatado,
    required this.onDiaAnterior,
    required this.onProximoDia,
    required this.onSelecionarData,
    required this.onTapTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navegação de data
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dataFormatada,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
            const SizedBox(height: 12),

            // Total gasto no dia (ajustado p/ não dar overflow)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total gasto no dia',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: InkWell(
                    onTap: onTapTotal,
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              totalGastoFormatado,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.bar_chart, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Linha extra de pagamento de fatura (se houver)
            if (totalPagamentoFaturaFormatado.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pagamento de fatura: $totalPagamentoFaturaFormatado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
