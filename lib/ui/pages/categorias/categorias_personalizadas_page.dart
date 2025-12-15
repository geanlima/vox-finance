// lib/ui/pages/categorias/categorias_personalizadas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart'; // TipoMovimento

class CategoriasPersonalizadasPage extends StatefulWidget {
  static const routeName = '/categorias-personalizadas';

  const CategoriasPersonalizadasPage({super.key});

  @override
  State<CategoriasPersonalizadasPage> createState() =>
      _CategoriasPersonalizadasPageState();
}

class _CategoriasPersonalizadasPageState
    extends State<CategoriasPersonalizadasPage> {
  final _repo = CategoriaPersonalizadaRepository();
  bool _carregando = false;
  List<CategoriaPersonalizada> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await _repo.listarTodas();
    setState(() {
      _categorias = lista;
      _carregando = false;
    });
  }

  Future<void> _abrirForm({CategoriaPersonalizada? existente}) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    TipoMovimento tipo = existente?.tipoMovimento ?? TipoMovimento.despesa;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (ctx2, scrollController) {
            final viewInsets = MediaQuery.of(ctx2).viewInsets;
            final theme = Theme.of(ctx2);

            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  viewInsets.bottom + 16,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      existente == null ? 'Nova categoria' : 'Editar categoria',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome da categoria',
                        hintText: 'Ex.: Mercado, Farmácia, Salário...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tipo de movimento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Despesa'),
                          selected: tipo == TipoMovimento.despesa,
                          onSelected: (sel) {
                            if (!sel) return;
                            (ctx2 as Element).markNeedsBuild();
                            tipo = TipoMovimento.despesa;
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Receita'),
                          selected: tipo == TipoMovimento.receita,
                          onSelected: (sel) {
                            if (!sel) return;
                            (ctx2 as Element).markNeedsBuild();
                            tipo = TipoMovimento.receita;
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Ambos'),
                          selected: tipo == TipoMovimento.ambos,
                          onSelected: (sel) {
                            if (!sel) return;
                            (ctx2 as Element).markNeedsBuild();
                            tipo = TipoMovimento.ambos;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx2, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final nome = nomeCtrl.text.trim();
                            if (nome.isEmpty) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(
                                  content: Text('Informe o nome da categoria.'),
                                ),
                              );
                              return;
                            }

                            final cat =
                                existente == null
                                    ? CategoriaPersonalizada(
                                      nome: nome,
                                      tipoMovimento: tipo,
                                    )
                                    : existente.copyWith(
                                      nome: nome,
                                      tipoMovimento: tipo,
                                    );

                            await _repo.salvar(cat);
                            if (!ctx2.mounted) return;
                            Navigator.pop(ctx2, true);
                          },
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      await _carregar();
    }
  }

  Future<void> _confirmarExcluir(CategoriaPersonalizada cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir categoria'),
            content: Text(
              'Deseja realmente excluir a categoria "${cat.nome}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );

    if (ok == true && cat.id != null) {
      await _repo.deletar(cat.id!);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas categorias')),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _categorias.isEmpty
              ? const Center(
                child: Text(
                  'Nenhuma categoria personalizada.\n'
                  'Use o botão + para adicionar.',
                  textAlign: TextAlign.center,
                ),
              )
              : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categorias.length,
                  itemBuilder: (ctx, index) {
                    final cat = _categorias[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Slidable(
                        key: ValueKey(cat.id ?? cat.nome),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.35,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _abrirForm(existente: cat),
                              icon: Icons.edit,
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                            SlidableAction(
                              onPressed: (_) => _confirmarExcluir(cat),
                              icon: Icons.delete,
                              backgroundColor: colors.error,
                              foregroundColor: Colors.white,
                            ),
                          ],
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                cat.nome.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(cat.nome),
                            subtitle: Text(
                              cat.tipoMovimento == TipoMovimento.despesa
                                  ? 'Despesa'
                                  : cat.tipoMovimento == TipoMovimento.receita
                                  ? 'Receita'
                                  : 'Despesa e receita',
                            ),
                            onTap: () => _abrirForm(existente: cat),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
