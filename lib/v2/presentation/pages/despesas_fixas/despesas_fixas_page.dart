// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads, unused_local_variable, unused_element

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
    setState(() => _loading = true);

    final itens = await _repo.listarNoMes(_ano, _mes);
    final total = await _repo.totalNoMes(_ano, _mes);

    if (!mounted) return;
    setState(() {
      _itens = itens;
      _total = total;
      _loading = false;
    });
  }

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtDatePt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    // iso: yyyy-MM-dd
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  int _parseMoneyToCents(String input) {
    // aceita: "1200", "1.200", "1.200,50", "1200,50", "1200.50"
    var s = input.trim();
    if (s.isEmpty) return 0;

    // remove espaços e "R$"
    s = s.replaceAll('R\$', '').replaceAll(' ', '');

    // se tiver vírgula, assume que vírgula é decimal e ponto é milhar
    if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s) ?? 0.0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          // toggle rápido
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

    // ✅ carrega combos direto do DB (sem depender de outro repo)
    final categorias = await InjectorV2.db.db.rawQuery(
      "SELECT id, nome, COALESCE(emoji,'📌') AS emoji FROM categorias WHERE ativo = 1 ORDER BY nome",
    );

    final formas = await InjectorV2.db.db.rawQuery(
      "SELECT id, nome FROM formas_pagamento ORDER BY nome",
    );

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        String dataLabel() {
          if (dataPagamento == null) return 'Selecionar data';
          return '${dataPagamento!.day}/${dataPagamento!.month}/${dataPagamento!.year}';
        }

        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

                    // ✅ Categoria
                    DropdownButtonFormField<int>(
                      value: categoriaId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Sem categoria'),
                        ),
                        ...categorias.map((c) {
                          final id = c['id'] as int;
                          final nome = (c['nome'] as String?) ?? '';
                          final emoji = (c['emoji'] as String?) ?? '📌';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('$emoji $nome'),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => categoriaId = v),
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Forma pagamento
                    DropdownButtonFormField<int>(
                      value: formaPagamentoId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Sem forma de pagamento'),
                        ),
                        ...formas.map((f) {
                          final id = f['id'] as int;
                          final nome = (f['nome'] as String?) ?? '';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(nome),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => formaPagamentoId = v),
                      decoration: const InputDecoration(
                        labelText: 'Forma de pagamento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Status
                    DropdownButtonFormField<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'a_pagar',
                          child: Text('A pagar'),
                        ),
                        DropdownMenuItem(value: 'pago', child: Text('Pago')),
                      ],
                      onChanged:
                          (v) => setModal(() {
                            status = v ?? 'a_pagar';
                            // se virou pago e não tem data, sugere hoje
                            if (status == 'pago' && dataPagamento == null) {
                              dataPagamento = DateTime.now();
                            }
                            // se virou a_pagar, limpa data
                            if (status == 'a_pagar') dataPagamento = null;
                          }),
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Data pagamento (só faz sentido quando pago)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        status == 'pago'
                            ? 'Data de pagamento: ${dataLabel()}'
                            : 'Data de pagamento (opcional)',
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dataPagamento ?? now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setModal(() => dataPagamento = d);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ✅ Opção 1 / Opção 2
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Opção 1: Repetir 1 mês'),
                      value: repetir1Mes,
                      onChanged: (v) => setModal(() => repetir1Mes = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Opção 2: Ajustar data pagamento'),
                      value: ajustarDataPagamento,
                      onChanged:
                          (v) => setModal(() => ajustarDataPagamento = v),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Dia renovação
                    TextField(
                      controller: diaRenovacaoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia de renovação (1..31)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Recibo (por enquanto texto/path)
                    TextField(
                      controller: reciboCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Recibo (path/url)',
                        border: OutlineInputBorder(),
                      ),
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

                          final cents = _parseMoneyToCents(valorCtrl.text);
                          if (cents <= 0) return;

                          String? iso;
                          if (dataPagamento != null) {
                            iso =
                                '${dataPagamento!.year.toString().padLeft(4, '0')}-'
                                '${dataPagamento!.month.toString().padLeft(2, '0')}-'
                                '${dataPagamento!.day.toString().padLeft(2, '0')}';
                          }

                          final diaRenovacao = int.tryParse(
                            diaRenovacaoCtrl.text.trim(),
                          );

                          await _repo.inserir(
                            descricao: desc,
                            valorCentavos: cents,
                            anoRef: _ano,
                            mesRef: _mes,
                            status: status,
                            dataPagamentoIso: iso,
                            categoriaId: categoriaId,
                            formaPagamentoId: formaPagamentoId,
                            repetir1Mes: repetir1Mes ? 1 : 0,
                            ajustarDataPagamento: ajustarDataPagamento ? 1 : 0,
                            diaRenovacao: diaRenovacao,
                            reciboPath:
                                reciboCtrl.text.trim().isEmpty
                                    ? null
                                    : reciboCtrl.text.trim(),
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
