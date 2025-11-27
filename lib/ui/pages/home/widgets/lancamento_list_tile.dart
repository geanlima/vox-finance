// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';

class LancamentoListTile extends StatelessWidget {
  final Lancamento lancamento;
  final List<CartaoCredito> cartoes;
  final List<ContaBancaria> contas;
  final NumberFormat currency;

  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final void Function(bool novoStatus) onTogglePago;

  const LancamentoListTile({
    super.key,
    required this.lancamento,
    required this.cartoes,
    required this.contas,
    required this.currency,
    required this.onEditar,
    required this.onExcluir,
    required this.onTogglePago,
  });

  // =====================================================================
  //  Informações extras (cartão, conta, parcelas)
  // =====================================================================

  String? _descricaoCartao() {
    if (lancamento.idCartao == null) return null;
    final c = cartoes.where((x) => x.id == lancamento.idCartao).toList();
    if (c.isEmpty) return null;
    return c.first.label;
  }

  String? _descricaoConta() {
    if (lancamento.idConta == null) return null;
    final c = contas.where((x) => x.id == lancamento.idConta).toList();
    if (c.isEmpty) return null;
    final texto =
        '${c.first.descricao}${c.first.banco != null ? " (${c.first.banco})" : ""}';
    return texto;
  }

  String? _descricaoParcela() {
    if (lancamento.parcelaTotal != null &&
        lancamento.parcelaTotal! > 1 &&
        lancamento.parcelaNumero != null) {
      return '${lancamento.parcelaNumero}/${lancamento.parcelaTotal}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final iconeCategoria = CategoriaService.icon(lancamento.categoria);
    final colorCategoria = CategoriaService.color(lancamento.categoria);

    final valorFmt = currency.format(lancamento.valor);

    // Linha extra onde aparece: cartão / conta / parcela
    final detalhes = <String>[];

    final cartao = _descricaoCartao();
    if (cartao != null) detalhes.add(cartao);

    final conta = _descricaoConta();
    if (conta != null) detalhes.add(conta);

    final parcela = _descricaoParcela();
    if (parcela != null) detalhes.add('Parcela $parcela');

    // Pagamento de fatura aparece como destaque
    if (lancamento.pagamentoFatura) {
      detalhes.add('Pagamento de fatura');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone categoria
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorCategoria.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconeCategoria, color: colorCategoria, size: 24),
          ),

          const SizedBox(width: 12),

          // Descrição + detalhes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descrição do lançamento
                Text(
                  lancamento.descricao,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),

                // Linha de detalhes (cartão / conta / parcelas / fatura)
                if (detalhes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalhes.join(' • '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Valor + ações
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valorFmt,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      lancamento.pagamentoFatura
                          ? Colors.deepPurple
                          : Colors.black,
                ),
              ),

              const SizedBox(height: 4),

              // Pago / não pago
              Row(
                children: [
                  Text(
                    lancamento.pago ? 'Pago' : 'Pendente',
                    style: TextStyle(
                      fontSize: 11,
                      color: lancamento.pago ? Colors.green : Colors.deepOrange,
                    ),
                  ),
                  Switch(
                    value: lancamento.pago,
                    onChanged: onTogglePago,
                    activeColor: Colors.green,
                  ),
                ],
              ),

              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEditar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: onExcluir,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
