import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class SelecionarLancamentoAssociacaoPage extends StatefulWidget {
  final int idCartao;
  final DateTime diaInicial;

  /// IDs de lançamentos já associados a OUTROS itens desta fatura.
  /// (o atual pode estar aqui também; nesse caso, ele continua selecionável)
  final Set<int> jaAssociados;

  /// ID atualmente associado ao item (se houver).
  final int? idAtual;

  const SelecionarLancamentoAssociacaoPage({
    super.key,
    required this.idCartao,
    required this.diaInicial,
    required this.jaAssociados,
    required this.idAtual,
  });

  @override
  State<SelecionarLancamentoAssociacaoPage> createState() =>
      _SelecionarLancamentoAssociacaoPageState();
}

class _SelecionarLancamentoAssociacaoPageState
    extends State<SelecionarLancamentoAssociacaoPage> {
  final _repo = LancamentoRepository();

  final _fmtDia = DateFormat('dd/MM/yyyy', 'pt_BR');
  final _fmtChip = DateFormat('dd/MM', 'pt_BR');
  final _fmtHora = DateFormat('HH:mm', 'pt_BR');
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  late DateTime _dia;
  bool _loading = true;
  List<Lancamento> _lista = const [];

  @override
  void initState() {
    super.initState();
    _dia = DateTime(
      widget.diaInicial.year,
      widget.diaInicial.month,
      widget.diaInicial.day,
    );
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final ini = DateTime(_dia.year, _dia.month, _dia.day);
      final fim = ini.add(const Duration(days: 1));
      final rows = await _repo.getByPeriodo(ini, fim);
      final filtrados = rows
          .where((l) => !l.pagamentoFatura)
          .toList()
        ..sort((a, b) {
          // Prioriza o mesmo cartão no topo, mas mostra TODOS os lançamentos do dia.
          final aMesmo = a.idCartao == widget.idCartao ? 1 : 0;
          final bMesmo = b.idCartao == widget.idCartao ? 1 : 0;
          if (aMesmo != bMesmo) return bMesmo.compareTo(aMesmo);
          return b.dataHora.compareTo(a.dataHora);
        });
      if (!mounted) return;
      setState(() => _lista = filtrados);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selecionarDia() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _dia = DateTime(picked.year, picked.month, picked.day);
    });
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar lançamento'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.55),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Dia anterior',
                    onPressed: () async {
                      setState(() {
                        _dia = _dia.subtract(const Duration(days: 1));
                      });
                      await _carregar();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Dia selecionado',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtDia.format(_dia),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próximo dia',
                    onPressed: () async {
                      setState(() {
                        _dia = _dia.add(const Duration(days: 1));
                      });
                      await _carregar();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Escolher dia',
                    onPressed: _selecionarDia,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lista.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhum lançamento para este dia.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _lista.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final l = _lista[i];
                          final id = l.id;
                          final bool ehAtual = id != null && id == widget.idAtual;
                          final bool jaAssoc =
                              id != null && widget.jaAssociados.contains(id);
                          final bool bloqueado = jaAssoc && !ehAtual;

                          final dia = _fmtChip.format(l.dataHora);
                          final hora = _fmtHora.format(l.dataHora);

                          return Card(
                            elevation: 1,
                            child: ListTile(
                              enabled: !bloqueado,
                              leading: Container(
                                width: 52,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cs.primary.withOpacity(0.18),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dia,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: cs.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hora,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                l.descricao,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(_money.format(l.valor)),
                              trailing: jaAssoc
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (bloqueado
                                                ? cs.error
                                                : cs.primary)
                                            .withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: (bloqueado
                                                  ? cs.error
                                                  : cs.primary)
                                              .withOpacity(0.25),
                                        ),
                                      ),
                                      child: Text(
                                        bloqueado ? 'Já associado' : 'Atual',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: bloqueado
                                              ? cs.error
                                              : cs.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                if (id == null) return;
                                Navigator.pop(context, id);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

