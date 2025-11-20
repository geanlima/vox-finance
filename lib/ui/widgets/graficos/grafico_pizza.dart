import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

enum TipoAgrupamentoPizza {
  categoria,
  formaPagamento,
}

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

  // Ano fixo = ano atual
  late final int _anoAtual;
  int _mesSelecionado = DateTime.now().month;

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
    _anoAtual = DateTime.now().year;
    _carregarDados();
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    final inicioMes = DateTime(_anoAtual, _mesSelecionado, 1);
    final fimMes = DateTime(_anoAtual, _mesSelecionado + 1, 0, 23, 59, 59);

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
      totais.update(l.formaPagamento, (v) => v + l.valor, ifAbsent: () => l.valor);
    }
    return totais;
  }

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

  @override
  Widget build(BuildContext context) {
    final labelMesAno = '${_nomeMes(_mesSelecionado)} / $_anoAtual';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ====== FILTROS: MÊS DO ANO + AGRUPAMENTO ======
        Row(
          children: [
            // MÊS DO ANO
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
                  setState(() {
                    _mesSelecionado = novoMes;
                  });
                  _carregarDados();
                },
              ),
            ),
            const SizedBox(width: 8),

            // TIPO AGRUPAMENTO
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
                  setState(() {
                    _tipo = novo;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          labelMesAno,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        if (_carregando)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_lancamentos.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Sem lançamentos neste período.'),
            ),
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
            child: _tipo == TipoAgrupamentoPizza.categoria
                ? _buildLegendaCategoria()
                : _buildLegendaFormaPagamento(),
          ),
        ],
      ],
    );
  }

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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
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
