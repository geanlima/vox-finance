// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/investimentos_repository.dart';

class InvestimentosPage extends StatefulWidget {
  const InvestimentosPage({super.key});

  @override
  State<InvestimentosPage> createState() => _InvestimentosPageState();
}

class _InvestimentosPageState extends State<InvestimentosPage> {
  final InvestimentosRepository _repo = InjectorV2.investimentosRepo;

  bool _loading = true;
  bool _somenteAtivos = true;
  List<InvestimentoRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  Color _tipoColor(int tipo) {
    switch (tipo) {
      case 1:
        return Colors.blue; // renda fixa
      case 2:
        return Colors.purple; // renda variável
      case 3:
        return Colors.orange; // cripto
      default:
        return Colors.blueGrey; // outros
    }
  }

  String _tipoLabel(int tipo) {
    switch (tipo) {
      case 1:
        return 'Renda Fixa';
      case 2:
        return 'Renda Variável';
      case 3:
        return 'Cripto';
      default:
        return 'Outros';
    }
  }

  Color _statusColor(bool ativo) => ativo ? Colors.green : Colors.red;
  String _statusLabel(bool ativo) => ativo ? 'Ativo' : 'Inativo';

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final itens = await _repo.listar(); // se tiver filtro no repo, aplica aqui
    if (!mounted) return;

    setState(() {
      _itens = _somenteAtivos ? itens.where((e) => e.ativoFlag).toList() : itens;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _InvestimentoModal(
        titulo: 'Novo investimento',
        onSave: (r) async {
          await _repo.inserir(
            tipo: r.tipo,
            instituicao: r.instituicao,
            ativo: r.ativo,
            categoria: r.categoria,
            valorAplicado: r.valorAplicado,
            quantidade: r.quantidade,
            precoMedio: r.precoMedio,
            dataAporte: r.dataAporte,
            vencimento: r.vencimento,
            rentabilidadeTipo: r.rentabilidadeTipo,
            rentabilidadeValor: r.rentabilidadeValor,
            observacoes: r.observacoes,
            ativoFlag: r.ativoFlag,
          );
        },
      ),
    );

    if (ok == true) {
      await _load();
      _snack('Investimento salvo!');
    }
  }

  Future<void> _edit(InvestimentoRow item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _InvestimentoModal(
        titulo: 'Editar investimento',
        initial: _InvestimentoEditResult(
          tipo: item.tipo,
          instituicao: item.instituicao,
          ativo: item.ativo,
          categoria: item.categoria,
          valorAplicado: item.valorAplicado,
          quantidade: item.quantidade,
          precoMedio: item.precoMedio,
          dataAporte: item.dataAporte,
          vencimento: item.vencimento,
          rentabilidadeTipo: item.rentabilidadeTipo,
          rentabilidadeValor: item.rentabilidadeValor,
          observacoes: item.observacoes,
          ativoFlag: item.ativoFlag,
        ),
        onSave: (r) async {
          await _repo.atualizar(
            id: item.id,
            tipo: r.tipo,
            instituicao: r.instituicao,
            ativo: r.ativo,
            categoria: r.categoria,
            valorAplicado: r.valorAplicado,
            quantidade: r.quantidade,
            precoMedio: r.precoMedio,
            dataAporte: r.dataAporte,
            vencimento: r.vencimento,
            rentabilidadeTipo: r.rentabilidadeTipo,
            rentabilidadeValor: r.rentabilidadeValor,
            observacoes: r.observacoes,
            ativoFlag: r.ativoFlag,
          );
        },
      ),
    );

    if (ok == true) {
      await _load();
      _snack('Investimento atualizado!');
    }
  }

  Future<void> _remove(InvestimentoRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover'),
        content: Text('Remover "${item.ativo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.remover(item.id);
      await _load();
      _snack('Investimento removido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _somenteAtivos,
              onChanged: (v) async {
                setState(() => _somenteAtivos = v);
                await _load();
              },
              title: const Text('Somente ativos'),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _itens.isEmpty
                    ? const Center(child: Text('Nenhum investimento cadastrado'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: _itens.map((item) {
                          final tipoColor = _tipoColor(item.tipo);
                          final statusColor = _statusColor(item.ativoFlag);

                          final sub1 = (item.instituicao ?? '').trim().isNotEmpty
                              ? 'Instituição: ${item.instituicao}'
                              : null;

                          final sub2 = 'Aplicado: ${_brl(item.valorAplicado)}'
                              '  •  Qtd: ${_num(item.quantidade)}'
                              '  •  PM: ${_brl(item.precoMedio)}';

                          final sub3 = (item.vencimento ?? '').trim().isNotEmpty
                              ? 'Vencimento: ${item.vencimento}'
                              : null;

                          return Card(
                            child: ListTile(
                              isThreeLine: true,
                              title: Text(
                                item.ativo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_tipoLabel(item.tipo)),
                                  if (sub1 != null)
                                    Text(sub1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  Text(sub2,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  if (sub3 != null)
                                    Text(sub3,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                              trailing: SizedBox(
                                width: 120,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _ChipTag(
                                      text: _tipoLabel(item.tipo),
                                      color: tipoColor,
                                    ),
                                    const SizedBox(height: 6),
                                    _ChipTag(
                                      text: _statusLabel(item.ativoFlag),
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () => _edit(item),
                              onLongPress: () => _remove(item),
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

/// =========================
/// Modal (BottomSheet)
/// =========================

class _InvestimentoEditResult {
  final int tipo;
  final String? instituicao;
  final String ativo;
  final String? categoria;

  final double valorAplicado;
  final double quantidade;
  final double precoMedio;

  final String? dataAporte; // yyyy-mm-dd
  final String? vencimento;

  final int rentabilidadeTipo; // 0 nenhum / 1 % / 2 valor
  final double rentabilidadeValor;

  final String? observacoes;
  final bool ativoFlag;

  const _InvestimentoEditResult({
    required this.tipo,
    required this.instituicao,
    required this.ativo,
    required this.categoria,
    required this.valorAplicado,
    required this.quantidade,
    required this.precoMedio,
    required this.dataAporte,
    required this.vencimento,
    required this.rentabilidadeTipo,
    required this.rentabilidadeValor,
    required this.observacoes,
    required this.ativoFlag,
  });
}

class _ChipTag extends StatelessWidget {
  final String text;
  final Color color;

  const _ChipTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
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
}

class _InvestimentoModal extends StatefulWidget {
  final String titulo;
  final _InvestimentoEditResult? initial;
  final Future<void> Function(_InvestimentoEditResult r) onSave;

  const _InvestimentoModal({
    required this.titulo,
    required this.onSave,
    this.initial,
  });

  @override
  State<_InvestimentoModal> createState() => _InvestimentoModalState();
}

class _InvestimentoModalState extends State<_InvestimentoModal> {
  late final TextEditingController ativoCtrl;
  late final TextEditingController instCtrl;
  late final TextEditingController catCtrl;
  late final TextEditingController valorCtrl;
  late final TextEditingController qtdCtrl;
  late final TextEditingController pmCtrl;
  late final TextEditingController aporteCtrl;
  late final TextEditingController vencCtrl;
  late final TextEditingController rentCtrl;
  late final TextEditingController obsCtrl;

  int tipoLocal = 1;
  int rentTipoLocal = 0;
  bool ativoFlagLocal = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;

    tipoLocal = i?.tipo ?? 1;
    rentTipoLocal = i?.rentabilidadeTipo ?? 0;
    ativoFlagLocal = i?.ativoFlag ?? true;

    ativoCtrl = TextEditingController(text: i?.ativo ?? '');
    instCtrl = TextEditingController(text: i?.instituicao ?? '');
    catCtrl = TextEditingController(text: i?.categoria ?? '');
    valorCtrl = TextEditingController(text: _num(i?.valorAplicado ?? 0));
    qtdCtrl = TextEditingController(text: _num(i?.quantidade ?? 0));
    pmCtrl = TextEditingController(text: _num(i?.precoMedio ?? 0));
    aporteCtrl = TextEditingController(text: i?.dataAporte ?? '');
    vencCtrl = TextEditingController(text: i?.vencimento ?? '');
    rentCtrl = TextEditingController(text: _num(i?.rentabilidadeValor ?? 0));
    obsCtrl = TextEditingController(text: i?.observacoes ?? '');
  }

  @override
  void dispose() {
    ativoCtrl.dispose();
    instCtrl.dispose();
    catCtrl.dispose();
    valorCtrl.dispose();
    qtdCtrl.dispose();
    pmCtrl.dispose();
    aporteCtrl.dispose();
    vencCtrl.dispose();
    rentCtrl.dispose();
    obsCtrl.dispose();
    super.dispose();
  }

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double _parseDouble(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  String? _cleanStr(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;

    final a = ativoCtrl.text.trim();
    if (a.isEmpty) return;

    final r = _InvestimentoEditResult(
      tipo: tipoLocal,
      instituicao: _cleanStr(instCtrl.text),
      ativo: a,
      categoria: _cleanStr(catCtrl.text),
      valorAplicado: _parseDouble(valorCtrl.text),
      quantidade: _parseDouble(qtdCtrl.text),
      precoMedio: _parseDouble(pmCtrl.text),
      dataAporte: _cleanStr(aporteCtrl.text),
      vencimento: _cleanStr(vencCtrl.text),
      rentabilidadeTipo: rentTipoLocal,
      rentabilidadeValor: _parseDouble(rentCtrl.text),
      observacoes: _cleanStr(obsCtrl.text),
      ativoFlag: ativoFlagLocal,
    );

    setState(() => _saving = true);
    try {
      await widget.onSave(r);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final safe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.90,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        value: tipoLocal,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Renda Fixa')),
                          DropdownMenuItem(value: 2, child: Text('Renda Variável')),
                          DropdownMenuItem(value: 3, child: Text('Cripto')),
                          DropdownMenuItem(value: 4, child: Text('Outros')),
                        ],
                        onChanged: (v) => setState(() => tipoLocal = v ?? 1),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: ativoCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ativo (ex: PETR4, BTC, CDB)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: instCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Instituição',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: catCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor aplicado',
                          hintText: 'Ex: 1500,00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtdCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantidade',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: pmCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Preço médio',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: aporteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Data do aporte',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: vencCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Vencimento',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<int>(
                        value: rentTipoLocal,
                        decoration: const InputDecoration(
                          labelText: 'Rentabilidade',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Nenhuma')),
                          DropdownMenuItem(value: 1, child: Text('% (percentual)')),
                          DropdownMenuItem(value: 2, child: Text('R\$ (valor)')),
                        ],
                        onChanged: (v) => setState(() => rentTipoLocal = v ?? 0),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: rentCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rentabilidade (valor)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: obsCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: ativoFlagLocal,
                        onChanged: (v) => setState(() => ativoFlagLocal = v),
                        title: const Text('Ativo?'),
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safe),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
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
