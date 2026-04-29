import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class _ResumoMes {
  final int ano;
  final int mes;
  final double receitas;
  final double despesas;

  const _ResumoMes({
    required this.ano,
    required this.mes,
    required this.receitas,
    required this.despesas,
  });

  double get saldo => receitas - despesas;

  String get label => '${mes.toString().padLeft(2, '0')}/$ano';
}

class ComparativoGanhosGastosPage extends StatefulWidget {
  static const String routeName = '/comparativo-ganhos-gastos';

  const ComparativoGanhosGastosPage({super.key});

  @override
  State<ComparativoGanhosGastosPage> createState() =>
      _ComparativoGanhosGastosPageState();
}

class _ComparativoGanhosGastosPageState
    extends State<ComparativoGanhosGastosPage> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _repo = LancamentoRepository();
  final _rendaRepo = RendaRepository();

  final List<Color> _paleta = const [
    Color(0xFF2E7D32), // ganhos
    Color(0xFFC62828), // gastos
  ];

  bool _carregando = false;
  int _meses = 12;
  late DateTime _mesBase;
  bool _incluirReceitasCadastro = true;
  List<_ResumoMes> _itens = const [];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesBase = DateTime(agora.year, agora.month, 1);
    _recarregar();
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Future<void> _recarregar() async {
    setState(() => _carregando = true);
    try {
      final end = DateTime(_mesBase.year, _mesBase.month, 1);
      final start = DateTime(end.year, end.month - (_meses - 1), 1);

      final fontesAtivas = _incluirReceitasCadastro
          ? await _rendaRepo.listarFontes(apenasAtivas: true)
          : const [];
      final totalCadastroMes = fontesAtivas.fold<double>(
        0.0,
        (s, f) => s + f.valorBase,
      );

      final out = <_ResumoMes>[];
      for (var i = 0; i < _meses; i++) {
        final ref = DateTime(start.year, start.month + i, 1);
        final inicioMes = DateTime(ref.year, ref.month, 1);
        final fimMes = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999);

        final receitas = await _repo.getReceitasDoMes(ref.year, ref.month);
        final despesas = await _repo.getDespesasByPeriodo(inicioMes, fimMes);

        final totalReceitasLancadas =
            receitas.fold<double>(0, (s, l) => s + (l.valor));
        final totalReceitas =
            totalReceitasLancadas + (_incluirReceitasCadastro ? totalCadastroMes : 0.0);
        final totalDespesas =
            despesas.fold<double>(0, (s, l) => s + (l.valor));

        out.add(
          _ResumoMes(
            ano: ref.year,
            mes: ref.month,
            receitas: totalReceitas,
            despesas: totalDespesas,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _itens = out);
    } finally {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  Widget _buildLegenda() {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(t),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        item(const Color(0xFF2E7D32), 'Ganhos'),
        item(const Color(0xFFC62828), 'Gastos'),
      ],
    );
  }

  BarChartData _buildBarData() {
    final maxY = _itens.isEmpty
        ? 0.0
        : _itens
            .map((e) => e.receitas > e.despesas ? e.receitas : e.despesas)
            .reduce((a, b) => a > b ? a : b);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY <= 0 ? 1 : maxY * 1.15,
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, meta) {
              if (v == 0) return const SizedBox.shrink();
              return Text(
                NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$')
                    .format(v),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= _itens.length) return const SizedBox.shrink();
              final m = _itens[i];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  m.mes.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < _itens.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: 6,
            barRods: [
              BarChartRodData(
                toY: _itens[i].receitas,
                color: const Color(0xFF2E7D32),
                width: 8,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: _itens[i].despesas,
                color: const Color(0xFFC62828),
                width: 8,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double chartHeight = isLandscape ? 220 : 280;

    return Scaffold(
      appBar: AppBar(title: const Text('Comparativo (Ganhos x Gastos)')),
      drawer: const AppDrawer(currentRoute: ComparativoGanhosGastosPage.routeName),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _recarregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            onChanged: (novoMes) async {
                              if (novoMes == null) return;
                              setState(() {
                                _mesBase = DateTime(_mesBase.year, novoMes, 1);
                              });
                              await _recarregar();
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
                              return DropdownMenuItem(
                                value: ano,
                                child: Text('$ano'),
                              );
                            }),
                            onChanged: (novoAno) async {
                              if (novoAno == null) return;
                              setState(() {
                                _mesBase = DateTime(novoAno, _mesBase.month, 1);
                              });
                              await _recarregar();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Theme(
                        data: tema.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          title: const Text(
                            'Filtros',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Ganhos x Gastos por mês',
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurface
                                  .withOpacity(0.65),
                            ),
                          ),
                          children: [
                            DropdownButtonFormField<int>(
                              isDense: true,
                              value: _meses,
                              decoration: const InputDecoration(
                                labelText: 'Período',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 6,
                                  child: Text('Últimos 6 meses'),
                                ),
                                DropdownMenuItem(
                                  value: 12,
                                  child: Text('Últimos 12 meses'),
                                ),
                                DropdownMenuItem(
                                  value: 24,
                                  child: Text('Últimos 24 meses'),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _meses = v);
                                await _recarregar();
                              },
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Incluir receitas do cadastro'),
                              subtitle: Text(
                                'Soma as fontes de renda ativas do cadastro em cada mês.',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurface
                                      .withOpacity(0.65),
                                ),
                              ),
                              value: _incluirReceitasCadastro,
                              onChanged: (v) async {
                                setState(() => _incluirReceitasCadastro = v);
                                await _recarregar();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildLegenda(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: chartHeight,
                          child: _itens.isEmpty
                              ? const Center(
                                  child: Text('Sem dados para o período.'),
                                )
                              : BarChart(_buildBarData()),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Detalhes',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            for (final it in _itens.reversed) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(it.label),
                                subtitle: Text(
                                  'Saldo: ${_currency.format(it.saldo)}',
                                  style: TextStyle(
                                    color: it.saldo >= 0
                                        ? _paleta[0]
                                        : _paleta[1],
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Ganhos: ${_currency.format(it.receitas)}',
                                    ),
                                    Text(
                                      'Gastos: ${_currency.format(it.despesas)}',
                                    ),
                                  ],
                                ),
                              ),
                              if (it != _itens.first) const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

