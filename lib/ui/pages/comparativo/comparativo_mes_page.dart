// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

// ⭐ NOVO: categorias personalizadas
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';

enum TipoComparativoMes { categoria, formaPagamento }

class _SerieSemana {
  final DateTime inicio;
  final DateTime fim;
  final Color cor;
  final String label; // "S1", "S2"...
  final Map<int, double> valoresPorDiaSemana; // weekday 1..7 (Seg..Dom)

  _SerieSemana({
    required this.inicio,
    required this.fim,
    required this.cor,
    required this.label,
    required this.valoresPorDiaSemana,
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

class _FiltroSubcategoria {
  final int? idSubcategoriaPersonalizada;
  final String label;
  final bool todas;
  final bool semSubcategoria;

  const _FiltroSubcategoria({
    required this.idSubcategoriaPersonalizada,
    required this.label,
    required this.todas,
    required this.semSubcategoria,
  });

  factory _FiltroSubcategoria.todas() => const _FiltroSubcategoria(
        idSubcategoriaPersonalizada: null,
        label: 'Todas',
        todas: true,
        semSubcategoria: false,
      );

  factory _FiltroSubcategoria.semSubcategoria() => const _FiltroSubcategoria(
        idSubcategoriaPersonalizada: null,
        label: '— Sem subcategoria —',
        todas: false,
        semSubcategoria: true,
      );

  factory _FiltroSubcategoria.fromPersonalizada(SubcategoriaPersonalizada sub) =>
      _FiltroSubcategoria(
        idSubcategoriaPersonalizada: sub.id,
        label: sub.nome,
        todas: false,
        semSubcategoria: false,
      );

  bool get eTodas => todas;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FiltroSubcategoria &&
        other.idSubcategoriaPersonalizada == idSubcategoriaPersonalizada &&
        other.todas == todas &&
        other.semSubcategoria == semSubcategoria;
  }

  @override
  int get hashCode =>
      Object.hash(idSubcategoriaPersonalizada, todas, semSubcategoria);
}

class ComparativoMesPage extends StatefulWidget {
  const ComparativoMesPage({super.key});

  @override
  State<ComparativoMesPage> createState() => _ComparativoMesPageState();
}

class _ComparativoMesPageState extends State<ComparativoMesPage> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  // paleta simples para semanas (até ~6)
  final List<Color> _paletaSemanas = const [
    Color(0xFF1976D2), // azul
    Color(0xFF43A047), // verde
    Color(0xFFFBC02D), // amarelo
    Color(0xFF8E24AA), // roxo
    Color(0xFFE53935), // vermelho
    Color(0xFF00838F), // teal
  ];

  final LancamentoRepository _repository = LancamentoRepository();

  // ⭐ NOVO: repo de categorias personalizadas
  final CategoriaPersonalizadaRepository _categoriaRepo =
      CategoriaPersonalizadaRepository();
  final SubcategoriaPersonalizadaRepository _subcategoriaRepo =
      SubcategoriaPersonalizadaRepository();

  TipoComparativoMes _tipo = TipoComparativoMes.categoria;

  // 🔹 AJUSTE: agora usamos um filtro genérico em vez de Categoria?
  _FiltroCategoria _filtroCategoriaSelecionado = _FiltroCategoria.todas();
  _FiltroSubcategoria _filtroSubcategoriaSelecionado =
      _FiltroSubcategoria.todas();

  FormaPagamento? _formaPagamentoSelecionada;

  late DateTime _mesBase;

  bool _carregando = false;
  List<_SerieSemana> _seriesSemanais = [];
  int _maxX = 7;

  // ⭐ NOVO: cache de categorias personalizadas
  List<CategoriaPersonalizada> _categoriasPersonalizadas = [];
  List<SubcategoriaPersonalizada> _subcategorias = [];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesBase = DateTime(agora.year, agora.month, 1);

    _carregarCategoriasPersonalizadas(); // ⭐
    _carregarSubcategorias(); // ⭐
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

  Future<void> _carregarSubcategorias() async {
    try {
      final subs = await _subcategoriaRepo.listarTodasComCategoriaTipo();
      if (!mounted) return;
      setState(() {
        _subcategorias = subs;
        if (_filtroSubcategoriaSelecionado.idSubcategoriaPersonalizada != null) {
          final existe = subs.any(
            (s) => s.id == _filtroSubcategoriaSelecionado.idSubcategoriaPersonalizada,
          );
          if (!existe) _filtroSubcategoriaSelecionado = _FiltroSubcategoria.todas();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subcategorias = [];
        _filtroSubcategoriaSelecionado = _FiltroSubcategoria.todas();
      });
    }
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  DateTime _inicioSemana(DateTime base) {
    final d = DateTime(base.year, base.month, base.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  List<DateTime> _iniciosSemanasDoMes(DateTime mesRef) {
    final inicioMes = DateTime(mesRef.year, mesRef.month, 1);
    final fimMes = DateTime(mesRef.year, mesRef.month + 1, 0, 23, 59, 59);
    final firstWeekStart = _inicioSemana(inicioMes);

    final starts = <DateTime>[];
    var cur = firstWeekStart;
    while (cur.isBefore(fimMes) || cur.isAtSameMomentAs(fimMes)) {
      starts.add(cur);
      cur = cur.add(const Duration(days: 7));
    }
    return starts;
  }

  int _indiceSemanaNoMes(DateTime data, List<DateTime> weekStarts) {
    final d = DateTime(data.year, data.month, data.day);
    for (var i = 0; i < weekStarts.length; i++) {
      final ini = weekStarts[i];
      final fim = ini.add(const Duration(days: 7));
      if (!d.isBefore(ini) && d.isBefore(fim)) return i + 1; // 1..n
    }
    return 1;
  }

  bool _passaFiltrosLancamento(l) {
    if (l.pagamentoFatura) return false;

    if (_tipo == TipoComparativoMes.categoria &&
        !_filtroCategoriaSelecionado.eTodas) {
      final filtro = _filtroCategoriaSelecionado;
      if (filtro.idCategoriaPersonalizada != null) {
        if (l.idCategoriaPersonalizada != filtro.idCategoriaPersonalizada) {
          return false;
        }

        // filtro extra: subcategoria personalizada (apenas quando a categoria
        // selecionada é personalizada)
        if (!_filtroSubcategoriaSelecionado.eTodas) {
          if (l.idSubcategoriaPersonalizada !=
              _filtroSubcategoriaSelecionado.idSubcategoriaPersonalizada) {
            return false;
          }
        }
      } else if (filtro.categoriaEnum != null) {
        if (l.categoria != filtro.categoriaEnum) return false;
      }
    }

    if (!_filtroSubcategoriaSelecionado.eTodas) {
      if (_filtroSubcategoriaSelecionado.semSubcategoria) {
        if (l.idSubcategoriaPersonalizada != null) return false;
      } else {
        if (l.idSubcategoriaPersonalizada !=
            _filtroSubcategoriaSelecionado.idSubcategoriaPersonalizada) {
          return false;
        }
      }
    }

    if (_tipo == TipoComparativoMes.formaPagamento &&
        _formaPagamentoSelecionada != null &&
        l.formaPagamento != _formaPagamentoSelecionada) {
      return false;
    }

    return true;
  }

  Future<List<_SerieSemana>> _carregarSeriesSemanaisDoMes({
    required DateTime mesRef,
  }) async {
    final ano = mesRef.year;
    final mes = mesRef.month;

    final inicioMes = DateTime(ano, mes, 1);
    final fimMes = DateTime(ano, mes + 1, 0, 23, 59, 59);

    final lancs = await _repository.getDespesasByPeriodo(inicioMes, fimMes);
    final filtrados = lancs.where(_passaFiltrosLancamento).toList();

    final weekStarts = _iniciosSemanasDoMes(mesRef);
    final Map<int, Map<int, double>> porSemanaEDia = {};

    for (final l in filtrados) {
      final idxSemana = _indiceSemanaNoMes(l.dataHora, weekStarts); // 1..n
      final weekday = l.dataHora.weekday; // 1..7 (seg..dom)
      final mapaDia = porSemanaEDia.putIfAbsent(idxSemana, () => {});
      mapaDia.update(weekday, (v) => v + l.valor, ifAbsent: () => l.valor);
    }

    final series = <_SerieSemana>[];
    for (var i = 0; i < weekStarts.length; i++) {
      final idx = i + 1;
      final inicio = weekStarts[i];
      final fim = inicio.add(const Duration(days: 6));
      final valores = porSemanaEDia[idx] ?? {};
      final cor = _paletaSemanas[i % _paletaSemanas.length];
      series.add(
        _SerieSemana(
          inicio: inicio,
          fim: fim,
          cor: cor,
          label: 'S$idx',
          valoresPorDiaSemana: valores,
        ),
      );
    }

    // remove semanas totalmente vazias
    series.removeWhere((s) =>
        s.valoresPorDiaSemana.values.fold<double>(0, (a, b) => a + b) == 0);

    return series;
  }

  Future<void> _recarregarDados() async {
    setState(() {
      _carregando = true;
    });
    setState(() {
      _seriesSemanais = [];
      _maxX = 7;
      _carregando = false;
    });

    try {
      final series = await _carregarSeriesSemanaisDoMes(mesRef: _mesBase);
      if (!mounted) return;
      setState(() {
        _seriesSemanais = series;
        _maxX = 7;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  // ============ GRÁFICO DE LINHAS ============

  List<FlSpot> _spotsFromSerieSemana(_SerieSemana serie) {
    final List<FlSpot> spots = [];
    final diasOrdenados = serie.valoresPorDiaSemana.keys.toList()..sort();
    for (final diaSemana in diasOrdenados) {
      final valor = serie.valoresPorDiaSemana[diaSemana] ?? 0.0;
      if (valor == 0) continue;
      spots.add(FlSpot(diaSemana.toDouble(), valor));
    }
    return spots;
  }

  String _labelDiaSemana(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '$weekday';
    }
  }

  LineChartData _buildLineChartData() {
    final List<LineChartBarData> lines = [];

    for (final s in _seriesSemanais) {
      lines.add(
        LineChartBarData(
          spots: _spotsFromSerieSemana(s),
          isCurved: true,
          color: s.cor,
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return LineChartData(
      lineBarsData: lines,
      minX: 1,
      maxX: _maxX.toDouble(),
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
            interval: 1,
            getTitlesWidget: (value, meta) {
              final v = value.toInt();
              if (v < 1 || v > _maxX) return const SizedBox.shrink();
              return Text(
                _labelDiaSemana(v),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============ DETALHAMENTO SEMANAL (BOTTOM SHEET) ============

  void _mostrarDetalhamentoSemanal() {
    if (_seriesSemanais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem dados para detalhar com os filtros atuais.')),
      );
      return;
    }

    final tema = Theme.of(context);
    final header = '${_nomeMes(_mesBase.month)} / ${_mesBase.year}';
    final fmt = DateFormat('dd/MM');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final safeBottom = MediaQuery.of(context).padding.bottom;
            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: tema.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                          'Detalhamento por semana (Seg–Dom)',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          header,
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
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safeBottom),
                      itemCount: _seriesSemanais.length,
                      itemBuilder: (context, index) {
                        final s = _seriesSemanais[index];
                        final totalSemana = s.valoresPorDiaSemana.values.fold<double>(
                          0,
                          (a, b) => a + b,
                        );
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: tema.colorScheme.surfaceVariant.withOpacity(0.25),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: s.cor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${s.label} • ${fmt.format(s.inicio)}-${fmt.format(s.fim)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _currency.format(totalSemana),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: List.generate(7, (i) {
                                  final wd = i + 1;
                                  final v = s.valoresPorDiaSemana[wd] ?? 0.0;
                                  return SizedBox(
                                    width: 96,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _labelDiaSemana(wd),
                                          style: tema.textTheme.bodySmall?.copyWith(
                                            color: tema.colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _currency.format(v),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  ],
                ),
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

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double chartHeight = isLandscape ? 220 : 280;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparativo semanal do mês'),
      ),
      drawer: const AppDrawer(currentRoute: '/comparativo-mes'),
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
            const SizedBox(height: 12),

            // ===== FILTROS (COMPACTO) =====
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: tema.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  initiallyExpanded: false,
                  title: const Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _tipo == TipoComparativoMes.categoria
                        ? 'Categoria/Subcategoria'
                        : 'Forma de pagamento',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                  children: [
                    DropdownButtonFormField<TipoComparativoMes>(
                      isDense: true,
                      value: _tipo,
                      decoration: const InputDecoration(
                        labelText: 'Comparar por',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                          _filtroSubcategoriaSelecionado =
                              _FiltroSubcategoria.todas();
                          _formaPagamentoSelecionada = null;
                        });
                        _recarregarDados();
                      },
                    ),
                    const SizedBox(height: 10),
                    _tipo == TipoComparativoMes.categoria
                        ? Column(
                            children: [
                              DropdownButtonFormField<_FiltroCategoria>(
                                isDense: true,
                                value: _filtroCategoriaSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Categoria',
                                  border: OutlineInputBorder(),
                                  isDense: true,
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
                                        value:
                                            _FiltroCategoria.fromPersonalizada(
                                          cat,
                                        ),
                                        child: Text(cat.nome),
                                      ),
                                    ),
                                  ],
                                ],
                                onChanged: (novoFiltro) {
                                  if (novoFiltro == null) return;
                                  setState(() {
                                    _filtroCategoriaSelecionado = novoFiltro;
                                    _filtroSubcategoriaSelecionado =
                                        _FiltroSubcategoria.todas();
                                  });
                                  _recarregarDados();
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<_FiltroSubcategoria>(
                                isDense: true,
                                value: _filtroSubcategoriaSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Subcategoria',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: _FiltroSubcategoria.todas(),
                                    child: const Text('Todas'),
                                  ),
                                  DropdownMenuItem(
                                    value: _FiltroSubcategoria.semSubcategoria(),
                                    child: const Text('— Sem subcategoria —'),
                                  ),
                                  ..._subcategorias.map(
                                    (s) => DropdownMenuItem(
                                      value:
                                          _FiltroSubcategoria.fromPersonalizada(
                                        s,
                                      ),
                                      child: Text(s.nome),
                                    ),
                                  ),
                                ],
                                onChanged: (novo) {
                                  if (novo == null) return;
                                  setState(
                                    () =>
                                        _filtroSubcategoriaSelecionado = novo,
                                  );
                                  _recarregarDados();
                                },
                              ),
                            ],
                          )
                        : DropdownButtonFormField<FormaPagamento?>(
                            isDense: true,
                            value: _formaPagamentoSelecionada,
                            decoration: const InputDecoration(
                              labelText: 'Forma pgto',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todas'),
                              ),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_carregando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_seriesSemanais.isEmpty)
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
                    onTap: _mostrarDetalhamentoSemanal,
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
                  onPressed: _mostrarDetalhamentoSemanal,
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('Ver semanas', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 4),

              // LEGENDA
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _seriesSemanais.map((s) {
                  final fmt = DateFormat('dd/MM');
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.cor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.label} (${fmt.format(s.inicio)}-${fmt.format(s.fim)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Text(
                labelBase,
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
