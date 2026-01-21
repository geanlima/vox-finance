// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/dividas_repository.dart';

class MinhasDividasPage extends StatefulWidget {
  const MinhasDividasPage({super.key});

  @override
  State<MinhasDividasPage> createState() => _MinhasDividasPageState();
}

class _MinhasDividasPageState extends State<MinhasDividasPage> {
  final _repo = InjectorV2.dividasRepo;

  late int _ano;
  late int _mes;

  bool _loading = true;
  int _totalPendente = 0;
  List<DividaRow> _itens = const [];

  // labels para UI sem JOIN
  final Map<int, String> _catLabelById = {};
  final Map<int, String> _fpLabelById = {};

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

    final catsF = InjectorV2.categoriasRepo.listarCategorias(
      tipo: 'variavel', // se criar tipo "divida", trocar aqui
      apenasAtivas: true,
    );
    final fpsF = InjectorV2.formasPagamentoRepo.listarFormas(
      apenasAtivas: true,
    );

    final itensF = _repo.listarNoMes(_ano, _mes);
    final totalF = _repo.totalPendenteNoMes(_ano, _mes);

    final cats = await catsF;
    final fps = await fpsF;
    final itens = await itensF;
    final total = await totalF;

    if (!mounted) return;

    _catLabelById
      ..clear()
      ..addEntries(
        cats.map((c) => MapEntry(c.id, '${c.emoji ?? '🏷️'} ${c.nome}')),
      );

    _fpLabelById
      ..clear()
      ..addEntries(fps.map((f) => MapEntry(f.id, f.nome)));

    setState(() {
      _itens = itens;
      _totalPendente = total;
      _loading = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _prevMes() {
    setState(() {
      if (_mes == 1) {
        _mes = 12;
        _ano -= 1;
      } else {
        _mes -= 1;
      }
    });
    _load();
  }

  void _nextMes() {
    setState(() {
      if (_mes == 12) {
        _mes = 1;
        _ano += 1;
      } else {
        _mes += 1;
      }
    });
    _load();
  }

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtDatePt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
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

  DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = ((d.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final safeDay = d.day > lastDay ? lastDay : d.day;
    return DateTime(y, m, safeDay);
  }

  @override
  Widget build(BuildContext context) {
    final mesAno = '$_mes/$_ano';

    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 Minhas Dívidas'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMes),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                mesAno,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMes,
          ),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novaDivida),
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
                        title: const Text('Total pendente (mês)'),
                        subtitle: Text(mesAno),
                        trailing: Text(
                          _money(_totalPendente),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_itens.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('Nenhuma dívida neste mês.')),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _statusChip(bool quitado) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        quitado
            ? Colors.green.withOpacity(.15)
            : cs.errorContainer.withOpacity(.65);
    final fg = quitado ? Colors.green : cs.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        quitado ? 'QUITADA' : 'ATIVA',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  Widget _item(DividaRow d) {
    final catText =
        d.categoriaId == null
            ? 'Sem categoria'
            : (_catLabelById[d.categoriaId!] ?? '🏷️ Categoria');

    final fpText =
        d.formaPagamentoId == null
            ? 'Sem forma de pagamento'
            : (_fpLabelById[d.formaPagamentoId!] ?? 'Forma de pagamento');

    final dataDivText = _fmtDatePt(d.dataDividaIso);

    return Card(
      child: ListTile(
        title: Text('${d.credor} • ${d.descricao}'),
        subtitle: Text('$catText • $fpText • Data: $dataDivText'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(d.valorParcelaCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Pendentes: ${d.parcelasPendentes}/${d.parcelasTotal}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            _statusChip(d.isQuitado),
          ],
        ),
        onTap: () async {
          await _repo.pagarUmaParcela(d.id);
          await _load();
        },
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder:
                (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text('Marcar como quitada'),
                        onTap: () => Navigator.pop(ctx, 'quitado'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.pause_circle_outline),
                        title: const Text('Marcar como ativa'),
                        onTap: () => Navigator.pop(ctx, 'ativo'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.undo),
                        title: const Text('Desfazer 1 parcela paga'),
                        onTap: () => Navigator.pop(ctx, 'undo'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Excluir'),
                        onTap: () => Navigator.pop(ctx, 'delete'),
                      ),
                    ],
                  ),
                ),
          );

          if (action == null) return;

          if (action == 'delete') {
            final ok = await _confirmDelete('${d.credor} • ${d.descricao}');
            if (!ok) return;
            await _repo.deletar(d.id);
            await _load();
            _snack('Dívida removida.');
            return;
          }

          if (action == 'undo') {
            await _repo.desfazerPagamentoUmaParcela(d.id);
            await _load();
            return;
          }

          if (action == 'quitado' || action == 'ativo') {
            await _repo.atualizarStatus(d.id, action);
            await _load();
          }
        },
      ),
    );
  }

  Future<bool> _confirmDelete(String desc) async {
    return (await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Excluir dívida?'),
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

  Future<void> _novaDivida() async {
    final categorias = await InjectorV2.categoriasRepo.listarCategorias(
      tipo: 'variavel',
      apenasAtivas: true,
    );
    final formas = await InjectorV2.formasPagamentoRepo.listarFormas(
      apenasAtivas: true,
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _DividaModal(
            repo: _repo,
            ano: _ano,
            mes: _mes,
            categorias: categorias,
            formas: formas,
            parseMoneyToCents: _parseMoneyToCents,
            addMonths: _addMonths,
          ),
    );

    if (ok == true) {
      await _load();
      _snack('Dívida salva!');
    }
  }
}

/// =============================
/// Modal separado
/// =============================
class _DividaModal extends StatefulWidget {
  final DividasRepository repo;
  final int ano;
  final int mes;
  final List<dynamic> categorias;
  final List<dynamic> formas;

  final int Function(String) parseMoneyToCents;
  final DateTime Function(DateTime, int) addMonths;

  const _DividaModal({
    required this.repo,
    required this.ano,
    required this.mes,
    required this.categorias,
    required this.formas,
    required this.parseMoneyToCents,
    required this.addMonths,
  });

  @override
  State<_DividaModal> createState() => _DividaModalState();
}

class _DividaModalState extends State<_DividaModal> {
  final credorCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final valorParcelaCtrl = TextEditingController();
  final parcelasTotalCtrl = TextEditingController(text: '1');

  String status = 'ativo';
  bool repetir1Mes = false;
  int? categoriaId;
  int? formaPagamentoId;

  late DateTime dataDivida;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dataDivida = DateTime(
      widget.ano,
      widget.mes,
      (now.year == widget.ano && now.month == widget.mes) ? now.day : 1,
    );
  }

  @override
  void dispose() {
    credorCtrl.dispose();
    descCtrl.dispose();
    valorParcelaCtrl.dispose();
    parcelasTotalCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year.toString().padLeft(4, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: dataDivida,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => dataDivida = d);
  }

  Future<void> _salvar() async {
    if (_saving) return;

    final credor = credorCtrl.text.trim();
    final desc = descCtrl.text.trim();
    if (credor.isEmpty || desc.isEmpty) return;

    final valorParcela = widget.parseMoneyToCents(valorParcelaCtrl.text);
    if (valorParcela <= 0) return;

    final parcelasTotal = int.tryParse(parcelasTotalCtrl.text.trim()) ?? 1;
    final pendentes = (status == 'quitado') ? 0 : parcelasTotal;

    setState(() => _saving = true);
    try {
      await widget.repo.inserir(
        credor: credor,
        descricao: desc,
        valorParcelaCentavos: valorParcela,
        parcelasTotal: parcelasTotal,
        parcelasPendentes: pendentes,
        dataDivida: dataDivida,
        status: status,
        categoriaId: categoriaId,
        formaPagamentoId: formaPagamentoId,
        repetir1Mes: repetir1Mes,
      );

      if (repetir1Mes) {
        final nextDate = widget.addMonths(dataDivida, 1);
        await widget.repo.inserir(
          credor: credor,
          descricao: desc,
          valorParcelaCentavos: valorParcela,
          parcelasTotal: parcelasTotal,
          parcelasPendentes: (status == 'quitado') ? 0 : parcelasTotal,
          dataDivida: nextDate,
          status: status,
          categoriaId: categoriaId,
          formaPagamentoId: formaPagamentoId,
          repetir1Mes: false,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
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
                      const Text(
                        'Nova dívida',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: credorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Credor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descrição da dívida',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int?>(
                        value: categoriaId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sem categoria'),
                          ),
                          ...widget.categorias.map((c) {
                            return DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text('${c.emoji ?? '🏷️'} ${c.nome}'),
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

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(_dateLabel(dataDivida)),
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: valorParcelaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Valor parcela (R\$)',
                                border: OutlineInputBorder(),
                                prefixText: 'R\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: parcelasTotalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Parcelas total',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'ativo',
                                  child: Text('Ativa'),
                                ),
                                DropdownMenuItem(
                                  value: 'quitado',
                                  child: Text('Quitada'),
                                ),
                                DropdownMenuItem(
                                  value: 'cancelado',
                                  child: Text('Cancelada'),
                                ),
                              ],
                              onChanged:
                                  (v) => setState(() => status = v ?? 'ativo'),
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int?>(
                        value: formaPagamentoId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sem forma de pagamento'),
                          ),
                          ...widget.formas.map((f) {
                            return DropdownMenuItem<int?>(
                              value: f.id,
                              child: Text(f.nome),
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

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: repetir1Mes,
                        onChanged: (v) => setState(() => repetir1Mes = v),
                        title: const Text('Repetir 1 mês'),
                        subtitle: const Text(
                          'Replica esta dívida para o próximo mês',
                        ),
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
