// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/balanco_repository.dart';

class BalancoPage extends StatefulWidget {
  const BalancoPage({super.key});

  @override
  State<BalancoPage> createState() => _BalancoPageState();
}

class _BalancoPageState extends State<BalancoPage> {
  final _repo = InjectorV2.balancoRepo;

  int _ano = 2026;
  bool _loading = true;

  List<BalancoMesRow> _rows = const [];
  BalancoAnoResumo? _resumo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final resumo = await _repo.resumoAno(_ano);
    final r = await _repo.listarAno(_ano);

    if (!mounted) return;
    setState(() {
      _resumo = resumo;
      _rows = r;
      _loading = false;
    });
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

  String _money(int cents) {
    final v = cents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color? _saldoColor(ColorScheme cs, int cents) {
    if (cents > 0) return Colors.green;
    if (cents < 0) return cs.error;
    return cs.onSurfaceVariant;
  }

  Widget _chipAno(int a) {
    return ChoiceChip(
      label: Text('$a'),
      selected: _ano == a,
      onSelected: (_) async {
        setState(() => _ano = a);
        await _load();
      },
    );
  }

  Widget _resumoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _resumo;

    if (r == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo $_ano',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _kv('Ganhos', _money(r.ganhos)),
                const SizedBox(width: 12),
                _kv('Gastos', _money(r.gastosTotal)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.surfaceContainerHighest.withOpacity(.7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo do ano',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _money(r.saldo),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: _saldoColor(cs, r.saldo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Fixos: ${_money(r.gastosFixos)}   •   Variáveis: ${_money(r.gastosVariaveis)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _mesCard(BuildContext context, BalancoMesRow r) {
    final cs = Theme.of(context).colorScheme;

    final titulo = '${_mesNome(r.mes)} ${r.ano}';
    final saldo = r.balanco; // inclui parcelas/dividas (por enquanto 0)
    final corSaldo = _saldoColor(cs, saldo);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // ✅ drill-down: depois você cria essa rota/tela
        // Navigator.pushNamed(context, AppRouterV2.balancoDetalhe, arguments: BalancoDetalheArgs(ano: r.ano, mes: r.mes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abrir detalhes: $titulo (em breve)')),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _kv('Ganhos', _money(r.ganhos)),
                  const SizedBox(width: 12),
                  _kv('Gastos', _money(r.gastosTotal)),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fixos: ${_money(r.gastosFixos)}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Variáveis: ${_money(r.gastosVariaveis)}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.surfaceContainerHighest.withOpacity(.7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo do mês',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _money(saldo),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: corSaldo,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Balanço do mês/ano')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [_chipAno(2026), _chipAno(2027), _chipAno(2028)],
                  ),
                  const SizedBox(height: 14),

                  _resumoCard(context),
                  const SizedBox(height: 10),

                  ..._rows.map((r) => _mesCard(context, r)),

                  const SizedBox(height: 14),
                  Text(
                    'Obs.: “Parcelas” e “Dívidas” ainda ficam em 0 até criarmos os módulos de parcelamento e dívidas.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
    );
  }
}
