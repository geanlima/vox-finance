import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';

class LancamentoFuturoTile extends StatelessWidget {
  final Lancamento lancamento;
  final ValueChanged<bool> onAlterarPago;
  final VoidCallback? onTap;

  LancamentoFuturoTile({
    super.key,
    required this.lancamento,
    required this.onAlterarPago,
    this.onTap,
  });

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final valor = lancamento.valor;
    final data = lancamento.dataHora;
    final descricao = lancamento.descricao;

    // por enquanto: tudo que é futuro é saída -> vermelho
    final corValor = Colors.red;

    return ListTile(
      leading: Checkbox(
        value: lancamento.pago,
        onChanged: (v) {
          if (v != null) onAlterarPago(v);
        },
      ),
      title: Text(
        descricao,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_dateFormat.format(data)),
      trailing: Text(
        _currency.format(valor),
        style: TextStyle(color: corValor, fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }
}
