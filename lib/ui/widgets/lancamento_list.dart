import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';

class LancamentoList extends StatelessWidget {
  final List<Lancamento> lancamentos;
  final NumberFormat currency;
  final DateFormat dateHoraFormat;
  final void Function(Lancamento) onEditar;
  final void Function(Lancamento) onExcluir;

  const LancamentoList({
    super.key,
    required this.lancamentos,
    required this.currency,
    required this.dateHoraFormat,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    if (lancamentos.isEmpty) {
      return const Center(child: Text('Nenhum lançamento nesse dia.'));
    }

    return ListView.separated(
      itemCount: lancamentos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lanc = lancamentos[index];
        final isFatura = lanc.pagamentoFatura;

        // 👇 Status baseado no campo pago
        final statusTexto = lanc.pago ? 'Pago' : 'Pendente';
        final statusCor = lanc.pago ? Colors.green : Colors.orange;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(child: Icon(lanc.formaPagamento.icon)),
            title: Text(
              currency.format(lanc.valor),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFatura ? Colors.red : null,
              ),
            ),
            subtitle: Text(
              '${lanc.descricao}'
              '${isFatura ? ' (Pagamento de fatura)' : ''}\n'
              'Status: $statusTexto\n'
              '${dateHoraFormat.format(lanc.dataHora)}',
              style: TextStyle(color: statusCor),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => onEditar(lanc),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => onExcluir(lanc),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
