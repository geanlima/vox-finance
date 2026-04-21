// lib/ui/pages/contas_pagar/contas_pagar_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/service/ia_service.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_service.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';

import 'conta_pagar_detalhe.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

/// Modo ao editar um grupo em [ContasPagarPage]: só dados do grupo ou também quantidade de parcelas.
enum _ModoEdicaoContasPagar { cabecalho, parcelas }

class ContaPagarResumo {
  final String grupoParcelas;
  final String descricao;

  /// soma de TODAS as parcelas do grupo
  final double valorTotal;

  /// soma SOMENTE das parcelas ainda não pagas
  final double valorPendente;

  final int quantidadeParcelas;
  final DateTime primeiroVencimento;
  final DateTime? ultimoVencimento;
  final bool todasPagas;

  // descrição da forma de pagamento (ex: "Crédito - Nubank • ****1234")
  final String? formaDescricao;

  /// Referência da compra (planejamento e filtros); se nula no banco, igual ao 1º vencimento.
  final DateTime dataCabecalho;

  ContaPagarResumo({
    required this.grupoParcelas,
    required this.descricao,
    required this.valorTotal,
    required this.valorPendente,
    required this.quantidadeParcelas,
    required this.primeiroVencimento,
    required this.ultimoVencimento,
    required this.todasPagas,
    required this.dataCabecalho,
    this.formaDescricao,
  });
}

class ContasPagarPage extends StatefulWidget {
  const ContasPagarPage({super.key});

  @override
  State<ContasPagarPage> createState() => _ContasPagarPageState();
}

class _ContasPagarPageState extends State<ContasPagarPage> {
  final _isarService = DbService();
  late final IAService _iaService;

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final LancamentoRepository _repositoryLancamento = LancamentoRepository();
  final CartaoCreditoRepository _cartaoLancamento = CartaoCreditoRepository();
  final ContaPagarRepository _contaPagarLancamento = ContaPagarRepository();
  final DespesasFixasService _despesasFixasService = DespesasFixasService();

  List<ContaPagarResumo> _resumos = [];
  bool _mostrarSomentePendentes = true;
  bool _carregando = false;

  // 🔢 Totalizadores
  double _totalGeral = 0;
  double _totalPendente = 0;
  double get _totalPago => _totalGeral - _totalPendente;

  // 🔢 Totalizadores (somente faturas de cartão)
  double _totalFaturasGeral = 0;

  Widget _totChip(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool fullWidth = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _iaService = IAService(_isarService);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _despesasFixasService.gerarNoMesAtualSeNecessario();
    await _carregar();
  }

  Future<String?> _obterDescricaoFormaPagamento(String grupoParcelas) async {
    // usa os lançamentos daquele grupo de parcelas
    final lancs =
        await _repositoryLancamento.getParcelasPorGrupo(grupoParcelas);

    if (lancs.isEmpty) return null;

    final Lancamento l = lancs.first;

    // Se tiver cartão
    if (l.formaPagamento == FormaPagamento.credito && l.idCartao != null) {
      final CartaoCredito? cartao =
          await _cartaoLancamento.getCartaoCreditoById(l.idCartao!);

      if (cartao != null) {
        final ultimos =
            (cartao.ultimos4Digitos.isNotEmpty)
                ? cartao.ultimos4Digitos
                : '****';
        return 'Crédito - ${cartao.descricao} • **** $ultimos';
      }

      return 'Crédito (sem cartão cadastrado)';
    }

    // PIX / boleto / transferência / débito / dinheiro etc.
    return l.formaPagamento.label; // se o enum tiver label
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    final todasParcelas =
        _mostrarSomentePendentes
            ? await _contaPagarLancamento.getPendentes()
            : await _contaPagarLancamento.getTodas();

    // Agrupa por grupoParcelas
    final mapa = <String, List<ContaPagar>>{};
    final mapaFaturas = <String, List<ContaPagar>>{};

    for (final conta in todasParcelas) {
      final grupo = conta.grupoParcelas; // agora é obrigatório (String)
      // Não considerar "contas a pagar" geradas apenas para o lançamento de fatura do cartão.
      // Elas existem para controle do vencimento da fatura, mas não devem entrar nos totais
      // (nem na lista) de Contas a pagar.
      if (grupo.startsWith('FATURA_')) {
        mapaFaturas.putIfAbsent(grupo, () => []).add(conta);
        continue;
      }
      mapa.putIfAbsent(grupo, () => []).add(conta);
    }

    final resumos = <ContaPagarResumo>[];
    final resumosFaturas = <ContaPagarResumo>[];

    for (final entry in mapa.entries) {
      final grupo = entry.key;
      final parcelas = entry.value;

      parcelas.sort((a, b) {
        final pa = a.parcelaNumero ?? 0;
        final pb = b.parcelaNumero ?? 0;
        return pa.compareTo(pb);
      });

      final descricao = parcelas.first.descricao;
      final qtd = parcelas.length;

      // 🔢 total do grupo (todas as parcelas)
      final valorTotal = parcelas.fold<double>(
        0,
        (soma, c) => soma + c.valor,
      );

      // 🔢 total PENDENTE do grupo (somente não pagas)
      final valorPendente = parcelas
          .where((c) => !c.pago)
          .fold<double>(0, (soma, c) => soma + c.valor);

      final primeiroVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final ultimoVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final todasPagas = parcelas.every((c) => c.pago);

      final dataCabecalho =
          parcelas.first.dataCabecalho ?? primeiroVencimento;

      // pega a forma de pagamento através dos lançamentos (se existirem)
      final formaDescricao = await _obterDescricaoFormaPagamento(grupo);

      resumos.add(
        ContaPagarResumo(
          grupoParcelas: grupo,
          descricao: descricao,
          valorTotal: valorTotal,
          valorPendente: valorPendente,
          quantidadeParcelas: qtd,
          primeiroVencimento: primeiroVencimento,
          ultimoVencimento: qtd > 1 ? ultimoVencimento : null,
          todasPagas: todasPagas,
          dataCabecalho: dataCabecalho,
          formaDescricao: formaDescricao,
        ),
      );
    }

    for (final entry in mapaFaturas.entries) {
      final grupo = entry.key;
      final parcelas = entry.value;

      parcelas.sort((a, b) {
        final pa = a.parcelaNumero ?? 0;
        final pb = b.parcelaNumero ?? 0;
        return pa.compareTo(pb);
      });

      final descricao = parcelas.first.descricao;
      final qtd = parcelas.length;
      final valorTotal = parcelas.fold<double>(0, (soma, c) => soma + c.valor);
      final valorPendente =
          parcelas.where((c) => !c.pago).fold<double>(0, (soma, c) => soma + c.valor);

      final primeiroVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final ultimoVencimento = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final todasPagas = parcelas.every((c) => c.pago);
      final formaDescricao = await _obterDescricaoFormaPagamento(grupo);
      final dataCabecalho =
          parcelas.first.dataCabecalho ?? primeiroVencimento;

      resumosFaturas.add(
        ContaPagarResumo(
          grupoParcelas: grupo,
          descricao: descricao,
          valorTotal: valorTotal,
          valorPendente: valorPendente,
          quantidadeParcelas: qtd,
          primeiroVencimento: primeiroVencimento,
          ultimoVencimento: qtd > 1 ? ultimoVencimento : null,
          todasPagas: todasPagas,
          dataCabecalho: dataCabecalho,
          formaDescricao: formaDescricao,
        ),
      );
    }

    // 🔢 recalcula totalizadores
    double totalGeral = 0;
    double totalPendente = 0;
    for (final r in resumos) {
      totalGeral += r.valorTotal;
      totalPendente += r.valorPendente;
    }

    double totalFaturasGeral = 0;
    for (final r in resumosFaturas) {
      totalFaturasGeral += r.valorTotal;
    }

    setState(() {
      _resumos = resumos;
      _carregando = false;
      _totalGeral = totalGeral;
      _totalPendente = totalPendente;
      _totalFaturasGeral = totalFaturasGeral;
    });
  }

  Future<void> _excluirGrupo(ContaPagarResumo resumo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir contas a pagar'),
          content: Text(
            'Deseja excluir todas as parcelas de "${resumo.descricao}" '
            '(${resumo.quantidadeParcelas} parcela(s))?\n\n'
            'Os lançamentos vinculados também serão removidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      // 1) Exclui contas a pagar
      await _contaPagarLancamento.deletarPorGrupo(resumo.grupoParcelas);

      // 2) Exclui lançamentos vinculados ao mesmo grupo
      await _repositoryLancamento.deletarPorGrupo(resumo.grupoParcelas);

      await _carregar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contas e lançamentos excluídos.')),
        );
      }
    }
  }

  /// Lançamentos do mesmo `grupo_parcelas` ou, se vazio, via `id_lancamento` nas contas.
  Future<void> _abrirLancamentosDoGrupo(ContaPagarResumo resumo) async {
    var lancs = await _repositoryLancamento.getParcelasPorGrupo(
      resumo.grupoParcelas,
    );
    if (lancs.isEmpty) {
      final parcelas = await _contaPagarLancamento.getParcelasPorGrupo(
        resumo.grupoParcelas,
      );
      final ids = <int>{};
      for (final p in parcelas) {
        if (p.idLancamento != null) ids.add(p.idLancamento!);
      }
      if (ids.isNotEmpty) {
        final map = await _repositoryLancamento.getByIds(ids);
        lancs = map.values.toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
      }
    }

    if (!mounted) return;
    if (lancs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum lançamento vinculado a este grupo.'),
        ),
      );
      return;
    }

    final dateLinha = DateFormat('dd/MM/yyyy');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.55;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lançamentos — ${resumo.descricao}',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: maxH.clamp(180.0, 520.0),
                  child: ListView.separated(
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
                    itemCount: lancs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = lancs[i];
                      final ehParc =
                          l.parcelaTotal != null && l.parcelaTotal! > 1;
                      final rotuloParc =
                          ehParc
                              ? ' · ${l.parcelaNumero ?? '?'}/${l.parcelaTotal}'
                              : '';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(
                          '${l.descricao}$rotuloParc',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${dateLinha.format(l.dataHora)} · '
                          '${l.pago ? 'Pago' : 'Pendente'}',
                        ),
                        trailing: Text(
                          _currency.format(l.valor),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirForm({ContaPagarResumo? existente}) async {
    final descricaoController = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final valorController = TextEditingController(
      text:
          existente != null
              ? NumberFormat('#,##0.00', 'pt_BR').format(existente.valorTotal)
              : '',
    );
    final parcelasController = TextEditingController(
      text: existente?.quantidadeParcelas.toString() ?? '1',
    );

    DateTime dataPrimeiroVencimento =
        existente?.primeiroVencimento ?? DateTime.now();
    DateTime dataCabecalho =
        existente?.dataCabecalho ?? existente?.primeiroVencimento ?? DateTime.now();
    var modoEdicao = _ModoEdicaoContasPagar.cabecalho;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mq = MediaQuery.of(context);
            final viewInsets = mq.viewInsets;
            final sysPadding = mq.padding;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: viewInsets.bottom + sysPadding.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ============ CONTEÚDO ROLÁVEL ============
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // "pegador"
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),

                              Row(
                                children: [
                                  Icon(
                                    existente == null ? Icons.add : Icons.edit,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    existente == null
                                        ? 'Nova conta / compra parcelada'
                                        : 'Editar contas a pagar',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (existente != null) ...[
                                Text(
                                  'Modo de edição',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final cs = Theme.of(context).colorScheme;
                                    return SegmentedButton<_ModoEdicaoContasPagar>(
                                      showSelectedIcon: false,
                                      style: ButtonStyle(
                                        side: WidgetStateProperty.all(
                                          BorderSide(
                                            color: cs.outline
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states
                                              .contains(WidgetState.selected)) {
                                            return cs.primaryContainer;
                                          }
                                          return cs.surfaceContainerHighest
                                              .withValues(alpha: 0.65);
                                        }),
                                        foregroundColor:
                                            WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states
                                              .contains(WidgetState.selected)) {
                                            return cs.onPrimaryContainer;
                                          }
                                          return cs.onSurface;
                                        }),
                                        iconColor:
                                            WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states
                                              .contains(WidgetState.selected)) {
                                            return cs.onPrimaryContainer;
                                          }
                                          return cs.onSurfaceVariant;
                                        }),
                                      ),
                                      segments: const [
                                        ButtonSegment(
                                          value:
                                              _ModoEdicaoContasPagar.cabecalho,
                                          label: Text('Cabeçalho'),
                                          icon: Icon(Icons.article_outlined),
                                        ),
                                        ButtonSegment(
                                          value:
                                              _ModoEdicaoContasPagar.parcelas,
                                          label: Text('Parcelas'),
                                          icon: Icon(Icons.view_list_outlined),
                                        ),
                                      ],
                                      selected: {modoEdicao},
                                      onSelectionChanged: (s) {
                                        setModalState(() {
                                          modoEdicao = s.first;
                                        });
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  modoEdicao == _ModoEdicaoContasPagar.cabecalho
                                      ? 'Cabeçalho: descrição, valor total e data da compra '
                                          '(referência). Não altera vencimentos nem lançamentos.'
                                      : 'Parcelas: quantidade e primeiro vencimento — '
                                          'recalcula todas as parcelas e alinha lançamentos. '
                                          'Não é possível excluir parcelas já pagas.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              TextField(
                                controller: descricaoController,
                                decoration: const InputDecoration(
                                  labelText: 'Descrição',
                                  hintText: 'Ex: Notebook, TV, Cartão, etc.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: valorController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Valor total',
                                  hintText: 'Ex: 1200,00',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (existente == null)
                                TextField(
                                  controller: parcelasController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade de parcelas',
                                    hintText: 'Ex: 1, 6, 12...',
                                    border: OutlineInputBorder(),
                                  ),
                                )
                              else if (modoEdicao ==
                                  _ModoEdicaoContasPagar.cabecalho)
                                InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Parcelas',
                                    border: const OutlineInputBorder(),
                                    helperText:
                                        '${existente.quantidadeParcelas} parcela'
                                        '${existente.quantidadeParcelas == 1 ? '' : 's'} '
                                        '— para mudar a quantidade, use o modo Parcelas.',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '${existente.quantidadeParcelas} parcela'
                                      '${existente.quantidadeParcelas == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              else
                                TextField(
                                  controller: parcelasController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade de parcelas',
                                    hintText: 'Ex: 1, 6, 12...',
                                    border: OutlineInputBorder(),
                                    helperText:
                                        'Parcelas a mais serão criadas; a mais no fim '
                                        '(não pagas) serão excluídas com o lançamento.',
                                  ),
                                ),
                              const SizedBox(height: 12),

                              if (existente == null)
                                InkWell(
                                  onTap: () async {
                                    final novaData = await showDatePicker(
                                      context: context,
                                      initialDate: dataPrimeiroVencimento,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (novaData != null) {
                                      setModalState(() {
                                        dataPrimeiroVencimento = DateTime(
                                          novaData.year,
                                          novaData.month,
                                          novaData.day,
                                        );
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Primeiro vencimento: '
                                            '${_dateFormat.format(dataPrimeiroVencimento)} '
                                            '(data do cabeçalho será a mesma ao criar)',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (modoEdicao ==
                                  _ModoEdicaoContasPagar.cabecalho) ...[
                                InkWell(
                                  onTap: () async {
                                    final novaData = await showDatePicker(
                                      context: context,
                                      initialDate: dataCabecalho,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (novaData != null) {
                                      setModalState(() {
                                        dataCabecalho = DateTime(
                                          novaData.year,
                                          novaData.month,
                                          novaData.day,
                                        );
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Data do cabeçalho (compra/referência): '
                                            '${_dateFormat.format(dataCabecalho)}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                InkWell(
                                  onTap: () async {
                                    final novaData = await showDatePicker(
                                      context: context,
                                      initialDate: dataPrimeiroVencimento,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (novaData != null) {
                                      setModalState(() {
                                        dataPrimeiroVencimento = DateTime(
                                          novaData.year,
                                          novaData.month,
                                          novaData.day,
                                        );
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Primeiro vencimento (recalcula parcelas e '
                                            'lançamentos): '
                                            '${_dateFormat.format(dataPrimeiroVencimento)}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data do cabeçalho (referência)',
                                    border: OutlineInputBorder(),
                                    helperText:
                                        'Editada no modo Cabeçalho. Usada no planejamento para vincular o grupo.',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      _dateFormat.format(existente.dataCabecalho),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                      // ============ RODAPÉ FIXO COM BOTÕES ============
                      const Divider(height: 1),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          8 + sysPadding.bottom,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final desc = descricaoController.text.trim();
                                final valorTotal = CurrencyInputFormatter.parse(
                                  valorController.text,
                                );
                                final qtdParcelas =
                                    existente == null
                                        ? (int.tryParse(
                                              parcelasController.text.trim(),
                                            ) ??
                                            1)
                                        : modoEdicao ==
                                            _ModoEdicaoContasPagar.cabecalho
                                        ? existente.quantidadeParcelas
                                        : (int.tryParse(
                                              parcelasController.text.trim(),
                                            ) ??
                                            existente.quantidadeParcelas);

                                if (desc.isEmpty ||
                                    valorTotal <= 0 ||
                                    qtdParcelas <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Informe descrição, valor total e '
                                        'quantidade de parcelas válidos.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (existente != null) {
                                  if (modoEdicao ==
                                      _ModoEdicaoContasPagar.cabecalho) {
                                    await _contaPagarLancamento
                                        .atualizarCabecalhoGrupoContasPagar(
                                          grupoParcelas:
                                              existente.grupoParcelas,
                                          descricao: desc,
                                          valorTotal: valorTotal,
                                          dataCabecalho: dataCabecalho,
                                        );
                                  } else {
                                    final err = await _contaPagarLancamento
                                        .redimensionarEAtualizarGrupoContasPagar(
                                          grupoParcelas:
                                              existente.grupoParcelas,
                                          descricao: desc,
                                          valorTotal: valorTotal,
                                          primeiraDataVencimento:
                                              dataPrimeiroVencimento,
                                          novaQuantidadeParcelas: qtdParcelas,
                                        );
                                    if (err != null) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(err)),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                } else if (qtdParcelas == 1) {
                                  await _iaService.salvarContaSimples(
                                    descricao: desc,
                                    valor: valorTotal,
                                    dataVencimento: dataPrimeiroVencimento,
                                  );
                                } else {
                                  await _iaService.salvarContasParceladas(
                                    descricao: desc,
                                    valorTotal: valorTotal,
                                    quantidadeParcelas: qtdParcelas,
                                    primeiraDataVencimento:
                                        dataPrimeiroVencimento,
                                  );
                                }

                                await _carregar();

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (existente != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          modoEdicao ==
                                                  _ModoEdicaoContasPagar.cabecalho
                                              ? 'Cabeçalho atualizado (descrição, '
                                                  'valores e data de referência). '
                                                  'Vencimentos e lançamentos não mudaram.'
                                              : 'Parcelas atualizadas. Valores e '
                                                  'vencimentos recalculados; '
                                                  'lançamentos foram ajustados ou '
                                                  'removidos conforme o novo tamanho.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                existente == null ? 'Salvar' : 'Salvar alterações',
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget buildLista() {
      if (_carregando) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_resumos.isEmpty) {
        return const Center(child: Text('Nenhuma conta cadastrada.'));
      }

      return ListView.builder(
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
        itemCount: _resumos.length,
        itemBuilder: (context, index) {
          final resumo = _resumos[index];
          final vencida =
              !resumo.todasPagas &&
              resumo.ultimoVencimento != null &&
              resumo.ultimoVencimento!.isBefore(DateTime.now());

          final theme = Theme.of(context);
          final primary = theme.colorScheme.primary;
          final secondary = theme.colorScheme.secondary;
          final danger = Colors.red.shade400;

          return Slidable(
            key: ValueKey(resumo.grupoParcelas),
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.22,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _abrirLancamentosDoGrupo(resumo),
                  backgroundColor: secondary,
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.receipt_long,
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
                  onPressed: (_) => _abrirForm(existente: resumo),
                  backgroundColor: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(Icons.edit, size: 28, color: primary),
                ),
                CustomSlidableAction(
                  onPressed: (_) => _excluirGrupo(resumo),
                  backgroundColor: danger,
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.delete, size: 28, color: Colors.white),
                ),
              ],
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  resumo.todasPagas
                      ? Icons.check_circle
                      : (resumo.quantidadeParcelas > 1
                          ? Icons.payments
                          : Icons.schedule),
                  color: resumo.todasPagas
                      ? Colors.green
                      : (vencida ? colors.error : colors.primary),
                ),
                title: Text(resumo.descricao),
                isThreeLine: resumo.quantidadeParcelas == 1,
                subtitle: Text(
                  resumo.quantidadeParcelas == 1
                      ? 'Vencimento: ${_dateFormat.format(resumo.primeiroVencimento)}\n'
                          '${resumo.valorPendente > 0 ? 'Pendente: ${_currency.format(resumo.valorPendente)}' : 'Tudo pago'}'
                      : (resumo.valorPendente > 0
                          ? 'Pendente: ${_currency.format(resumo.valorPendente)}'
                          : 'Tudo pago'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        resumo.todasPagas
                            ? Colors.green.shade800
                            : (vencida ? colors.error : Colors.orange.shade900),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(resumo.valorTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (resumo.quantidadeParcelas > 1)
                      Text(
                        '(${resumo.quantidadeParcelas}x de '
                        '${_currency.format(resumo.valorTotal / resumo.quantidadeParcelas)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ContaPagarDetalhePage(
                            grupoParcelas: resumo.grupoParcelas,
                          ),
                    ),
                  ).then((_) => _carregar());
                },
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a pagar'),
        actions: [
          IconButton(
            icon: Icon(
              _mostrarSomentePendentes
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            tooltip:
                _mostrarSomentePendentes
                    ? 'Mostrar todas'
                    : 'Mostrar só pendentes',
            onPressed: () {
              setState(() {
                _mostrarSomentePendentes = !_mostrarSomentePendentes;
              });
              _carregar();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/contas-pagar'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 🔢 TOTALIZADOR
          if (!_carregando && _resumos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumo',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _totChip(
                              context,
                              'Já pago',
                              _currency.format(_totalPago),
                              Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _totChip(
                              context,
                              'Pendente',
                              _currency.format(_totalPendente),
                              Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _totChip(
                              context,
                              'Total geral',
                              _currency.format(_totalGeral),
                              Theme.of(context).colorScheme.primary,
                              fullWidth: true,
                            ),
                          ),
                          if (_totalFaturasGeral > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _totChip(
                                context,
                                'Faturas cartão',
                                _currency.format(_totalFaturasGeral),
                                Theme.of(context).colorScheme.primary,
                                fullWidth: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Lista
          Expanded(child: buildLista()),
        ],
      ),
    );
  }
}
