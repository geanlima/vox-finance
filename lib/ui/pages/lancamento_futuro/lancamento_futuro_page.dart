import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/pages/lancamento_futuro/widgets/lancamento_futuro_tile.dart';

class LancamentosFuturosPage extends StatefulWidget {
  const LancamentosFuturosPage({super.key});

  @override
  State<LancamentosFuturosPage> createState() => _LancamentosFuturosPageState();
}

class _LancamentosFuturosPageState extends State<LancamentosFuturosPage> {
  final _dbService = DbService(); // antes: _isarService
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  late Future<List<Lancamento>> _futureLancamentos;
  late Future<double> _futureTotal;

  @override
  void initState() {
    super.initState();
    // não precisa aguardar aqui
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final hoje = DateTime.now();

    // último dia do mês atual
    final fimDoMes = DateTime(
      hoje.year,
      hoje.month + 1,
      1,
    ).subtract(const Duration(days: 1));

    setState(() {
      _futureLancamentos = _dbService.getLancamentosFuturosAte(fimDoMes);
      _futureTotal = _dbService.getTotalLancamentosFuturosAte(fimDoMes);
    });
  }

  Future<void> _marcarComoPago(Lancamento lanc, bool pago) async {
    // no modelo SQLite o id é int?, então usamos !
    if (lanc.id == null) return;

    await _dbService.marcarLancamentoComoPago(lanc.id!, pago);
    await _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos Futuros')),
      body: Column(
        children: [
          // Cabeçalho com total
          Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<double>(
              future: _futureTotal,
              builder: (context, snapshot) {
                final total = snapshot.data ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total até fim do mês:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _currency.format(total),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: total >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Lista
          Expanded(
            child: FutureBuilder<List<Lancamento>>(
              future: _futureLancamentos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar: ${snapshot.error}'),
                  );
                }

                final itens = snapshot.data ?? [];

                if (itens.isEmpty) {
                  return const Center(
                    child: Text('Nenhum lançamento futuro até o fim do mês.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView.separated(
                    itemCount: itens.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final lanc = itens[index];
                      return LancamentoFuturoTile(
                        lancamento: lanc,
                        onAlterarPago: (pago) => _marcarComoPago(lanc, pago),
                      );
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
