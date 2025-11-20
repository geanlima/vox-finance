import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

enum TipoAgrupamentoPizza { categoria, formaPagamento }

class GraficoPizzaComponent extends StatefulWidget {
  const GraficoPizzaComponent({
    super.key,
    this.considerarSomentePagos = true,
    this.ignorarPagamentoFatura = true,
  });

  final bool considerarSomentePagos;
  final bool ignorarPagamentoFatura;

  @override
  State<GraficoPizzaComponent> createState() => _GraficoPizzaComponentState();
}

class _GraficoPizzaComponentState extends State<GraficoPizzaComponent> {
  final _db = DbService();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  // 🔹 Ano / mês selecionados + anos disponíveis
  late int _anoSelecionado;
  int _mesSelecionado = DateTime.now().month;
  late final List<int> _anosDisponiveis;

  TipoAgrupamentoPizza _tipo = TipoAgrupamentoPizza.categoria;

  bool _carregando = false;
  List<Lancamento> _lancamentos = [];

  final List<Color> _palette = const [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFFC107),
    Color(0xFFF44336),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFF3F51B5),
    Color(0xFF795548),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF8BC34A),
    Color(0xFF673AB7),
  ];

  Color _colorForIndex(int index) => _palette[index % _palette.length];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _anoSelecionado = agora.year;

    _anosDisponiveis = List<int>.generate(
      9, // 5 anos atrás + ano atual + 3 à frente
      (i) => agora.year - 5 + i,
    );

    _carregarDados();
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    final inicioMes = DateTime(_anoSelecionado, _mesSelecionado, 1);
    final fimMes = DateTime(
      _anoSelecionado,
      _mesSelecionado + 1,
      0,
      23,
      59,
      59,
    );

    final lista = await _db.getLancamentosByPeriodo(inicioMes, fimMes);

    Iterable<Lancamento> filtrados = lista;

    if (widget.considerarSomentePagos) {
      filtrados = filtrados.where((l) => l.pago);
    }

    if (widget.ignorarPagamentoFatura) {
      filtrados = filtrados.where((l) => !l.pagamentoFatura);
    }

    setState(() {
      _lancamentos = filtrados.toList();
      _carregando = false;
    });
  }

  // ======= TOTAIS =======

  double get _totalMes =>
      _lancamentos.fold<double>(0.0, (acc, l) => acc + l.valor);

  Map<Categoria, double> _totaisPorCategoria() {
    final Map<Categoria, double> totais = {};
    for (final l in _lancamentos) {
      totais.update(l.categoria, (v) => v + l.valor, ifAbsent: () => l.valor);
    }
    return totais;
  }

  Map<FormaPagamento, double> _totaisPorFormaPagamento() {
    final Map<FormaPagamento, double> totais = {};
    for (final l in _lancamentos) {
      totais.update(
        l.formaPagamento,
        (v) => v + l.valor,
        ifAbsent: () => l.valor,
      );
    }
    return totais;
  }

  // ======= GRÁFICO =======

  List<PieChartSectionData> _buildSections() {
    if (_lancamentos.isEmpty) return [];

    if (_tipo == TipoAgrupamentoPizza.categoria) {
      final data = _totaisPorCategoria();
      final total = data.values.fold<double>(0.0, (a, b) => a + b);
      if (total == 0) return [];

      final entries = data.entries.toList();

      return List.generate(entries.length, (i) {
        final entry = entries[i];
        final valor = entry.value;
        final percent = (valor / total) * 100;
        final color = _colorForIndex(i);

        return PieChartSectionData(
          value: valor,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 80,
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: color,
        );
      });
    } else {
      final data = _totaisPorFormaPagamento();
      final total = data.values.fold<double>(0.0, (a, b) => a + b);
      if (total == 0) return [];

      final entries = data.entries.toList();

      return List.generate(entries.length, (i) {
        final entry = entries[i];
        final valor = entry.value;
        final percent = (valor / total) * 100;
        final color = _colorForIndex(i);

        return PieChartSectionData(
          value: valor,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 80,
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: color,
        );
      });
    }
  }

  // ======= RESUMO POR FORMA (MÊS) =======

  void _mostrarResumoPorFormaPagamentoMes() {
    if (_lancamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há lançamentos neste mês para detalhar.'),
        ),
      );
      return;
    }

    final totaisPorForma = _totaisPorFormaPagamento();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final mesAnoLabel = '${_nomeMes(_mesSelecionado)} / $_anoSelecionado';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gastos por forma de pagamento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                mesAnoLabel,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...totaisPorForma.entries.map((entry) {
                final forma = entry.key;
                final valor = entry.value;

                return ListTile(
                  leading: CircleAvatar(child: Icon(forma.icon, size: 18)),
                  title: Text(forma.label),
                  trailing: Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ======= BUILD =======

  @override
  Widget build(BuildContext context) {
    final labelMesAno = '${_nomeMes(_mesSelecionado)} / $_anoSelecionado';
    final totalMesFormatado = _currency.format(_totalMes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ====== FILTROS (2 linhas) ======
        Column(
          children: [
            // Linha 1: MÊS + ANO
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mesSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Mês',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(12, (i) {
                      final mes = i + 1;
                      return DropdownMenuItem(
                        value: mes,
                        child: Text(_nomeMes(mes)),
                      );
                    }),
                    onChanged: (novoMes) {
                      if (novoMes == null) return;
                      setState(() => _mesSelecionado = novoMes);
                      _carregarDados();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _anoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Ano',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items:
                        _anosDisponiveis
                            .map(
                              (ano) => DropdownMenuItem(
                                value: ano,
                                child: Text(ano.toString()),
                              ),
                            )
                            .toList(),
                    onChanged: (novoAno) {
                      if (novoAno == null) return;
                      setState(() => _anoSelecionado = novoAno);
                      _carregarDados();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Linha 2: AGRUPAR POR
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TipoAgrupamentoPizza>(
                    value: _tipo,
                    decoration: const InputDecoration(
                      labelText: 'Agrupar por',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TipoAgrupamentoPizza.categoria,
                        child: Text('Categoria'),
                      ),
                      DropdownMenuItem(
                        value: TipoAgrupamentoPizza.formaPagamento,
                        child: Text('Forma pgto'),
                      ),
                    ],
                    onChanged: (novo) {
                      if (novo == null) return;
                      setState(() => _tipo = novo);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // MÊS / ANO
        Text(
          labelMesAno,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // ====== TOTAL GASTO NO MÊS (CLICÁVEL) ======
        InkWell(
          onTap: _mostrarResumoPorFormaPagamentoMes,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.summarize,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Total gasto no mês:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  totalMesFormatado,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_carregando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_lancamentos.isEmpty)
          const Expanded(
            child: Center(child: Text('Sem lançamentos neste período.')),
          )
        else ...[
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sections: _buildSections(),
                sectionsSpace: 2,
                centerSpaceRadius: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _tipo == TipoAgrupamentoPizza.categoria
                    ? _buildLegendaCategoria()
                    : _buildLegendaFormaPagamento(),
          ),
        ],
      ],
    );
  }

  // ======= LEGENDAS =======

  Widget _buildLegendaCategoria() {
    final data = _totaisPorCategoria();
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final cat = entry.key;
        final valor = entry.value;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return ListTile(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          title: Text(CategoriaService.toName(cat)),
          subtitle: Text('${percent.toStringAsFixed(1)}%'),
          trailing: Text(
            _currency.format(valor),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildLegendaFormaPagamento() {
    final data = _totaisPorFormaPagamento();
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final forma = entry.key;
        final valor = entry.value;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Icon(forma.icon, size: 18),
            ],
          ),
          title: Text(forma.label),
          subtitle: Text('${percent.toStringAsFixed(1)}%'),
          trailing: Text(
            _currency.format(valor),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
