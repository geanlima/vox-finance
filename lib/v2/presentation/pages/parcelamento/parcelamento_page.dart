// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/parcelamentos_repository.dart';

class ParcelamentosPage extends StatefulWidget {
  const ParcelamentosPage({super.key});

  @override
  State<ParcelamentosPage> createState() => _ParcelamentosPageState();
}

class _ParcelamentosPageState extends State<ParcelamentosPage> {
  final _repo = InjectorV2.parcelamentosRepo;

  late int _ano;
  late int _mes;

  bool _loading = true;
  int _total = 0;
  List<ParcelaRow> _itens = const [];

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

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💳 Controle de Parcelamentos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novaParcela),
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
                          child: Text('Nenhuma parcela neste mês.'),
                        ),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _item(ParcelaRow p) {
    final cs = Theme.of(context).colorScheme;
    final isPago = p.status == 'pago';

    final catText =
        (p.catNome == null || p.catNome!.isEmpty)
            ? 'Sem categoria'
            : '${p.catEmoji ?? '🏷️'} ${p.catNome}';

    final fpText =
        (p.fpNome == null || p.fpNome!.isEmpty) ? 'Sem forma' : p.fpNome!;
    final dataCompra = _fmtDatePt(p.dataCompraIso);
    final dataPg = _fmtDatePt(p.dataPagamentoIso);

    return Card(
      child: ListTile(
        title: Text('${p.descricao}  •  ${p.numeroParcela}/${p.totalParcelas}'),
        subtitle: Text(
          '$catText • $fpText • Compra: $dataCompra • Pgto: $dataPg',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(p.valorParcelaCentavos),
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
          if (isPago) {
            await _repo.atualizarStatus(
              p.id,
              'a_pagar',
              dataPagamentoIso: null,
            );
          } else {
            await _repo.atualizarStatus(
              p.id,
              'pago',
              dataPagamentoIso: _toIso(DateTime.now()),
            );
          }
          await _load();
        },
        onLongPress: () async {
          await _repo.deletar(p.id);
          await _load();
        },
      ),
    );
  }

  Future<void> _novaParcela() async {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final numCtrl = TextEditingController(text: '1');
    final totalCtrl = TextEditingController(text: '12');

    DateTime dataCompra = DateTime.now();
    String status = 'a_pagar';

    int? categoriaId;
    int? formaPagamentoId;
    bool duplicar = false;

    // ✅ usa seus métodos reais
    final categorias = await InjectorV2.categoriasRepo.listarCategorias(
      apenasAtivas: true,
    );
    final formas = await InjectorV2.formasPagamentoRepo.listarFormas(
      apenasAtivas: true,
    );

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
                    'Nova parcela',
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

                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      'Data da compra: ${dataCompra.day}/${dataCompra.month}/${dataCompra.year}',
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: dataCompra,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModal(() => dataCompra = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: numCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'N Parcela',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: totalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total parcelas',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: valorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor da parcela (R\$)',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
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
                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Duplicar parcela'),
                    subtitle: const Text('Marca a opção do seu print (1/0).'),
                    value: duplicar,
                    onChanged: (v) => setModal(() => duplicar = v),
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

                        final num = int.tryParse(numCtrl.text.trim()) ?? 1;
                        final tot = int.tryParse(totalCtrl.text.trim()) ?? 1;

                        final dataCompraIso = _toIso(dataCompra);
                        final dataPagamentoIso =
                            (status == 'pago') ? _toIso(DateTime.now()) : null;

                        await _repo.inserir(
                          dataCompraIso: dataCompraIso,
                          descricao: desc,
                          valorParcelaCentavos: cents,
                          status: status,
                          anoRef: _ano,
                          mesRef: _mes,
                          numeroParcela: num,
                          totalParcelas: tot,
                          categoriaId: categoriaId,
                          formaPagamentoId: formaPagamentoId,
                          duplicarParcela: duplicar,
                          dataPagamentoIso: dataPagamentoIso,
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
