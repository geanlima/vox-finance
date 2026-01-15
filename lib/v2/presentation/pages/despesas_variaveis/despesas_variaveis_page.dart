// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_element, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/despesas_variaveis_repository.dart';

class DespesasVariaveisPage extends StatefulWidget {
  const DespesasVariaveisPage({super.key});

  @override
  State<DespesasVariaveisPage> createState() => _DespesasVariaveisPageState();
}

class _DespesasVariaveisPageState extends State<DespesasVariaveisPage> {
  final _repo = InjectorV2.despesasVariaveisRepo;

  late int _ano;
  late int _mes;

  bool _loading = true;
  int _total = 0;
  List<DespesaVariavelRow> _itens = const [];

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

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📉 Minhas Despesas Variáveis'),
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
                          child: Text('Nenhuma despesa variável neste mês.'),
                        ),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _item(DespesaVariavelRow d) {
    final cs = Theme.of(context).colorScheme;
    final isPago = d.status == 'pago';

    final catText =
        (d.catNome == null || d.catNome!.isEmpty)
            ? 'Sem categoria'
            : '${d.catEmoji ?? '🏷️'} ${d.catNome}';

    final fpText =
        (d.fpNome == null || d.fpNome!.isEmpty)
            ? 'Sem forma de pagamento'
            : d.fpNome!;

    final dataText = _fmtDatePt(d.dataGastoIso);

    return Card(
      child: ListTile(
        title: Text(d.descricao),
        subtitle: Text('$catText • $fpText • Data: $dataText'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(d.valorCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    isPago
                        ? Colors.green.withOpacity(.15)
                        : cs.errorContainer.withOpacity(.65),
              ),
              child: Text(
                isPago ? 'PAGO' : 'A PAGAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isPago ? Colors.green : cs.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        onTap: () async {
          await _repo.atualizarStatus(d.id, isPago ? 'a_pagar' : 'pago');
          await _load();
        },
        onLongPress: () async {
          await _repo.deletar(d.id);
          await _load();
        },
      ),
    );
  }

  Future<void> _novaDespesa() async {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();

    String status = 'a_pagar';
    DateTime data = DateTime.now();

    int? categoriaId;
    int? formaPagamentoId;

    // ✅ carrega listas reais, usando seus repos
    final categorias = await InjectorV2.categoriasRepo.listarCategorias(
      tipo: 'variavel',
      apenasAtivas: true,
    );

    final formas = await InjectorV2.formasPagamentoRepo.listarFormas(
      apenasAtivas: true,
    );

    if (!mounted) return;

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
                    'Nova despesa variável',
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

                  DropdownButtonFormField<int?>(
                    value: categoriaId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sem categoria'),
                      ),
                      ...categorias.map((c) {
                        final label = '${c.emoji ?? '🏷️'} ${c.nome}';
                        return DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(label),
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
                        child: TextField(
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
                      ),
                    ],
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
                    onChanged: (v) => setModal(() => status = v ?? 'a_pagar'),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int?>(
                    value: formaPagamentoId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sem forma de pagamento'),
                      ),
                      ...formas.map((f) {
                        return DropdownMenuItem<int?>(
                          value: f.id,
                          child: Text(f.nome),
                        );
                      }),
                    ],
                    onChanged: (v) => setModal(() => formaPagamentoId = v),
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
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

                        await _repo.inserir(
                          descricao: desc,
                          valorCentavos: cents,
                          dataGasto: data,
                          status: status,
                          anoRef: _ano,
                          mesRef: _mes,
                          categoriaId: categoriaId,
                          formaPagamentoId: formaPagamentoId,
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
