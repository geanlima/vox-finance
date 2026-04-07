// ignore_for_file: deprecated_member_use, control_flow_in_finally

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';

class SubcategoriasPersonalizadasPage extends StatefulWidget {
  const SubcategoriasPersonalizadasPage({super.key});

  static const routeName = '/subcategorias-personalizadas';

  @override
  State<SubcategoriasPersonalizadasPage> createState() =>
      _SubcategoriasPersonalizadasPageState();
}

class _SubcategoriasPersonalizadasPageState
    extends State<SubcategoriasPersonalizadasPage> {
  final _subRepo = SubcategoriaPersonalizadaRepository();
  final _catRepo = CategoriaPersonalizadaRepository();

  bool _carregando = false;
  List<CategoriaPersonalizada> _cats = const [];
  List<SubcategoriaPersonalizada> _subs = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final cats = await _catRepo.listarTodas();

      final subs = await _subRepo.listarTodasComCategoriaTipo();

      if (!mounted) return;
      setState(() {
        _cats = cats;
        _subs = subs;
      });
    } finally {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  CategoriaPersonalizada? _catById(int id) {
    try {
      return _cats.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _abrirForm({SubcategoriaPersonalizada? existente}) async {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');

    CategoriaPersonalizada? catSel =
        existente != null ? _catById(existente.idCategoriaPersonalizada) : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final tema = Theme.of(context);
        final bottom = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: BoxDecoration(
              color: tema.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        existente == null
                            ? 'Nova subcategoria'
                            : 'Editar subcategoria',
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CategoriaPersonalizada>(
                    value: catSel,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _cats
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.nome),
                              ),
                            )
                            .toList(),
                    validator:
                        (v) => v == null ? 'Selecione a categoria.' : null,
                    onChanged: (v) => catSel = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subcategoria',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Informe o nome da subcategoria.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final cat = catSel!;
                        final nome = nomeCtrl.text.trim();

                        await _subRepo.salvar(
                          SubcategoriaPersonalizada(
                            id: existente?.id,
                            idCategoriaPersonalizada: cat.id!,
                            nome: nome,
                          ),
                        );

                        if (!mounted) return;
                        Navigator.pop(context);
                        await _carregar();
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarExcluir(SubcategoriaPersonalizada s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir subcategoria'),
          content: Text('Deseja excluir "${s.nome}"?'),
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
        );
      },
    );

    if (ok != true) return;
    await _subRepo.deletar(s.id!);
    if (!mounted) return;
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final groups = <int, List<SubcategoriaPersonalizada>>{};
    for (final s in _subs) {
      groups.putIfAbsent(s.idCategoriaPersonalizada, () => []).add(s);
    }

    final catIds =
        groups.keys.toList()..sort((a, b) {
          final ca = _catById(a)?.nome ?? '';
          final cb = _catById(b)?.nome ?? '';
          return ca.compareTo(cb);
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Subcategorias')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _subs.isEmpty
              ? Center(
                child: Text(
                  'Nenhuma subcategoria cadastrada.',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: catIds.length,
                itemBuilder: (context, idx) {
                  final catId = catIds[idx];
                  final cat = _catById(catId);
                  final subs = groups[catId] ?? const [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(cat?.nome ?? 'Categoria id $catId'),
                      subtitle: Text('${subs.length} subcategoria(s)'),
                      children:
                          subs.map((s) {
                            return ListTile(
                              title: Text(s.nome),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _abrirForm(existente: s),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir',
                                    onPressed: () => _confirmarExcluir(s),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  );
                },
              ),
    );
  }
}
