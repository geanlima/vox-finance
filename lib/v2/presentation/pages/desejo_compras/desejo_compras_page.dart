// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/desejos_compras_repository.dart';

class _DesejoEditResult {
  final String produto;
  final String categoria;
  final double valor;
  final int prioridade;
  final String linkCompra;
  final bool comprado;

  const _DesejoEditResult({
    required this.produto,
    required this.categoria,
    required this.valor,
    required this.prioridade,
    required this.linkCompra,
    required this.comprado,
  });
}

/// Chip compacto (cabe no trailing do ListTile sem overflow)
class _ChipTag extends StatelessWidget {
  final String text;
  final Color color;

  const _ChipTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1.0,
        ),
      ),
    );
  }
}

class DesejosComprasPage extends StatefulWidget {
  const DesejosComprasPage({super.key});

  @override
  State<DesejosComprasPage> createState() => _DesejosComprasPageState();
}

class _DesejosComprasPageState extends State<DesejosComprasPage> {
  final DesejosComprasRepository _repo = InjectorV2.desejosComprasRepo;

  bool _loading = true;
  List<DesejoCompraRow> _itens = const [];

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

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  double _parseMoney(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  Color _prioridadeColor(int p) {
    switch (p) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Color _statusColor(bool comprado) => comprado ? Colors.green : Colors.red;

  Future<_DesejoEditResult?> _openEditor({
    required String titulo,
    String produto = '',
    String categoria = '',
    double valor = 0,
    int prioridade = 2,
    String linkCompra = '',
    bool comprado = false,
    bool allowComprado = true,
  }) async {
    return showDialog<_DesejoEditResult>(
      context: context,
      builder: (dialogContext) {
        final produtoCtrl = TextEditingController(text: produto);
        final categoriaCtrl = TextEditingController(text: categoria);
        final valorCtrl = TextEditingController(
          text: valor.toStringAsFixed(2).replaceAll('.', ','),
        );
        final linkCtrl = TextEditingController(text: linkCompra);

        int prio = prioridade;
        bool compradoLocal = comprado;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(titulo),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: produtoCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Produto'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoriaCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        hintText: 'Ex: 199,90',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: prio,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('1 - Essencial'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('2 - Importante'),
                        ),
                        DropdownMenuItem(value: 3, child: Text('3 - Desejo')),
                      ],
                      onChanged: (v) => setLocal(() => prio = v ?? 2),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link da compra',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (allowComprado)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: compradoLocal,
                        onChanged: (v) => setLocal(() => compradoLocal = v),
                        title: const Text('Comprei?'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final p = produtoCtrl.text.trim();
                    if (p.isEmpty) return;

                    Navigator.of(dialogContext).pop(
                      _DesejoEditResult(
                        produto: p,
                        categoria: categoriaCtrl.text.trim(),
                        valor: _parseMoney(valorCtrl.text),
                        prioridade: prio,
                        linkCompra: linkCtrl.text.trim(),
                        comprado: compradoLocal,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _add() async {
    final r = await _openEditor(titulo: 'Novo desejo');
    if (r == null) return;

    final id = await _repo.inserir(
      produto: r.produto,
      categoria: r.categoria.isEmpty ? null : r.categoria,
      valor: r.valor,
      prioridade: r.prioridade,
      linkCompra: r.linkCompra.isEmpty ? null : r.linkCompra,
    );

    if (r.comprado) {
      await _repo.setComprado(id, true);
    }

    await _load();
  }

  Future<void> _edit(DesejoCompraRow item) async {
    final r = await _openEditor(
      titulo: 'Editar desejo',
      produto: item.produto,
      categoria: item.categoria ?? '',
      valor: item.valor,
      prioridade: item.prioridade,
      linkCompra: item.linkCompra ?? '',
      comprado: item.comprado,
    );
    if (r == null) return;

    await _repo.atualizar(
      id: item.id,
      produto: r.produto,
      categoria: r.categoria.isEmpty ? null : r.categoria,
      valor: r.valor,
      prioridade: r.prioridade,
      linkCompra: r.linkCompra.isEmpty ? null : r.linkCompra,
    );
    await _repo.setComprado(item.id, r.comprado);

    await _load();
  }

  Future<void> _remove(DesejoCompraRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remover'),
            content: Text('Remover "${item.produto}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _repo.remover(item.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desejos de Compras'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
              ? const Center(child: Text('Nenhum desejo cadastrado'))
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _itens.length,
                itemBuilder: (context, i) {
                  final item = _itens[i];
                  final prioColor = _prioridadeColor(item.prioridade);
                  final stColor = _statusColor(item.comprado);

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      isThreeLine: true,
                      title: Text(
                        item.produto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((item.categoria ?? '').isNotEmpty)
                            Text(
                              'Categoria: ${item.categoria}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text('Valor: ${_brl(item.valor)}'),
                          if ((item.linkCompra ?? '').isNotEmpty)
                            Text(
                              'Link: ${item.linkCompra}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),

                      // ✅ sem overflow: Wrap vertical + chips compactos
                      trailing: SizedBox(
                        width: 120,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            direction: Axis.vertical,
                            spacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: _ChipTag(
                                  text: item.prioridadeLabel,
                                  color: prioColor,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: _ChipTag(
                                  text: item.statusLabel,
                                  color: stColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      onTap: () => _edit(item),
                      onLongPress: () => _remove(item),
                    ),
                  );
                },
              ),
    );
  }
}
