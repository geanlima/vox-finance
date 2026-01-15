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

    // ajusta dia selecionado para dentro do mês
    final last = DateTime(novo.year, novo.month + 1, 0).day;
    final day = _diaSelecionado.day.clamp(1, last);
    final sel = DateTime(novo.year, novo.month, day);
    setState(() => _diaSelecionado = sel);

    await _load();
  }

  int _countNoDia(DateTime d) {
    return _itensMes.where((x) => _isSameDay(x.data, d)).length;
  }

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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _NovoVencimentoSheet(dataInicial: _diaSelecionado),
          );
          if (created == true) _load();
        },
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Header mês
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

                  // Calendário (grid)
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

                  // Lista do dia selecionado
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
                    ..._itensDia.map(
                      (v) => _VencimentoTile(
                        item: v,
                        onTogglePago: (p) async {
                          await _repo.setPago(v.id, p);
                          await _selecionarDia(_diaSelecionado);
                          await _load();
                        },
                        onDelete: () async {
                          await _repo.remover(v.id);
                          await _selecionarDia(_diaSelecionado);
                          await _load();
                        },
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final first = DateTime(mes.year, mes.month, 1);
    final lastDay = DateTime(mes.year, mes.month + 1, 0).day;
    final firstWeekday = first.weekday; // 1=Mon..7=Sun

    // vamos começar no domingo
    int startOffset = (firstWeekday % 7); // Mon=1 =>1, Sun=0
    final totalCells = ((startOffset + lastDay) <= 35) ? 35 : 42;

    final labels = const [
      'dom.',
      'seg.',
      'ter.',
      'qua.',
      'qui.',
      'sex.',
      'sáb.',
    ];

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
            final selected =
                d.year == selecionado.year &&
                d.month == selecionado.month &&
                d.day == selecionado.day;
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

class _VencimentoTile extends StatelessWidget {
  final VencimentoItem item;
  final ValueChanged<bool> onTogglePago;
  final VoidCallback onDelete;

  const _VencimentoTile({
    required this.item,
    required this.onTogglePago,
    required this.onDelete,
  });

  String _fmtMoney(int cents) {
    final v = cents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('venc_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
        ),
        onDismissed: (_) => onDelete(),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: ListTile(
            leading: Checkbox(
              value: item.pago,
              onChanged: (v) => onTogglePago(v == true),
            ),
            title: Text(
              item.titulo,
              style: TextStyle(
                decoration: item.pago ? TextDecoration.lineThrough : null,
                color: item.pago ? cs.outline : null,
              ),
            ),
            subtitle:
                item.valorCentavos != null ||
                        (item.observacao?.isNotEmpty ?? false)
                    ? Text(
                      [
                        if (item.valorCentavos != null)
                          _fmtMoney(item.valorCentavos!),
                        if (item.observacao?.isNotEmpty ?? false)
                          item.observacao!,
                      ].join(' • '),
                    )
                    : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}

class _NovoVencimentoSheet extends StatefulWidget {
  final DateTime dataInicial;
  const _NovoVencimentoSheet({required this.dataInicial});

  @override
  State<_NovoVencimentoSheet> createState() => _NovoVencimentoSheetState();
}

class _NovoVencimentoSheetState extends State<_NovoVencimentoSheet> {
  final _titulo = TextEditingController();
  final _valor = TextEditingController();
  final _obs = TextEditingController();

  DateTime _data = DateTime.now();
  bool _mensal = true;

  final _repo = InjectorV2.vencimentosRepo;

  @override
  void initState() {
    super.initState();
    _data = widget.dataInicial;
  }

  int? _parseCentavos(String s) {
    final raw = s.trim().replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottom + 16,
        top: 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Novo vencimento',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _titulo,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valor,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDate: _data,
                    );
                    if (picked != null) setState(() => _data = picked);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    '${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _obs,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          SwitchListTile(
            value: _mensal,
            onChanged: (v) => setState(() => _mensal = v),
            title: const Text('Repetir mensalmente'),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final titulo = _titulo.text.trim();
                    if (titulo.isEmpty) return;

                    await _repo.adicionar(
                      titulo: titulo,
                      data: _data,
                      valorCentavos: _parseCentavos(_valor.text),
                      observacao:
                          _obs.text.trim().isEmpty ? null : _obs.text.trim(),
                      recorrencia: _mensal ? 'mensal' : 'nenhuma',
                    );

                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
