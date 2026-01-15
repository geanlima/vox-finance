// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/categorias_repository.dart';

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final _repo = InjectorV2.categoriasRepo;

  bool _loading = true;
  List<CategoriaRow> _cats = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final cats = await _repo.listarCategorias(apenasAtivas: true);

    if (!mounted) return;
    setState(() {
      _cats = cats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        actions: [
          IconButton(
            tooltip: 'Nova categoria',
            icon: const Icon(Icons.add),
            onPressed: _abrirNovaCategoria,
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  _categoriasCriadasCard(context, cs),
                  const SizedBox(height: 12),
                  Text(
                    'Dica: toque longo no chip para editar ou desativar.',
                    style: TextStyle(color: cs.outline),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _categoriasCriadasCard(BuildContext context, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Categorias criadas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${_cats.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cats.isEmpty)
              Text(
                'Nenhuma categoria ainda. Clique em + para criar.',
                style: TextStyle(color: cs.outline),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _cats.map((c) {
                  final label = '${c.emoji ?? '📌'} ${c.nome}';
                  return GestureDetector(
                    onLongPress: () async {
                      await _editarCategoriaModal(context, c);
                      await _load();
                    },
                    child: Chip(
                      label: Text(label),
                      side: BorderSide(color: cs.outlineVariant),
                      backgroundColor:
                          cs.surfaceContainerHighest.withOpacity(.55),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- criar categoria ----------
  Future<void> _abrirNovaCategoria() async {
    final nomeCtrl = TextEditingController();

    String tipo = 'variavel';
    String emoji = '📌';

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
                  const Text(
                    'Nova categoria',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nomeCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nome da categoria',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Tipo',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Ganho'),
                        selected: tipo == 'ganho',
                        onSelected: (_) => setModal(() => tipo = 'ganho'),
                      ),
                      ChoiceChip(
                        label: const Text('Fixa'),
                        selected: tipo == 'fixa',
                        onSelected: (_) => setModal(() => tipo = 'fixa'),
                      ),
                      ChoiceChip(
                        label: const Text('Variável'),
                        selected: tipo == 'variavel',
                        onSelected: (_) => setModal(() => tipo = 'variavel'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text('Emoji',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['🛒', '🍔', '🚗', '🏠', '💡', '🎮', '💊', '📌']
                        .map((e) {
                      return ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 16)),
                        selected: emoji == e,
                        onSelected: (_) => setModal(() => emoji = e),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Criar categoria'),
                      onPressed: () async {
                        final nome = nomeCtrl.text.trim();
                        if (nome.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Informe o nome da categoria')),
                          );
                          return;
                        }

                        await _repo.criarCategoria(
                          nome: nome,
                          tipo: tipo,
                          emoji: emoji,
                        );

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

  // ---------- editar/desativar categoria ----------
  Future<void> _editarCategoriaModal(
    BuildContext context,
    CategoriaRow c,
  ) async {
    final nomeCtrl = TextEditingController(text: c.nome);

    String tipo = c.tipo;
    String emoji = (c.emoji?.isNotEmpty ?? false) ? c.emoji! : '📌';

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
                  const Text(
                    'Editar categoria',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                  const Text('Tipo',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Ganho'),
                        selected: tipo == 'ganho',
                        onSelected: (_) => setModal(() => tipo = 'ganho'),
                      ),
                      ChoiceChip(
                        label: const Text('Fixa'),
                        selected: tipo == 'fixa',
                        onSelected: (_) => setModal(() => tipo = 'fixa'),
                      ),
                      ChoiceChip(
                        label: const Text('Variável'),
                        selected: tipo == 'variavel',
                        onSelected: (_) => setModal(() => tipo = 'variavel'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text('Emoji',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['🛒', '🍔', '🚗', '🏠', '💡', '🎮', '💰', '📌']
                        .map((e) {
                      return ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 16)),
                        selected: emoji == e,
                        onSelected: (_) => setModal(() => emoji = e),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.block),
                          label: const Text('Desativar'),
                          onPressed: () async {
                            await _repo.setAtivo(c.id, false);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar'),
                          onPressed: () async {
                            final nome = nomeCtrl.text.trim();
                            if (nome.isEmpty) return;

                            await _repo.editarCategoria(
                              id: c.id,
                              nome: nome,
                              tipo: tipo,
                              emoji: emoji,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
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
