import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa.dart';
import 'package:vox_finance/ui/data/modules/despesas_fixas/despesa_fixa_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class DespesasFixasPage extends StatefulWidget {
  const DespesasFixasPage({super.key});

  @override
  State<DespesasFixasPage> createState() => _DespesasFixasPageState();
}

class _DespesasFixasPageState extends State<DespesasFixasPage> {
  final _repo = DespesaFixaRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _loading = true;
  List<DespesaFixa> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final itens = await _repo.listar();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _loading = false;
    });
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
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                28 + mq.viewInsets.bottom + mq.viewPadding.bottom,
              ),
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
                        if (desc.isEmpty || valor == null || valor <= 0 || dia == null || dia < 1 || dia > 31) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Preencha descrição, valor e dia válidos.')),
                          );
                          return;
                        }

                        await _repo.salvar(
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
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
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
          : _itens.isEmpty
          ? const Center(child: Text('Nenhuma despesa fixa cadastrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _itens.length,
              itemBuilder: (_, i) {
                final d = _itens[i];
                final theme = Theme.of(context);
                final primary = theme.colorScheme.primary;
                final danger = Colors.red.shade400;
                return Slidable(
                  key: ValueKey(d.id ?? i),
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
                      subtitle: Text(
                        'Vence dia ${d.diaVencimento} • ${d.gerarAutomatico ? 'Auto mensal' : 'Manual'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money.format(d.valor),
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
    );
  }
}

