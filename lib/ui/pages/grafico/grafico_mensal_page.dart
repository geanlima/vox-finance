import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/enum/grafico_visao_inicial.dart';
import 'package:vox_finance/ui/core/service/preferencias_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

enum GraficoNivel { ano, mes, dia }

class GraficoMensalPage extends StatefulWidget {
  const GraficoMensalPage({super.key});

  @override
  State<GraficoMensalPage> createState() => _GraficoMensalPageState();
}

class _GraficoMensalPageState extends State<GraficoMensalPage> {
  final _isarService = DbService();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  /// nível atual do gráfico (ano / mês / dia)
  GraficoNivel _nivel = GraficoNivel.ano;

  /// configuração inicial (vindo das preferências)
  GraficoVisaoInicial _visaoInicial = GraficoVisaoInicial.ano;

  /// Ano base (para nível ano/mes/dia)
  int _anoSelecionado = DateTime.now().year;

  /// Mês selecionado (1-12) para nível mês/dia
  int _mesSelecionado = DateTime.now().month;

  /// Dia selecionado para nível dia
  int _diaSelecionado = DateTime.now().day;

  /// Dados por mês (1-12 → total)
  Map<int, double> _totaisPorMes = {};

  /// Dados por dia (1-31 → total)
  Map<int, double> _totaisPorDia = {};

  /// Dados por forma de pagamento (FormaPagamento → total)
  Map<FormaPagamento, double> _totaisPorForma = {};

  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  /// Lê a configuração (ano/mês/dia) e carrega o nível inicial.
  Future<void> _carregarPreferencias() async {
    try {
      _visaoInicial =
          await PreferenciasService.carregarVisao();
    } catch (_) {
      _visaoInicial = GraficoVisaoInicial.ano;
    }

    switch (_visaoInicial) {
      case GraficoVisaoInicial.ano:
        _nivel = GraficoNivel.ano;
        await _carregarAno();
        break;
      case GraficoVisaoInicial.mes:
        _nivel = GraficoNivel.mes;
        await _carregarMes();
        break;
      case GraficoVisaoInicial.dia:
        _nivel = GraficoNivel.dia;
        await _carregarDia();
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // =================== CARREGAMENTO DE DADOS ===================

  Future<void> _carregarAno() async {
    setState(() {
      _carregando = true;
      _nivel = GraficoNivel.ano;
      _totaisPorMes = {};
      _totaisPorDia = {};
      _totaisPorForma = {};
    });

    final inicio = DateTime(_anoSelecionado, 1, 1);
    final fim = DateTime(
      _anoSelecionado + 1,
      1,
      1,
    ).subtract(const Duration(seconds: 1));

    final lancamentos = await _isarService.getLancamentosByPeriodo(inicio, fim);

    final mapa = <int, double>{};
    for (final Lancamento l in lancamentos) {
      final mes = l.dataHora.month;
      mapa.update(mes, (atual) => atual + l.valor, ifAbsent: () => l.valor);
    }

    if (!mounted) return;
    setState(() {
      _totaisPorMes = mapa;
      _carregando = false;
    });
  }

  Future<void> _carregarMes() async {
    setState(() {
      _carregando = true;
      _nivel = GraficoNivel.mes;
      _totaisPorDia = {};
      _totaisPorForma = {};
    });

    final inicio = DateTime(_anoSelecionado, _mesSelecionado, 1);
    final proximoMes = DateTime(_anoSelecionado, _mesSelecionado + 1, 1);
    final fim = proximoMes.subtract(const Duration(seconds: 1));

    final lancamentos = await _isarService.getLancamentosByPeriodo(inicio, fim);

    final mapa = <int, double>{};
    for (final Lancamento l in lancamentos) {
      final dia = l.dataHora.day;
      mapa.update(dia, (atual) => atual + l.valor, ifAbsent: () => l.valor);
    }

    if (!mounted) return;
    setState(() {
      _totaisPorDia = mapa;
      _carregando = false;
    });
  }

  Future<void> _carregarDia() async {
    setState(() {
      _carregando = true;
      _nivel = GraficoNivel.dia;
      _totaisPorForma = {};
    });

    final inicio = DateTime(_anoSelecionado, _mesSelecionado, _diaSelecionado);
    final fim = inicio
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final lancamentos = await _isarService.getLancamentosByPeriodo(inicio, fim);

    final mapa = <FormaPagamento, double>{};
    for (final Lancamento l in lancamentos) {
      mapa.update(
        l.formaPagamento,
        (atual) => atual + l.valor,
        ifAbsent: () => l.valor,
      );
    }

    if (!mounted) return;
    setState(() {
      _totaisPorForma = mapa;
      _carregando = false;
    });
  }

  // =================== NAVEGAÇÃO DE NÍVEIS ===================

  void _voltarNivel() {
    switch (_nivel) {
      case GraficoNivel.dia:
        _carregarMes();
        break;
      case GraficoNivel.mes:
        if (_visaoInicial == GraficoVisaoInicial.ano) {
          _carregarAno();
        } else {
          Navigator.pop(context);
        }
        break;
      case GraficoNivel.ano:
        Navigator.pop(context);
        break;
    }
  }

  void _anoAnterior() {
    setState(() => _anoSelecionado--);
    _carregarAno();
  }

  void _proximoAno() {
    setState(() => _anoSelecionado++);
    _carregarAno();
  }

  void _mesAnterior() {
    setState(() {
      if (_mesSelecionado == 1) {
        _mesSelecionado = 12;
        _anoSelecionado--;
      } else {
        _mesSelecionado--;
      }
    });
    _carregarMes();
  }

  void _proximoMes() {
    setState(() {
      if (_mesSelecionado == 12) {
        _mesSelecionado = 1;
        _anoSelecionado++;
      } else {
        _mesSelecionado++;
      }
    });
    _carregarMes();
  }

  // =================== BUILD ===================

  @override
  Widget build(BuildContext context) {
    final titulo = _buildTitulo();

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        leading: Builder(
          builder: (context) {
            if (_nivel == GraficoNivel.ano) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            }
            return IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _voltarNivel,
            );
          },
        ),
      ),
      drawer: const AppDrawer(currentRoute: '/grafico-mensal'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderFiltro(),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _carregando
                      ? const Center(child: CircularProgressIndicator())
                      : _buildChartAtual(),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTitulo() {
    switch (_nivel) {
      case GraficoNivel.ano:
        return 'Gastos por mês ($_anoSelecionado)';
      case GraficoNivel.mes:
        final mesNome = DateFormat(
          'MMMM',
          'pt_BR',
        ).format(DateTime(_anoSelecionado, _mesSelecionado, 1));
        return 'Gastos por dia - '
            '${mesNome[0].toUpperCase()}${mesNome.substring(1)} $_anoSelecionado';
      case GraficoNivel.dia:
        final data = DateTime(
          _anoSelecionado,
          _mesSelecionado,
          _diaSelecionado,
        );
        return 'Gastos por forma - ${DateFormat('dd/MM/yyyy').format(data)}';
    }
  }

  Widget _buildHeaderFiltro() {
    switch (_nivel) {
      case GraficoNivel.ano:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _anoAnterior,
            ),
            Text(
              'Ano $_anoSelecionado',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _proximoAno,
            ),
          ],
        );

      case GraficoNivel.mes:
        final mesNome = DateFormat(
          'MMMM',
          'pt_BR',
        ).format(DateTime(_anoSelecionado, _mesSelecionado, 1));
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _mesAnterior,
            ),
            Column(
              children: [
                const Text(
                  'Mês selecionado',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  '${mesNome[0].toUpperCase()}${mesNome.substring(1)} '
                  '$_anoSelecionado',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _proximoMes,
            ),
          ],
        );

      case GraficoNivel.dia:
        final data = DateTime(
          _anoSelecionado,
          _mesSelecionado,
          _diaSelecionado,
        );
        return Center(
          child: Text(
            DateFormat('dd/MM/yyyy').format(data),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        );
    }
  }

  Widget _buildChartAtual() {
    switch (_nivel) {
      case GraficoNivel.ano:
        return _buildChartAno();
      case GraficoNivel.mes:
        return _buildChartMes();
      case GraficoNivel.dia:
        return _buildChartDia();
    }
  }

  // =================== GRÁFICO ANO (barras por mês) ===================

  Widget _buildChartAno() {
    if (_totaisPorMes.isEmpty) {
      return const Center(child: Text('Nenhum lançamento neste ano.'));
    }

    final grupos =
        _totaisPorMes.entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final maxValor = _totaisPorMes.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValor == 0 ? 100 : maxValor * 1.2,
        barGroups: grupos,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final mes = value.toInt();
                final nomeMes = DateFormat(
                  'MMM',
                  'pt_BR',
                ).format(DateTime(_anoSelecionado, mes, 1));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    nomeMes.substring(0, 3).toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: _leftTitleBuilder,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              return;
            }
            final mes = response.spot!.touchedBarGroup.x.toInt();
            _mesSelecionado = mes;
            _carregarMes();
          },
        ),
      ),
    );
  }

  // =================== GRÁFICO MÊS (barras por dia) ===================

  Widget _buildChartMes() {
    if (_totaisPorDia.isEmpty) {
      return const Center(child: Text('Nenhum lançamento neste mês.'));
    }

    final grupos =
        _totaisPorDia.entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final maxValor = _totaisPorDia.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValor == 0 ? 100 : maxValor * 1.2,
        barGroups: grupos,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final dia = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dia.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: _leftTitleBuilder,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              return;
            }
            final dia = response.spot!.touchedBarGroup.x.toInt();
            _diaSelecionado = dia;
            _carregarDia();
          },
        ),
      ),
    );
  }

  // =================== GRÁFICO DIA (barras por forma de pagamento) ===================

  Widget _buildChartDia() {
    if (_totaisPorForma.isEmpty) {
      return const Center(child: Text('Nenhum lançamento neste dia.'));
    }

    final formas = FormaPagamento.values.toList();

    final grupos = <BarChartGroupData>[];
    for (var i = 0; i < formas.length; i++) {
      final forma = formas[i];
      final valor = _totaisPorForma[forma] ?? 0;

      if (valor == 0) continue;

      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: valor, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      );
    }

    if (grupos.isEmpty) {
      return const Center(child: Text('Nenhum valor nas formas usadas.'));
    }

    final maxValor = _totaisPorForma.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValor == 0 ? 100 : maxValor * 1.2,
        barGroups: grupos,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= formas.length) {
                  return const SizedBox.shrink();
                }
                final forma = formas[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    forma.name,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: _leftTitleBuilder,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }

  // =================== HELPERS ===================

  Widget _leftTitleBuilder(double value, TitleMeta meta) {
    if (value == 0) return const SizedBox.shrink();
    return Text(_currency.format(value), style: const TextStyle(fontSize: 9));
  }
}
