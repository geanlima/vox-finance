import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/vencimentos_repository.dart';

class CalendarioVencimentosPage extends StatefulWidget {
  const CalendarioVencimentosPage({super.key});

  @override
  State<CalendarioVencimentosPage> createState() =>
      _CalendarioVencimentosPageState();
}

class _CalendarioVencimentosPageState extends State<CalendarioVencimentosPage> {
  final _repo = InjectorV2.vencimentosRepo;

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _diaSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  bool _loading = true;
  List<VencimentoItem> _itensMes = const [];
  List<VencimentoItem> _itensDia = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final mes = await _repo.listarPorMes(_mes);
    final dia = await _repo.listarPorDia(_diaSelecionado);
    if (!mounted) return;
    setState(() {
      _itensMes = mes;
      _itensDia = dia;
      _loading = false;
    });
  }

  Future<void> _selecionarDia(DateTime d) async {
    setState(() => _diaSelecionado = d);
    final dia = await _repo.listarPorDia(d);
    if (!mounted) return;
    setState(() => _itensDia = dia);
  }

  Future<void> _mudarMes(int delta) async {
    final novo = DateTime(_mes.year, _mes.month + delta, 1);
    setState(() => _mes = novo);

    final last = DateTime(novo.year, novo.month + 1, 0).day;
    final day = _diaSelecionado.day.clamp(1, last);
    final sel = DateTime(novo.year, novo.month, day);
    setState(() => _diaSelecionado = sel);

    await _load();
  }

  int _countNoDia(DateTime d) =>
      _itensMes.where((x) => _isSameDay(x.data, d)).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Vencimentos'),
        actions: [
          IconButton(
            tooltip: 'Hoje',
            icon: const Icon(Icons.today),
            onPressed: () async {
              final now = DateTime.now();
              setState(() {
                _mes = DateTime(now.year, now.month, 1);
                _diaSelecionado = DateTime(now.year, now.month, now.day);
              });
              await _load();
            },
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      // ✅ sem FAB (não cria manual)
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _mudarMes(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _fmtMesAno(_mes),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _mudarMes(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _CalendarGrid(
                        mes: _mes,
                        selecionado: _diaSelecionado,
                        countForDay: _countNoDia,
                        onTapDay: _selecionarDia,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Dia ${_diaSelecionado.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${_itensDia.length} itens',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_itensDia.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        'Nenhum vencimento nesse dia.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: cs.outline),
                      ),
                    )
                  else
                    ..._itensDia.map((v) => _VencimentoTileReadOnly(item: v)),
                ],
              ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _fmtMesAno(DateTime d) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${meses[d.month - 1]} de ${d.year}';
  }
}

class _VencimentoTileReadOnly extends StatelessWidget {
  final VencimentoItem item;
  const _VencimentoTileReadOnly({required this.item});

  String _fmtMoney(int cents) {
    final v = cents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ListTile(
          leading: Icon(
            item.origemTipo == 'fixa'
                ? Icons.push_pin_outlined
                : Icons.shopping_cart_outlined,
          ),
          title: Text(
            item.titulo,
            style: TextStyle(
              decoration: item.pago ? TextDecoration.lineThrough : null,
              color: item.pago ? cs.outline : null,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            [
              if (item.valorCentavos != null) _fmtMoney(item.valorCentavos!),
              item.origemTipo == 'fixa' ? 'Despesa fixa' : 'Despesa variável',
            ].join(' • '),
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime mes;
  final DateTime selecionado;
  final int Function(DateTime day) countForDay;
  final ValueChanged<DateTime> onTapDay;

  const _CalendarGrid({
    required this.mes,
    required this.selecionado,
    required this.countForDay,
    required this.onTapDay,
  });

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final first = DateTime(mes.year, mes.month, 1);
    final lastDay = DateTime(mes.year, mes.month + 1, 0).day;

    // weekday: Mon=1..Sun=7. Queremos começar no Domingo.
    final startOffset = first.weekday % 7; // Sun->0, Mon->1, ...
    final totalCells = ((startOffset + lastDay) <= 35) ? 35 : 42;

    const labels = ['dom.', 'seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.'];

    return Column(
      children: [
        Row(
          children:
              labels
                  .map(
                    (e) => Expanded(
                      child: Center(
                        child: Text(
                          e,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: cs.outline),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (_, idx) {
            final dayNum = idx - startOffset + 1;
            if (dayNum < 1 || dayNum > lastDay) {
              return const SizedBox.shrink();
            }

            final d = DateTime(mes.year, mes.month, dayNum);
            final selected = _isSameDay(d, selecionado);
            final count = countForDay(d);

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTapDay(d),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected ? cs.primaryContainer : cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$dayNum',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected ? cs.onPrimaryContainer : null,
                          ),
                        ),
                      ),
                    ),
                    if (count > 0)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected ? cs.primary : cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color:
                                    selected
                                        ? cs.onPrimary
                                        : cs.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
