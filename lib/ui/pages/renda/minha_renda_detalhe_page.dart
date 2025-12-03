// lib/ui/pages/renda/minha_renda_mensal_detalhe_page.dart
// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class MinhaRendaMensalDetalhePage extends StatefulWidget {
  final int ano;
  final int mes;

  const MinhaRendaMensalDetalhePage({
    super.key,
    required this.ano,
    required this.mes,
  });

  @override
  State<MinhaRendaMensalDetalhePage> createState() =>
      _MinhaRendaMensalDetalhePageState();
}

class _MinhaRendaMensalDetalhePageState
    extends State<MinhaRendaMensalDetalhePage> {
  final _repo = LancamentoRepository();
  late Future<List<Lancamento>> _futureReceitas;

  @override
  void initState() {
    super.initState();
    _futureReceitas = _repo.getReceitasDoMes(widget.ano, widget.mes);
  }

  String _nomeMes(int mes) {
    final date = DateTime(2025, mes, 1);
    return DateFormat.MMMM('pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM');

    final tituloMes = '${_nomeMes(widget.mes)} / ${widget.ano}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Renda – $tituloMes'),
      ),
      body: FutureBuilder<List<Lancamento>>(
        future: _futureReceitas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final itens = snapshot.data ?? [];

          if (itens.isEmpty) {
            return const Center(
              child: Text('Sem receitas registradas neste mês.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final lanc = itens[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Text(
                    dateFormat.format(lanc.dataHora),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(lanc.descricao),
                  subtitle: lanc.categoria != null
                      ? Text(lanc.categoria.name)
                      : null,
                  trailing: Text(
                    currency.format(lanc.valor),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
