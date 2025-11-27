// ignore_for_file: unnecessary_const

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

import 'package:vox_finance/ui/pages/home/models/grupo_resumo_dia.dart';
import 'package:vox_finance/ui/pages/home/widgets/resumo_gastos_dia_item.dart';

class ResumoGastosDiaBottomSheet extends StatelessWidget {
  final DateTime dataSelecionada;
  final List<Lancamento> lancamentos; // já filtrados (pagos e não pagamento fatura)
  final List<CartaoCredito> cartoes;
  final List<ContaBancaria> contas;
  final NumberFormat currency;

  const ResumoGastosDiaBottomSheet({
    super.key,
    required this.dataSelecionada,
    required this.lancamentos,
    required this.cartoes,
    required this.contas,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = tema.colorScheme.primary;
    final dateDiaFormat = DateFormat('dd/MM/yyyy');

    // ===================== AGRUPAMENTO =====================

    final Map<String, GrupoResumoDia> grupos = {};

    String keyFrom(String label, String? subtitulo) =>
        '$label|${subtitulo ?? ""}';

    for (final lanc in lancamentos) {
      final forma = lanc.formaPagamento;

      String label;
      String? subtitulo;
      IconData icon;

      if (forma == FormaPagamento.credito) {
        // Crédito → agrupa por cartão
        CartaoCredito? cartao;
        if (lanc.idCartao != null) {
          try {
            cartao = cartoes.firstWhere((c) => c.id == lanc.idCartao);
          } catch (_) {
            cartao = null;
          }
        }

        if (cartao != null) {
          label = cartao.descricao;
          subtitulo = '${cartao.bandeira} • **** ${cartao.ultimos4Digitos}';
        } else if (lanc.idCartao == null) {
          label = 'Crédito (sem cartão vinculado)';
          subtitulo = null;
        } else {
          label = 'Crédito (cartão id ${lanc.idCartao})';
          subtitulo = null;
        }

        icon = Icons.credit_card;
      } else {
        // Outras formas → agrupa por CONTA + FORMA
        ContaBancaria? conta;
        if (lanc.idConta != null) {
          try {
            conta = contas.firstWhere((c) => c.id == lanc.idConta);
          } catch (_) {
            conta = null;
          }
        }

        if (conta != null) {
          label = conta.descricao;
          subtitulo = forma.label; // Ex.: Pix, Boleto, Transferência
        } else if (lanc.idConta == null) {
          label = forma.label;
          subtitulo = 'Sem conta vinculada';
        } else {
          label = forma.label;
          subtitulo = 'Conta id ${lanc.idConta}';
        }

        icon = forma.icon;
      }

      final key = keyFrom(label, subtitulo);

      if (grupos.containsKey(key)) {
        grupos[key]!.total += lanc.valor;
      } else {
        grupos[key] = GrupoResumoDia(
          label: label,
          subtitulo: subtitulo,
          icon: icon,
          total: lanc.valor,
        );
      }
    }

    final totalGeral =
        lancamentos.fold<double>(0.0, (a, b) => a + b.valor);

    // ===================== UI =====================

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tema.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
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
              const SizedBox(height: 12),

              // CABEÇALHO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos detalhados',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateDiaFormat.format(dataSelecionada),
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CARD TOTAL
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: corPrimaria.withOpacity(0.06),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: corPrimaria.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.payments,
                              color: corPrimaria,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total do dia',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                currency.format(totalGeral),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Detalhado por forma / cartão / conta',
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // LISTA
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: grupos.values.map((g) {
                    return ResumoGastosDiaItem(
                      icone: g.icon,
                      titulo: g.label,
                      subtitulo: g.subtitulo,
                      valor: g.total,
                      color: corPrimaria,
                      currency: currency,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
