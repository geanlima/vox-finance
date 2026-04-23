// ignore_for_file: use_build_context_synchronously, unnecessary_brace_in_string_interps, deprecated_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';
import 'package:vox_finance/ui/data/modules/metricas/metrica_limite_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

enum _VisaoAnalise { ano, mes, semana }

enum _TipoGraficoAnalise { barra, linha }

class _PontoSerie {
  final String label;
  final double valor;
  final double meta;
  final DateTime inicio;
  final DateTime fim;

  const _PontoSerie({
    required this.label,
    required this.valor,
    required this.meta,
    required this.inicio,
    required this.fim,
  });
}

class MetricasAnalisesPage extends StatefulWidget {
  const MetricasAnalisesPage({super.key});

  static const routeName = '/metricas-analises';

  @override
  State<MetricasAnalisesPage> createState() => _MetricasAnalisesPageState();
}

class _MetricasAnalisesPageState extends State<MetricasAnalisesPage> {
  final _repo = MetricaLimiteRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _mesAbrev = DateFormat('MMM', 'pt_BR');
  final _diaCurto = DateFormat('dd/MM', 'pt_BR');

  bool _loading = true;
  String? _erro;

  List<MetricaLimite> _metricas = const [];
  MetricaLimite? _metricaSel;

  _VisaoAnalise _visao = _VisaoAnalise.ano;
  _TipoGraficoAnalise _tipoGrafico = _TipoGraficoAnalise.barra;

  int _anoRef = DateTime.now().year;
  int _mesRef = DateTime.now().month;
  DateTime _dataRefSemana = DateTime.now();

  List<_PontoSerie> _serie = const [];
  double _totalPeriodo = 0.0;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _anoRef = agora.year;
    _mesRef = agora.month;
    _dataRefSemana = agora;
    _init();
  }

  int? _argMetricaId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) return null;
    if (args is int) return args;
    if (args is Map) {
      final v = args['metricaId'] ?? args['id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      // Garante recorrentes antes de listar, para não “sumir” no mês novo.
      await _repo.gerarRecorrentesDoMesAtualSeNecessario(DateTime.now());

      final list = await _repo.listarDoPeriodoAtual(DateTime.now());
      list.sort((a, b) {
        final pa = a.periodoTipo;
        final pb = b.periodoTipo;
        if (pa != pb) return pa.compareTo(pb);
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      final wantedId = _argMetricaId();
      MetricaLimite? sel;
      if (wantedId != null) {
        try {
          sel = list.firstWhere((m) => m.id == wantedId);
        } catch (_) {
          sel = null;
        }
      }
      sel ??= list.isNotEmpty ? list.first : null;

      if (!mounted) return;
      setState(() {
        _metricas = list;
        _metricaSel = sel;
        _loading = false;
      });

      await _recalcular();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
      });
    }
  }

  String _labelMetrica(MetricaLimite m) {
    final periodo =
        m.periodoTipo == 'semanal'
            ? 'Semanal'
            : 'Mensal';

    if (m.escopo == 'forma') {
      final fp = m.formaPagamento;
      final alvo =
          (fp == null)
              ? 'Forma'
              : (fp == 0
                  ? (m.idCartao == null ? 'Crédito (todos)' : 'Crédito (cartão)')
                  : 'Forma #$fp');
      return '$periodo • $alvo • limite ${_money.format(m.limiteValor)}';
    }

    if (m.idCategoriaPersonalizada <= 0) {
      return '$periodo • Todas as despesas • limite ${_money.format(m.limiteValor)}';
    }
    final sub = m.idSubcategoriaPersonalizada == null ? '' : ' • Sub';
    return '$periodo • Categoria${sub} • limite ${_money.format(m.limiteValor)}';
  }

  DateTime _inicioSemana(DateTime base) {
    final d = DateTime(base.year, base.month, base.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime _fimSemana(DateTime base) {
    final ini = _inicioSemana(base);
    return ini.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  }

  int _diasNoMes(int ano, int mes) => DateTime(ano, mes + 1, 0).day;

  int _diasNoIntervalo(DateTime ini, DateTime fim) {
    final a = DateTime(ini.year, ini.month, ini.day);
    final b = DateTime(fim.year, fim.month, fim.day);
    return b.difference(a).inDays + 1;
  }

  String _fmtPeriodoTooltip(_PontoSerie p) {
    if (_visao == _VisaoAnalise.ano) return p.label;
    final ini = _diaCurto.format(p.inicio);
    final fim = _diaCurto.format(p.fim);
    return '$ini–$fim';
  }

  double _projecaoPeriodoAtual({
    required MetricaLimite metrica,
    required double gastoAtual,
  }) {
    // Projeção só faz sentido para mês/semana quando não inclui futuros
    // (se incluir, o gasto já pode conter valores futuros e a projeção distorce).
    if (metrica.incluirFuturos) return gastoAtual;

    final now = DateTime.now();

    if (_visao == _VisaoAnalise.semana) {
      final ini = _inicioSemana(_dataRefSemana);
      final fim = _fimSemana(_dataRefSemana);
      final isSemanaAtual =
          !now.isBefore(ini) && !now.isAfter(fim);
      if (!isSemanaAtual) return gastoAtual;

      final diasPassados = now.difference(DateTime(ini.year, ini.month, ini.day)).inDays + 1;
      final diasTotal = 7;
      if (diasPassados <= 0) return gastoAtual;
      final mediaDia = gastoAtual / diasPassados;
      return mediaDia * diasTotal;
    }

    if (_visao == _VisaoAnalise.mes) {
      final isMesAtual = now.year == _anoRef && now.month == _mesRef;
      if (!isMesAtual) return gastoAtual;

      final diasPassados = now.day.clamp(1, _diasNoMes(_anoRef, _mesRef));
      final diasTotal = _diasNoMes(_anoRef, _mesRef);
      if (diasPassados <= 0) return gastoAtual;
      final mediaDia = gastoAtual / diasPassados;
      return mediaDia * diasTotal;
    }

    // Ano: não projeta (muito ruído)
    return gastoAtual;
  }

  double _metaParaPonto({
    required MetricaLimite metrica,
    required DateTime inicio,
    required DateTime fim,
    required int diasTotalVisao,
  }) {
    // Se o período natural da métrica já coincide com o bucket, usa o limite cheio.
    if (metrica.periodoTipo == 'mensal' && _visao == _VisaoAnalise.ano) {
      return metrica.limiteValor; // meta por mês (12 buckets)
    }
    if (metrica.periodoTipo == 'semanal' && _visao == _VisaoAnalise.ano) {
      return metrica.limiteValor; // meta por semana (N buckets)
    }
    if (metrica.periodoTipo == 'semanal' && _visao == _VisaoAnalise.mes) {
      return metrica.limiteValor; // bucket=semana
    }

    // Caso contrário, rateia proporcionalmente pelos dias do bucket dentro do total da visão.
    final diasBucket = _diasNoIntervalo(inicio, fim);
    if (diasTotalVisao <= 0) return 0;
    return metrica.limiteValor * (diasBucket / diasTotalVisao);
  }

  Future<void> _recalcular() async {
    final m = _metricaSel;
    if (m == null) {
      if (!mounted) return;
      setState(() {
        _serie = const [];
        _totalPeriodo = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final serie = <_PontoSerie>[];

      if (_visao == _VisaoAnalise.ano) {
        if (m.periodoTipo == 'mensal') {
          for (var mes = 1; mes <= 12; mes++) {
            final ini = DateTime(_anoRef, mes, 1);
            final fim = DateTime(_anoRef, mes + 1, 1).subtract(const Duration(milliseconds: 1));
            final v = await _repo.somarGastosNoIntervalo(metrica: m, inicio: ini, fim: fim);
            final meta = m.limiteValor;
            final label = _mesAbrev.format(DateTime(2000, mes, 1));
            serie.add(_PontoSerie(label: label, valor: v, meta: meta, inicio: ini, fim: fim));
          }
        } else {
          final maxSemana = _repo.semanaDoAno(DateTime(_anoRef, 12, 31));
          for (var sem = 1; sem <= maxSemana; sem++) {
            final (ini, fim) = _repo.intervaloDaSemana(ano: _anoRef, semana: sem);
            final v = await _repo.somarGastosNoIntervalo(metrica: m, inicio: ini, fim: fim);
            final meta = m.limiteValor;
            serie.add(_PontoSerie(label: 'S$sem', valor: v, meta: meta, inicio: ini, fim: fim));
          }
        }
      } else if (_visao == _VisaoAnalise.mes) {
        final iniMes = DateTime(_anoRef, _mesRef, 1);
        final fimMes = DateTime(_anoRef, _mesRef + 1, 1).subtract(const Duration(milliseconds: 1));
        final diasNoMes = _diasNoMes(_anoRef, _mesRef);

        // semanas que cruzam o mês (segunda→domingo), mas somando APENAS dentro do mês
        final firstWeekStart = _inicioSemana(iniMes);
        var cur = firstWeekStart;
        var idx = 1;
        while (cur.isBefore(fimMes) || cur.isAtSameMomentAs(fimMes)) {
          final iniSem = cur;
          final fimSem = cur.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          final clipIni = iniSem.isBefore(iniMes) ? iniMes : iniSem;
          final clipFim = fimSem.isAfter(fimMes) ? fimMes : fimSem;
          final v = await _repo.somarGastosNoIntervalo(metrica: m, inicio: clipIni, fim: clipFim);
          final meta = _metaParaPonto(
            metrica: m,
            inicio: clipIni,
            fim: clipFim,
            diasTotalVisao: diasNoMes,
          );
          serie.add(_PontoSerie(label: 'S$idx', valor: v, meta: meta, inicio: clipIni, fim: clipFim));
          idx++;
          cur = cur.add(const Duration(days: 7));
        }
      } else {
        final ini = _inicioSemana(_dataRefSemana);
        final diasTotal =
            (m.periodoTipo == 'semanal')
                ? 7
                : _diasNoMes(_anoRef, _mesRef);
        for (var i = 0; i < 7; i++) {
          final dIni = DateTime(ini.year, ini.month, ini.day).add(Duration(days: i));
          final dFim = dIni.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          final label = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][i];
          final v = await _repo.somarGastosNoIntervalo(metrica: m, inicio: dIni, fim: dFim);
          final meta = _metaParaPonto(
            metrica: m,
            inicio: dIni,
            fim: dFim,
            diasTotalVisao: diasTotal,
          );
          serie.add(_PontoSerie(label: label, valor: v, meta: meta, inicio: dIni, fim: dFim));
        }
      }

      final total = serie.fold<double>(0.0, (s, p) => s + p.valor);

      if (!mounted) return;
      setState(() {
        _serie = serie;
        _totalPeriodo = total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<MetricaLimite>(
              value: _metricaSel,
              decoration: const InputDecoration(
                labelText: 'Métrica',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items:
                  _metricas
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            _labelMetrica(m),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              selectedItemBuilder: (context) {
                return _metricas
                    .map(
                      (m) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _labelMetrica(m),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList();
              },
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _metricaSel = v);
                await _recalcular();
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<_VisaoAnalise>(
              showSelectedIcon: false,
              style: ButtonStyle(
                side: WidgetStateProperty.all(
                  BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.primaryContainer;
                  }
                  return cs.surfaceContainerHighest.withValues(alpha: 0.65);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.onPrimaryContainer;
                  }
                  return cs.onSurface;
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.onPrimaryContainer;
                  }
                  return cs.onSurfaceVariant;
                }),
              ),
              segments: const [
                ButtonSegment(
                  value: _VisaoAnalise.ano,
                  label: Text('Ano'),
                  icon: Icon(Icons.calendar_today_outlined),
                ),
                ButtonSegment(
                  value: _VisaoAnalise.mes,
                  label: Text('Mês'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: _VisaoAnalise.semana,
                  label: Text('Semana'),
                  icon: Icon(Icons.view_week_outlined),
                ),
              ],
              selected: {_visao},
              onSelectionChanged: (s) async {
                final v = s.first;
                if (v == _visao) return;
                setState(() => _visao = v);
                await _recalcular();
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool narrow = constraints.maxWidth < 360;
                final graficoBtn = PopupMenuButton<_TipoGraficoAnalise>(
                  tooltip: 'Tipo de gráfico',
                  onSelected: (t) => setState(() => _tipoGrafico = t),
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: _TipoGraficoAnalise.barra,
                          child: Row(
                            children: [
                              Icon(Icons.bar_chart, size: 18),
                              SizedBox(width: 8),
                              Text('Barra'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _TipoGraficoAnalise.linha,
                          child: Row(
                            children: [
                              Icon(Icons.show_chart, size: 18),
                              SizedBox(width: 8),
                              Text('Linha'),
                            ],
                          ),
                        ),
                      ],
                  icon: const Icon(Icons.insights_outlined),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPeriodoPicker(context),
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: graficoBtn),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _buildPeriodoPicker(context)),
                    const SizedBox(width: 10),
                    graficoBtn,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoPicker(BuildContext context) {
    if (_visao == _VisaoAnalise.ano) {
      final anos = List<int>.generate(9, (i) => DateTime.now().year - 5 + i);
      return DropdownButtonFormField<int>(
        value: _anoRef,
        decoration: const InputDecoration(
          labelText: 'Ano',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items:
            anos
                .map((a) => DropdownMenuItem(value: a, child: Text('$a')))
                .toList(),
        onChanged: (v) async {
          if (v == null) return;
          setState(() => _anoRef = v);
          await _recalcular();
        },
      );
    }

    if (_visao == _VisaoAnalise.mes) {
      final anos = List<int>.generate(9, (i) => DateTime.now().year - 5 + i);
      return Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _mesRef,
              decoration: const InputDecoration(
                labelText: 'Mês',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_mesAbrev.format(DateTime(2000, i + 1, 1))),
                ),
              ),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _mesRef = v);
                await _recalcular();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _anoRef,
              decoration: const InputDecoration(
                labelText: 'Ano',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items:
                  anos
                      .map((a) => DropdownMenuItem(value: a, child: Text('$a')))
                      .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _anoRef = v);
                await _recalcular();
              },
            ),
          ),
        ],
      );
    }

    // Semana
    final ini = _inicioSemana(_dataRefSemana);
    final fim = _fimSemana(_dataRefSemana);
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dataRefSemana,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
        );
        if (picked == null) return;
        setState(() => _dataRefSemana = picked);
        await _recalcular();
      },
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('${_diaCurto.format(ini)}–${_diaCurto.format(fim)}'),
    );
  }

  Widget _buildResumo(BuildContext context) {
    final m = _metricaSel;
    if (m == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final limite = m.limiteValor;
    final pct = limite <= 0 ? 0.0 : (_totalPeriodo / limite) * 100.0;
    final diff = limite - _totalPeriodo;
    final proj = _projecaoPeriodoAtual(metrica: m, gastoAtual: _totalPeriodo);
    final projPct = limite <= 0 ? 0.0 : (proj / limite) * 100.0;
    Color cor = cs.primary;
    if (pct >= m.alertaPct2) {
      cor = cs.error;
    } else if (pct >= m.alertaPct1) {
      cor = Colors.orange.shade800;
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gasto: ${_money.format(_totalPeriodo)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.w900, color: cor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Limite: ${_money.format(limite)}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              diff >= 0
                  ? 'Restante: ${_money.format(diff)}'
                  : 'Estouro: ${_money.format(-diff)}',
              style: TextStyle(
                color: diff >= 0 ? Colors.green.shade700 : cs.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((_visao == _VisaoAnalise.mes || _visao == _VisaoAnalise.semana) &&
                !m.incluirFuturos) ...[
              const SizedBox(height: 6),
              Text(
                'Projeção (no ritmo atual): ${_money.format(proj)} (${projPct.toStringAsFixed(0)}%)',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pct / 100.0).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafico(BuildContext context) {
    if (_serie.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Sem dados para exibir.')),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final maxY =
        _serie
            .map((e) => (e.valor > e.meta) ? e.valor : e.meta)
            .fold<double>(0, (m, v) => v > m ? v : m);
    final yTop = maxY <= 0 ? 1.0 : maxY * 1.15;

    if (_tipoGrafico == _TipoGraficoAnalise.linha) {
      final spots = <FlSpot>[];
      final spotsMeta = <FlSpot>[];
      for (var i = 0; i < _serie.length; i++) {
        spots.add(FlSpot(i.toDouble() + 1, _serie[i].valor));
        spotsMeta.add(FlSpot(i.toDouble() + 1, _serie[i].meta));
      }
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: _serie.length.toDouble(),
                minY: 0,
                maxY: yTop,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final idx = touchedSpots.first.x.toInt() - 1;
                      if (idx < 0 || idx >= _serie.length) return [];
                      final p = _serie[idx];
                      final pct = p.meta <= 0 ? 0.0 : (p.valor / p.meta) * 100.0;
                      final diff = p.meta - p.valor;
                      return [
                        LineTooltipItem(
                          '${p.label} • ${_fmtPeriodoTooltip(p)}\n'
                          'Gasto: ${_money.format(p.valor)}\n'
                          'Meta: ${_money.format(p.meta)}\n'
                          '${diff >= 0 ? 'Restante' : 'Estouro'}: ${_money.format(diff.abs())}\n'
                          '${pct.toStringAsFixed(0)}%',
                          TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ];
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _money.format(value).replaceAll('R\$', '').trim(),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt() - 1;
                        if (idx < 0 || idx >= _serie.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _serie[idx].label,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: cs.primary,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: spotsMeta,
                    isCurved: false,
                    barWidth: 2,
                    color: cs.primaryContainer,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Barras
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < _serie.length; i++) {
      final p = _serie[i];
      final bool estourou = p.valor > p.meta && p.meta > 0;
      groups.add(
        BarChartGroupData(
          x: i + 1,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: p.valor,
              borderRadius: BorderRadius.circular(4),
              color: estourou ? cs.error : cs.primary,
              width: 8,
            ),
            BarChartRodData(
              toY: p.meta,
              borderRadius: BorderRadius.circular(4),
              color: cs.primaryContainer,
              width: 8,
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Gasto', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Meta', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: yTop,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 10,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x - 1;
                        if (idx < 0 || idx >= _serie.length) return null;
                        final p = _serie[idx];
                        final pct = p.meta <= 0 ? 0.0 : (p.valor / p.meta) * 100.0;
                        final diff = p.meta - p.valor;
                        final title = '${p.label} • ${_fmtPeriodoTooltip(p)}';
                        final body =
                            'Gasto: ${_money.format(p.valor)}\n'
                            'Meta: ${_money.format(p.meta)}\n'
                            '${diff >= 0 ? 'Restante' : 'Estouro'}: ${_money.format(diff.abs())}\n'
                            '${pct.toStringAsFixed(0)}%';
                        return BarTooltipItem(
                          '$title\n$body',
                          TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            _money.format(value).replaceAll('R\$', '').trim(),
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt() - 1;
                          if (idx < 0 || idx >= _serie.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            _serie[idx].label,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    final m = _metricaSel;
    if (m == null || _serie.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Detalhamento',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ..._serie.map((p) {
              final pct = p.meta <= 0 ? 0.0 : (p.valor / p.meta) * 100.0;
              final diff = p.meta - p.valor;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        p.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${_money.format(p.valor)} / ${_money.format(p.meta)}'
                        ' • ${diff >= 0 ? 'resta' : 'estoura'} ${_money.format(diff.abs())}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análises de métricas'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _init,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: MetricasAnalisesPage.routeName),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : (_erro != null)
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não consegui carregar as análises.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(_erro!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _init,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
              : ListView(
                padding: listViewPaddingWithBottomInset(
                  context,
                  const EdgeInsets.all(16),
                ),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildResumo(context),
                  const SizedBox(height: 12),
                  _buildGrafico(context),
                  const SizedBox(height: 12),
                  _buildLista(context),
                ],
              ),
    );
  }
}

