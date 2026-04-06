import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/conta_pagar_pagamento_service.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_aviso_service.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart'
    show CartaoCredito, TipoCartao;
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa_mes_resumo.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/despesas_fixas/despesa_fixa_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class DespesasFixasPage extends StatefulWidget {
  const DespesasFixasPage({super.key});

  @override
  State<DespesasFixasPage> createState() => _DespesasFixasPageState();
}

class _DespesasFixasPageState extends State<DespesasFixasPage> {
  final _repo = DespesaFixaRepository();
  final _pagamentoService = ContaPagarPagamentoService();
  final _contaPagarRepo = ContaPagarRepository();
  final _cartaoRepo = CartaoCreditoRepository();
  final _contaBancariaRepo = ContaBancariaRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _date = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  ResumoDespesasFixasMes? _resumo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resumo = await _repo.resumoMesAtual();
    if (!mounted) return;
    setState(() {
      _resumo = resumo;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DespesasFixasAvisoService.tentarMostrarAvisoMesAnteriorSeNecessario(
        context,
      );
    });
  }

  String _mesEtiqueta(DateTime ref) {
    final raw = DateFormat('MMMM yyyy', 'pt_BR').format(ref);
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _subtituloSituacaoMes(DespesaFixaMesLinha linha) {
    final mes = _mesEtiqueta(linha.conta?.dataVencimento ?? _resumo!.mesReferencia);
    switch (linha.situacao) {
      case DespesaFixaSituacaoMes.inativa:
        return '$mes: Inativa (não entra no fechamento)';
      case DespesaFixaSituacaoMes.quitado:
        return '$mes: Quitado';
      case DespesaFixaSituacaoMes.pendente:
        return '$mes: Não quitado';
      case DespesaFixaSituacaoMes.semLancamento:
        return '$mes: Sem lançamento no mês (manual ou gere em Contas a pagar)';
    }
  }

  Future<void> _openForm({DespesaFixa? item}) async {
    final descCtrl = TextEditingController(text: item?.descricao ?? '');
    final valorCtrl = TextEditingController(
      text: item != null ? item.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    final diaCtrl = TextEditingController(text: (item?.diaVencimento ?? 10).toString());
    FormaPagamento? forma = item?.formaPagamento;
    bool ativo = item?.ativo ?? true;
    bool auto = item?.gerarAutomatico ?? true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom:
                    mq.viewInsets.bottom + mq.viewPadding.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: diaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dia de vencimento (1..31)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FormaPagamento?>(
                    initialValue: forma,
                    items: [
                      const DropdownMenuItem<FormaPagamento?>(
                        value: null,
                        child: Text('Forma de pagamento (opcional)'),
                      ),
                      ...FormaPagamento.values.map(
                        (f) => DropdownMenuItem<FormaPagamento?>(
                          value: f,
                          child: Text(f.label),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModal(() => forma = v),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    value: ativo,
                    onChanged: (v) => setModal(() => ativo = v),
                    title: const Text('Ativa'),
                  ),
                  SwitchListTile(
                    value: auto,
                    onChanged: (v) => setModal(() => auto = v),
                    title: const Text('Gerar automaticamente na virada do mês'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final desc = descCtrl.text.trim();
                        final valor = double.tryParse(
                          valorCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
                        );
                        final dia = int.tryParse(diaCtrl.text.trim());
                        if (desc.isEmpty ||
                            valor == null ||
                            valor < 0 ||
                            dia == null ||
                            dia < 1 ||
                            dia > 31) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Preencha descrição, valor e dia válidos.')),
                          );
                          return;
                        }

                        final retId = await _repo.salvar(
                          DespesaFixa(
                            id: item?.id,
                            descricao: desc,
                            valor: valor,
                            diaVencimento: dia,
                            formaPagamento: forma,
                            ativo: ativo,
                            gerarAutomatico: auto,
                            criadoEm: item?.criadoEm ?? DateTime.now(),
                          ),
                        );
                        final idFixa = item?.id ?? retId;
                        await _contaPagarRepo.atualizarContasAbertasDaDespesaFixa(
                          idDespesaFixa: idFixa,
                          valor: valor,
                          descricao: desc,
                          formaPagamentoIndex: forma?.index,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _load();
  }

  Future<void> _delete(DespesaFixa item) async {
    if (item.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir despesa fixa'),
        content: Text('Deseja excluir "${item.descricao}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deletar(item.id!);
    await _load();
  }

  Future<void> _pagarMes(DespesaFixa fixa) async {
    if (fixa.id == null) return;
    final now = DateTime.now();
    final ref = DateTime(now.year, now.month, 1);

    final vencDia = fixa.diaVencimento.clamp(
      1,
      DateTime(now.year, now.month + 1, 0).day,
    );
    final venc = DateTime(now.year, now.month, vencDia);

    final bool valorVariavel = fixa.valor == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Marcar como pago?'),
          content: Text(
            '${fixa.descricao}\n'
            'Venc: ${_date.format(venc)}\n'
            'Valor: ${valorVariavel ? 'Variável' : _money.format(fixa.valor)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pagar'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    // garantir que a conta do mês exista (auto mensal)
    await _repo.gerarPendenciasDoMes(ref);
    final conta = await _repo.getContaDoMesParaFixa(
      idDespesaFixa: fixa.id!,
      referencia: ref,
    );

    if (!mounted) return;
    if (conta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não encontrei a conta deste mês.')),
      );
      return;
    }

    if (conta.pago == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este mês já está como pago.')),
      );
      return;
    }

    double valorPago = conta.valor;
    if (valorVariavel) {
      final ctrl = TextEditingController();
      final v = await showDialog<double?>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Informe o valor pago'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor pago',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(
                    ctrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Informe um valor válido.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, parsed);
                },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      if (v == null) return;
      valorPago = v;
    }

    if (conta.id != null && valorPago != conta.valor) {
      await _contaPagarRepo.atualizarValorParcela(conta.id!, valorPago);
      conta.valor = valorPago;
    }

    final forma = fixa.formaPagamento ?? conta.formaPagamento;
    final okOrigem = await _solicitarOrigemPagamentoSeNecessario(conta, forma);
    if (!okOrigem) return;

    if (conta.id != null) {
      await _contaPagarRepo.salvar(conta);
    }

    await _pagamentoService.registrarPagamento(conta);
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pago com sucesso. Lançamento gerado.')),
    );
  }

  List<CartaoCredito> _filtrarCartoesParaForma(
    List<CartaoCredito> todos,
    FormaPagamento forma,
  ) {
    if (forma == FormaPagamento.debito) {
      return todos
          .where(
            (c) => c.tipo == TipoCartao.debito || c.tipo == TipoCartao.ambos,
          )
          .toList();
    }
    if (forma == FormaPagamento.credito) {
      return todos
          .where(
            (c) => c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos,
          )
          .toList();
    }
    return const [];
  }

  String _tituloDialogConta(FormaPagamento forma) {
    switch (forma) {
      case FormaPagamento.pix:
        return 'Conta para Pix';
      case FormaPagamento.transferencia:
        return 'Conta para transferência';
      case FormaPagamento.boleto:
        return 'Conta para boleto';
      default:
        return 'Conta bancária';
    }
  }

  /// Para crédito/débito ou Pix (e demais formas que usam conta no app), pede cartão ou conta.
  Future<bool> _solicitarOrigemPagamentoSeNecessario(
    ContaPagar conta,
    FormaPagamento? forma,
  ) async {
    if (forma == null) return true;

    final precisaCartao =
        forma == FormaPagamento.credito || forma == FormaPagamento.debito;
    final precisaContaBancaria =
        forma == FormaPagamento.pix ||
        forma == FormaPagamento.transferencia ||
        forma == FormaPagamento.boleto;

    if (!precisaCartao && !precisaContaBancaria) return true;

    if (precisaCartao) {
      final todos = await _cartaoRepo.getCartoesCredito();
      final filtrados = _filtrarCartoesParaForma(todos, forma);
      if (filtrados.isEmpty) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cadastre um cartão compatível em Menu → Cartões de crédito.',
            ),
          ),
        );
        return false;
      }

      CartaoCredito? preSelecionado;
      for (final c in filtrados) {
        if (c.id == conta.idCartao) {
          preSelecionado = c;
          break;
        }
      }
      preSelecionado ??= filtrados.first;

      if (!mounted) return false;
      final escolhido = await showDialog<CartaoCredito>(
        context: context,
        builder: (ctx) {
          CartaoCredito? sel = preSelecionado;
          return StatefulBuilder(
            builder: (ctx, setS) {
              return AlertDialog(
                title: Text(
                  forma == FormaPagamento.credito
                      ? 'Cartão de crédito'
                      : 'Cartão de débito',
                ),
                content: DropdownButtonFormField<CartaoCredito>(
                  key: ValueKey(sel?.id),
                  initialValue: sel,
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      filtrados
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setS(() => sel = v),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, sel),
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (escolhido == null) return false;
      conta.idCartao = escolhido.id;
      conta.idConta = null;
      conta.formaPagamento = forma;
      return true;
    }

    final contas = await _contaBancariaRepo.getContasBancarias(
      apenasAtivas: true,
    );
    if (contas.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma conta bancária ativa. Cadastre em Menu → Contas bancárias.',
          ),
        ),
      );
      return false;
    }

    ContaBancaria? preConta;
    for (final c in contas) {
      if (c.id == conta.idConta) {
        preConta = c;
        break;
      }
    }
    preConta ??= contas.first;

    if (!mounted) return false;
    final escolhida = await showDialog<ContaBancaria>(
      context: context,
      builder: (ctx) {
        ContaBancaria? sel = preConta;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(_tituloDialogConta(forma)),
              content: DropdownButtonFormField<ContaBancaria>(
                key: ValueKey(sel?.id),
                initialValue: sel,
                decoration: const InputDecoration(
                  labelText: 'Conta bancária',
                  border: OutlineInputBorder(),
                ),
                items:
                    contas.map((c) {
                      final texto =
                          '${c.descricao} ${c.banco != null && c.banco!.isNotEmpty ? "(${c.banco})" : ""}';
                      return DropdownMenuItem(value: c, child: Text(texto));
                    }).toList(),
                onChanged: (v) => setS(() => sel = v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, sel),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (escolhida == null) return false;
    conta.idConta = escolhida.id;
    conta.idCartao = null;
    conta.formaPagamento = forma;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    // Espaço extra para não ficar atrás da barra de navegação e do FAB.
    final listBottomPadding = bottomSafe + 88;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas Fixas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/despesas-fixas'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _resumo == null || _resumo!.linhas.isEmpty
          ? const Center(child: Text('Nenhuma despesa fixa cadastrada.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mesEtiqueta(_resumo!.mesReferencia),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _totChip(
                                  context,
                                  'Quitado no mês',
                                  _money.format(_resumo!.totalPago),
                                  Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _totChip(
                                  context,
                                  'Falta pagar',
                                  _money.format(_resumo!.totalPendente),
                                  Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _totChip(
                            context,
                            'Total do mês (quitado + pendente)',
                            _money.format(_resumo!.totalMes),
                            Theme.of(context).colorScheme.primary,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 12, 12, listBottomPadding),
              itemCount: _resumo!.linhas.length,
              itemBuilder: (_, i) {
                final linha = _resumo!.linhas[i];
                final d = linha.fixa;
                final theme = Theme.of(context);
                final primary = theme.colorScheme.primary;
                final danger = Colors.red.shade400;
                return Slidable(
                  key: ValueKey(d.id ?? i),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.22,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) => _pagarMes(d),
                        backgroundColor: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(
                          Icons.check_circle,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.35,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) => _openForm(item: d),
                        backgroundColor: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: Icon(Icons.edit, size: 28, color: primary),
                      ),
                      CustomSlidableAction(
                        onPressed: (_) => _delete(d),
                        backgroundColor: danger,
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(
                          Icons.delete,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  child: Card(
                    child: ListTile(
                      title: Text(d.descricao),
                      isThreeLine: true,
                      subtitle: Text(
                        'Vence dia ${d.diaVencimento} • ${d.gerarAutomatico ? 'Auto mensal' : 'Manual'}\n'
                        '${_subtituloSituacaoMes(linha)}',
                        style: TextStyle(
                          color: switch (linha.situacao) {
                            DespesaFixaSituacaoMes.quitado => Colors.green.shade800,
                            DespesaFixaSituacaoMes.pendente => Colors.orange.shade900,
                            DespesaFixaSituacaoMes.semLancamento => null,
                            DespesaFixaSituacaoMes.inativa => Colors.grey.shade700,
                          },
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money.format(linha.valorReferencia),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            d.ativo ? 'Ativa' : 'Inativa',
                            style: TextStyle(
                              color: d.ativo ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _openForm(item: d),
                    ),
                  ),
                );
              },
            ),
                ),
              ],
            ),
    );
  }

  Widget _totChip(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

