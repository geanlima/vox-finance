import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco_oferta.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco_oferta_historico.dart';
import 'package:vox_finance/ui/data/modules/monitoramento_precos/monitoramento_preco_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class MonitoramentoPrecoLojaDetalhePage extends StatefulWidget {
  const MonitoramentoPrecoLojaDetalhePage({
    super.key,
    required this.loja,
    this.onTrySetProductImageFromUrl,
  });

  final MonitoramentoPrecoOferta loja;
  final Future<void> Function(String url)? onTrySetProductImageFromUrl;

  @override
  State<MonitoramentoPrecoLojaDetalhePage> createState() =>
      _MonitoramentoPrecoLojaDetalhePageState();
}

class _MonitoramentoPrecoLojaDetalhePageState
    extends State<MonitoramentoPrecoLojaDetalhePage> {
  final _repo = MonitoramentoPrecoRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _date = DateFormat('dd/MM/yyyy HH:mm');

  late MonitoramentoPrecoOferta _loja;
  bool _loading = true;
  List<MonitoramentoPrecoOfertaHistorico> _historico = const [];

  @override
  void initState() {
    super.initState();
    _loja = widget.loja;
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final id = _loja.id;
    if (id == null) return;
    setState(() => _loading = true);
    final rows = await _repo.listarHistoricoPorOferta(id);
    if (!mounted) return;
    setState(() {
      _historico = rows;
      _loading = false;
    });
  }

  Future<void> _editarLoja() async {
    final id = _loja.id;
    if (id == null) return;

    final lojaCtrl = TextEditingController(text: _loja.loja ?? '');
    final urlCtrl = TextEditingController(text: _loja.url ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              28 + mq.viewInsets.bottom + mq.viewPadding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Editar loja',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lojaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Loja / site',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Link (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    final loja = lojaCtrl.text.trim();
                    final url = urlCtrl.text.trim();
                    final now = DateTime.now();
                    final novo = _loja.copyWith(
                      loja: loja.isEmpty ? null : loja,
                      url: url.isEmpty ? null : url,
                      atualizadoEm: now,
                    );
                    await _repo.salvarLoja(novo);
                    if (!ctx.mounted) return;
                    setState(() => _loja = novo);
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok == true) {
      _snack('Loja atualizada.');
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _adicionarPreco() async {
    final id = _loja.id;
    if (id == null) return;

    final precoCtrl = TextEditingController();
    DateTime dataHora = DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  28 + mq.viewInsets.bottom + mq.viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Adicionar preço',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Preço',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data e hora'),
                      subtitle: Text(_date.format(dataHora)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final base = dataHora;
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: base,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(DateTime.now().year + 5),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (t == null) return;
                        setModal(() {
                          dataHora = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        double preco;
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

                        await _repo.adicionarPreco(
                          idOferta: id,
                          preco: preco,
                          dataHora: dataHora,
                        );

                        final url = (_loja.url ?? '').trim();
                        if (url.isNotEmpty) {
                          await widget.onTrySetProductImageFromUrl?.call(url);
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok == true) {
      await _load();
      _snack('Preço adicionado.');
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _editarPreco(MonitoramentoPrecoOfertaHistorico h) async {
    final idOferta = _loja.id;
    final idHist = h.id;
    if (idOferta == null || idHist == null) return;

    final precoCtrl = TextEditingController(text: _money.format(h.preco));
    DateTime dataHora = h.criadoEm;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  28 + mq.viewInsets.bottom + mq.viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Editar preço',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Preço',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data e hora'),
                      subtitle: Text(_date.format(dataHora)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final base = dataHora;
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: base,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(DateTime.now().year + 5),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (t == null) return;
                        setModal(() {
                          dataHora = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        double preco;
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

                        await _repo.atualizarPrecoHistorico(
                          idHistorico: idHist,
                          idOferta: idOferta,
                          preco: preco,
                          dataHora: dataHora,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok == true) {
      await _load();
      _snack('Preço atualizado.');
    }
  }

  Future<void> _removerPreco(MonitoramentoPrecoOfertaHistorico h) async {
    final idOferta = _loja.id;
    final idHist = h.id;
    if (idOferta == null || idHist == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover preço'),
        content: const Text('Deseja remover este registro de preço?'),
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
    await _repo.deletarPrecoHistorico(idHistorico: idHist, idOferta: idOferta);
    await _load();
    _snack('Preço removido.');
  }

  Future<void> _removerLoja() async {
    final id = _loja.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover loja'),
        content: const Text('Deseja remover esta loja e todo o histórico?'),
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
    await _repo.deletarOferta(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lojaLabel = (_loja.loja ?? '').trim();
    final titulo = lojaLabel.isEmpty ? 'Loja' : lojaLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: 'Editar loja',
            onPressed: _editarLoja,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover loja',
            onPressed: _removerLoja,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _adicionarPreco,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar preço'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _historico.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum preço cadastrado.\n\nToque em “Adicionar preço”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                  itemCount: _historico.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final h = _historico[i];
                    return Slidable(
                      key: ValueKey('preco_${h.id ?? i}'),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.34,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _editarPreco(h),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) => _removerPreco(h),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(
                            _money.format(h.preco),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_date.format(h.criadoEm)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

