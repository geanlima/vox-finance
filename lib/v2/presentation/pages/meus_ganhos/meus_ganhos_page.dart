// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

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
    if (mounted) setState(() => _loading = true);

    final itens = await _repo.listarNoMes(_ano, _mes);
    final total = await _repo.totalNoMes(_ano, _mes, somenteRecebidos: false);

    if (!mounted) return;
    setState(() {
      _itens = itens;
      _total = total;
      _loading = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtDatePt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

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
                        subtitle: Text('$_mes/$_ano'),
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

  Widget _statusChip(bool recebido) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        recebido
            ? Colors.green.withOpacity(.15)
            : cs.tertiaryContainer.withOpacity(.65);
    final fg = recebido ? Colors.green : cs.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        recebido ? 'RECEBIDO' : 'PENDENTE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  Widget _item(GanhoRow g) {
    final isRecebido = g.status == 'recebido';
    final dataText = _fmtDatePt(g.dataIso);

    return Card(
      child: ListTile(
        title: Text(g.descricao),
        subtitle: Text('$dataText • ${isRecebido ? 'Recebido' : 'Pendente'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(g.valorCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            _statusChip(isRecebido),
          ],
        ),
        onTap: () async {
          final novo = isRecebido ? 'pendente' : 'recebido';
          await _repo.atualizarStatus(g.id, novo);
          await _load();
        },
        onLongPress: () async {
          final ok = await _confirmDelete(g.descricao);
          if (!ok) return;
          await _repo.deletar(g.id);
          await _load();
          _snack('Ganho removido.');
        },
      ),
    );
  }

  Future<bool> _confirmDelete(String desc) async {
    return (await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Excluir ganho?'),
                content: Text('Deseja excluir "$desc"?'),
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

  Future<void> _novoGanho() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GanhoModal(repo: _repo),
    );

    if (ok == true) {
      await _load();
      _snack('Ganho salvo!');
    }
  }
}

/// =============================
/// Modal separado (organização)
/// =============================
class _GanhoModal extends StatefulWidget {
  final GanhosRepository repo;

  const _GanhoModal({required this.repo});

  @override
  State<_GanhoModal> createState() => _GanhoModalState();
}

class _GanhoModalState extends State<_GanhoModal> {
  final descCtrl = TextEditingController();
  final valorCtrl = TextEditingController();

  DateTime data = DateTime.now();
  String status = 'pendente';

  bool _saving = false;

  @override
  void dispose() {
    descCtrl.dispose();
    valorCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _parseMoneyToCents(String input) {
    // aceita: "1200", "1.200", "1.200,50", "1200,50", "1200.50"
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

  String _dateLabel() =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year.toString().padLeft(4, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => data = d);
  }

  Future<void> _salvar() async {
    if (_saving) return;

    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      _snack('Informe a descrição.');
      return;
    }

    final cents = _parseMoneyToCents(valorCtrl.text);
    if (cents <= 0) {
      _snack('Informe um valor válido.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.inserir(
        descricao: desc,
        valorCentavos: cents,
        data: data,
        status: status,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom; // teclado
    final safeBottom =
        MediaQuery.of(context).padding.bottom; // barra do sistema

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Novo ganho',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
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
                              label: Text(_dateLabel()),
                              onPressed: _pickDate,
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
                                  (v) =>
                                      setState(() => status = v ?? 'pendente'),
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safeBottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _salvar,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save),
                    label: Text(_saving ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
