// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/sevice/isar_service.dart';

class ContaPagarDetalhePage extends StatefulWidget {
  final String grupoParcelas;

  const ContaPagarDetalhePage({super.key, required this.grupoParcelas});

  @override
  State<ContaPagarDetalhePage> createState() => _ContaPagarDetalhePageState();
}

class _ContaPagarDetalhePageState extends State<ContaPagarDetalhePage> {
  final _isarService = IsarService();
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

    // 👉 usa o service, que já faz filter/sortBy/findAll certinho
    final lista =
        await _isarService.getParcelasPorGrupo(widget.grupoParcelas);

    setState(() {
      _parcelas = lista;
      _carregando = false;
    });
  }

  Future<void> _registrarPagamento(ContaPagar parcela) async {
    final isar = await _isarService.db;
    final agora = DateTime.now();

    await isar.writeTxn(() async {
      // 1) marca parcela como paga
      parcela
        ..pago = true
        ..dataPagamento = agora;
      await isar.contaPagars.put(parcela);

      // 2) cria lançamento financeiro
      final lanc = Lancamento()
        ..valor = parcela.valor
        ..descricao =
            'Parcela ${parcela.parcelaNumero}/${parcela.parcelaTotal} - ${parcela.descricao}'
        ..formaPagamento = FormaPagamento.debito // por enquanto default
        ..dataHora = agora
        ..pagamentoFatura = false
        ..categoria = Categoria.contas
        ..grupoParcelas = parcela.grupoParcelas
        ..parcelaNumero = parcela.parcelaNumero;

      await isar.lancamentos.put(lanc);
    });

    await _carregar();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento registrado e lançamento criado.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes das parcelas')),
      body: _carregando
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
                      color: vencida
                          ? colors.errorContainer.withOpacity(0.15)
                          : null,
                      child: ListTile(
                        leading: Icon(
                          p.pago ? Icons.check_circle : Icons.schedule,
                          color: p.pago
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!p.pago) const SizedBox(height: 4),
                            if (!p.pago)
                              Text(
                                'Pendente',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      vencida ? colors.error : colors.primary,
                                ),
                              ),
                          ],
                        ),
                        onTap: p.pago
                            ? null
                            : () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title:
                                          const Text('Registrar pagamento'),
                                      content: Text(
                                        'Registrar o pagamento desta parcela '
                                        'no valor de ${_currency.format(p.valor)}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
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
