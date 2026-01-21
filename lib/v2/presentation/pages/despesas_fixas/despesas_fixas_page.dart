// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/despesas_fixas_repository.dart';

class DespesasFixasPage extends StatefulWidget {
  const DespesasFixasPage({super.key});

  @override
  State<DespesasFixasPage> createState() => _DespesasFixasPageState();
}

class _DespesasFixasPageState extends State<DespesasFixasPage> {
  final _repo = InjectorV2.despesasFixasRepo;

  late int _ano;
  late int _mes;

  bool _loading = true;
  int _total = 0;
  List<DespesaFixaRow> _itens = const [];

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
    final total = await _repo.totalNoMes(_ano, _mes);

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
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📌 Minhas Despesas Fixas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novaDespesa),
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
                        child: Center(
                          child: Text('Nenhuma despesa fixa neste mês.'),
                        ),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _statusChip(bool isPago) {
    final cs = Theme.of(context).colorScheme;

    final bg =
        isPago
            ? Colors.green.withOpacity(.15)
            : cs.errorContainer.withOpacity(.65);

    final fg = isPago ? Colors.green : cs.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        isPago ? 'PAGO' : 'A PAGAR',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  Widget _item(DespesaFixaRow d) {
    final isPago = d.status == 'pago';

    final catText =
        (d.catNome == null || d.catNome!.isEmpty)
            ? 'Sem categoria'
            : '${d.catEmoji ?? '📌'} ${d.catNome}';

    final fpText =
        (d.fpNome == null || d.fpNome!.isEmpty)
            ? 'Sem forma de pagamento'
            : d.fpNome!;

    final dataText = _fmtDatePt(d.dataPagamentoIso);

    return Card(
      child: ListTile(
        title: Text(d.descricao),
        subtitle: Text('$catText • $fpText • Pagamento: $dataText'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(d.valorCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            _statusChip(isPago),
          ],
        ),
        onTap: () async {
          if (isPago) {
            await _repo.marcarComoAPagar(d.id);
          } else {
            await _repo.marcarComoPago(d.id, DateTime.now());
          }
          await _load();
        },
        onLongPress: () async {
          final ok = await _confirmDelete(d.descricao);
          if (!ok) return;
          await _repo.deletar(d.id);
          await _load();
        },
      ),
    );
  }

  Future<bool> _confirmDelete(String desc) async {
    return (await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Excluir despesa?'),
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

  Future<void> _novaDespesa() async {
    // carrega combos direto do DB (como você fez)
    final categorias = await InjectorV2.db.db.rawQuery(
      "SELECT id, nome, COALESCE(emoji,'📌') AS emoji FROM categorias WHERE ativo = 1 ORDER BY nome",
    );

    final formas = await InjectorV2.db.db.rawQuery(
      "SELECT id, nome FROM formas_pagamento ORDER BY nome",
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _DespesaFixaModal(
            ano: _ano,
            mes: _mes,
            repo: _repo,
            categorias: categorias,
            formas: formas,
          ),
    );

    if (ok == true) {
      await _load();
      _snack('Despesa fixa salva!');
    }
  }
}

/// =============================
/// Modal separado (organização)
/// =============================
class _DespesaFixaModal extends StatefulWidget {
  final int ano;
  final int mes;
  final DespesasFixasRepository repo;
  final List<Map<String, Object?>> categorias;
  final List<Map<String, Object?>> formas;

  const _DespesaFixaModal({
    required this.ano,
    required this.mes,
    required this.repo,
    required this.categorias,
    required this.formas,
  });

  @override
  State<_DespesaFixaModal> createState() => _DespesaFixaModalState();
}

class _DespesaFixaModalState extends State<_DespesaFixaModal> {
  final descCtrl = TextEditingController();
  final valorCtrl = TextEditingController();
  final diaRenovacaoCtrl = TextEditingController();
  final reciboCtrl = TextEditingController();

  String status = 'a_pagar';
  DateTime? dataPagamento;

  int? categoriaId;
  int? formaPagamentoId;

  bool repetir1Mes = false;
  bool ajustarDataPagamento = false;

  bool _saving = false;

  @override
  void dispose() {
    descCtrl.dispose();
    valorCtrl.dispose();
    diaRenovacaoCtrl.dispose();
    reciboCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _parseMoneyToCents(String input) {
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

  String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _dateLabel() {
    final d = dataPagamento;
    if (d == null) return 'Selecionar data';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year.toString().padLeft(4, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: dataPagamento ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => dataPagamento = d);
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

    // se status pago e sem data -> hoje
    if (status == 'pago' && dataPagamento == null) {
      dataPagamento = DateTime.now();
    }

    final diaRenovacao = int.tryParse(diaRenovacaoCtrl.text.trim());
    if (diaRenovacao != null && (diaRenovacao < 1 || diaRenovacao > 31)) {
      _snack('Dia de renovação deve estar entre 1 e 31.');
      return;
    }

    final iso = (dataPagamento != null) ? _dateIso(dataPagamento!) : null;

    setState(() => _saving = true);
    try {
      await widget.repo.inserir(
        descricao: desc,
        valorCentavos: cents,
        anoRef: widget.ano,
        mesRef: widget.mes,
        status: status,
        dataPagamentoIso: iso,
        categoriaId: categoriaId,
        formaPagamentoId: formaPagamentoId,
        repetir1Mes: repetir1Mes ? 1 : 0,
        ajustarDataPagamento: ajustarDataPagamento ? 1 : 0,
        diaRenovacao: diaRenovacao,
        reciboPath:
            reciboCtrl.text.trim().isEmpty ? null : reciboCtrl.text.trim(),
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
          height: MediaQuery.of(context).size.height * 0.88,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nova despesa fixa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        textInputAction: TextInputAction.next,
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

                      DropdownButtonFormField<int>(
                        value: categoriaId,
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Sem categoria'),
                          ),
                          ...widget.categorias.map((c) {
                            final id = c['id'] as int;
                            final nome = (c['nome'] as String?) ?? '';
                            final emoji = (c['emoji'] as String?) ?? '📌';
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text('$emoji $nome'),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => categoriaId = v),
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        value: formaPagamentoId,
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Sem forma de pagamento'),
                          ),
                          ...widget.formas.map((f) {
                            final id = f['id'] as int;
                            final nome = (f['nome'] as String?) ?? '';
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(nome),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => formaPagamentoId = v),
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(
                            value: 'a_pagar',
                            child: Text('A pagar'),
                          ),
                          DropdownMenuItem(value: 'pago', child: Text('Pago')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            status = v ?? 'a_pagar';
                            if (status == 'pago' && dataPagamento == null) {
                              dataPagamento = DateTime.now();
                            }
                            if (status == 'a_pagar') dataPagamento = null;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          status == 'pago'
                              ? 'Data de pagamento: ${_dateLabel()}'
                              : 'Data de pagamento (opcional)',
                        ),
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Opção 1: Repetir 1 mês'),
                        value: repetir1Mes,
                        onChanged: (v) => setState(() => repetir1Mes = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Opção 2: Ajustar data pagamento'),
                        value: ajustarDataPagamento,
                        onChanged:
                            (v) => setState(() => ajustarDataPagamento = v),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: diaRenovacaoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia de renovação (1..31)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: reciboCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Recibo (path/url)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 90), // espaço pro botão fixo
                    ],
                  ),
                ),
              ),

              // ✅ Botão fixo (nunca fica atrás da barra)
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
