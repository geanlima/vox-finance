import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_rendimentos_repository.dart';

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
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');
  final _monthFmt = DateFormat('MMMM/yyyy', 'pt_BR');

  bool _loading = true;
  List<InvestimentoCdiRendimentoRow> _itens = const [];
  Map<int, double> _saldoAposPorId = const {};
  Map<String, double> _totalPorMes = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ymKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listarPorCarteira(widget.idCarteira);
    if (!mounted) return;

    // rows vem DESC, para calcular saldo acumulado precisamos ASC.
    final asc = List<InvestimentoCdiRendimentoRow>.from(rows)
      ..sort((a, b) => a.data.compareTo(b.data));
    double saldo = widget.saldoInicial;
    final mapa = <int, double>{};
    for (final r in asc) {
      saldo += r.rendimentoValor;
      mapa[r.id] = saldo;
    }

    final totalPorMes = <String, double>{};
    for (final r in rows) {
      final k = _ymKey(r.data);
      totalPorMes[k] = (totalPorMes[k] ?? 0) + r.rendimentoValor;
    }

    setState(() {
      _itens = rows;
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
    for (final r in _itens) {
      final k = _ymKey(r.data);
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
                    _monthFmt.format(DateTime(r.data.year, r.data.month, 1)),
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

      final saldoApos = _saldoAposPorId[r.id] ?? (r.base + r.rendimentoValor);
      out.add(
        Card(
          child: ListTile(
            dense: true,
            title: Text(_dateFmt.format(r.data)),
            subtitle: Text(
              'Taxa aplicada: ${r.pctCdi.toStringAsFixed(4).replaceAll('.', ',')}%',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(r.rendimentoValor),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
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
            ),
          ),
        ),
      );
    }

    return out;
  }
}

