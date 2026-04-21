// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/integracao_fatura_cache.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/utils/money_split.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/regra_cartao_parcelado_service.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/integracao/integracao_fatura_cache_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';
import 'package:vox_finance/ui/core/service/integracao_cartoes_api_service.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

enum _ModoAssociarFaturaItem { lancamento, contaPagar }

class FaturaSalvaDetalhePage extends StatefulWidget {
  final IntegracaoFaturaCache fatura;
  final CartaoCredito? cartao;
  final String periodoLabel;

  const FaturaSalvaDetalhePage({
    super.key,
    required this.fatura,
    required this.cartao,
    required this.periodoLabel,
  });

  @override
  State<FaturaSalvaDetalhePage> createState() => _FaturaSalvaDetalhePageState();
}

class _FaturaSalvaDetalhePageState extends State<FaturaSalvaDetalhePage> {
  final _repo = IntegracaoFaturaCacheRepository();
  final _cartaoRepo = CartaoCreditoRepository();
  final _contaRepo = ContaBancariaRepository();
  final _lancRepo = LancamentoRepository();
  final _contaPagarRepo = ContaPagarRepository();
  final _api = IntegracaoCartoesApiService.instance;
  final _dbService = DbService.instance;
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHora = DateFormat.yMMMd('pt_BR').add_Hm();

  bool _loading = true;
  List<IntegracaoFaturaCacheItem> _itens = const [];
  List<Lancamento> _lancamentosPeriodo = const [];
  List<ContaPagar> _contasPagarPeriodo = const [];
  final Map<int, Lancamento> _lancById = {};
  bool _mostrarSomenteNaoAssociados = false;
  IntegracaoFaturaCache? _faturaAtual;
  Lancamento? _lancamentoFaturaGerado;
  final ScrollController _itensScroll = ScrollController();

  @override
  void dispose() {
    _itensScroll.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _bloquearAlteracoesSeFechada() {
    if (!_faturaFechada) return false;
    _snack('A fatura está fechada. Para alterar, favor reabrir.');
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.fatura.id;
    if (id == null) {
      setState(() {
        _itens = const [];
        _lancamentosPeriodo = const [];
        _contasPagarPeriodo = const [];
        _lancById.clear();
        _faturaAtual = null;
        _lancamentoFaturaGerado = null;
        _loading = false;
      });
      return;
    }
    final itens = await _repo.listarItens(id);
    final lancs = await _repo.listarLancamentosParaAssociacaoFatura(
      idCartaoLocal: widget.fatura.idCartaoLocal,
    );
    final contas = await _contaPagarRepo.listarParaAssociacaoFatura(
      idCartaoLocal: widget.fatura.idCartaoLocal,
    );
    final fat = await _repo.getById(id);
    final int? idLancFatura = fat?.idLancamentoFatura;
    final Lancamento? lancFatura =
        idLancFatura == null ? null : await _lancRepo.getById(idLancFatura);
    final byId = <int, Lancamento>{};
    for (final l in lancs) {
      final lid = l.id;
      if (lid != null) byId[lid] = l;
    }
    // Vínculos já salvos podem apontar para lançamentos fora do filtro de candidatos
    // (ex.: vencimento da parcela em outro recorte); ainda assim precisam aparecer no chip.
    final idsVinculo = <int>{};
    for (final it in itens) {
      final v = it.idLancamentoLocal;
      if (v != null && !byId.containsKey(v)) idsVinculo.add(v);
    }
    for (final idL in idsVinculo) {
      final extra = await _lancRepo.getById(idL);
      if (extra != null) byId[idL] = extra;
    }
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _lancamentosPeriodo = lancs;
      _contasPagarPeriodo = contas;
      _lancById
        ..clear()
        ..addAll(byId);
      _faturaAtual = fat;
      _lancamentoFaturaGerado = lancFatura;
      _loading = false;
    });
  }

  double? _scrollOffsetAtualItens() {
    if (!_itensScroll.hasClients) return null;
    return _itensScroll.offset;
  }

  Future<void> _restaurarScrollItens(double? offset) async {
    if (offset == null) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_itensScroll.hasClients) return;
      final max = _itensScroll.position.maxScrollExtent;
      final target = offset.clamp(0.0, max);
      _itensScroll.jumpTo(target);
    });
  }

  double get _somaItens => _itens.fold<double>(0, (a, l) => a + l.valor);
  double get _somaAssociados =>
      _itens
          .where((i) => i.idLancamentoLocal != null)
          .fold<double>(0, (a, l) => a + l.valor);
  double get _somaNaoAssociados =>
      _itens
          .where((i) => i.idLancamentoLocal == null)
          .fold<double>(0, (a, l) => a + l.valor);
  int get _qtdAssociados =>
      _itens.where((i) => i.idLancamentoLocal != null).length;
  int get _qtdNaoAssociados =>
      _itens.where((i) => i.idLancamentoLocal == null).length;

  bool get _faturaFechada =>
      _faturaAtual != null
          ? (_faturaAtual!.idLancamentoFatura != null)
          : (widget.fatura.idLancamentoFatura != null);

  bool get _temItensSemData => _itens.any((i) => i.dataHora == null);

  Future<void> _atualizarDatasDoCachePelaApi() async {
    if (_bloquearAlteracoesSeFechada()) return;
    final f = _faturaAtual ?? widget.fatura;
    final idFaturaCache = f.id;
    if (idFaturaCache == null) return;
    final idApiCartao = f.codigoCartaoApi.trim();
    if (idApiCartao.isEmpty) {
      _snack('Cartão não está associado à API (codigoCartaoApi vazio).');
      return;
    }

    setState(() => _loading = true);
    try {
      final faturasApi = await _api.listarFaturasPorCartaoMes(
        idCartaoApi: idApiCartao,
        ano: f.ano,
        mes: f.mes,
      );
      if (faturasApi.isEmpty) {
        _snack('Não encontrei fatura na API para este período.');
        return;
      }

      // Preferência: bater pelo id da fatura na API (quando disponível)
      final apiId = f.faturaApiId?.trim();
      final alvo =
          (apiId != null && apiId.isNotEmpty)
              ? (faturasApi.firstWhere(
                (x) => x.id?.toString() == apiId,
                orElse: () => faturasApi.first,
              ))
              : faturasApi.first;

      final map = <String, DateTime>{};
      for (final it in alvo.lancamentos) {
        final k = it.id?.toString();
        final dt = it.dataHora;
        if (k == null || k.isEmpty || dt == null) continue;
        map[k] = dt;
      }

      await _repo.atualizarDataHoraItens(
        idFaturaCache: idFaturaCache,
        dataPorItemApiId: map,
      );

      if (!mounted) return;
      await _load();
      _snack('Datas atualizadas no cache.');
    } catch (e) {
      _snack('Erro ao atualizar datas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fecharFatura(BuildContext context) async {
    final f = _faturaAtual ?? widget.fatura;
    final idFaturaCache = f.id;
    final cartao = widget.cartao;

    if (idFaturaCache == null || cartao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível fechar a fatura.')),
      );
      return;
    }

    final double valorFechamento = _somaAssociados;
    final int qtdPendentes = _qtdNaoAssociados;
    if (qtdPendentes > 0) {
      final bool confirmar = (await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Pendência de associação'),
              content: Text(
                'Ainda existem $qtdPendentes item(ns) não associado(s).\n\n'
                'Se você continuar, vou fechar a fatura apenas com os lançamentos já associados '
                'no valor de ${_money.format(valorFechamento)}.\n\n'
                'Deseja fechar mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sim, fechar'),
                ),
              ],
            ),
          )) ??
          false;

      if (!confirmar) return;
    }

    if (valorFechamento <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum lançamento associado para fechar a fatura.'),
        ),
      );
      return;
    }

    // O lançamento de pagamento da fatura deve ser gerado no dia de vencimento
    // configurado no cadastro do cartão (mesmo que a API não traga vencimento).
    final int diaVenc = cartao.diaVencimento ?? 1;
    final venc =
        f.dataVencimento ?? DateTime(f.ano, f.mes, diaVenc);
    final fech = f.dataFechamento ?? venc;
    final periodo = '${f.mes.toString().padLeft(2, '0')}/${f.ano}';

    setState(() => _loading = true);
    try {
      // 1) Salva/atualiza a fatura "clássica" (fatura_cartao) para permitir abrir itens na Home
      final idFaturaCartao = await _cartaoRepo.salvarFaturaCartao(
        idCartao: cartao.id!,
        anoReferencia: venc.year,
        mesReferencia: venc.month,
        dataFechamento: fech,
        dataVencimento: venc,
        valorTotal: valorFechamento,
        pago: false,
      );

      // 2) Vínculos da fatura -> lançamentos locais (somente os associados)
      final idsLanc = _itens
          .map((i) => i.idLancamentoLocal)
          .whereType<int>()
          .toSet()
          .toList()
        ..sort();

      await _cartaoRepo.salvarFaturaCartaoLancamentos(
        idFatura: idFaturaCartao,
        idsLancamentos: idsLanc,
        substituirVinculos: true,
      );

      // 3) Cria o lançamento de "pagamento de fatura" (é ele que, ao clicar, abre os itens)
      final lancFatura = Lancamento(
        valor: valorFechamento,
        descricao: 'Fatura ${cartao.label} $periodo',
        formaPagamento: FormaPagamento.credito,
        // Usa 00:00 para bater com as regras existentes (e aviso na Home).
        dataHora: DateTime(venc.year, venc.month, venc.day),
        pagamentoFatura: true,
        pago: false,
        categoria: Categoria.outros,
        idCartao: cartao.id,
      );
      final idLancFatura = await _lancRepo.salvar(lancFatura);

      // 3b) Conta a pagar do valor total da fatura (vinculada ao lançamento de pagamento)
      await _contaPagarRepo.upsertContaPagarDaFatura(
        idLancamento: idLancFatura,
        descricao: lancFatura.descricao,
        valor: valorFechamento,
        dataVencimento: DateTime(venc.year, venc.month, venc.day),
        idCartao: cartao.id,
      );

      // 4) Marca a fatura salva como fechada e guarda o id do lançamento gerado
      await _repo.marcarFaturaComoFechada(
        idFaturaCache: idFaturaCache,
        idLancamentoFatura: idLancFatura,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura fechada. Lançamento gerado.')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao fechar fatura: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _reabrirFatura(BuildContext context) async {
    final f = _faturaAtual ?? widget.fatura;
    final idFaturaCache = f.id;
    final idLancFatura = f.idLancamentoFatura;
    if (idFaturaCache == null || idLancFatura == null) return;

    // Se o lançamento de pagamento já está pago, não pode reabrir.
    if (_lancamentoFaturaGerado?.pago == true) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Não é possível reabrir'),
          content: const Text(
            'O lançamento da fatura já está pago. Não é possível reabrir.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final bool confirmar = (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reabrir fatura?'),
            content: const Text(
              'Isso vai remover o lançamento de pagamento da fatura e permitir fechar novamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reabrir'),
              ),
            ],
          ),
        )) ??
        false;

    if (!confirmar) return;

    setState(() => _loading = true);
    try {
      await _lancRepo.deletar(idLancFatura);
      await _repo.reabrirFatura(idFaturaCache: idFaturaCache);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura reaberta.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reabrir fatura: $e')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = _faturaAtual ?? widget.fatura;

    final itensVisiveis =
        _mostrarSomenteNaoAssociados
            ? _itens.where((i) => i.idLancamentoLocal == null).toList()
            : _itens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos'),
        actions: [
          if (!_loading && !_faturaFechada && _temItensSemData)
            IconButton(
              tooltip: 'Atualizar datas',
              icon: const Icon(Icons.event_repeat),
              onPressed: _atualizarDatasDoCachePelaApi,
            ),
          IconButton(
            tooltip:
                _mostrarSomenteNaoAssociados
                    ? 'Mostrando: não associados'
                    : 'Filtrar não associados',
            icon: Icon(
              _mostrarSomenteNaoAssociados
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed:
                _loading
                    ? null
                    : () => setState(() {
                      _mostrarSomenteNaoAssociados =
                          !_mostrarSomenteNaoAssociados;
                    }),
          ),
          IconButton(
            tooltip: 'Auto-associar',
            icon: const Icon(Icons.auto_fix_high),
            onPressed:
                _loading || _faturaFechada ? null : () => _autoAssociar(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (f.fechadaEm != null)
                          _infoRow(
                            'Fechada em',
                            DateFormat.yMMMd('pt_BR').add_Hm().format(f.fechadaEm!),
                          ),
                        if (_lancamentoFaturaGerado != null) ...[
                          _infoRow(
                            'Lançamento gerado',
                            DateFormat.yMMMd('pt_BR').format(
                              _lancamentoFaturaGerado!.dataHora,
                            ),
                          ),
                          _infoRow(
                            'Valor do lançamento',
                            _money.format(_lancamentoFaturaGerado!.valor),
                          ),
                        ],
                        if (f.dataFechamento != null)
                          _infoRow(
                            'Fechamento',
                            DateFormat.yMMMd('pt_BR').format(f.dataFechamento!),
                          ),
                        if (f.dataVencimento != null)
                          _infoRow(
                            'Vencimento',
                            DateFormat.yMMMd('pt_BR').format(f.dataVencimento!),
                          ),
                        if (f.pago != null)
                          _infoRow('Situação', f.pago! ? 'Paga' : 'Em aberto'),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total da fatura',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _money.format(f.valorTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_faturaFechada)
                          ElevatedButton.icon(
                            onPressed:
                                _loading ? null : () => _fecharFatura(context),
                            icon: const Icon(Icons.lock),
                            label: Text(
                              _qtdNaoAssociados > 0
                                  ? 'Fechar fatura (pendente: $_qtdNaoAssociados)'
                                  : 'Fechar fatura',
                            ),
                          )
                        else ...[
                          OutlinedButton.icon(
                            onPressed:
                                _loading ? null : () => _reabrirFatura(context),
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Reabrir fatura'),
                          ),
                        ],
                        if (_itens.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _totalizadorChip(
                                  label: 'Associados',
                                  qtd: _qtdAssociados,
                                  valor: _somaAssociados,
                                  color: cs.primary,
                                  icon: Icons.link,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _totalizadorChip(
                                  label: 'Faltam associar',
                                  qtd: _qtdNaoAssociados,
                                  valor: _somaNaoAssociados,
                                  color: cs.error,
                                  icon: Icons.link_off,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_itens.isNotEmpty &&
                            (_somaItens - f.valorTotal).abs() > 0.009) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Soma dos lançamentos: ${_money.format(_somaItens)} '
                            '(diferença ${_money.format((_somaItens - f.valorTotal).abs())}).',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _mostrarSomenteNaoAssociados
                          ? 'Não associados (${itensVisiveis.length} de ${_itens.length})'
                          : 'Lançamentos (${_itens.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: itensVisiveis.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum lançamento encontrado para esta fatura.',
                          ),
                        )
                      : ListView.separated(
                          padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 0, 16, 16)),
                          controller: _itensScroll,
                          itemCount: itensVisiveis.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final l = itensVisiveis[i];
                            final chips = <String>[];
                            if (l.dataHora != null) {
                              chips.add(_dateHora.format(l.dataHora!));
                            }
                            if (l.categoria?.trim().isNotEmpty == true) {
                              chips.add(l.categoria!.trim());
                            }

                            final vincId = l.idLancamentoLocal;
                            final vinc = vincId == null ? null : _lancById[vincId];
                            final badgeBg =
                                vinc == null
                                    ? cs.error.withOpacity(0.10)
                                    : cs.primary.withOpacity(0.10);
                            final badgeFg = vinc == null ? cs.error : cs.primary;

                            return Slidable(
                              key: ValueKey(l.id ?? i),
                              startActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.22,
                                children: [
                                  CustomSlidableAction(
                                    onPressed:
                                        (_) =>
                                            _faturaFechada
                                                ? _snack(
                                                  'A fatura está fechada. Para alterar, favor reabrir.',
                                                )
                                                : _selecionarLancamento(l),
                                    backgroundColor: cs.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Icon(
                                      Icons.link,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.22,
                                children: [
                                  CustomSlidableAction(
                                    onPressed:
                                        vinc == null
                                            ? null
                                            : (_) =>
                                                _faturaFechada
                                                    ? _snack(
                                                      'A fatura está fechada. Para alterar, favor reabrir.',
                                                    )
                                                    : _editarLancamento(vinc),
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Icon(
                                      Icons.edit,
                                      size: 28,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                title: Text(
                                  l.dataHora == null
                                      ? l.descricao
                                      : '${DateFormat('dd/MM').format(l.dataHora!)} - ${l.descricao}',
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (chips.isNotEmpty)
                                        Text(
                                          chips.join(' • '),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: badgeFg.withOpacity(0.30),
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(999),
                                          onTap:
                                              _faturaFechada
                                                  ? () => _snack(
                                                    'A fatura está fechada. Para alterar, favor reabrir.',
                                                  )
                                                  : () => _selecionarLancamento(l),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Icon(
                                                vinc == null
                                                    ? Icons.link_off
                                                    : Icons.link,
                                                size: 16,
                                                color: badgeFg,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  vinc == null
                                                      ? 'Não associado'
                                                      : 'Associado: ${vinc.descricao}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: badgeFg,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: badgeFg,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (vinc == null && !_faturaFechada) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                _loading
                                                    ? null
                                                    : () =>
                                                        _gerarLancamentoEAssociar(
                                                          l,
                                                        ),
                                            icon: const Icon(
                                              Icons.add_card_outlined,
                                              size: 20,
                                            ),
                                            label: const Text(
                                              'Gerar lançamento',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: cs.primary,
                                              backgroundColor: cs.surface,
                                              side: BorderSide(
                                                color: cs.primary
                                                    .withOpacity(0.55),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: Text(
                                  _money.format(l.valor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// Cria 1 lançamento no crédito (com [conta_pagar] quando o cartão tem regras) e retorna o id.
  Future<int?> _criarLancamentoApartirDoItem(IntegracaoFaturaCacheItem item) async {
    final idCartao = widget.cartao?.id ?? widget.fatura.idCartaoLocal;
    if (item.valor == 0) {
      _snack('Valor do item inválido.');
      return null;
    }

    final dataCompra =
        item.dataHora ??
        DateTime(widget.fatura.ano, widget.fatura.mes, 1, 12);
    final dataCompraDia = DateTime(
      dataCompra.year,
      dataCompra.month,
      dataCompra.day,
      dataCompra.hour,
      dataCompra.minute,
    );

    final desc = item.descricao.trim().isEmpty
        ? 'Compra cartão (importada)'
        : item.descricao.trim();

    final grupo = 'FAT_API_${DateTime.now().microsecondsSinceEpoch}';

    // Regra:
    // - valor negativo no extrato/API => tratar como RECEITA (estorno/crédito)
    // - lançamentos gerados aqui devem ficar como PAGO
    final isReceita = item.valor < 0;
    final valorAbs = item.valor.abs();

    // Receita: não deve gerar conta a pagar.
    if (isReceita) {
      final lanc = Lancamento(
        valor: valorAbs,
        descricao: desc,
        formaPagamento: FormaPagamento.credito,
        dataHora: dataCompraDia,
        pagamentoFatura: false,
        pago: true,
        dataPagamento: DateTime.now(),
        categoria: Categoria.outros,
        idCartao: idCartao,
        tipoMovimento: TipoMovimento.receita,
        tipoDespesa: TipoDespesa.variavel,
        grupoParcelas: grupo,
      );
      final id = await _lancRepo.salvar(lanc);
      return id;
    }

    final base = Lancamento(
      valor: valorAbs,
      descricao: desc,
      formaPagamento: FormaPagamento.credito,
      dataHora: dataCompraDia,
      pagamentoFatura: false,
      pago: true,
      dataPagamento: DateTime.now(),
      categoria: Categoria.outros,
      idCartao: idCartao,
      tipoMovimento: TipoMovimento.despesa,
      tipoDespesa: TipoDespesa.variavel,
      grupoParcelas: grupo,
    );

    final svc = RegraCartaoParceladoService(lancRepo: _lancRepo);
    await svc.processarCompraParcelada(
      compraBase: base,
      qtdParcelas: 1,
    );

    final parcelasGrupo = await _lancRepo.getParcelasPorGrupo(grupo);
    if (parcelasGrupo.isEmpty) return null;
    final primeiro = parcelasGrupo.first;

    // Garantia: o lançamento deve ficar na DATA DA COMPRA (item da API),
    // mesmo que a conta a pagar use o vencimento do cartão.
    final d = primeiro.dataHora;
    final mesmaData =
        d.year == dataCompraDia.year &&
        d.month == dataCompraDia.month &&
        d.day == dataCompraDia.day;
    if (!mesmaData) {
      await _lancRepo.salvar(primeiro.copyWith(dataHora: dataCompraDia));
    }
    return primeiro.id;
  }

  Future<void> _gerarLancamentoEAssociar(IntegracaoFaturaCacheItem item) async {
    if (_bloquearAlteracoesSeFechada()) return;
    final itemId = item.id;
    if (itemId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar lançamento'),
        content: const Text(
          'Será criado um lançamento no crédito (1×) com valor, descrição e data '
          'deste item da fatura, e já associado a ele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final offsetAntes = _scrollOffsetAtualItens();
    setState(() => _loading = true);
    try {
      final idLanc = await _criarLancamentoApartirDoItem(item);
      if (idLanc == null) {
        _snack('Não foi possível gerar o lançamento.');
        return;
      }
      await _repo.vincularItemComLancamento(
        idItem: itemId,
        idLancamentoLocal: idLanc,
      );
      if (!mounted) return;
      await _load();
      await _restaurarScrollItens(offsetAntes);
      _snack('Lançamento gerado e associado.');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoAssociar(BuildContext context) async {
    if (_bloquearAlteracoesSeFechada()) return;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Auto-associar lançamentos'),
          content: const Text(
            'Vou associar itens da fatura com lançamentos locais pelo valor '
            '(e proximidade da data quando houver).\n\n'
            'Deseja sobrescrever associações já existentes?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sobrescrever'),
            ),
          ],
        );
      },
    );
    if (overwrite == null) return;

    final qtd = await _repo.autoAssociarItens(
      fatura: widget.fatura,
      overwrite: overwrite,
    );
    if (!mounted) return;
    await _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Associados automaticamente: $qtd')),
    );
  }

  Future<void> _selecionarLancamento(IntegracaoFaturaCacheItem item) async {
    if (_bloquearAlteracoesSeFechada()) return;
    final itemId = item.id;
    if (itemId == null) return;

    final jaAssociados =
        _itens
            .where((i) => i.id != itemId && i.idLancamentoLocal != null)
            .map((i) => i.idLancamentoLocal!)
            .toSet();

    final candidatosLanc = _lancamentosPeriodo
        .where((l) => coincideValorAssociacao(l.valor, item.valor))
        .where((l) => l.id == null || !jaAssociados.contains(l.id!))
        .toList();
    final listaLanc =
        (candidatosLanc.isEmpty
            ? _lancamentosPeriodo
                .where((l) => l.id == null || !jaAssociados.contains(l.id!))
                .toList()
            : candidatosLanc);

    bool contaUsavel(ContaPagar c) {
      final idL = c.idLancamento;
      if (idL == null) return false;
      return !jaAssociados.contains(idL);
    }

    final candidatosConta = _contasPagarPeriodo
        .where(contaUsavel)
        .where((c) => coincideValorAssociacao(c.valor, item.valor))
        .toList();
    final listaContas =
        (candidatosConta.isEmpty
            ? _contasPagarPeriodo.where(contaUsavel).toList()
            : candidatosConta);

    var modo = _ModoAssociarFaturaItem.lancamento;

    final idEscolhido = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final mq = MediaQuery.of(sheetCtx);
        final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final usarContas = modo == _ModoAssociarFaturaItem.contaPagar;

            final filhos = <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Associar item da fatura',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return SegmentedButton<_ModoAssociarFaturaItem>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        side: WidgetStateProperty.all(
                          BorderSide(color: cs.outline.withOpacity(0.35)),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return cs.primaryContainer;
                          }
                          return cs.surfaceContainerHighest.withOpacity(0.65);
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return cs.onPrimaryContainer;
                          }
                          return cs.onSurface;
                        }),
                        iconColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return cs.onPrimaryContainer;
                          }
                          return cs.onSurfaceVariant;
                        }),
                      ),
                      segments: const [
                        ButtonSegment<_ModoAssociarFaturaItem>(
                          value: _ModoAssociarFaturaItem.lancamento,
                          label: Text('Lançamento'),
                          icon: Icon(Icons.receipt_long_outlined, size: 18),
                        ),
                        ButtonSegment<_ModoAssociarFaturaItem>(
                          value: _ModoAssociarFaturaItem.contaPagar,
                          label: Text('Conta a pagar'),
                          icon: Icon(Icons.request_quote_outlined, size: 18),
                        ),
                      ],
                      selected: {modo},
                      onSelectionChanged: (s) {
                        setModalState(() {
                          modo = s.first;
                        });
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('Remover associação'),
                onTap: () => Navigator.pop(sheetCtx, null),
              ),
            ];

            if (usarContas) {
              if (listaContas.isEmpty) {
                filhos.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      'Nenhuma conta a pagar para este cartão com lançamento '
                      'vinculado (exceto fatura).',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                );
              } else {
                for (final c in listaContas) {
                  final idL = c.idLancamento!;
                  final lanc = _lancById[idL];
                  final venc = DateFormat('dd/MM').format(c.dataVencimento);
                  final parc =
                      (c.parcelaTotal != null && c.parcelaTotal! > 1)
                          ? ' • Parc. ${c.parcelaNumero}/${c.parcelaTotal}'
                          : '';
                  final sub =
                      lanc == null
                          ? '$venc • ${_money.format(c.valor)}$parc'
                          : '$venc • ${_money.format(c.valor)}$parc • ${lanc.descricao}';
                  filhos.add(
                    ListTile(
                      leading: const Icon(Icons.request_quote_outlined),
                      title: Text(c.descricao),
                      subtitle: Text(sub),
                      onTap: () => Navigator.pop(sheetCtx, idL),
                    ),
                  );
                }
              }
            } else {
              if (listaLanc.isEmpty) {
                filhos.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      'Nenhum lançamento candidato para este cartão.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                );
              } else {
                for (final l in listaLanc) {
                  filhos.add(
                    ListTile(
                      title: Text(l.descricao),
                      subtitle: Text(
                        '${DateFormat('dd/MM HH:mm').format(l.dataHora)} • ${_money.format(l.valor)}',
                      ),
                      onTap: () => Navigator.pop(sheetCtx, l.id),
                    ),
                  );
                }
              }
            }

            return SafeArea(
              child: ListView(
                padding: listViewPaddingWithBottomInset(context, EdgeInsets.only(bottom: bottomPad + 16)),
                children: filhos,
              ),
            );
          },
        );
      },
    );

    await _repo.vincularItemComLancamento(
      idItem: itemId,
      idLancamentoLocal: idEscolhido,
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _editarLancamento(Lancamento existente) async {
    final cartoes = await _cartaoRepo.getCartoesCredito();
    final contas = await _contaRepo.getContasBancarias();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LancamentoFormBottomSheet(
          existente: existente,
          dataSelecionada: existente.dataHora,
          currency: _money,
          dateDiaFormat: DateFormat('dd/MM/yyyy'),
          dbService: _dbService,
          cartoes: cartoes,
          contas: contas,
          onSaved: () async {
            await _load();
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalizadorChip({
    required String label,
    required int qtd,
    required double valor,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
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
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qtd item(ns) • ${_money.format(valor)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

