// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

// ⭐ NOVO: categorias personalizadas
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';

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

// ⭐ NOVO: filtro de categoria (enum + personalizada + "todas")
class _FiltroCategoria {
  final int? idCategoriaPersonalizada;
  final Categoria? categoriaEnum;
  final String label;
  final bool todas;

  const _FiltroCategoria({
    required this.idCategoriaPersonalizada,
    required this.categoriaEnum,
    required this.label,
    required this.todas,
  });

  factory _FiltroCategoria.todas() => const _FiltroCategoria(
    idCategoriaPersonalizada: null,
    categoriaEnum: null,
    label: 'Todas',
    todas: true,
  );

  factory _FiltroCategoria.fromEnum(Categoria c) => _FiltroCategoria(
    idCategoriaPersonalizada: null,
    categoriaEnum: c,
    label: CategoriaService.toName(c),
    todas: false,
  );

  factory _FiltroCategoria.fromPersonalizada(CategoriaPersonalizada cat) =>
      _FiltroCategoria(
        idCategoriaPersonalizada: cat.id,
        categoriaEnum: null,
        label: cat.nome,
        todas: false,
      );

  bool get eTodas => todas;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FiltroCategoria &&
        other.idCategoriaPersonalizada == idCategoriaPersonalizada &&
        other.categoriaEnum == categoriaEnum &&
        other.todas == todas;
  }

  @override
  int get hashCode =>
      Object.hash(idCategoriaPersonalizada, categoriaEnum, todas);
}

class ComparativoMesPage extends StatefulWidget {
  const ComparativoMesPage({super.key});

  @override
  State<ComparativoMesPage> createState() => _ComparativoMesPageState();
}

class _ComparativoMesPageState extends State<ComparativoMesPage> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  // paleta simples para 3 linhas
  final Color _corBase = const Color(0xFF1976D2); // azul
  final Color _corComparacao = const Color(0xFFFBC02D); // amarelo
  final Color _corComparacao2 = const Color(0xFF43A047); // verde

  final LancamentoRepository _repository = LancamentoRepository();

  // ⭐ NOVO: repo de categorias personalizadas
  final CategoriaPersonalizadaRepository _categoriaRepo =
      CategoriaPersonalizadaRepository();

  TipoComparativoMes _tipo = TipoComparativoMes.categoria;

  // 🔹 AJUSTE: agora usamos um filtro genérico em vez de Categoria?
  _FiltroCategoria _filtroCategoriaSelecionado = _FiltroCategoria.todas();

  FormaPagamento? _formaPagamentoSelecionada;

  late DateTime _mesBase;
  DateTime? _mesComparacao;
  DateTime? _mesComparacao2; // 🔹 já existia

  bool _carregando = false;
  _SerieMes? _serieBase;
  _SerieMes? _serieComparacao;
  _SerieMes? _serieComparacao2; // 🔹 já existia
  int _maxDia = 31;

  // ⭐ NOVO: cache de categorias personalizadas
  List<CategoriaPersonalizada> _categoriasPersonalizadas = [];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesBase = DateTime(agora.year, agora.month, 1);
    _mesComparacao = null;
    _mesComparacao2 = null;

    _carregarCategoriasPersonalizadas(); // ⭐
    _recarregarDados();
  }

  Future<void> _carregarCategoriasPersonalizadas() async {
    try {
      // aqui assumo um listarTodas(); se você estiver usando listarPorTipo,
      // pode ajustar igual fez na tela do gráfico de pizza
      final lista = await _categoriaRepo.listarTodas();
      setState(() {
        _categoriasPersonalizadas = lista;
      });
    } catch (_) {
      // se der erro, simplesmente não mostra as personalizadas no filtro
    }
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

    final lancs = await _repository.getDespesasByPeriodo(inicioMes, fimMes);

    final filtrados =
        lancs.where((l) {
          if (!l.pago) return false;
          if (l.pagamentoFatura) return false;

          // 🔹 FILTRO POR CATEGORIA (agora com enum + personalizada)
          if (_tipo == TipoComparativoMes.categoria &&
              !_filtroCategoriaSelecionado.eTodas) {
            final filtro = _filtroCategoriaSelecionado;

            // se filtro for categoria personalizada
            if (filtro.idCategoriaPersonalizada != null) {
              if (l.idCategoriaPersonalizada !=
                  filtro.idCategoriaPersonalizada) {
                return false;
              }
            }
            // se filtro for categoria do enum
            else if (filtro.categoriaEnum != null) {
              // se lançamento está em categoria personalizada, não entra
              if (l.idCategoriaPersonalizada != null) return false;
              if (l.categoria != filtro.categoriaEnum) return false;
            }
          }

          // 🔹 FILTRO POR FORMA PGTO (mantido)
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

    _SerieMes? comp2;
    if (_mesComparacao2 != null) {
      comp = await _carregarSerieMes(
        mesRef: _mesComparacao2!,
        cor: _corComparacao2,
      );
      for (final d in comp.valoresPorDia.keys) {
        if (d > maxDia) maxDia = d;
      }
    }

    setState(() {
      _serieBase = base;
      _serieComparacao = comp;
      _serieComparacao2 = comp2;
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

    if (_serieComparacao2 != null) {
      lines.add(
        LineChartBarData(
          spots: _spotsFromSerie(_serieComparacao2!),
          isCurved: true,
          color: _serieComparacao2!.cor,
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
    if (_serieBase == null &&
        _serieComparacao == null &&
        _serieComparacao2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem dados para detalhar com os filtros atuais.'),
        ),
      );
      return;
    }

    final tema = Theme.of(context);
    final labelBase = '${_nomeMes(_mesBase.month)} / ${_mesBase.year}';
    final labelComp1 =
        _mesComparacao == null
            ? null
            : '${_nomeMes(_mesComparacao!.month)} / ${_mesComparacao!.year}';
    final labelComp2 =
        _mesComparacao2 == null
            ? null
            : '${_nomeMes(_mesComparacao2!.month)} / ${_mesComparacao2!.year}';

    final titulos = <String>[labelBase];
    if (labelComp1 != null) titulos.add(labelComp1);
    if (labelComp2 != null) titulos.add(labelComp2);

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
                          titulos.join('  ×  '),
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
                        final vComp1 =
                            _serieComparacao?.valoresPorDia[dia] ?? 0.0;
                        final vComp2 =
                            _serieComparacao2?.valoresPorDia[dia] ?? 0.0;

                        if (vBase == 0 && vComp1 == 0 && vComp2 == 0) {
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
                                    if (vComp1 > 0) ...[
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
                                                  'Mês comparação 1',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _currency.format(vComp1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (vComp2 > 0)
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _corComparacao2,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _serieComparacao2?.label ??
                                                  'Mês comparação 2',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _currency.format(vComp2),
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
    final labelComparacao1 =
        _mesComparacao == null
            ? 'Nenhum'
            : '${_nomeMes(_mesComparacao!.month)} / ${_mesComparacao!.year}';
    final labelComparacao2 =
        _mesComparacao2 == null
            ? 'Nenhum'
            : '${_nomeMes(_mesComparacao2!.month)} / ${_mesComparacao2!.year}';

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double chartHeight = isLandscape ? 220 : 280;

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

            // ===== COMPARAR COM (1) =====
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesComparacao?.month,
                    decoration: const InputDecoration(
                      labelText: 'Comparar mês 1',
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
                      labelText: 'Ano 1',
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

            const SizedBox(height: 8),

            // ===== COMPARAR COM (2) =====
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesComparacao2?.month,
                    decoration: const InputDecoration(
                      labelText: 'Comparar mês 2',
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
                          _mesComparacao2 = null;
                        } else {
                          _mesComparacao2 = DateTime(
                            _mesComparacao2?.year ?? _mesBase.year,
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
                    value: _mesComparacao2?.year,
                    decoration: const InputDecoration(
                      labelText: 'Ano 2',
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
                          _mesComparacao2 = null;
                        } else {
                          _mesComparacao2 = DateTime(
                            novoAno,
                            _mesComparacao2?.month ?? _mesBase.month,
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
                  _filtroCategoriaSelecionado = _FiltroCategoria.todas();
                  _formaPagamentoSelecionada = null;
                });
                _recarregarDados();
              },
            ),
            const SizedBox(height: 8),

            // 🔹 AJUSTE: dropdown de categoria agora mistura enum + personalizadas
            _tipo == TipoComparativoMes.categoria
                ? DropdownButtonFormField<_FiltroCategoria>(
                  value: _filtroCategoriaSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _FiltroCategoria.todas(),
                      child: const Text('Todas'),
                    ),
                    ...Categoria.values.map(
                      (c) => DropdownMenuItem(
                        value: _FiltroCategoria.fromEnum(c),
                        child: Text(CategoriaService.toName(c)),
                      ),
                    ),
                    if (_categoriasPersonalizadas.isNotEmpty) ...[
                      const DropdownMenuItem(
                        enabled: false,
                        value: null,
                        child: Text(
                          '--- Personalizadas ---',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      ..._categoriasPersonalizadas.map(
                        (cat) => DropdownMenuItem(
                          value: _FiltroCategoria.fromPersonalizada(cat),
                          child: Text(cat.nome),
                        ),
                      ),
                    ],
                  ],
                  onChanged: (novoFiltro) {
                    if (novoFiltro == null) return;
                    setState(() => _filtroCategoriaSelecionado = novoFiltro);
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
            else if (_serieBase == null &&
                _serieComparacao == null &&
                _serieComparacao2 == null)
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
                    const SizedBox(width: 12),
                  ],
                  if (_serieComparacao2 != null) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _corComparacao2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _serieComparacao2!.label,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Base: $labelBase • Comp.1: $labelComparacao1 • Comp.2: $labelComparacao2',
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
