import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco.dart';
import 'package:vox_finance/ui/data/modules/monitoramento_precos/monitoramento_preco_repository.dart';
import 'package:vox_finance/ui/pages/monitoramento_precos/monitoramento_preco_detalhe_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class MonitoramentoPrecosPage extends StatefulWidget {
  const MonitoramentoPrecosPage({super.key});

  static const routeName = '/monitoramento-precos';

  @override
  State<MonitoramentoPrecosPage> createState() => _MonitoramentoPrecosPageState();
}

class _MonitoramentoPrecosPageState extends State<MonitoramentoPrecosPage> {
  final _repo = MonitoramentoPrecoRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _loading = true;
  List<MonitoramentoPreco> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listarProdutos();
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openForm({MonitoramentoPreco? item}) async {
    final produtoCtrl = TextEditingController(text: item?.produto ?? '');
    final precoCtrl = TextEditingController(
      text: item != null ? _money.format(item.preco) : '',
    );
    final lojaCtrl = TextEditingController(text: item?.loja ?? '');
    final urlCtrl = TextEditingController(text: item?.url ?? '');
    String? fotoPath = item?.fotoPath;

    final salvo = await showModalBottomSheet<MonitoramentoPreco?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              final bottomPad = 28 + mq.viewInsets.bottom + mq.viewPadding.bottom;
              final bool primeiroPasso = item == null;

              Future<void> pickImage() async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                final path = result?.files.single.path;
                if (path == null || path.trim().isEmpty) return;
                setModal(() => fotoPath = path);
              }

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      primeiroPasso ? 'Novo produto' : 'Produto',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: pickImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              border: Border.all(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: (fotoPath != null &&
                                      fotoPath!.trim().isNotEmpty &&
                                      File(fotoPath!).existsSync())
                                  ? Image.file(
                                      File(fotoPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.photo_camera_outlined,
                                      color: Theme.of(ctx).colorScheme.outline,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: produtoCtrl,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Produto',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (!primeiroPasso) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: precoCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Preço',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fotoPath != null && fotoPath!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setModal(() => fotoPath = null),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover foto'),
                        ),
                      ),
                    ],
                    if (!primeiroPasso) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Detalhes (opcional)'),
                        children: [
                          TextField(
                            controller: lojaCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Local / Loja',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: urlCtrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Link',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                      final produto = produtoCtrl.text.trim();
                      if (produto.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe o produto.')),
                        );
                        return;
                      }

                          double preco = 0.0;
                          if (!primeiroPasso) {
                            try {
                              preco = CurrencyInputFormatter.parse(precoCtrl.text);
                            } catch (_) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Preço inválido.')),
                              );
                              return;
                            }
                            if (preco <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Preço inválido.')),
                              );
                              return;
                            }
                          }

                      final loja = lojaCtrl.text.trim();
                      final url = urlCtrl.text.trim();
                      final now = DateTime.now();
                      final novo = (item == null)
                          ? MonitoramentoPreco(
                              produto: produto,
                              preco: preco,
                                  loja: primeiroPasso
                                      ? null
                                      : (loja.isEmpty ? null : loja),
                                  url:
                                      primeiroPasso ? null : (url.isEmpty ? null : url),
                              fotoPath:
                                  (fotoPath == null || fotoPath!.trim().isEmpty)
                                      ? null
                                      : fotoPath,
                              criadoEm: now,
                              atualizadoEm: now,
                            )
                          : item.copyWith(
                              produto: produto,
                              preco: preco,
                              loja: loja.isEmpty ? null : loja,
                              url: url.isEmpty ? null : url,
                              fotoPath:
                                  (fotoPath == null || fotoPath!.trim().isEmpty)
                                      ? null
                                      : fotoPath,
                              atualizadoEm: now,
                            );

                          final id = await _repo.salvar(novo);
                      if (!ctx.mounted) return;
                          final savedObj =
                              (item == null) ? novo.copyWith(id: id) : novo;
                          Navigator.pop(ctx, savedObj);
                        },
                        child: Text(primeiroPasso ? 'Salvar produto' : 'Salvar'),
                      ),
                    ),
                    if (item?.id != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(ctx).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('Deletar produto'),
                                content: Text(
                                  'Deseja deletar "${item!.produto}" do monitoramento?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, true),
                                    child: const Text('Deletar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            await _repo.deletar(item!.id!);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx, null);
                          },
                          label: const Text('Deletar'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (salvo != null) {
      await _load();
      if (item == null) {
        // 2º passo: abre o detalhe para adicionar lojas/ofertas.
        if (!mounted) return;
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MonitoramentoPrecoDetalhePage(produto: salvo),
          ),
        );
        if (changed == true) await _load();
      } else {
        _snack('Salvo.');
      }
    }
  }

  Future<void> _delete(MonitoramentoPreco item) async {
    final id = item.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover'),
        content: Text('Remover "${item.produto}" do monitoramento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deletar(id);
    await _load();
    _snack('Removido.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoramento de preços')),
      drawer: const AppDrawer(currentRoute: MonitoramentoPrecosPage.routeName),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum produto monitorado.\n\nToque em “+” para adicionar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      final loja = (it.loja ?? '').trim();
                      final url = (it.url ?? '').trim();
                      final sub = <String>[
                        if (loja.isNotEmpty) loja,
                        if (url.isNotEmpty) url,
                      ].join(' • ');
                      final fotoPath = (it.fotoPath ?? '').trim();
                      final menorPreco = it.menorPreco;
                      final ofertasCount = it.ofertasCount;

                      return Card(
                        child: ListTile(
                          leading: fotoPath.isEmpty
                              ? const CircleAvatar(
                                  child: Icon(Icons.local_offer_outlined),
                                )
                              : CircleAvatar(
                                  backgroundImage:
                                      FileImage(File(fotoPath)),
                                ),
                          title: Text(
                            it.produto,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (ofertasCount > 0)
                                '$ofertasCount loja(s)',
                              if (sub.isNotEmpty) sub,
                            ].join(' • '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                (menorPreco == null || menorPreco <= 0)
                                    ? '—'
                                    : _money.format(menorPreco),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd/MM/yyyy').format(it.atualizadoEm),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MonitoramentoPrecoDetalhePage(produto: it),
                              ),
                            );
                            if (changed == true) await _load();
                          },
                          onLongPress: () => _delete(it),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

