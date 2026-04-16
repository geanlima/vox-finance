// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/planejamento_despesa.dart';
import 'package:vox_finance/ui/data/modules/planejamentos/planejamento_despesa_repository.dart';
import 'package:vox_finance/ui/pages/planejamentos/planejamento_despesa_detalhe_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class PlanejamentosDespesaListPage extends StatefulWidget {
  const PlanejamentosDespesaListPage({super.key});

  static const routeName = '/planejamentos-despesa';

  @override
  State<PlanejamentosDespesaListPage> createState() =>
      _PlanejamentosDespesaListPageState();
}

class _PlanejamentosDespesaListPageState
    extends State<PlanejamentosDespesaListPage> {
  final _repo = PlanejamentoDespesaRepository();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _df = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<PlanejamentoDespesa> _lista = const [];
  final Map<int, double> _totais = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listar();
      final totais = <int, double>{};
      for (final p in list) {
        if (p.id != null) {
          totais[p.id!] = await _repo.somaValoresItens(p.id!);
        }
      }
      if (!mounted) return;
      setState(() {
        _lista = list;
        _totais
          ..clear()
          ..addAll(totais);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirForm({PlanejamentoDespesa? existente}) async {
    DateTime apenasDia(DateTime d) => DateTime(d.year, d.month, d.day);

    final tituloCtrl = TextEditingController(text: existente?.titulo ?? '');
    final localCtrl = TextEditingController(text: existente?.local ?? '');
    final notasCtrl = TextEditingController(text: existente?.notas ?? '');
    var inicio =
        existente != null
            ? apenasDia(existente.dataInicio)
            : apenasDia(DateTime.now());
    var fim =
        existente != null
            ? apenasDia(existente.dataFim)
            : inicio.add(const Duration(days: 1));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            final bottom = mq.viewInsets.bottom + mq.padding.bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existente == null
                            ? 'Novo planejamento'
                            : 'Editar planejamento',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título (ex.: Viagem Salvador)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: localCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Local (opcional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final first = DateTime(2020);
                                final last = DateTime(2100);
                                var init = apenasDia(inicio);
                                if (init.isBefore(first)) init = first;
                                if (init.isAfter(last)) init = last;
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: init,
                                  firstDate: first,
                                  lastDate: last,
                                  useRootNavigator: true,
                                );
                                if (d != null) {
                                  setModal(() {
                                    inicio = apenasDia(d);
                                    if (apenasDia(fim).isBefore(inicio)) {
                                      fim = inicio;
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text('Início ${_df.format(inicio)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final last = DateTime(2100);
                                final first = apenasDia(inicio);
                                var init = apenasDia(fim);
                                if (init.isBefore(first)) init = first;
                                if (init.isAfter(last)) init = last;
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: init,
                                  firstDate: first,
                                  lastDate: last,
                                  useRootNavigator: true,
                                );
                                if (d != null) {
                                  setModal(() => fim = apenasDia(d));
                                }
                              },
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text('Fim ${_df.format(fim)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notasCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações (opcional)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          if (tituloCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Informe um título.'),
                              ),
                            );
                            return;
                          }
                          if (fim.isBefore(inicio)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A data fim deve ser após ou igual à início.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final now = DateTime.now();
    final p = PlanejamentoDespesa(
      id: existente?.id,
      titulo: tituloCtrl.text.trim(),
      local: localCtrl.text.trim().isEmpty ? null : localCtrl.text.trim(),
      dataInicio: DateTime(inicio.year, inicio.month, inicio.day),
      dataFim: DateTime(fim.year, fim.month, fim.day, 23, 59, 59, 999),
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
      criadoEm: existente?.criadoEm ?? now,
      atualizadoEm: now,
    );

    await _repo.salvar(p);
    await _carregar();
  }

  Future<void> _confirmarExcluir(PlanejamentoDespesa p) async {
    final id = p.id;
    if (id == null) return;
    final sim = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir planejamento?'),
            content: Text(
              'Remove "${p.titulo}" e todos os itens de despesa previstos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
    if (sim != true) return;
    await _repo.excluir(id);
    await _carregar();
  }

  Future<void> _abrirDetalhe(int planejamentoId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlanejamentoDespesaDetalhePage(planejamentoId: planejamentoId),
      ),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;
    final danger = Colors.red.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejar gastos'),
      ),
      drawer: const AppDrawer(currentRoute: PlanejamentosDespesaListPage.routeName),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _lista.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.event_note_rounded,
                          size: 48,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Nenhum planejamento ainda',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Viagens, churrasco, eventos: defina período e depois '
                        'monte a lista de despesas previstas (com categorias). '
                        'Nas despesas você pode gerar ou vincular lançamentos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _abrirForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar planejamento'),
                      ),
                    ],
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: _lista.length,
                itemBuilder: (context, i) {
                  final p = _lista[i];
                  final id = p.id;
                  final total = id != null ? (_totais[id] ?? 0) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Slidable(
                      key: ValueKey('planej_list_${p.id}_${p.titulo}'),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.2,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) {
                              if (id != null) _abrirDetalhe(id);
                            },
                            backgroundColor: secondary,
                            borderRadius: BorderRadius.circular(12),
                            child: const Icon(
                              Icons.list_alt_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _abrirForm(existente: p),
                            backgroundColor: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.edit,
                              size: 28,
                              color: primary,
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) => _confirmarExcluir(p),
                            backgroundColor: danger,
                            borderRadius: BorderRadius.circular(12),
                            child: const Icon(
                              Icons.delete,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: id == null ? null : () => _abrirDetalhe(id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.luggage_rounded,
                                    color: cs.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.titulo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (p.local != null &&
                                          p.local!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          p.local!,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.date_range_rounded,
                                            size: 16,
                                            color: cs.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${_df.format(p.dataInicio)} — ${_df.format(p.dataFim)}',
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Total previsto',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _currency.format(total),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Toque para abrir · deslize para ações',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.outline,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: cs.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
