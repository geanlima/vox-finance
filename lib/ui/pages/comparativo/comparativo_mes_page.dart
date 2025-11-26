// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

enum TipoComparativoMes { categoria, formaPagamento }

class _SerieMes {
  final int ano;
  final int mes;
  final Color cor;
  final String label;
  final Map<int, double> valoresPorDia; // dia -> total

  _SerieMes({
    required this.ano,
    required this.mes,
    required this.cor,
    required this.label,
    required this.valoresPorDia,
  });
}

class ComparativoMesPage extends StatefulWidget {
  const ComparativoMesPage({super.key});

  @override
  State<ComparativoMesPage> createState() => _ComparativoMesPageState();
}

class _ComparativoMesPageState extends State<ComparativoMesPage> {
  final _db = DbService();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  // paleta simples para 2 linhas
  final Color _corBase = const Color(0xFF1976D2); // azul
  final Color _corComparacao = const Color(0xFFFBC02D); // amarelo

  TipoComparativoMes _tipo = TipoComparativoMes.categoria;
  Categoria? _categoriaSelecionada;
  FormaPagamento? _formaPagamentoSelecionada;

  late DateTime _mesBase;
  DateTime? _mesComparacao;

  bool _carregando = false;
  _SerieMes? _serieBase;
  _SerieMes? _serieComparacao;
  int _maxDia = 31;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesBase = DateTime(agora.year, agora.month, 1);
    _mesComparacao = null;
    _recarregarDados();
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Future<_SerieMes> _carregarSerieMes({
    required DateTime mesRef,
    required Color cor,
  }) async {
    final ano = mesRef.year;
    final mes = mesRef.month;

    final inicioMes = DateTime(ano, mes, 1);
    final fimMes = DateTime(ano, mes + 1, 0, 23, 59, 59);

    final lancs = await _db.getLancamentosByPeriodo(inicioMes, fimMes);

    final filtrados =
        lancs.where((l) {
          if (!l.pago) return false;
          if (l.pagamentoFatura) return false;

          if (_tipo == TipoComparativoMes.categoria &&
              _categoriaSelecionada != null &&
              l.categoria != _categoriaSelecionada) {
            return false;
          }

          if (_tipo == TipoComparativoMes.formaPagamento &&
              _formaPagamentoSelecionada != null &&
              l.formaPagamento != _formaPagamentoSelecionada) {
            return false;
          }

          return true;
        }).toList();

    final Map<int, double> valoresPorDia = {};
    for (final l in filtrados) {
      final dia = l.dataHora.day;
      valoresPorDia.update(dia, (v) => v + l.valor, ifAbsent: () => l.valor);
    }

    final label = '${_nomeMes(mes)} / $ano';

    return _SerieMes(
      ano: ano,
      mes: mes,
      cor: cor,
      label: label,
      valoresPorDia: valoresPorDia,
    );
  }

  Future<void> _recarregarDados() async {
    setState(() {
      _carregando = true;
    });

    int maxDia = 1;

    final base = await _carregarSerieMes(mesRef: _mesBase, cor: _corBase);
    for (final d in base.valoresPorDia.keys) {
      if (d > maxDia) maxDia = d;
    }

    _SerieMes? comp;
    if (_mesComparacao != null) {
      comp = await _carregarSerieMes(
        mesRef: _mesComparacao!,
        cor: _corComparacao,
      );
      for (final d in comp.valoresPorDia.keys) {
        if (d > maxDia) maxDia = d;
      }
    }

    setState(() {
      _serieBase = base;
      _serieComparacao = comp;
      _maxDia = maxDia;
      _carregando = false;
    });
  }

  // ============ GRÁFICO DE LINHAS ============

  List<FlSpot> _spotsFromSerie(_SerieMes serie) {
    final List<FlSpot> spots = [];
    final diasOrdenados = serie.valoresPorDia.keys.toList()..sort();
    for (final dia in diasOrdenados) {
      final valor = serie.valoresPorDia[dia] ?? 0.0;
      if (valor == 0) continue;
      spots.add(FlSpot(dia.toDouble(), valor));
    }
    return spots;
  }

  LineChartData _buildLineChartData() {
    final List<LineChartBarData> lines = [];

    if (_serieBase != null) {
      lines.add(
        LineChartBarData(
          spots: _spotsFromSerie(_serieBase!),
          isCurved: true,
          color: _serieBase!.cor,
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (_serieComparacao != null) {
      lines.add(
        LineChartBarData(
          spots: _spotsFromSerie(_serieComparacao!),
          isCurved: true,
          color: _serieComparacao!.cor,
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return LineChartData(
      lineBarsData: lines,
      minX: 1,
      maxX: _maxDia.toDouble(),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                _currency.format(value).replaceAll('R\$', '').trim(),
                style: const TextStyle(fontSize: 9),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: (_maxDia > 15) ? 2 : 1,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============ DETALHAMENTO DIA A DIA (BOTTOM SHEET) ============

  void _mostrarDetalhamentoDiaADia() {
    if (_serieBase == null && _serieComparacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem dados para detalhar com os filtros atuais.'),
        ),
      );
      return;
    }

    final tema = Theme.of(context);
    final labelBase = '${_nomeMes(_mesBase.month)} / ${_mesBase.year}';
    final labelComp =
        _mesComparacao == null
            ? null
            : '${_nomeMes(_mesComparacao!.month)} / ${_mesComparacao!.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalhamento dia a dia',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labelComp == null
                              ? labelBase
                              : '$labelBase  ×  $labelComp',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _maxDia,
                      itemBuilder: (context, index) {
                        final dia = index + 1;
                        final vBase = _serieBase?.valoresPorDia[dia] ?? 0.0;
                        final vComp =
                            _serieComparacao?.valoresPorDia[dia] ?? 0.0;

                        if (vBase == 0 && vComp == 0) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: tema.colorScheme.surfaceVariant.withOpacity(
                              0.25,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  dia.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (vBase > 0) ...[
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _corBase,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _serieBase?.label ?? 'Mês base',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _currency.format(vBase),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (vComp > 0)
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _corComparacao,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _serieComparacao?.label ??
                                                  'Mês comparação',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _currency.format(vComp),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
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

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final labelBase = '${_nomeMes(_mesBase.month)} / ${_mesBase.year}';
    final labelComparacao =
        _mesComparacao == null
            ? 'Nenhum'
            : '${_nomeMes(_mesComparacao!.month)} / ${_mesComparacao!.year}';

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double chartHeight = isLandscape ? 220 : 280; // 🔺 aumentei

    return Scaffold(
      appBar: AppBar(title: const Text('Comparativo de meses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== MÊS BASE =====
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesBase.month,
                    decoration: const InputDecoration(
                      labelText: 'Mês base',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_nomeMes(i + 1)),
                      ),
                    ),
                    onChanged: (novoMes) {
                      if (novoMes == null) return;
                      setState(() {
                        _mesBase = DateTime(_mesBase.year, novoMes, 1);
                      });
                      _recarregarDados();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesBase.year,
                    decoration: const InputDecoration(
                      labelText: 'Ano base',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(10, (i) {
                      final ano = DateTime.now().year - 5 + i;
                      return DropdownMenuItem(value: ano, child: Text('$ano'));
                    }),
                    onChanged: (novoAno) {
                      if (novoAno == null) return;
                      setState(() {
                        _mesBase = DateTime(novoAno, _mesBase.month, 1);
                      });
                      _recarregarDados();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ===== COMPARAR COM =====
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesComparacao?.month,
                    decoration: const InputDecoration(
                      labelText: 'Comparar mês',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Nenhum'),
                      ),
                      ...List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_nomeMes(i + 1)),
                        ),
                      ),
                    ],
                    onChanged: (novoMes) {
                      setState(() {
                        if (novoMes == null) {
                          _mesComparacao = null;
                        } else {
                          _mesComparacao = DateTime(
                            _mesComparacao?.year ?? _mesBase.year,
                            novoMes,
                            1,
                          );
                        }
                      });
                      _recarregarDados();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesComparacao?.year,
                    decoration: const InputDecoration(
                      labelText: 'Comparar ano',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Nenhum'),
                      ),
                      ...List.generate(10, (i) {
                        final ano = DateTime.now().year - 5 + i;
                        return DropdownMenuItem(
                          value: ano,
                          child: Text('$ano'),
                        );
                      }),
                    ],
                    onChanged: (novoAno) {
                      setState(() {
                        if (novoAno == null) {
                          _mesComparacao = null;
                        } else {
                          _mesComparacao = DateTime(
                            novoAno,
                            _mesComparacao?.month ?? _mesBase.month,
                            1,
                          );
                        }
                      });
                      _recarregarDados();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ===== TIPO + FILTRO =====
            DropdownButtonFormField<TipoComparativoMes>(
              value: _tipo,
              decoration: const InputDecoration(
                labelText: 'Comparar por',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: TipoComparativoMes.categoria,
                  child: Text('Categoria'),
                ),
                DropdownMenuItem(
                  value: TipoComparativoMes.formaPagamento,
                  child: Text('Forma de pagamento'),
                ),
              ],
              onChanged: (novo) {
                if (novo == null) return;
                setState(() {
                  _tipo = novo;
                  _categoriaSelecionada = null;
                  _formaPagamentoSelecionada = null;
                });
                _recarregarDados();
              },
            ),
            const SizedBox(height: 8),
            _tipo == TipoComparativoMes.categoria
                ? DropdownButtonFormField<Categoria?>(
                  value: _categoriaSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...Categoria.values.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(CategoriaService.toName(c)),
                      ),
                    ),
                  ],
                  onChanged: (nova) {
                    setState(() => _categoriaSelecionada = nova);
                    _recarregarDados();
                  },
                )
                : DropdownButtonFormField<FormaPagamento?>(
                  value: _formaPagamentoSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Forma pgto',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...FormaPagamento.values.map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            Icon(f.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(f.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (nova) {
                    setState(() => _formaPagamentoSelecionada = nova);
                    _recarregarDados();
                  },
                ),

            const SizedBox(height: 16),

            if (_carregando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_serieBase == null && _serieComparacao == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Sem dados para os filtros selecionados.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              // GRÁFICO (CLICÁVEL)
              SizedBox(
                height: chartHeight,
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _mostrarDetalhamentoDiaADia,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LineChart(_buildLineChartData()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _mostrarDetalhamentoDiaADia,
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text(
                    'Ver dia a dia',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // LEGENDA
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _corBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _serieBase?.label ?? labelBase,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  if (_serieComparacao != null) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _corComparacao,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _serieComparacao!.label,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Base: $labelBase • Comparação: $labelComparacao',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
