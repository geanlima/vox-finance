// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

enum TipoAgrupamentoPizza { categoria, formaPagamento, dia }

/// Grupo para resumo por forma/cartão
class _GrupoFormaPagamento {
  final String label;
  final IconData icon;
  double total;

  _GrupoFormaPagamento({
    required this.label,
    required this.icon,
    required this.total,
  });
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
  final _dateHoraFormat = DateFormat('dd/MM HH:mm');
  final _dateDiaFormat = DateFormat('dd/MM');

  // 🔹 Ano / mês selecionados e anos disponíveis
  late int _anoSelecionado;
  int _mesSelecionado = DateTime.now().month;
  late final List<int> _anosDisponiveis;

  TipoAgrupamentoPizza _tipo = TipoAgrupamentoPizza.categoria;

  bool _carregando = false;
  List<Lancamento> _lancamentos = [];

  // 🔹 Cartões carregados do banco
  List<CartaoCredito> _cartoes = [];

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

    // 5 anos para trás + ano atual + 3 anos para frente = 9 anos
    const anosAtras = 5;
    const anosFrente = 3;
    _anosDisponiveis = List<int>.generate(
      anosAtras + anosFrente + 1,
      (i) => agora.year - anosAtras + i,
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
    final cards = await _db.getCartoesCredito();

    Iterable<Lancamento> filtrados = lista;

    if (widget.considerarSomentePagos) {
      filtrados = filtrados.where((l) => l.pago);
    }

    if (widget.ignorarPagamentoFatura) {
      filtrados = filtrados.where((l) => !l.pagamentoFatura);
    }

    setState(() {
      _lancamentos = filtrados.toList();
      _cartoes = cards;
      _carregando = false;
    });
  }

  // ======= TOTAIS =======

  double get _totalMes {
    return _lancamentos.fold<double>(0.0, (acc, l) => acc + l.valor);
  }

  Map<Categoria, double> _totaisPorCategoria() {
    final Map<Categoria, double> totais = {};
    for (final l in _lancamentos) {
      totais.update(l.categoria, (v) => v + l.valor, ifAbsent: () => l.valor);
    }
    return totais;
  }

  /// 🔹 Forma pagamento: débito/pix/dinheiro etc. normal,
  /// crédito agrupado por CARTÃO (descrição + bandeira + últimos 4 dígitos)
  Map<String, _GrupoFormaPagamento> _totaisPorFormaPagamentoAgrupado() {
    final Map<String, _GrupoFormaPagamento> mapa = {};

    for (final l in _lancamentos) {
      if (l.formaPagamento == FormaPagamento.credito) {
        CartaoCredito? cartao;
        if (l.idCartao != null) {
          try {
            cartao = _cartoes.firstWhere((c) => c.id == l.idCartao);
          } catch (_) {
            cartao = null;
          }
        }

        final String label;
        if (cartao != null) {
          label =
              '${cartao.descricao} • ${cartao.bandeira} • **** ${cartao.ultimos4Digitos}';
        } else if (l.idCartao == null) {
          label = 'Crédito (sem cartão vinculado)';
        } else {
          label = 'Crédito (cartão id ${l.idCartao})';
        }

        final key = label;
        if (mapa.containsKey(key)) {
          mapa[key]!.total += l.valor;
        } else {
          mapa[key] = _GrupoFormaPagamento(
            label: label,
            icon: Icons.credit_card,
            total: l.valor,
          );
        }
      } else {
        final label = l.formaPagamento.label;
        final key = label;

        if (mapa.containsKey(key)) {
          mapa[key]!.total += l.valor;
        } else {
          mapa[key] = _GrupoFormaPagamento(
            label: label,
            icon: l.formaPagamento.icon,
            total: l.valor,
          );
        }
      }
    }

    return mapa;
  }

  /// 🔹 Mapa: label (forma/cartão) → lista de lançamentos
  Map<String, List<Lancamento>> _lancamentosPorGrupoFormaPagamento() {
    final Map<String, List<Lancamento>> mapa = {};

    for (final l in _lancamentos) {
      String label;

      if (l.formaPagamento == FormaPagamento.credito) {
        CartaoCredito? cartao;
        if (l.idCartao != null) {
          try {
            cartao = _cartoes.firstWhere((c) => c.id == l.idCartao);
          } catch (_) {
            cartao = null;
          }
        }

        if (cartao != null) {
          label =
              '${cartao.descricao} • ${cartao.bandeira} • **** ${cartao.ultimos4Digitos}';
        } else if (l.idCartao == null) {
          label = 'Crédito (sem cartão vinculado)';
        } else {
          label = 'Crédito (cartão id ${l.idCartao})';
        }
      } else {
        label = l.formaPagamento.label;
      }

      mapa.putIfAbsent(label, () => []).add(l);
    }

    return mapa;
  }

  /// 🔹 Total por dia do mês (cada dia é um "grupo")
  Map<DateTime, double> _totaisPorDia() {
    final Map<DateTime, double> totais = {};
    for (final l in _lancamentos) {
      final d = DateTime(l.dataHora.year, l.dataHora.month, l.dataHora.day);
      totais.update(d, (v) => v + l.valor, ifAbsent: () => l.valor);
    }
    // ordena por dia
    final entries =
        totais.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }

  /// 🔹 Mapa: dia → lista de lançamentos
  Map<DateTime, List<Lancamento>> _lancamentosPorDia() {
    final Map<DateTime, List<Lancamento>> mapa = {};
    for (final l in _lancamentos) {
      final d = DateTime(l.dataHora.year, l.dataHora.month, l.dataHora.day);
      mapa.putIfAbsent(d, () => []).add(l);
    }
    return mapa;
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
    } else if (_tipo == TipoAgrupamentoPizza.formaPagamento) {
      final data = _totaisPorFormaPagamentoAgrupado();
      final total = data.values.fold<double>(0.0, (a, b) => a + b.total);
      if (total == 0) return [];

      final entries = data.values.toList();

      return List.generate(entries.length, (i) {
        final grupo = entries[i];
        final valor = grupo.total;
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
      // 🔹 Agrupamento por DIA
      final data = _totaisPorDia();
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
            fontSize: 11,
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
    } else {
      final totaisPorGrupo = _totaisPorFormaPagamentoAgrupado();

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
                  'Gastos por forma de pagamento / cartão',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  mesAnoLabel,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...totaisPorGrupo.values.map((grupo) {
                  return ListTile(
                    leading: CircleAvatar(child: Icon(grupo.icon, size: 18)),
                    title: Text(grupo.label),
                    trailing: Text(
                      _currency.format(grupo.total),
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
  }

  // ======= DETALHAMENTO (VISUAL NOVO) =======

  void _mostrarDetalheLancamentos({
    required String titulo,
    required String subtitulo,
    required List<Lancamento> lancamentos,
  }) {
    if (lancamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum lançamento para detalhar.')),
      );
      return;
    }

    final total = lancamentos.fold<double>(0.0, (a, b) => a + b.valor);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final tema = Theme.of(context);
        final corPrimaria = tema.colorScheme.primary;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.92,
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
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CABEÇALHO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitulo,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card com total
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: corPrimaria.withOpacity(0.06),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: corPrimaria.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.pie_chart_rounded,
                                  color: corPrimaria,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    _currency.format(total),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lançamentos',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: Colors.grey[700],
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // LISTA
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: lancamentos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final l = lancamentos[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.surfaceVariant
                                .withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: corPrimaria.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.descricao,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_dateHoraFormat.format(l.dataHora)} • '
                                      '${CategoriaService.toName(l.categoria)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currency.format(l.valor),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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

  // ======= BUILD =======

  @override
  Widget build(BuildContext context) {
    final labelMesAno = '${_nomeMes(_mesSelecionado)} / $_anoSelecionado';
    final totalMesFormatado = _currency.format(_totalMes);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ====== LINHA 1: MÊS + ANO ======
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
                          setState(() {
                            _mesSelecionado = novoMes;
                          });
                          _carregarDados();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _anoSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Ano',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _anosDisponiveis
                            .map(
                              (ano) => DropdownMenuItem(
                                value: ano,
                                child: Text(ano.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (novoAno) {
                          if (novoAno == null) return;
                          setState(() {
                            _anoSelecionado = novoAno;
                          });
                          _carregarDados();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ====== LINHA 2: TIPO (AGRUPAR POR) ======
                DropdownButtonFormField<TipoAgrupamentoPizza>(
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
                      child: Text('Forma pgto / Cartão'),
                    ),
                    DropdownMenuItem(
                      value: TipoAgrupamentoPizza.dia,
                      child: Text('Dia'),
                    ),
                  ],
                  onChanged: (novo) {
                    if (novo == null) return;
                    setState(() {
                      _tipo = novo;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // MÊS / ANO
                Text(
                  labelMesAno,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // ====== TOTAL GASTO NO MÊS (CLICÁVEL) ======
                InkWell(
                  onTap: _mostrarResumoPorFormaPagamentoMes,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
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
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_lancamentos.isEmpty)
                  const SizedBox(
                    height: 120,
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
                  if (_tipo == TipoAgrupamentoPizza.categoria)
                    _buildLegendaCategoria()
                  else if (_tipo == TipoAgrupamentoPizza.formaPagamento)
                    _buildLegendaFormaPagamento()
                  else
                    _buildLegendaDia(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ======= LEGENDAS – VISUAL EM CARD =======

  Widget _buildLegendaCategoria() {
    final data = _totaisPorCategoria();
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final cat = entry.key;
        final valor = entry.value;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final lancs =
                  _lancamentos.where((l) => l.categoria == cat).toList();
              _mostrarDetalheLancamentos(
                titulo: 'Detalhe por categoria',
                subtitulo:
                    '${CategoriaService.toName(cat)} • ${_nomeMes(_mesSelecionado)} / $_anoSelecionado',
                lancamentos: lancs,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CategoriaService.toName(cat),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendaFormaPagamento() {
    final dataResumo = _totaisPorFormaPagamentoAgrupado();
    final dataLancs = _lancamentosPorGrupoFormaPagamento();
    final total = dataResumo.values.fold<double>(0.0, (a, b) => a + b.total);
    final entries = dataResumo.values.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final grupo = entries[index];
        final valor = grupo.total;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final lancs = dataLancs[grupo.label] ?? const <Lancamento>[];
              _mostrarDetalheLancamentos(
                titulo: 'Detalhe por forma / cartão',
                subtitulo:
                    '${grupo.label} • ${_nomeMes(_mesSelecionado)} / $_anoSelecionado',
                lancamentos: lancs,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: Row(
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
                  Icon(grupo.icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Legenda quando agrupado por DIA
  Widget _buildLegendaDia() {
    final data = _totaisPorDia();
    final dataLancs = _lancamentosPorDia();
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final dia = entry.key;
        final valor = entry.value;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final lancs = dataLancs[dia] ?? const <Lancamento>[];
              _mostrarDetalheLancamentos(
                titulo: 'Detalhe do dia',
                subtitulo: _dateDiaFormat.format(dia),
                lancamentos: lancs,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dia ${_dateDiaFormat.format(dia)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
