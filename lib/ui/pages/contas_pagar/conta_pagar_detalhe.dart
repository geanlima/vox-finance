// lib/ui/pages/contas_pagar/conta_pagar_detalhe.dart
// ignore_for_file: deprecated_member_use, depend_on_referenced_packages, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/extensions/list_extensions.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/core/service/conta_pagar_pagamento_service.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

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
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  final ContaPagarRepository _repository = ContaPagarRepository();
  final LancamentoRepository _repositoryLancamento = LancamentoRepository();
  final _pagamentoService = ContaPagarPagamentoService();

  List<ContaPagar> _parcelas = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    final lista = await _repository.getParcelasPorGrupo(widget.grupoParcelas);

    setState(() {
      _parcelas = lista;
      _carregando = false;
    });
  }

  Future<void> _adicionarParcelas() async {
    if (_parcelas.isEmpty) return;

    final qtdCtrl = TextEditingController(text: '1');
    final valorCtrl = TextEditingController();

    final totalAtual = _parcelas.fold<double>(0, (s, p) => s + p.valor);
    final qtdAtual = _parcelas.length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Adicionar parcelas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grupo atual: $qtdAtual parcela(s) · Total ${_currency.format(totalAtual)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade a adicionar',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 2',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor de cada nova parcela',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 120,00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final qtd = int.tryParse(qtdCtrl.text.trim()) ?? 0;
    final valor = CurrencyInputFormatter.parse(valorCtrl.text);

    if (qtd <= 0 || valor <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe quantidade e valor válidos.')),
      );
      return;
    }

    setState(() => _carregando = true);
    final err = await _repository.adicionarParcelasAoGrupo(
      grupoParcelas: widget.grupoParcelas,
      quantidadeAdicionar: qtd,
      valorNovaParcela: valor,
    );
    await _carregar();

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Parcelas adicionadas. Novo total: ${_currency.format(totalAtual + (qtd * valor))}.',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOSTRAR LANÇAMENTO VINCULADO A UMA PARCELA (id_lancamento)
  // ---------------------------------------------------------------------------
  Future<void> _mostrarLancamentoVinculado(ContaPagar parcela) async {
    Lancamento? lanc;

    // 1) Tenta pelo id_lancamento (caso fatura de cartão)
    if (parcela.idLancamento != null) {
      lanc = await _repositoryLancamento.getById(parcela.idLancamento!);
    }

    // 2) Se não encontrou, tenta pelo grupo + nº parcela
    if (lanc == null) {
      final lancamentosDoGrupo = await _repositoryLancamento
          .getParcelasPorGrupo(parcela.grupoParcelas);

      lanc = lancamentosDoGrupo.firstWhereOrNull(
        (l) => (l.parcelaNumero ?? 1) == (parcela.parcelaNumero ?? 1),
      );
    }

    // 3) Fallback final: tenta bater por data + valor + descrição
    if (lanc == null) {
      final db = await _dbService.db;

      final result = await db.query(
        'lancamentos',
        where: 'data_hora = ? AND valor = ? AND descricao = ?',
        whereArgs: [
          parcela.dataVencimento.millisecondsSinceEpoch,
          parcela.valor,
          parcela.descricao,
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        lanc = Lancamento.fromMap(result.first);
      }
    }

    // 4) Se ainda assim não achou, mostra aviso
    if (lanc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta parcela não possui lançamento vinculado.'),
          ),
        );
      }
      return;
    }

    // 5) Achou → exibe o bottom sheet com o lançamento
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
        final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
        final mq = MediaQuery.of(ctx);
        final bottom = mq.viewInsets.bottom + mq.padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Lançamento vinculado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  lanc!.pagamentoFatura == true
                      ? Icons.credit_card
                      : Icons.receipt_long,
                ),
                title: Text(lanc.descricao),
                subtitle: Text(dateTimeFormat.format(lanc.dataHora)),
                trailing: Text(
                  currency.format(lanc.valor),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forma de pagamento: '
                      '${lanc.formaPagamento.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (lanc.grupoParcelas != null &&
                        lanc.parcelaNumero != null &&
                        lanc.parcelaTotal != null)
                      Text(
                        'Grupo: ${lanc.grupoParcelas} · '
                        'Parcela ${lanc.parcelaNumero}/${lanc.parcelaTotal}',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTRAR PAGAMENTO
  // ---------------------------------------------------------------------------
  Future<void> _registrarPagamento(ContaPagar parcela) async {
    await _pagamentoService.registrarPagamento(parcela);
    await _carregar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parcela paga com sucesso. Lançamento atualizado.'),
      ),
    );
  }

  Future<void> _reabrirPagamento(ContaPagar parcela) async {
    await _pagamentoService.reabrirPagamento(parcela);
    await _carregar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parcela reaberta. Lançamento ajustado.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes das parcelas'),
        actions: [
          IconButton(
            tooltip: 'Adicionar parcelas',
            icon: const Icon(Icons.add),
            onPressed: _carregando ? null : _adicionarParcelas,
          ),
        ],
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _parcelas.isEmpty
              ? const Center(child: Text('Nenhuma parcela encontrada.'))
              : ListView.builder(
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
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
                        '${p.pago && p.dataPagamento != null ? ' · paga em ${_dateFormat.format(p.dataPagamento!)}' : ''}\n'
                        'Toque longo para ver o lançamento vinculado',
                        maxLines: 2,
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
                      // Toque normal → pagar
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
                      // Toque longo → ver lançamento vinculado
                      onLongPress: () async {
                        final opt = await showModalBottomSheet<String>(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (ctx) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.receipt_long),
                                    title: const Text('Ver lançamento vinculado'),
                                    onTap: () =>
                                        Navigator.pop(ctx, 'verLanc'),
                                  ),
                                  if (p.pago)
                                    ListTile(
                                      leading: const Icon(Icons.undo),
                                      title: const Text('Reabrir parcela'),
                                      subtitle: const Text(
                                        'Desfaz o pagamento desta parcela.',
                                      ),
                                      onTap: () =>
                                          Navigator.pop(ctx, 'reabrir'),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            );
                          },
                        );

                        if (opt == 'verLanc') {
                          await _mostrarLancamentoVinculado(p);
                          return;
                        }
                        if (opt == 'reabrir') {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Reabrir parcela'),
                                content: const Text(
                                  'Deseja reabrir esta parcela?\n\n'
                                  'Isso irá remover o lançamento criado no pagamento (quando existir) '
                                  'e voltar a parcela para pendente.',
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
                                    child: const Text('Reabrir'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmar == true) {
                            await _reabrirPagamento(p);
                          }
                        }
                      },
                    ),
                  );
                },
              ),
    );
  }
}
