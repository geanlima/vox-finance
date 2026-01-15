// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/formas_pagamento_repository.dart';

class FormasPagamentoPage extends StatefulWidget {
  const FormasPagamentoPage({super.key});

  @override
  State<FormasPagamentoPage> createState() => _FormasPagamentoPageState();
}

class _FormasPagamentoPageState extends State<FormasPagamentoPage>
    with SingleTickerProviderStateMixin {
  final _repo = InjectorV2.formasPagamentoRepo;

  bool _loading = true;
  List<FormaPagamentoRow> _todas = const [];

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final itens = await _repo.listarFormas(apenasAtivas: false);

    if (!mounted) return;
    setState(() {
      _todas = itens;
      _loading = false;
    });
  }

  List<FormaPagamentoRow> get _cartoes =>
      _todas.where((x) => x.tipo == 'cartao_credito').toList();

  List<FormaPagamentoRow> get _outras =>
      _todas.where((x) => x.tipo != 'cartao_credito').toList();

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💳 Minhas Formas de Pagamento'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novaForma),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Cartões de Crédito'),
            Tab(text: 'Outras Formas'),
          ],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabs,
                children: [
                  _grid(_cartoes, isCartao: true),
                  _grid(_outras, isCartao: false),
                ],
              ),
    );
  }

  Widget _grid(List<FormaPagamentoRow> itens, {required bool isCartao}) {
    if (itens.isEmpty) {
      return Center(
        child: Text(
          isCartao ? 'Nenhum cartão cadastrado.' : 'Nenhuma forma cadastrada.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          final cross =
              w >= 1100
                  ? 5
                  : w >= 900
                  ? 4
                  : w >= 650
                  ? 3
                  : 2;

          // ✅ cards mais altos => menos overflow
          final aspect = w < 420 ? 1.05 : 1.15;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: itens.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspect,
            ),
            itemBuilder: (_, i) => _card(itens[i]),
          );
        },
      ),
    );
  }

  Widget _card(FormaPagamentoRow f) {
    final cs = Theme.of(context).colorScheme;

    final ativo = f.ativo == true;
    final isCartao = f.tipo == 'cartao_credito';

    final titulo = f.nome;

    final tags = <Widget>[];
    if (isCartao && (f.principal == true)) tags.add(_chip('Cartão Principal'));
    final alias = (f.alias ?? '').trim();
    if (alias.isNotEmpty) tags.add(_chip(alias));

    final linhas = <Widget>[];
    if (isCartao) {
      final limite = f.limiteCentavos ?? 0;
      linhas.add(_linha('💰', 'Limite', _money(limite)));
      linhas.add(_linha('🗓️', 'Fechamento', 'dia ${f.diaFechamento ?? '-'}'));
      linhas.add(_linha('📅', 'Vencimento', 'dia ${f.diaVencimento ?? '-'}'));
    } else {
      linhas.add(_linha('🔖', 'Tipo', f.tipoLabel));
    }

    return Opacity(
      opacity: ativo ? 1 : 0.55,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _editarForma(f),
          onLongPress: () => _menuForma(f),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.max, // ✅ ocupa altura do card
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // topo
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mais',
                      onPressed: () => _menuForma(f),
                      icon: const Icon(Icons.more_horiz),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                // tags em 1 linha (sem quebrar)
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in tags) ...[t, const SizedBox(width: 8)],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // corpo flexível (se apertar, ele encolhe antes do switch)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: linhas,
                  ),
                ),

                const SizedBox(height: 8),

                // rodapé fixo
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ativo ? 'Ativo' : 'Inativo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ativo ? cs.primary : cs.outline,
                        ),
                      ),
                    ),
                    Switch(
                      value: ativo,
                      onChanged: (v) async {
                        await _repo.setAtivo(f.id, v);
                        await _load();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.secondaryContainer.withOpacity(.7),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _linha(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> _menuForma(FormaPagamentoRow f) async {
    final isCartao = f.tipo == 'cartao_credito';

    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar'),
                onTap: () => Navigator.pop(ctx, 'editar'),
              ),
              if (isCartao)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('Marcar como principal'),
                  onTap: () => Navigator.pop(ctx, 'principal'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () => Navigator.pop(ctx, 'excluir'),
              ),
            ],
          ),
        );
      },
    );

    if (acao == null) return;

    if (acao == 'editar') {
      await _editarForma(f);
      return;
    }

    if (acao == 'principal') {
      await _repo.definirComoPrincipal(f.id);
      await _load();
      return;
    }

    if (acao == 'excluir') {
      final ok = await _confirmarExclusao(f.nome);
      if (!ok) return;
      await _repo.deletar(f.id);
      await _load();
    }
  }

  Future<bool> _confirmarExclusao(String nome) async {
    return (await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Excluir?'),
                content: Text('Deseja excluir "$nome"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
        )) ??
        false;
  }

  Future<void> _novaForma() async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Cartão de crédito'),
                onTap: () => Navigator.pop(ctx, 'cartao_credito'),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Outra forma (pix, dinheiro, débito...)'),
                onTap: () => Navigator.pop(ctx, 'outros'),
              ),
            ],
          ),
        );
      },
    );

    if (tipo == null) return;

    if (tipo == 'cartao_credito') {
      await _modalCartao();
    } else {
      await _modalOutraForma();
    }
  }

  Future<void> _editarForma(FormaPagamentoRow f) async {
    if (f.tipo == 'cartao_credito') {
      await _modalCartao(edit: f);
    } else {
      await _modalOutraForma(edit: f);
    }
  }

  // ---------------------------
  // MODAIS (mantive sua lógica)
  // ---------------------------

  Future<void> _modalOutraForma({FormaPagamentoRow? edit}) async {
    final nomeCtrl = TextEditingController(text: edit?.nome ?? '');
    String tipo = edit?.tipo ?? 'pix';
    bool ativo = edit?.ativo ?? true;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edit == null ? 'Nova forma de pagamento' : 'Editar forma',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tipo,
                    items: const [
                      DropdownMenuItem(value: 'pix', child: Text('PIX')),
                      DropdownMenuItem(
                        value: 'dinheiro',
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(
                        value: 'debito',
                        child: Text('Cartão de débito'),
                      ),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferência'),
                      ),
                      DropdownMenuItem(value: 'outros', child: Text('Outros')),
                    ],
                    onChanged: (v) => setModal(() => tipo = v ?? 'pix'),
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    value: ativo,
                    onChanged: (v) => setModal(() => ativo = v),
                    title: const Text('Ativo'),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                      onPressed: () async {
                        final nome = nomeCtrl.text.trim();
                        if (nome.isEmpty) return;

                        if (edit == null) {
                          await _repo.criarForma(
                            nome: nome,
                            tipo: tipo,
                            ativo: ativo,
                          );
                        } else {
                          await _repo.editarForma(
                            id: edit.id,
                            nome: nome,
                            tipo: tipo,
                            ativo: ativo,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _modalCartao({FormaPagamentoRow? edit}) async {
    final nomeCtrl = TextEditingController(text: edit?.nome ?? '');
    final limiteCtrl = TextEditingController(
      text:
          (edit?.limiteCentavos == null)
              ? ''
              : ((edit!.limiteCentavos! / 100).toStringAsFixed(
                2,
              )).replaceAll('.', ','),
    );

    int fechamento = edit?.diaFechamento ?? 10;
    int vencimento = edit?.diaVencimento ?? 17;

    bool principal = edit?.principal ?? false;
    bool ativo = edit?.ativo ?? true;

    int parseMoneyToCents(String input) {
      var s = input.trim();
      if (s.isEmpty) return 0;
      s = s.replaceAll('R\$', '').replaceAll(' ', '');
      if (s.contains(',')) {
        s = s.replaceAll('.', '');
        s = s.replaceAll(',', '.');
      }
      final v = double.tryParse(s) ?? 0.0;
      return (v * 100).round();
    }

    List<DropdownMenuItem<int>> dias() {
      return List.generate(31, (i) {
        final d = i + 1;
        return DropdownMenuItem<int>(value: d, child: Text('Dia $d'));
      });
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edit == null ? 'Novo cartão de crédito' : 'Editar cartão',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cartão',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: limiteCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Limite (R\$)',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: fechamento,
                          items: dias(),
                          onChanged:
                              (v) => setModal(() => fechamento = v ?? 10),
                          decoration: const InputDecoration(
                            labelText: 'Fechamento da fatura',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: vencimento,
                          items: dias(),
                          onChanged:
                              (v) => setModal(() => vencimento = v ?? 17),
                          decoration: const InputDecoration(
                            labelText: 'Vencimento da fatura',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: principal,
                    onChanged: (v) => setModal(() => principal = v),
                    title: const Text('Cartão principal'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: ativo,
                    onChanged: (v) => setModal(() => ativo = v),
                    title: const Text('Ativo'),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                      onPressed: () async {
                        final nome = nomeCtrl.text.trim();
                        if (nome.isEmpty) return;

                        final limiteCentavos = parseMoneyToCents(
                          limiteCtrl.text,
                        );

                        if (edit == null) {
                          await _repo.criarCartaoCredito(
                            nome: nome,
                            limiteCentavos: limiteCentavos,
                            diaFechamento: fechamento,
                            diaVencimento: vencimento,
                            principal: principal,
                            ativo: ativo,
                          );
                        } else {
                          await _repo.editarCartaoCredito(
                            id: edit.id,
                            nome: nome,
                            limiteCentavos: limiteCentavos,
                            diaFechamento: fechamento,
                            diaVencimento: vencimento,
                            principal: principal,
                            ativo: ativo,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// ✅ garante tipoLabel mesmo se sua model não tiver
extension FormaPagamentoRowUi on FormaPagamentoRow {
  String get tipoLabel {
    switch (tipo) {
      case 'cartao_credito':
        return 'Cartão de crédito';
      case 'pix':
        return 'PIX';
      case 'dinheiro':
        return 'Dinheiro';
      case 'debito':
        return 'Cartão de débito';
      case 'transferencia':
        return 'Transferência';
      default:
        return 'Outros';
    }
  }
}
