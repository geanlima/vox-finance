// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/mural_sonhos_repository.dart';

class _MuralSonhoEditResult {
  final String titulo;
  final String imagemPath;
  final double valorObjetivo;
  final int anoPrazo;
  final int prazoTipo; // 1 curto / 2 medio / 3 longo
  final bool status; // bati?

  const _MuralSonhoEditResult({
    required this.titulo,
    required this.imagemPath,
    required this.valorObjetivo,
    required this.anoPrazo,
    required this.prazoTipo,
    required this.status,
  });
}

class MuralSonhosPage extends StatefulWidget {
  const MuralSonhosPage({super.key});

  @override
  State<MuralSonhosPage> createState() => _MuralSonhosPageState();
}

class _MuralSonhosPageState extends State<MuralSonhosPage> {
  final MuralSonhosRepository _repo = InjectorV2.muralSonhosRepo;

  bool _loading = true;
  List<MuralSonhoRow> _itens = const [];

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

  int _parseInt(String v, {int fallback = 0}) =>
      int.tryParse(v.trim()) ?? fallback;

  Color _prazoColor(int tipo) {
    switch (tipo) {
      case 1:
        return Colors.orange; // curto
      case 2:
        return Colors.blue; // medio
      default:
        return Colors.purple; // longo
    }
  }

  Color _statusColor(bool bati) => bati ? Colors.green : Colors.red;

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        ),
      ),
    );
  }

  Future<_MuralSonhoEditResult?> _openEditor({
    required String tituloDialog,
    String titulo = '',
    String imagemPath = '',
    double valorObjetivo = 0,
    int anoPrazo = 2026,
    int prazoTipo = 1,
    bool status = false,
    bool allowStatus = true,
  }) async {
    return showDialog<_MuralSonhoEditResult>(
      context: context,
      builder: (dialogContext) {
        final tituloCtrl = TextEditingController(text: titulo);
        final imagemCtrl = TextEditingController(text: imagemPath);
        final valorCtrl = TextEditingController(
          text: valorObjetivo.toStringAsFixed(2).replaceAll('.', ','),
        );
        final anoCtrl = TextEditingController(text: anoPrazo.toString());

        int prazoTipoLocal = prazoTipo;
        bool statusLocal = status;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(tituloDialog),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imagemCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Imagem (opcional)',
                        hintText: 'Cole um path/url (ex: /storage/... ou https://...)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Valor que preciso',
                        hintText: 'Ex: 25000,00',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: anoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prazo (ano)',
                        hintText: 'Ex: 2028',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: prazoTipoLocal,
                      decoration: const InputDecoration(labelText: 'Tipo de prazo'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Curto prazo')),
                        DropdownMenuItem(value: 2, child: Text('Médio prazo')),
                        DropdownMenuItem(value: 3, child: Text('Longo prazo')),
                      ],
                      onChanged: (v) => setLocal(() => prazoTipoLocal = v ?? 1),
                    ),
                    const SizedBox(height: 10),
                    if (allowStatus)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: statusLocal,
                        onChanged: (v) => setLocal(() => statusLocal = v),
                        title: const Text('Meta batida?'),
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
                    final t = tituloCtrl.text.trim();
                    if (t.isEmpty) return;

                    Navigator.of(dialogContext).pop(
                      _MuralSonhoEditResult(
                        titulo: t,
                        imagemPath: imagemCtrl.text.trim(),
                        valorObjetivo: _parseMoney(valorCtrl.text),
                        anoPrazo: _parseInt(anoCtrl.text, fallback: DateTime.now().year),
                        prazoTipo: prazoTipoLocal,
                        status: statusLocal,
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
    final nowYear = DateTime.now().year;
    final r = await _openEditor(
      tituloDialog: 'Novo sonho',
      anoPrazo: nowYear,
      prazoTipo: 1,
      status: false,
      allowStatus: true,
    );
    if (r == null) return;

    await _repo.inserir(
      titulo: r.titulo,
      imagemPath: r.imagemPath.isEmpty ? null : r.imagemPath,
      valorObjetivo: r.valorObjetivo,
      anoPrazo: r.anoPrazo,
      prazoTipo: r.prazoTipo,
      status: r.status,
    );

    await _load();
  }

  Future<void> _edit(MuralSonhoRow item) async {
    final r = await _openEditor(
      tituloDialog: 'Editar sonho',
      titulo: item.titulo,
      imagemPath: item.imagemPath ?? '',
      valorObjetivo: item.valorObjetivo,
      anoPrazo: item.anoPrazo,
      prazoTipo: item.prazoTipo,
      status: item.status,
      allowStatus: true,
    );
    if (r == null) return;

    await _repo.atualizar(
      id: item.id,
      titulo: r.titulo,
      imagemPath: r.imagemPath.isEmpty ? null : r.imagemPath,
      valorObjetivo: r.valorObjetivo,
      anoPrazo: r.anoPrazo,
      prazoTipo: r.prazoTipo,
    );

    if (r.status != item.status) {
      await _repo.setStatus(item.id, r.status);
    }

    await _load();
  }

  Future<void> _toggleStatus(MuralSonhoRow item) async {
    await _repo.setStatus(item.id, !item.status);
    await _load();
  }

  Future<void> _remove(MuralSonhoRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover'),
        content: Text('Remover "${item.titulo}"?'),
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

  Widget _card(MuralSonhoRow item) {
    final prazoColor = _prazoColor(item.prazoTipo);
    final stColor = _statusColor(item.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _edit(item),
        onLongPress: () => _remove(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // topo: título + status toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: item.status ? 'Marcar como não bati' : 'Marcar como bati',
                    onPressed: () => _toggleStatus(item),
                    icon: Icon(
                      item.status ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: stColor,
                    ),
                  ),
                ],
              ),

              // imagem (se tiver path/url, mostramos um “placeholder” por enquanto)
              if ((item.imagemPath ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.04),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Imagem vinculada',
                    style: TextStyle(color: Colors.black.withOpacity(0.55)),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Text('Valor que preciso: ${_brl(item.valorObjetivo)}'),
              const SizedBox(height: 4),
              Text('Prazo para bater essa meta: ${item.anoPrazo}'),

              const SizedBox(height: 10),

              // chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(item.prazoLabel, prazoColor),
                  _chip(item.statusLabel, stColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mural dos Sonhos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty
              ? const Center(child: Text('Nenhum sonho cadastrado'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // fica bonito no celular (2 colunas)
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _itens.length,
                  itemBuilder: (_, i) => _card(_itens[i]),
                ),
    );
  }
}
