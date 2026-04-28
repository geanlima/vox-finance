// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/balanco_repository.dart';
import '../../../infrastructure/repositories/despesas_fixas_repository.dart';
import '../../../infrastructure/repositories/ganhos_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class BalancoPage extends StatefulWidget {
  const BalancoPage({super.key});

  @override
  State<BalancoPage> createState() => _BalancoPageState();
}

class _BalancoPageState extends State<BalancoPage> {
  final _repo = InjectorV2.balancoRepo;
  final GanhosRepository _ganhosRepo = InjectorV2.ganhosRepo;
  final DespesasFixasRepository _fixasRepo = InjectorV2.despesasFixasRepo;

  int _ano = 2026;
  bool _loading = true;

  List<BalancoMesRow> _rows = const [];
  BalancoAnoResumo? _resumo;

  // caches auxiliares do "Resumo"
  // key: mes(1..12)
  Map<int, int> _receitasMes = const {};
  Map<int, int> _fixasMes = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final resumo = await _repo.resumoAno(_ano);
    final r = await _repo.listarAno(_ano);

    // Carrega totais por mês (para cards do resumo)
    final receitasFutures = <Future<int>>[];
    final fixasFutures = <Future<int>>[];
    for (var m = 1; m <= 12; m++) {
      // receitas: somente recebidos (caixa)
      receitasFutures.add(_ganhosRepo.totalNoMes(_ano, m, somenteRecebidos: true));
      fixasFutures.add(_fixasRepo.totalNoMes(_ano, m));
    }

    final receitas = await Future.wait(receitasFutures);
    final fixas = await Future.wait(fixasFutures);

    final mapReceitas = <int, int>{};
    final mapFixas = <int, int>{};
    for (var i = 0; i < 12; i++) {
      mapReceitas[i + 1] = receitas[i];
      mapFixas[i + 1] = fixas[i];
    }

    if (!mounted) return;
    setState(() {
      _resumo = resumo;
      _rows = r;
      _receitasMes = mapReceitas;
      _fixasMes = mapFixas;
      _loading = false;
    });
  }

  String _mesNome(int m) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return meses[m - 1];
  }

  String _money(int cents) {
    final v = cents / 100.0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color? _saldoColor(ColorScheme cs, int cents) {
    if (cents > 0) return Colors.green;
    if (cents < 0) return cs.error;
    return cs.onSurfaceVariant;
  }

  Widget _chipAno(int a) {
    return ChoiceChip(
      label: Text('$a'),
      selected: _ano == a,
      onSelected: (_) async {
        setState(() => _ano = a);
        await _load();
      },
    );
  }

  Widget _resumoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _resumo;

    if (r == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo $_ano',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _kv('Ganhos', _money(r.ganhos)),
                const SizedBox(width: 12),
                _kv('Gastos', _money(r.gastosTotal)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.surfaceContainerHighest.withOpacity(.7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo do ano',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _money(r.saldo),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: _saldoColor(cs, r.saldo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Fixos: ${_money(r.gastosFixos)}   •   Variáveis: ${_money(r.gastosVariaveis)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _mesCard(BuildContext context, BalancoMesRow r) {
    final cs = Theme.of(context).colorScheme;

    final titulo = '${_mesNome(r.mes)} ${r.ano}';
    final now = DateTime.now();
    final isMesFuturo =
        (r.ano > now.year) || (r.ano == now.year && r.mes > now.month);

    // Despesas fixas "previstas" entram no total apenas para meses futuros.
    // No mês atual, não soma porque o lançamento é gerado quando pagar.
    final fixasPrevistas = isMesFuturo ? (_fixasMes[r.mes] ?? 0) : 0;

    final gastosFixosExib = r.gastosFixos + fixasPrevistas;
    final gastosTotalExib = r.gastosTotal + fixasPrevistas;
    final saldoExib = r.ganhos - gastosTotalExib;

    final saldo = saldoExib - (r.parcelas + r.dividas);
    final corSaldo = _saldoColor(cs, saldo);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // ✅ drill-down: depois você cria essa rota/tela
        // Navigator.pushNamed(context, AppRouterV2.balancoDetalhe, arguments: BalancoDetalheArgs(ano: r.ano, mes: r.mes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abrir detalhes: $titulo (em breve)')),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _kv('Ganhos', _money(r.ganhos)),
                  const SizedBox(width: 12),
                  _kv('Gastos', _money(gastosTotalExib)),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fixos: ${_money(gastosFixosExib)}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Variáveis: ${_money(r.gastosVariaveis)}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ✅ Cards solicitados: Receitas e Despesas Fixas (sem entrar no total do mês atual)
              Row(
                children: [
                  Expanded(
                    child: _miniResumoTapCard(
                      context,
                      titulo: 'Receitas',
                      subtitulo: 'Recebidas no mês',
                      valor: _money(_receitasMes[r.mes] ?? 0),
                      icon: Icons.arrow_upward,
                      color: Colors.green.shade700,
                      onTap: () => _showDetalheReceitas(ano: r.ano, mes: r.mes),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniResumoTapCard(
                      context,
                      titulo: 'Despesas fixas',
                      subtitulo:
                          isMesFuturo ? 'Previstas (entram no saldo)' : 'Não entram no total do mês atual',
                      valor: _money(_fixasMes[r.mes] ?? 0),
                      icon: Icons.push_pin_outlined,
                      color: Colors.deepOrange.shade700,
                      onTap: () => _showDetalheFixas(ano: r.ano, mes: r.mes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.surfaceContainerHighest.withOpacity(.7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo do mês',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _money(saldo),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: corSaldo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniResumoTapCard(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required String valor,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            color: cs.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetalheReceitas({required int ano, required int mes}) async {
    final itens = await _ganhosRepo.listarNoMes(ano, mes, somenteRecebidos: true);
    if (!mounted) return;

    final total = itens.fold<int>(0, (s, e) => s + e.valorCentavos);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.78,
          child: Column(
            children: [
              ListTile(
                title: const Text('Receitas (recebidas)'),
                subtitle: Text('$mes/$ano • ${itens.length} item(ns)'),
                trailing: Text(
                  _money(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child:
                    itens.isEmpty
                        ? const Center(
                          child: Text('Nenhuma receita recebida neste mês.'),
                        )
                        : ListView.separated(
                          padding: listViewPaddingWithBottomInset(
                            ctx,
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          ),
                          itemCount: itens.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final g = itens[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withOpacity(0.12),
                                child: Icon(
                                  Icons.arrow_upward,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              title: Text(g.descricao),
                              subtitle: Text(g.dataIso),
                              trailing: Text(
                                _money(g.valorCentavos),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface,
                                ),
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
  }

  Future<void> _showDetalheFixas({required int ano, required int mes}) async {
    final itens = await _fixasRepo.listarNoMes(ano, mes);
    if (!mounted) return;
    final total = itens.fold<int>(0, (s, e) => s + e.valorCentavos);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.78,
          child: Column(
            children: [
              ListTile(
                title: const Text('Despesas fixas'),
                subtitle: Text('$mes/$ano • ${itens.length} item(ns)'),
                trailing: Text(
                  _money(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child:
                    itens.isEmpty
                        ? const Center(
                          child: Text('Nenhuma despesa fixa neste mês.'),
                        )
                        : ListView.separated(
                          padding: listViewPaddingWithBottomInset(
                            ctx,
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          ),
                          itemCount: itens.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = itens[i];
                            final isPago = d.status == 'pago';
                            final cat =
                                (d.catNome == null || d.catNome!.isEmpty)
                                    ? 'Sem categoria'
                                    : '${d.catEmoji ?? '📌'} ${d.catNome}';
                            final fp =
                                (d.fpNome == null || d.fpNome!.isEmpty)
                                    ? 'Sem forma de pagamento'
                                    : d.fpNome!;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.deepOrange.withOpacity(0.12),
                                child: Icon(
                                  Icons.push_pin_outlined,
                                  color: Colors.deepOrange.shade700,
                                ),
                              ),
                              title: Text(d.descricao),
                              subtitle: Text(
                                '$cat • $fp'
                                '${d.dataPagamentoIso != null ? ' • Pgto: ${d.dataPagamentoIso}' : ''}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(d.valorCentavos),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPago ? 'PAGO' : 'A PAGAR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          isPago
                                              ? Colors.green.shade700
                                              : cs.error,
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
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Balanço do mês/ano')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 16, 16, 16)),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [_chipAno(2026), _chipAno(2027), _chipAno(2028)],
                  ),
                  const SizedBox(height: 14),

                  _resumoCard(context),
                  const SizedBox(height: 10),

                  ..._rows.map((r) => _mesCard(context, r)),

                  const SizedBox(height: 14),
                  Text(
                    'Obs.: “Parcelas” e “Dívidas” ainda ficam em 0 até criarmos os módulos de parcelamento e dívidas.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
    );
  }
}
