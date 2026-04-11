import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/fatura_cartao.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';

class FaturaCartaoDetalhePage extends StatefulWidget {
  final FaturaCartao fatura;

  const FaturaCartaoDetalhePage({
    super.key,
    required this.fatura,
  });

  @override
  State<FaturaCartaoDetalhePage> createState() =>
      _FaturaCartaoDetalhePageState();
}

class _FaturaCartaoDetalhePageState extends State<FaturaCartaoDetalhePage> {
  final _repo = CartaoCreditoRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHora = DateFormat.yMMMd('pt_BR').add_Hm();

  bool _loading = true;
  List<Lancamento> _itens = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lista = await _repo.getLancamentosPorIdFatura(widget.fatura.id);
    if (!mounted) return;
    setState(() {
      _itens = lista;
      _loading = false;
    });
  }

  double get _somaItens =>
      _itens.fold<double>(0, (a, l) => a + l.valor);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = widget.fatura;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _infoRow(
                            'Fechamento',
                            DateFormat.yMMMd(
                              'pt_BR',
                            ).format(f.dataFechamento),
                          ),
                          _infoRow(
                            'Vencimento',
                            DateFormat.yMMMd('pt_BR').format(
                              f.dataVencimento,
                            ),
                          ),
                          _infoRow(
                            'Situação',
                            f.pago ? 'Paga' : 'Em aberto',
                          ),
                          if (f.pago && f.dataPagamento != null)
                            _infoRow(
                              'Data pagamento',
                              DateFormat.yMMMd(
                                'pt_BR',
                              ).format(f.dataPagamento!),
                            ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total da fatura',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _money.format(f.valorTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Lançamentos (${_itens.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        _itens.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Nenhum lançamento vinculado a esta fatura no banco. '
                                  'Isso pode ocorrer em registros antigos; o total acima permanece o salvo na fatura.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              itemCount: _itens.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final l = _itens[i];
                                final linhaGrupo = l.linhaResumoParcelaCurta;

                                return Card(
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          child: Icon(
                                            l.formaPagamento.icon,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l.descricao,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _dateHora.format(l.dataHora),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      cs.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Forma: ${l.formaPagamento.label}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                              if (linhaGrupo != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  linhaGrupo,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _money.format(l.valor),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  Material(
                    color: cs.surfaceContainerHighest,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Soma dos lançamentos'),
                                Text(
                                  _money.format(_somaItens),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (_itens.isNotEmpty &&
                                (_somaItens - f.valorTotal).abs() > 0.009)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Atenção: a soma dos itens difere do total da fatura '
                                  '(${_money.format((_somaItens - f.valorTotal).abs())}).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
