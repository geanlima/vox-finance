import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/lembrete.dart';
import 'package:vox_finance/ui/data/modules/lembretes/lembrete_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class LembretesPage extends StatefulWidget {
  const LembretesPage({super.key});

  @override
  State<LembretesPage> createState() => _LembretesPageState();
}

class _LembretesPageState extends State<LembretesPage> {
  final _repo = LembreteRepository();
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _loading = true;
  List<Lembrete> _items = const [];
  bool _mostrarConcluidos = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listar(incluirConcluidos: _mostrarConcluidos);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _openForm({Lembrete? item}) async {
    final tituloCtrl = TextEditingController(text: item?.titulo ?? '');
    final descCtrl = TextEditingController(text: item?.descricao ?? '');
    DateTime dataHora = item?.dataHora ?? DateTime.now().add(const Duration(hours: 1));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
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
                  children: [
                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data e hora'),
                      subtitle: Text(_fmt.format(dataHora)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await _pickDateTime(ctx, initial: dataHora);
                        if (picked == null) return;
                        setModal(() => dataHora = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final titulo = tituloCtrl.text.trim();
                          if (titulo.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Informe o título.')),
                            );
                            return;
                          }
                          await _repo.salvar(
                            Lembrete(
                              id: item?.id,
                              titulo: titulo,
                              descricao: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              dataHora: dataHora,
                              concluido: item?.concluido ?? false,
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
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _load();
  }

  Future<void> _delete(Lembrete item) async {
    if (item.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lembrete'),
        content: Text('Deseja excluir "${item.titulo}"?'),
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
        title: const Text('Lembretes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            tooltip: _mostrarConcluidos ? 'Ocultar concluídos' : 'Mostrar concluídos',
            icon: Icon(_mostrarConcluidos ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () async {
              setState(() => _mostrarConcluidos = !_mostrarConcluidos);
              await _load();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/lembretes'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Nenhum lembrete.'))
              : ListView.builder(
                  padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(12)),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final danger = Colors.red.shade400;
                    final theme = Theme.of(context);

                    return Slidable(
                      key: ValueKey(it.id ?? i),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.22,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) async {
                              if (it.id == null) return;
                              await _repo.marcarConcluido(it.id!, !it.concluido);
                              await _load();
                            },
                            backgroundColor: it.concluido ? Colors.orange.shade700 : Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              it.concluido ? Icons.undo : Icons.check_circle,
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
                            onPressed: (_) => _openForm(item: it),
                            backgroundColor: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(Icons.edit, size: 28, color: theme.colorScheme.primary),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) => _delete(it),
                            backgroundColor: danger,
                            borderRadius: BorderRadius.circular(12),
                            child: const Icon(Icons.delete, size: 28, color: Colors.white),
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            it.concluido ? Icons.check_circle : Icons.notifications_active_outlined,
                            color: it.concluido ? Colors.green : null,
                          ),
                          title: Text(
                            it.titulo,
                            style: TextStyle(
                              decoration: it.concluido ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '${_fmt.format(it.dataHora)}${(it.descricao?.isNotEmpty ?? false) ? '\n${it.descricao}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openForm(item: it),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

