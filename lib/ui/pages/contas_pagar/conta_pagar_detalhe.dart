// lib/ui/pages/contas_pagar/conta_pagar_detalhe.dart
// ignore_for_file: deprecated_member_use, depend_on_referenced_packages, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/extensions/list_extensions.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class ContaPagarDetalhePage extends StatefulWidget {
  final String grupoParcelas;

  const ContaPagarDetalhePage({super.key, required this.grupoParcelas});

  @override
  State<ContaPagarDetalhePage> createState() => _ContaPagarDetalhePageState();
}

class _ContaPagarDetalhePageState extends State<ContaPagarDetalhePage> {
  final _dbService = DbService(); // antes era _isarService
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  final ContaPagarRepository _repository = ContaPagarRepository();
  final LancamentoRepository _repositoryLancamento = LancamentoRepository();

  List<ContaPagar> _parcelas = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    final lista = await _repository.getParcelasPorGrupo(widget.grupoParcelas);

    setState(() {
      _parcelas = lista;
      _carregando = false;
    });
  }

  // ---------------------------------------------------------------------------
  // MOSTRAR LANÇAMENTO VINCULADO A UMA PARCELA (id_lancamento)
  // ---------------------------------------------------------------------------
  Future<void> _mostrarLancamentoVinculado(ContaPagar parcela) async {
    Lancamento? lanc;

    // 1) Tenta pelo id_lancamento (caso fatura de cartão)
    if (parcela.idLancamento != null) {
      lanc = await _repositoryLancamento.getById(parcela.idLancamento!);
    }

    // 2) Se não encontrou, tenta pelo grupo + nº parcela
    if (lanc == null) {
      final lancamentosDoGrupo = await _repositoryLancamento
          .getParcelasPorGrupo(parcela.grupoParcelas);

      lanc = lancamentosDoGrupo.firstWhereOrNull(
        (l) => (l.parcelaNumero ?? 1) == (parcela.parcelaNumero ?? 1),
      );
    }

    // 3) Fallback final: tenta bater por data + valor + descrição
    if (lanc == null) {
      final db = await _dbService.db;

      final result = await db.query(
        'lancamentos',
        where: 'data_hora = ? AND valor = ? AND descricao = ?',
        whereArgs: [
          parcela.dataVencimento.millisecondsSinceEpoch,
          parcela.valor,
          parcela.descricao,
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        lanc = Lancamento.fromMap(result.first);
      }
    }

    // 4) Se ainda assim não achou, mostra aviso
    if (lanc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta parcela não possui lançamento vinculado.'),
          ),
        );
      }
      return;
    }

    // 5) Achou → exibe o bottom sheet com o lançamento
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
        final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Lançamento vinculado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  lanc!.pagamentoFatura == true
                      ? Icons.credit_card
                      : Icons.receipt_long,
                ),
                title: Text(lanc.descricao),
                subtitle: Text(dateTimeFormat.format(lanc.dataHora)),
                trailing: Text(
                  currency.format(lanc.valor),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forma de pagamento: '
                      '${lanc.formaPagamento.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (lanc.grupoParcelas != null &&
                        lanc.parcelaNumero != null &&
                        lanc.parcelaTotal != null)
                      Text(
                        'Grupo: ${lanc.grupoParcelas} · '
                        'Parcela ${lanc.parcelaNumero}/${lanc.parcelaTotal}',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTRAR PAGAMENTO
  // ---------------------------------------------------------------------------
  Future<void> _registrarPagamento(ContaPagar parcela) async {
    final agora = DateTime.now();
    final db = _dbService;

    // 0) Cartão de crédito → só marca conta a pagar como paga
    final bool ehCartao =
        parcela.formaPagamento == FormaPagamento.credito &&
        parcela.idCartao != null;

    if (ehCartao) {
      if (parcela.id != null) {
        await _repository.marcarParcelaComoPaga(parcela.id!, true);
      }

      await _carregar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Parcela de cartão paga. Aguarde quitação na fatura.',
            ),
          ),
        );
      }
      return;
    }

    // 1) Localizar lançamento FUTURO associado
    Lancamento? lancamentoOriginal;

    final lancamentosDoGrupo = await _repositoryLancamento.getParcelasPorGrupo(
      parcela.grupoParcelas,
    );

    lancamentoOriginal = lancamentosDoGrupo.firstWhereOrNull(
      (l) => (l.parcelaNumero ?? 1) == (parcela.parcelaNumero ?? 1),
    );

    // fallback caso não ache pelo grupo
    if (lancamentoOriginal == null) {
      final database = await db.db;
      final result = await database.query(
        'lancamentos',
        where: 'data_hora = ? AND valor = ? AND descricao = ?',
        whereArgs: [
          parcela.dataVencimento.millisecondsSinceEpoch,
          parcela.valor,
          parcela.descricao,
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        lancamentoOriginal = Lancamento.fromMap(result.first);
      }
    }

    // 2) Apagar lançamento FUTURO original
    if (lancamentoOriginal != null && lancamentoOriginal.id != null) {
      await _repositoryLancamento.deletar(lancamentoOriginal.id!);
    }

    // 3) Criar novo lançamento PAGO NA DATA ATUAL
    final novoLancamento = Lancamento(
      id: null,
      valor: parcela.valor,
      descricao:
          'Parcela ${parcela.parcelaNumero}/${parcela.parcelaTotal} - ${parcela.descricao}',
      formaPagamento: parcela.formaPagamento ?? FormaPagamento.debito,
      dataHora: agora,
      pagamentoFatura: false,
      pago: true,
      dataPagamento: agora,
      categoria: lancamentoOriginal?.categoria ?? Categoria.outros,
      idCartao: parcela.idCartao,
      idConta: parcela.idConta,
      grupoParcelas: parcela.grupoParcelas,
      parcelaNumero: parcela.parcelaNumero,
      parcelaTotal: parcela.parcelaTotal,
    );

    await _repositoryLancamento.salvar(novoLancamento);

    // 4) Marcar conta a pagar como paga
    if (parcela.id != null) {
      await _repository.marcarParcelaComoPaga(parcela.id!, true);
    }

    // 5) Atualizar tela e feedback
    await _carregar();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcela paga com sucesso. Lançamento atualizado.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes das parcelas')),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _parcelas.isEmpty
              ? const Center(child: Text('Nenhuma parcela encontrada.'))
              : ListView.builder(
                itemCount: _parcelas.length,
                itemBuilder: (context, index) {
                  final p = _parcelas[index];
                  final vencida =
                      !p.pago && p.dataVencimento.isBefore(DateTime.now());

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    color:
                        vencida
                            ? colors.errorContainer.withOpacity(0.15)
                            : null,
                    child: ListTile(
                      leading: Icon(
                        p.pago ? Icons.check_circle : Icons.schedule,
                        color:
                            p.pago
                                ? Colors.green
                                : (vencida ? colors.error : colors.primary),
                      ),
                      title: Text(
                        'Parcela ${p.parcelaNumero}/${p.parcelaTotal}',
                      ),
                      subtitle: Text(
                        'Vencimento: ${_dateFormat.format(p.dataVencimento)}'
                        '${p.pago && p.dataPagamento != null ? ' · paga em ${_dateFormat.format(p.dataPagamento!)}' : ''}\n'
                        'Toque longo para ver o lançamento vinculado',
                        maxLines: 2,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currency.format(p.valor),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (!p.pago) const SizedBox(height: 4),
                          if (!p.pago)
                            Text(
                              'Pendente',
                              style: TextStyle(
                                fontSize: 11,
                                color: vencida ? colors.error : colors.primary,
                              ),
                            ),
                        ],
                      ),
                      // Toque normal → pagar
                      onTap:
                          p.pago
                              ? null
                              : () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Registrar pagamento'),
                                      content: Text(
                                        'Registrar o pagamento desta parcela '
                                        'no valor de ${_currency.format(p.valor)}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Pagar'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmar == true) {
                                  await _registrarPagamento(p);
                                }
                              },
                      // Toque longo → ver lançamento vinculado
                      onLongPress: () => _mostrarLancamentoVinculado(p),
                    ),
                  );
                },
              ),
    );
  }
}
