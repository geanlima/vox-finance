import 'package:flutter/material.dart';

class ResumoDiaCard extends StatelessWidget {
  final bool ehHoje;
  final String dataFormatada;

  /// Total apenas de DESPESAS no dia
  final String totalDespesasFormatado;

  /// Total apenas de RECEITAS no dia
  final String totalReceitasFormatado;

  /// Se for string vazia, não mostra a linha de fatura
  final String totalPagamentoFaturaFormatado;

  final VoidCallback onDiaAnterior;
  final VoidCallback onProximoDia;
  final VoidCallback onSelecionarData;

  /// Callback quando tocar em algum total
  final VoidCallback onTapTotal;

  const ResumoDiaCard({
    super.key,
    required this.ehHoje,
    required this.dataFormatada,
    required this.totalDespesasFormatado,
    required this.totalReceitasFormatado,
    required this.totalPagamentoFaturaFormatado,
    required this.onDiaAnterior,
    required this.onProximoDia,
    required this.onSelecionarData,
    required this.onTapTotal,
  });

  @override
  Widget build(BuildContext context) {
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

            // Total DESPESAS
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Despesas no dia',
                    style: TextStyle(fontSize: 15),
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
                              totalDespesasFormatado,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_downward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Total RECEITAS
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Receitas no dia',
                    style: TextStyle(fontSize: 15),
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
                              totalReceitasFormatado,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_upward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (totalPagamentoFaturaFormatado.isNotEmpty) ...[
              const SizedBox(height: 8),
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
