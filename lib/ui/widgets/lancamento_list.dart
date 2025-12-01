import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';

class LancamentoList extends StatelessWidget {
  final List<Lancamento> lancamentos;
  final NumberFormat currency;
  final DateFormat dateHoraFormat;
  final void Function(Lancamento) onEditar;
  final void Function(Lancamento) onExcluir;
  final void Function(Lancamento)? onPagar;
  final void Function(Lancamento)? onVerItensFatura;

  const LancamentoList({
    super.key,
    required this.lancamentos,
    required this.currency,
    required this.dateHoraFormat,
    required this.onEditar,
    required this.onExcluir,
    this.onPagar,
    this.onVerItensFatura,
  });

  @override
  Widget build(BuildContext context) {
    if (lancamentos.isEmpty) {
      return const Center(child: Text('Nenhum lançamento nesse dia.'));
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final success = Colors.green.shade600;
    final danger = Colors.red.shade400;

    return ListView.separated(
      itemCount: lancamentos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lanc = lancamentos[index];
        final isFatura = lanc.pagamentoFatura;

        final statusTexto = lanc.pago ? 'Pago' : 'Pendente';
        final statusCor = lanc.pago ? Colors.green : Colors.orange;

        final bool ehParcelado =
            lanc.parcelaTotal != null && (lanc.parcelaTotal ?? 0) > 1;

        return Slidable(
          key: ValueKey(lanc.id ?? '${lanc.descricao}-$index'),

          // 👉 arrastar da esquerda para a direita (pagar / ver itens da fatura)
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: isFatura ? 0.35 : 0.20,
            children: [
              if (!lanc.pago && onPagar != null)
                CustomSlidableAction(
                  onPressed: (_) => onPagar!(lanc),
                  backgroundColor: success,
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.check_circle,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              if (isFatura && onVerItensFatura != null)
                CustomSlidableAction(
                  onPressed: (_) => onVerItensFatura!(lanc),
                  backgroundColor: secondary,
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
            ],
          ),

          // 👉 arrastar da direita para a esquerda (editar / excluir)
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.35,
            children: [
              CustomSlidableAction(
                onPressed: (_) => onEditar(lanc),
                backgroundColor: theme.colorScheme.surface, // quase branco
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.edit, size: 28, color: primary),
              ),
              CustomSlidableAction(
                onPressed: (_) => onExcluir(lanc),
                backgroundColor: danger,
                borderRadius: BorderRadius.circular(12),
                child: const Icon(Icons.delete, size: 28, color: Colors.white),
              ),
            ],
          ),

          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child:
                  isFatura
                      // =========================
                      //  L A Y O U T   F A T U R A
                      // =========================
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            child: Icon(lanc.formaPagamento.icon, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // valor em vermelho
                                Text(
                                  currency.format(lanc.valor),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // descrição + (Pagamento de fatura)
                                Text(
                                  '${lanc.descricao} (Pagamento de fatura)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // status
                                Text(
                                  'Status: $statusTexto',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: statusCor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // data
                                Text(
                                  dateHoraFormat.format(lanc.dataHora),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                      // ==============================
                      //  L A Y O U T   N O R M A L
                      // ==============================
                      : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ícone
                          CircleAvatar(
                            radius: 22,
                            child: Icon(lanc.formaPagamento.icon, size: 24),
                          ),
                          const SizedBox(width: 12),

                          // coluna central com texto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (lanc.descricao.isNotEmpty) ...[
                                  Text(
                                    lanc.descricao,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  'Status: $statusTexto',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: statusCor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (ehParcelado) ...[
                                  const SizedBox(height: 2),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Parcela ${lanc.parcelaNumero}/${lanc.parcelaTotal}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  dateHoraFormat.format(lanc.dataHora),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // valor alinhado à direita
                          Text(
                            currency.format(lanc.valor),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        );
      },
    );
  }
}
