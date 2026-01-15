// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/categorias_repository.dart';

class GastosPorCategoriaPage extends StatefulWidget {
  const GastosPorCategoriaPage({super.key});

  @override
  State<GastosPorCategoriaPage> createState() => _GastosPorCategoriaPageState();
}

class _GastosPorCategoriaPageState extends State<GastosPorCategoriaPage> {
  final _repo = InjectorV2.categoriasRepo;

  int _ano = 2026;
  int _mes = 1;
  bool _loading = true;

  List<CategoriaResumoMes> _resumo = const [];

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

    final resumo = await _repo.resumoPorCategoriaNoMes(ano: _ano, mes: _mes);

    if (!mounted) return;
    setState(() {
      _resumo = resumo;
      _loading = false;
    });
  }

  // ---------- helpers ----------
  String _money(int cents) {
    final v = cents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _mesNome(int m) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return meses[m - 1];
  }

  List<int> get _anosDisponiveis => [2026, 2027, 2028];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos por Categorias'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _pickerBox(
                          context,
                          title: 'Ano',
                          value: '$_ano',
                          onTap: () async {
                            final a = await _selectAno(context, _ano);
                            if (a == null) return;
                            setState(() => _ano = a);
                            await _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pickerBox(
                          context,
                          title: 'Mês',
                          value: _mesNome(_mes),
                          onTap: () async {
                            final m = await _selectMes(context, _mes);
                            if (m == null) return;
                            setState(() => _mes = m);
                            await _load();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Limites e gastos por categoria • ${_mesNome(_mes)} $_ano',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_resumo.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nenhuma categoria encontrada.',
                        style: TextStyle(color: cs.outline),
                      ),
                    )
                  else
                    ..._resumo.map((r) => _categoriaResumoCard(context, r)),

                  const SizedBox(height: 10),
                  Text(
                    'Dica: toque no card para editar o limite do mês.',
                    style: TextStyle(color: cs.outline),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pickerBox(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surfaceContainerHighest.withOpacity(.45),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }

  Widget _categoriaResumoCard(BuildContext context, CategoriaResumoMes r) {
    final cs = Theme.of(context).colorScheme;

    final saldo = r.saldo;
    final saldoColor =
        saldo > 0 ? Colors.green : (saldo < 0 ? cs.error : cs.onSurfaceVariant);

    final limite = r.limite;
    final gasto = r.gasto;
    final progress = limite <= 0 ? 0.0 : (gasto / limite).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await _editarLimiteModal(context, r);
        await _load();
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.emoji ?? '📌', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.nome,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: cs.surfaceContainerHighest.withOpacity(.7),
                    ),
                    child: Text(
                      r.tipo.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _kv('Limite', _money(r.limite))),
                  const SizedBox(width: 12),
                  Expanded(child: _kv('Gasto', _money(r.gasto))),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: cs.surfaceContainerHighest.withOpacity(.7),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.surfaceContainerHighest.withOpacity(.7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      _money(saldo),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: saldoColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );

  // ---------- pickers ----------
  Future<int?> _selectAno(BuildContext context, int atual) async {
    final anos = _anosDisponiveis;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('Selecionar ano',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          ...anos.map(
            (a) => ListTile(
              title: Text('$a'),
              trailing: a == atual ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, a),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _selectMes(BuildContext context, int atual) async {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('Selecionar mês',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          for (int m = 1; m <= 12; m++)
            ListTile(
              title: Text(_mesNome(m)),
              trailing: m == atual ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
  }

  // ---------- editar limite ----------
  Future<void> _editarLimiteModal(
    BuildContext context,
    CategoriaResumoMes r,
  ) async {
    final ctrl = TextEditingController(
      text: (r.limite / 100.0).toStringAsFixed(2).replaceAll('.', ','),
    );

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.emoji ?? '📌'} ${r.nome}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Definir limite para ${_mesNome(_mes)} $_ano',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limite (R\$)',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar limite'),
                  onPressed: () async {
                    final txt = ctrl.text
                        .trim()
                        .replaceAll('.', '')
                        .replaceAll(',', '.');
                    final value = double.tryParse(txt) ?? 0.0;
                    final cents = (value * 100).round();

                    await _repo.salvarLimiteMes(
                      categoriaId: r.categoriaId,
                      ano: _ano,
                      mes: _mes,
                      limiteCentavos: cents,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
