// ignore_for_file: deprecated_member_use

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
    final colors = Theme.of(context).colorScheme;

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

        // 🔹 tipo (entrada x saída)
        final bool ehReceita = lanc.tipoMovimento == TipoMovimento.receita;

        // 🔹 cor do valor (apenas receita x despesa; fatura continua vermelha)
        final Color valorColor =
            isFatura
                ? Colors.red.shade700
                : (ehReceita ? Colors.green.shade600 : colors.onSurface);

        return Slidable(
          key: ValueKey(lanc.id ?? '${lanc.descricao}-$index'),

          // 👉 esquerda: pagar / ver itens fatura
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

          // 👉 direita: editar / excluir
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.35,
            children: [
              CustomSlidableAction(
                onPressed: (_) => onEditar(lanc),
                backgroundColor: theme.colorScheme.surface,
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
            // 👉 agora SEM fundo colorido, igual os outros cards
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
                                Text(
                                  currency.format(lanc.valor),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: valorColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lanc.descricao} (Pagamento de fatura)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: $statusTexto',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: statusCor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                        ],
                      )
                      // ==============================
                      //  L A Y O U T   N O R M A L
                      // ==============================
                      : Row(
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

                                // 🔹 badge "Receita" / "Despesa"
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        ehReceita
                                            ? Colors.green.withOpacity(0.12)
                                            : Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    ehReceita ? 'Receita' : 'Despesa',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          ehReceita
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

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

                          // 🔹 valor (verde se receita, normal se despesa)
                          Text(
                            currency.format(lanc.valor),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: valorColor,
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
