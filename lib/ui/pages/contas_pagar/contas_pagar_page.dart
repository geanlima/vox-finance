// lib/ui/pages/contas_pagar/contas_pagar_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/service/ia_service.dart';

import 'conta_pagar_detalhe.dart';

class ContaPagarResumo {
  final String grupoParcelas;
  final String descricao;
  final double valorTotal;
  final int quantidadeParcelas;
  final DateTime primeiroVencimento;
  final DateTime? ultimoVencimento;
  final bool todasPagas;

  // 👇 NOVO: descrição da forma de pagamento (ex: "Crédito - Nubank • ****1234")
  final String? formaDescricao;

  ContaPagarResumo({
    required this.grupoParcelas,
    required this.descricao,
    required this.valorTotal,
    required this.quantidadeParcelas,
    required this.primeiroVencimento,
    required this.ultimoVencimento,
    required this.todasPagas,
    this.formaDescricao,
  });
}

class ContasPagarPage extends StatefulWidget {
  const ContasPagarPage({super.key});

  @override
  State<ContasPagarPage> createState() => _ContasPagarPageState();
}

class _ContasPagarPageState extends State<ContasPagarPage> {
  final _isarService = DbService();
  late final IAService _iaService;

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  List<ContaPagarResumo> _resumos = [];
  bool _mostrarSomentePendentes = true;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _iaService = IAService(_isarService);
    _carregar();
  }

  Future<String?> _obterDescricaoFormaPagamento(String grupoParcelas) async {
    // usa os lançamentos daquele grupo de parcelas
    final lancs = await _isarService.getParcelasPorGrupoLancamento(
      grupoParcelas,
    );

    if (lancs.isEmpty) return null;

    final Lancamento l = lancs.first;

    // Se tiver cartão
    if (l.formaPagamento == FormaPagamento.credito && l.idCartao != null) {
      final CartaoCredito? cartao = await _isarService.getCartaoCreditoById(
        l.idCartao!,
      );

      if (cartao != null) {
        final ultimos =
            (cartao.ultimos4Digitos.isNotEmpty)
                ? cartao.ultimos4Digitos
                : '****';
        return 'Crédito - ${cartao.descricao} • **** $ultimos';
      }

      return 'Crédito (sem cartão cadastrado)';
    }

    // PIX / boleto / transferência / débito / dinheiro etc.
    return l.formaPagamento.label; // se o enum tiver label
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    final todasParcelas =
        _mostrarSomentePendentes
            ? await _isarService.getContasPagarPendentes()
            : await _isarService.getContasPagar();

    // Agrupa por grupoParcelas
    final mapa = <String, List<ContaPagar>>{};

    for (final conta in todasParcelas) {
      // grupoParcelas agora é obrigatório (String, não-nulo)
      final grupo = conta.grupoParcelas;
      mapa.putIfAbsent(grupo, () => []).add(conta);
    }

    final resumos = <ContaPagarResumo>[];

    for (final entry in mapa.entries) {
      final grupo = entry.key;
      final parcelas = entry.value;

      parcelas.sort((a, b) {
        final pa = a.parcelaNumero ?? 0;
        final pb = b.parcelaNumero ?? 0;
        return pa.compareTo(pb);
      });

      final descricao = parcelas.first.descricao;
      final qtd = parcelas.length;
      final valorTotal = parcelas.fold<double>(0, (soma, c) => soma + c.valor);

      final primeiroVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final ultimoVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final todasPagas = parcelas.every((c) => c.pago);

      // 👇 pega a forma de pagamento através dos lançamentos (se existirem)
      final formaDescricao = await _obterDescricaoFormaPagamento(grupo);

      resumos.add(
        ContaPagarResumo(
          grupoParcelas: grupo,
          descricao: descricao,
          valorTotal: valorTotal,
          quantidadeParcelas: qtd,
          primeiroVencimento: primeiroVencimento,
          ultimoVencimento: qtd > 1 ? ultimoVencimento : null,
          todasPagas: todasPagas,
          formaDescricao: formaDescricao, // 👈 novo
        ),
      );
    }

    setState(() {
      _resumos = resumos;
      _carregando = false;
    });
  }

  Future<void> _excluirGrupo(ContaPagarResumo resumo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir contas a pagar'),
          content: Text(
            'Deseja excluir todas as parcelas de "${resumo.descricao}" '
            '(${resumo.quantidadeParcelas} parcela(s))?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _isarService.deletarContasPagarPorGrupo(resumo.grupoParcelas);
      await _carregar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contas a pagar excluídas.')),
        );
      }
    }
  }

  Future<void> _abrirForm({ContaPagarResumo? existente}) async {
    final descricaoController = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final valorController = TextEditingController(
      text: existente != null ? existente.valorTotal.toStringAsFixed(2) : '',
    );
    final parcelasController = TextEditingController(
      text: existente?.quantidadeParcelas.toString() ?? '1',
    );

    DateTime dataVencimento = existente?.primeiroVencimento ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(existente == null ? Icons.add : Icons.edit),
                        const SizedBox(width: 8),
                        Text(
                          existente == null
                              ? 'Nova conta / compra parcelada'
                              : 'Editar (não altera parcelas antigas)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex: Notebook, TV, Cartão, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor total',
                        hintText: 'Ex: 1200,00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: parcelasController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de parcelas',
                        hintText: 'Ex: 1, 6, 12...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () async {
                        final novaData = await showDatePicker(
                          context: context,
                          initialDate: dataVencimento,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (novaData != null) {
                          setModalState(() {
                            dataVencimento = DateTime(
                              novaData.year,
                              novaData.month,
                              novaData.day,
                            );
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Primeiro vencimento: '
                              '${_dateFormat.format(dataVencimento)}',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final desc = descricaoController.text.trim();
                            final valorTotal =
                                double.tryParse(
                                  valorController.text
                                      .replaceAll('.', '')
                                      .replaceAll(',', '.'),
                                ) ??
                                0;
                            final qtdParcelas =
                                int.tryParse(parcelasController.text.trim()) ??
                                1;

                            if (desc.isEmpty ||
                                valorTotal <= 0 ||
                                qtdParcelas <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Informe descrição, valor total e '
                                    'quantidade de parcelas válidos.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (qtdParcelas == 1) {
                              // conta simples
                              await _iaService.salvarContaSimples(
                                descricao: desc,
                                valor: valorTotal,
                                dataVencimento: dataVencimento,
                              );
                            } else {
                              // compra parcelada -> cria contas + lançamentos
                              await _iaService.salvarContasParceladas(
                                descricao: desc,
                                valorTotal: valorTotal,
                                quantidadeParcelas: qtdParcelas,
                                primeiraDataVencimento: dataVencimento,
                              );
                            }

                            await _carregar();

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            existente == null ? 'Salvar' : 'Gerar novas',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a pagar'),
        actions: [
          IconButton(
            icon: Icon(
              _mostrarSomentePendentes
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            tooltip:
                _mostrarSomentePendentes
                    ? 'Mostrar todas'
                    : 'Mostrar só pendentes',
            onPressed: () {
              setState(() {
                _mostrarSomentePendentes = !_mostrarSomentePendentes;
              });
              _carregar();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/contas-pagar'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _resumos.isEmpty
              ? const Center(child: Text('Nenhuma conta cadastrada.'))
              : ListView.builder(
                itemCount: _resumos.length,
                itemBuilder: (context, index) {
                  final resumo = _resumos[index];
                  final vencida =
                      !resumo.todasPagas &&
                      resumo.ultimoVencimento != null &&
                      resumo.ultimoVencimento!.isBefore(DateTime.now());

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
                        resumo.todasPagas
                            ? Icons.check_circle
                            : (resumo.quantidadeParcelas > 1
                                ? Icons.payments
                                : Icons.schedule),
                        color:
                            resumo.todasPagas
                                ? Colors.green
                                : (vencida ? colors.error : colors.primary),
                      ),
                      title: Text(resumo.descricao),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resumo.quantidadeParcelas > 1
                                ? '${resumo.quantidadeParcelas} parcelas · '
                                    '1ª ${_dateFormat.format(resumo.primeiroVencimento)}'
                                    '${resumo.ultimoVencimento != null ? ' · última ${_dateFormat.format(resumo.ultimoVencimento!)}' : ''}'
                                : 'Vencimento: ${_dateFormat.format(resumo.primeiroVencimento)}',
                          ),
                          if (resumo.formaDescricao != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              resumo.formaDescricao!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currency.format(resumo.valorTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (resumo.quantidadeParcelas > 1)
                            Text(
                              '(${resumo.quantidadeParcelas}x de '
                              '${_currency.format(resumo.valorTotal / resumo.quantidadeParcelas)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ContaPagarDetalhePage(
                                  grupoParcelas: resumo.grupoParcelas,
                                ),
                          ),
                        ).then((_) => _carregar());
                      },
                      onLongPress: () => _excluirGrupo(resumo), // 👈 aqui
                    ),
                  );
                },
              ),
    );
  }
}
