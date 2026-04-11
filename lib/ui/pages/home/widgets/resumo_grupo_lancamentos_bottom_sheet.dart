// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';

/// Lista os lançamentos que compõem um grupo do resumo (cartão, conta, etc.).
class ResumoGrupoLancamentosBottomSheet extends StatelessWidget {
  final String tituloGrupo;
  final String? subtituloGrupo;
  final IconData icone;
  final List<Lancamento> lancamentos;
  final NumberFormat currency;
  final bool ehDespesa;

  const ResumoGrupoLancamentosBottomSheet({
    super.key,
    required this.tituloGrupo,
    this.subtituloGrupo,
    required this.icone,
    required this.lancamentos,
    required this.currency,
    required this.ehDespesa,
  });

  static Future<void> show(
    BuildContext context, {
    required String tituloGrupo,
    String? subtituloGrupo,
    required IconData icone,
    required List<Lancamento> lancamentos,
    required NumberFormat currency,
    required bool ehDespesa,
  }) {
    final ordenados = [...lancamentos]..sort(
      (a, b) => b.dataHora.compareTo(a.dataHora),
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return ResumoGrupoLancamentosBottomSheet(
          tituloGrupo: tituloGrupo,
          subtituloGrupo: subtituloGrupo,
          icone: icone,
          lancamentos: ordenados,
          currency: currency,
          ehDespesa: ehDespesa,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final horaFmt = DateFormat('HH:mm');
    final corValor =
        ehDespesa ? Colors.redAccent.shade700 : Colors.green.shade700;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tema.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tema.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icone, color: tema.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tituloGrupo,
                            style: tema.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtituloGrupo != null)
                            Text(
                              subtituloGrupo!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${lancamentos.length} lançamento'
                  '${lancamentos.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: lancamentos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final l = lancamentos[index];
                    final extra = l.linhaResumoParcelaCurta;
                    return ListTile(
                      title: Text(
                        l.descricao.isEmpty ? '(Sem descrição)' : l.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            horaFmt.format(l.dataHora),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (extra != null)
                            Text(
                              extra,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        currency.format(l.valor),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: corValor,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
