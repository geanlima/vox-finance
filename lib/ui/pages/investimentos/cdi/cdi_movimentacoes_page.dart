import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_rendimentos_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_movimentos_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class CdiMovimentacoesPage extends StatefulWidget {
  final int idCarteira;
  final String nomeCarteira;
  final double saldoInicial;

  const CdiMovimentacoesPage({
    super.key,
    required this.idCarteira,
    required this.nomeCarteira,
    required this.saldoInicial,
  });

  @override
  State<CdiMovimentacoesPage> createState() => _CdiMovimentacoesPageState();
}

class _CdiMovimentacoesPageState extends State<CdiMovimentacoesPage> {
  final _repo = InvestimentoCdiRendimentosRepository();
  final _movRepo = InvestimentoCdiMovimentosRepository();
  final _lancRepo = LancamentoRepository();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');
  final _monthFmt = DateFormat('MMMM/yyyy', 'pt_BR');

  bool _loading = true;
  List<({DateTime data, String tipo, double valor, int? idRend})> _itens = const [];
  Map<int, InvestimentoCdiRendimentoRow> _rendPorId = const {};
  Map<int, double> _saldoAposPorId = const {};
  Map<String, double> _totalPorMes = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ymKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}';

  Future<void> _editarRendimentoDia(InvestimentoCdiRendimentoRow r) async {
    final ctrl = TextEditingController(
      text: NumberFormat('#,##0.00', 'pt_BR').format(r.rendimentoValor),
    );
    final novo = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar rendimento — ${_dateFmt.format(r.data)}'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rendeu (R\$)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = CurrencyInputFormatter.parse(ctrl.text);
                Navigator.pop(ctx, v);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (novo == null) return;

    await _repo.atualizarRendimentoValor(id: r.id, rendimentoValor: novo);
    final idLanc = r.idLancamento;
    if (idLanc != null) {
      final lanc = await _lancRepo.getById(idLanc);
      if (lanc != null) {
        lanc.valor = novo;
        await _lancRepo.salvar(lanc);
      }
    }

    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rendimento do dia atualizado.')),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listarPorCarteira(widget.idCarteira);
    final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
    if (!mounted) return;

    final events = <({DateTime data, String tipo, double valor, int? idRend})>[];
    for (final r in rows) {
      events.add((data: r.data, tipo: 'rendimento', valor: r.rendimentoValor, idRend: r.id));
    }
    for (final m in movs) {
      final tipo = (m.tipo == InvestimentoCdiMovimentoTipo.saque) ? 'saque' : 'aporte';
      final valor = (m.tipo == InvestimentoCdiMovimentoTipo.saque) ? -m.valor : m.valor;
      events.add((data: m.data, tipo: tipo, valor: valor, idRend: null));
    }

    // Para calcular saldo acumulado, mantemos como antes (só rendimentos) para evitar
    // dupla-contagem (saldoInicial já reflete o saldo base atual).
    final asc = List<InvestimentoCdiRendimentoRow>.from(rows)
      ..sort((a, b) => a.data.compareTo(b.data));
    double saldo = widget.saldoInicial;
    final mapa = <int, double>{};
    for (final r in asc) {
      saldo += r.rendimentoValor;
      mapa[r.id] = saldo;
    }

    final totalPorMes = <String, double>{};
    for (final e in events) {
      final k = _ymKey(e.data);
      totalPorMes[k] = (totalPorMes[k] ?? 0) + e.valor;
    }

    setState(() {
      _itens = events..sort((a, b) => b.data.compareTo(a.data));
      _rendPorId = {for (final r in rows) r.id: r};
      _saldoAposPorId = mapa;
      _totalPorMes = totalPorMes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Movimentações — ${widget.nomeCarteira}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty
              ? const Center(child: Text('Nenhuma movimentação encontrada.'))
              : ListView(
                  padding: listViewPaddingWithBottomInset(
                    context,
                    const EdgeInsets.all(12),
                  ),
                  children: _buildAgrupadoPorMes(context),
                ),
    );
  }

  List<Widget> _buildAgrupadoPorMes(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];

    String? ultimoMes;
    for (final e in _itens) {
      final k = _ymKey(e.data);
      if (k != ultimoMes) {
        ultimoMes = k;
        final total = _totalPorMes[k] ?? 0;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _monthFmt.format(DateTime(e.data.year, e.data.month, 1)),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  _currency.format(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final isRendimento = e.tipo == 'rendimento';
      final r = isRendimento && e.idRend != null ? _rendPorId[e.idRend!] : null;

      // Para rendimento, usamos o saldo acumulado calculado no load. Para saque/aporte, não mostramos saldo.
      final saldoApos = isRendimento && e.idRend != null ? _saldoAposPorId[e.idRend!] : null;
      final tile = Card(
        child: ListTile(
            dense: true,
            title: Text(_dateFmt.format(e.data)),
            subtitle: Text(
              isRendimento && r != null
                  ? 'Taxa aplicada: ${r.pctCdi.toStringAsFixed(4).replaceAll('.', ',')}%'
                  : (e.tipo == 'saque' ? 'Saque' : 'Aporte'),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: isRendimento ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
            onLongPress: isRendimento && e.idRend != null
                ? () async {
                    final rows = await _repo.listarPorCarteira(widget.idCarteira);
                    final rr = rows.firstWhere((x) => x.id == e.idRend);
                    await _editarRendimentoDia(rr);
                  }
                : null,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(e.valor),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: e.valor < 0 ? Colors.red.shade700 : null,
                  ),
                ),
                if (saldoApos != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Saldo: ${_currency.format(saldoApos)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
      );

      final actions = <Widget>[];
      if (isRendimento && e.idRend != null) {
        actions.addAll([
          CustomSlidableAction(
            onPressed: (_) async {
              final rows = await _repo.listarPorCarteira(widget.idCarteira);
              final rr = rows.firstWhere((x) => x.id == e.idRend);
              await _editarRendimentoDia(rr);
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.edit,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ]);
      }

      out.add(
        actions.isEmpty
            ? tile
            : Slidable(
                key: ValueKey('cdi_mov_${e.tipo}_${e.idRend ?? e.data.toIso8601String()}'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.22,
                  children: actions,
                ),
                child: tile,
              ),
      );
    }

    return out;
  }
}

