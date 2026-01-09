// ignore_for_file: control_flow_in_finally, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:vox_finance/ui/core/enum/tipo_grafico.dart';
import 'package:vox_finance/ui/core/service/grafico_preferencia_service.dart';
import 'package:vox_finance/ui/core/service/relatorio_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart'; // TipoMovimento

class GraficoMensalPage extends StatefulWidget {
  const GraficoMensalPage({super.key});

  @override
  State<GraficoMensalPage> createState() => _GraficoMensalPageState();
}

class _GraficoMensalPageState extends State<GraficoMensalPage> {
  final _prefService = GraficoPreferenciaService();
  final _relatorio = RelatorioService();

  TipoGrafico _tipo = TipoGrafico.barra;

  bool _loading = true;
  String? _erro;

  List<MesValor> _dadosMes = [];
  Map<String, double> _dadosCategoria = {};
  Map<String, int> _dadosHistograma = {};

  // ✅ Esta tela é de GASTOS
  final TipoMovimento _tipoMovimento = TipoMovimento.despesa;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final pref = await _prefService.carregarTipoGrafico();
      if (!mounted) return;

      setState(() {
        _tipo = pref;
      });

      await _carregarDados();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Falha ao carregar gráfico.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _carregarDados() async {
    final agora = DateTime.now();

    final dadosMes = await _relatorio.totaisPorMes(
      agora.year,
      tipo: _tipoMovimento,
    );

    final dadosCategoria = await _relatorio.totaisPorCategoria(
      agora,
      tipo: _tipoMovimento,
    );

    final dadosHistograma = await _relatorio.histograma(
      agora,
      tipo: _tipoMovimento,
    );

    if (!mounted) return;
    setState(() {
      _dadosMes = dadosMes;
      _dadosCategoria = dadosCategoria;
      _dadosHistograma = dadosHistograma;
      _erro = null;
    });
  }

  Future<void> _trocarTipo(TipoGrafico novo) async {
    setState(() => _tipo = novo);
    await _prefService.salvarTipoGrafico(novo);
  }

  Future<void> _recarregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      await _carregarDados();
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Falha ao recarregar dados.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Gastos do mês (${_tipo.label})'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
          ),
          PopupMenuButton<TipoGrafico>(
            tooltip: 'Tipo de gráfico',
            onSelected: _trocarTipo,
            itemBuilder:
                (_) => [
                  for (final t in TipoGrafico.values)
                    PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(_iconTipo(t), size: 18),
                          const SizedBox(width: 8),
                          Text(t.label),
                        ],
                      ),
                    ),
                ],
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _erro != null ? _buildErro(context) : _buildGrafico(),
      ),
    );
  }

  Widget _buildErro(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_erro!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
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
  //  LINHA
  // ============================================================

  Widget _graficoLinha() {
    if (_dadosMes.isEmpty)
      return const Center(child: Text('Sem dados no ano.'));

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
                if (idx < 1 || idx > 12) return const SizedBox.shrink();
                return Text('$idx');
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
  //  BARRAS
  // ============================================================

  Widget _graficoBarra() {
    if (_dadosMes.isEmpty)
      return const Center(child: Text('Sem dados no ano.'));

    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 1 || idx > 12) return const SizedBox.shrink();
                return Text('$idx');
              },
            ),
          ),
        ),
        barGroups:
            _dadosMes.map((m) {
              return BarChartGroupData(
                x: m.mes,
                barRods: [
                  BarChartRodData(
                    toY: m.total,
                    borderRadius: BorderRadius.zero,
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  // ============================================================
  //  PIZZA
  // ============================================================

  Widget _graficoPizza() {
    final total = _dadosCategoria.values.fold<double>(0, (a, b) => a + b);

    if (total <= 0) {
      return const Center(child: Text('Sem dados no mês.'));
    }

    final entries =
        _dadosCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 40,
              sections:
                  entries.map((e) {
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        '${e.key}: R\$ ${e.value.toStringAsFixed(2)}',
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  HISTOGRAMA
  // ============================================================

  Widget _graficoHistograma() {
    if (_dadosHistograma.isEmpty) {
      return const Center(child: Text('Sem dados no mês.'));
    }

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
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[idx]);
              },
            ),
          ),
        ),
        barGroups: List.generate(
          valores.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: valores[i].toDouble(),
                width: 18,
                borderRadius: BorderRadius.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconTipo(TipoGrafico t) {
    switch (t) {
      case TipoGrafico.linha:
        return Icons.show_chart;
      case TipoGrafico.barra:
        return Icons.bar_chart;
      case TipoGrafico.pizza:
        return Icons.pie_chart;
      case TipoGrafico.histograma:
        return Icons.stacked_bar_chart;
    }
  }
}
