import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/regra_cartao_parcelado_service.dart';
import 'package:vox_finance/ui/core/service/regra_outra_compra_parcelada_service.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/pages/lancamento/lancamento_form_result.dart';
import 'package:vox_finance/ui/pages/lancamento_futuro/lancamento_futuro_form.dart';
import 'package:vox_finance/ui/pages/lancamento_futuro/widgets/lancamento_futuro_tile.dart';
// ajuste o caminho se for diferente:

class LancamentosFuturosPage extends StatefulWidget {
  const LancamentosFuturosPage({super.key});

  @override
  State<LancamentosFuturosPage> createState() => _LancamentosFuturosPageState();
}

class _LancamentosFuturosPageState extends State<LancamentosFuturosPage> {
  final LancamentoRepository _repositoryLancamento = LancamentoRepository();
  final ContaPagarRepository _contapagarLancamento = ContaPagarRepository();

  late final RegraCartaoParceladoService _regraCartaoParcelado;
  late final RegraOutraCompraParceladaService _regraOutraCompra;

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  late Future<List<Lancamento>> _futureLancamentos;
  late Future<double> _futureTotal;

  @override
  void initState() {
    super.initState();

    _regraOutraCompra = RegraOutraCompraParceladaService(
      lancRepo: _repositoryLancamento,
      contaPagarRepo: _contapagarLancamento,
    );

    _regraCartaoParcelado = RegraCartaoParceladoService(_repositoryLancamento);

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
      _futureLancamentos = _repositoryLancamento.getFuturosAte(fimDoMes);
      _futureTotal = _repositoryLancamento.getTotalFuturosAte(fimDoMes);
    });
  }

  Future<void> _marcarComoPago(Lancamento lanc, bool pago) async {
    if (lanc.id == null) return;

    final ehCartaoCredito =
        lanc.formaPagamento == FormaPagamento.credito && lanc.idCartao != null;

    if (ehCartaoCredito && lanc.pagamentoFatura) {
      // 👉 Aqui continua sua lógica atual para fatura de cartão
      await _repositoryLancamento.marcarComoPago(lanc.id!, pago);
    } else {
      // 👉 Outra compra parcelada (boleto / pix / débito etc.)
      await _regraOutraCompra.marcarLancamentoComoPagoSincronizado(lanc, pago);
    }

    await _carregarDados();
  }

  Future<void> _novoLancamentoFuturo() async {
    final hoje = DateTime.now();

    // você pode usar hoje ou amanhã como data inicial, como preferir
    final dataInicial = DateTime(hoje.year, hoje.month, hoje.day);

    final result = await Navigator.push<LancamentoFormResult>(
      context,
      MaterialPageRoute(
        builder:
            (_) => LancamentoFormPage(dataInicial: dataInicial, isFuturo: true),
      ),
    );

    if (result == null) return;

    final base = result.lancamentoBase;
    final qtd = result.qtdParcelas;

    if (qtd <= 1) {
      // 👉 Lançamento simples (à vista ou 1x)
      await _repositoryLancamento.salvar(base);
    } else {
      // 👉 Parcelado
      if (base.formaPagamento == FormaPagamento.credito &&
          base.idCartao != null) {
        // ✅ Regra 1: Cartão de crédito parcelado
        await _regraCartaoParcelado.processarCompraParcelada(
          compraBase: base,
          qtdParcelas: qtd,
        );
      } else {
        // ✅ Regra 2: Outra compra parcelada (boleto, pix, débito etc.)
        await _regraOutraCompra.criarParcelasNaoPagas(base, qtd);
      }
    }

    await _carregarDados();
  }

  Future<void> _editarLancamento(Lancamento lanc) async {
    final resultado = await Navigator.push<LancamentoFormResult>(
      context,
      MaterialPageRoute(
        builder:
            (_) => LancamentoFormPage(
              lancamento: lanc,
              isFuturo: lanc.dataHora.isAfter(DateTime.now()),
            ),
      ),
    );

    if (resultado != null) {
      // para edição de um só, vamos manter simples: salva só esse
      await _repositoryLancamento.salvar(resultado.lancamentoBase);
      await _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos Futuros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // 👈 voltar
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoLancamentoFuturo, // 👈 incluir
        child: const Icon(Icons.add),
      ),
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
                        onTap: () => _editarLancamento(lanc), // 👈 editar
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
