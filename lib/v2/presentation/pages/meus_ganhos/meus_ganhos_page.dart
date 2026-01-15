// ignore_for_file: use_build_context_synchronously, unnecessary_to_list_in_spreads, deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/ganhos_repository.dart';

class MeusGanhosPage extends StatefulWidget {
  const MeusGanhosPage({super.key});

  @override
  State<MeusGanhosPage> createState() => _MeusGanhosPageState();
}

class _MeusGanhosPageState extends State<MeusGanhosPage> {
  final _repo = InjectorV2.ganhosRepo;

  late int _ano;
  late int _mes;

  bool _loading = true;
  int _total = 0;
  List<GanhoRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ano = now.year;
    _mes = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final itens = await _repo.listarNoMes(_ano, _mes);
    final total = await _repo.totalNoMes(_ano, _mes, somenteRecebidos: false);
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _total = total;
      _loading = false;
    });
  }

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Meus Ganhos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novoGanho),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Total do mês'),
                        trailing: Text(
                          _money(_total),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_itens.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('Nenhum ganho neste mês.')),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _item(GanhoRow g) {
    final isRecebido = g.status == 'recebido';

    return Card(
      child: ListTile(
        title: Text(g.descricao),
        subtitle: Text('${g.dataIso} • ${g.status}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(g.valorCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(isRecebido ? '✅' : '🕒'),
          ],
        ),
        onTap: () async {
          // toggle rápido pendente <-> recebido
          final novo = isRecebido ? 'pendente' : 'recebido';
          await _repo.atualizarStatus(g.id, novo);
          await _load();
        },
        onLongPress: () async {
          await _repo.deletar(g.id);
          await _load();
        },
      ),
    );
  }

  Future<void> _novoGanho() async {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();

    DateTime data = DateTime.now();
    String status = 'pendente';

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
                    'Novo ganho',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: valorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('${data.day}/${data.month}/${data.year}'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: data,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setModal(() => data = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(
                              value: 'pendente',
                              child: Text('Pendente'),
                            ),
                            DropdownMenuItem(
                              value: 'recebido',
                              child: Text('Recebido'),
                            ),
                          ],
                          onChanged:
                              (v) => setModal(() => status = v ?? 'pendente'),
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                      onPressed: () async {
                        final desc = descCtrl.text.trim();
                        if (desc.isEmpty) return;

                        final txt = valorCtrl.text
                            .trim()
                            .replaceAll('.', '')
                            .replaceAll(',', '.');
                        final valor = double.tryParse(txt) ?? 0.0;
                        final cents = (valor * 100).round();

                        await _repo.inserir(
                          descricao: desc,
                          valorCentavos: cents,
                          data: data,
                          status: status,
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
}
