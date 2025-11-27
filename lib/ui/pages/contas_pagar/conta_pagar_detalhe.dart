// lib/ui/pages/contas_pagar/conta_pagar_detalhe.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class ContaPagarDetalhePage extends StatefulWidget {
  final String grupoParcelas;

  const ContaPagarDetalhePage({super.key, required this.grupoParcelas});

  @override
  State<ContaPagarDetalhePage> createState() => _ContaPagarDetalhePageState();
}

class _ContaPagarDetalhePageState extends State<ContaPagarDetalhePage> {
  final _dbService = DbService(); // antes era _isarService
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  List<ContaPagar> _parcelas = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    // usa o DbService, que já filtra e ordena por grupo
    final lista = await _dbService.getParcelasPorGrupo(widget.grupoParcelas);

    setState(() {
      _parcelas = lista;
      _carregando = false;
    });
  }

  Future<void> _registrarPagamento(ContaPagar parcela) async {
    // Marca parcela como paga no SQLite
    if (parcela.id != null) {
      await _dbService.marcarParcelaComoPaga(parcela.id!, true);
    }

    // Recarrega a lista a partir do banco
    await _carregar();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pagamento registrado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes das parcelas')),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _parcelas.isEmpty
              ? const Center(child: Text('Nenhuma parcela encontrada.'))
              : ListView.builder(
                itemCount: _parcelas.length,
                itemBuilder: (context, index) {
                  final p = _parcelas[index];
                  final vencida =
                      !p.pago && p.dataVencimento.isBefore(DateTime.now());

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    color:
                        vencida
                            ? colors.errorContainer.withOpacity(0.15)
                            : null,
                    child: ListTile(
                      leading: Icon(
                        p.pago ? Icons.check_circle : Icons.schedule,
                        color:
                            p.pago
                                ? Colors.green
                                : (vencida ? colors.error : colors.primary),
                      ),
                      title: Text(
                        'Parcela ${p.parcelaNumero}/${p.parcelaTotal}',
                      ),
                      subtitle: Text(
                        'Vencimento: ${_dateFormat.format(p.dataVencimento)}'
                        '${p.pago && p.dataPagamento != null ? ' · paga em ${_dateFormat.format(p.dataPagamento!)}' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currency.format(p.valor),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (!p.pago) const SizedBox(height: 4),
                          if (!p.pago)
                            Text(
                              'Pendente',
                              style: TextStyle(
                                fontSize: 11,
                                color: vencida ? colors.error : colors.primary,
                              ),
                            ),
                        ],
                      ),
                      onTap:
                          p.pago
                              ? null
                              : () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Registrar pagamento'),
                                      content: Text(
                                        'Registrar o pagamento desta parcela '
                                        'no valor de ${_currency.format(p.valor)}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Pagar'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmar == true) {
                                  await _registrarPagamento(p);
                                }
                              },
                    ),
                  );
                },
              ),
    );
  }
}
