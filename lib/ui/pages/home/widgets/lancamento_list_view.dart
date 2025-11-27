import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_list_tile.dart';

class LancamentoListView extends StatelessWidget {
  final List<Lancamento> lancamentos;
  final List<CartaoCredito> cartoes;
  final List<ContaBancaria> contas;

  final NumberFormat currency;

  final void Function(Lancamento l) onEditar;
  final void Function(Lancamento l) onExcluir;
  final void Function(Lancamento l, bool novoStatus) onTogglePago;

  const LancamentoListView({
    super.key,
    required this.lancamentos,
    required this.cartoes,
    required this.contas,
    required this.currency,
    required this.onEditar,
    required this.onExcluir,
    required this.onTogglePago,
  });

  @override
  Widget build(BuildContext context) {
    if (lancamentos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum lançamento nesse dia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: lancamentos.length,
      itemBuilder: (context, index) {
        final lanc = lancamentos[index];
        return LancamentoListTile(
          lancamento: lanc,
          cartoes: cartoes,
          contas: contas,
          currency: currency,
          onEditar: () => onEditar(lanc),
          onExcluir: () => onExcluir(lanc),
          onTogglePago: (novoStatus) => onTogglePago(lanc, novoStatus),
        );
      },
    );
  }
}
