import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:vox_finance/ui/core/enum/tipo_grafico.dart';
import 'package:vox_finance/ui/core/service/grafico_preferencia_service.dart';
import 'package:vox_finance/ui/core/service/relatorio_service.dart';

class GraficoMensalPage extends StatefulWidget {
  const GraficoMensalPage({super.key});

  @override
  State<GraficoMensalPage> createState() => _GraficoMensalPageState();
}

class _GraficoMensalPageState extends State<GraficoMensalPage> {
  final _prefService = GraficoPreferenciaService();
  final _relatorio = RelatorioService();

  TipoGrafico _tipo = TipoGrafico.barra;

  bool _carregandoPrefs = true;
  bool _carregandoDados = true;

  List<MesValor> _dadosMes = [];
  Map<String, double> _dadosCategoria = {};
  Map<String, int> _dadosHistograma = {};

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final prefs = await _prefService.carregarTipoGrafico();
    setState(() => _tipo = prefs);

    await _carregarDados();

    setState(() {
      _carregandoPrefs = false;
      _carregandoDados = false;
    });
  }

  Future<void> _carregarDados() async {
    final agora = DateTime.now();
    _dadosMes = await _relatorio.totaisPorMes(agora.year);
    _dadosCategoria = await _relatorio.totaisPorCategoria(agora);
    _dadosHistograma = await _relatorio.histograma(agora);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPrefs || _carregandoDados) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gráfico Mensal (${_tipo.label})')),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildGrafico()),
    );
  }

  Widget _buildGrafico() {
    switch (_tipo) {
      case TipoGrafico.linha:
        return _graficoLinha();
      case TipoGrafico.barra:
        return _graficoBarra();
      case TipoGrafico.pizza:
        return _graficoPizza();
      case TipoGrafico.histograma:
        return _graficoHistograma();
    }
  }

  // ============================================================
  //  G R Á F I C O   D E   L I N H A
  // ============================================================

  Widget _graficoLinha() {
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 1 || idx > 12) return const SizedBox();
                return Text('$idxº');
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots:
                _dadosMes
                    .map((m) => FlSpot(m.mes.toDouble(), m.total))
                    .toList(),
            isCurved: true,
            dotData: FlDotData(show: true),
            barWidth: 3,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  B A R R A S
  // ============================================================

  Widget _graficoBarra() {
    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 1 || idx > 12) return const SizedBox();
                return Text('$idxº');
              },
            ),
          ),
        ),
        barGroups:
            _dadosMes
                .map(
                  (m) => BarChartGroupData(
                    x: m.mes,
                    barRods: [
                      BarChartRodData(
                        toY: m.total,
                        borderRadius: BorderRadius.zero,
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }

  // ============================================================
  //  P I Z Z A
  // ============================================================

  Widget _graficoPizza() {
    final total = _dadosCategoria.values.fold<double>(0, (a, b) => a + b);

    if (total == 0) return const Center(child: Text("Sem dados no mês."));

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 40,
              sections:
                  _dadosCategoria.entries.map((e) {
                    final pct = (e.value / total) * 100;
                    return PieChartSectionData(
                      value: e.value,
                      title: '${pct.toStringAsFixed(1)}%',
                      radius: 70,
                    );
                  }).toList(),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children:
              _dadosCategoria.entries.map((e) {
                return Chip(
                  label: Text('${e.key}: R\$ ${e.value.toStringAsFixed(2)}'),
                );
              }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  //  H I S T O G R A M A
  // ============================================================

  Widget _graficoHistograma() {
    final labels = _dadosHistograma.keys.toList();
    final valores = _dadosHistograma.values.toList();

    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox();
                return Text(labels[idx]);
              },
            ),
          ),
        ),
        barGroups: List.generate(
          valores.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: valores[i].toDouble(), width: 18)],
          ),
        ),
      ),
    );
  }
}
