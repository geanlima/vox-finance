import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/fatura_api_dto.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

/// Detalhe de uma fatura retornada pela API (lançamentos + totais).
class FaturaApiDetalhePage extends StatelessWidget {
  const FaturaApiDetalhePage({
    super.key,
    required this.fatura,
    required this.periodoLabel,
    this.onSalvarLocalmente,
  });

  final FaturaApiDto fatura;
  final String periodoLabel;

  /// Se preenchido, mostra botão para gravar no SQLite (mesmo fluxo da lista).
  final VoidCallback? onSalvarLocalmente;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dataFmt = DateFormat.yMMMd('pt_BR').add_Hm();

    final soma = fatura.somaLancamentos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos'),
        actions: [
          if (onSalvarLocalmente != null)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Salvar fatura local',
              onPressed: onSalvarLocalmente,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _linhaInfo(context, 'Período consultado', periodoLabel),
                  if (fatura.dataFechamento != null)
                    _linhaInfo(
                      context,
                      'Fechamento',
                      DateFormat.yMMMd('pt_BR').format(fatura.dataFechamento!),
                    ),
                  if (fatura.dataVencimento != null)
                    _linhaInfo(
                      context,
                      'Vencimento',
                      DateFormat.yMMMd('pt_BR').format(fatura.dataVencimento!),
                    ),
                  if (fatura.pago != null)
                    _linhaInfo(
                      context,
                      'Situação',
                      fatura.pago! ? 'Paga' : 'Em aberto',
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total da fatura',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        money.format(fatura.valorTotal),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Lançamentos (${fatura.lancamentos.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                fatura.lancamentos.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nenhum lançamento encontrado para esta fatura.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 0, 16, 16)),
                      itemCount: fatura.lancamentos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final l = fatura.lancamentos[i];
                        return Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.descricao,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (l.dataHora != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          dataFmt.format(l.dataHora!),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      if (l.categoria != null &&
                                          l.categoria!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          l.categoria!.trim(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  money.format(l.valor),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Material(
            color: cs.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Soma dos lançamentos'),
                        Text(
                          money.format(soma),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (fatura.lancamentos.isNotEmpty &&
                        (soma - fatura.valorTotal).abs() > 0.009)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'A soma dos itens difere do total da fatura '
                          '(${money.format((soma - fatura.valorTotal).abs())}).',
                          style: TextStyle(fontSize: 12, color: cs.error),
                        ),
                      ),
                    if (onSalvarLocalmente != null) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onSalvarLocalmente,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Salvar fatura local'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaInfo(BuildContext context, String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
