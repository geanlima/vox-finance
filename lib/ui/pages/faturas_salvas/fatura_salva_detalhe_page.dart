import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/integracao_fatura_cache.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/integracao/integracao_fatura_cache_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';

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
  final _dbService = DbService.instance;
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHora = DateFormat.yMMMd('pt_BR').add_Hm();

  bool _loading = true;
  List<IntegracaoFaturaCacheItem> _itens = const [];
  List<Lancamento> _lancamentosPeriodo = const [];
  final Map<int, Lancamento> _lancById = {};
  bool _mostrarSomenteNaoAssociados = false;
  IntegracaoFaturaCache? _faturaAtual;
  Lancamento? _lancamentoFaturaGerado;

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
        _lancById.clear();
        _faturaAtual = null;
        _lancamentoFaturaGerado = null;
        _loading = false;
      });
      return;
    }
    final itens = await _repo.listarItens(id);
    final lancs = await _repo.listarLancamentosCandidatos(
      idCartaoLocal: widget.fatura.idCartaoLocal,
      ano: widget.fatura.ano,
      mes: widget.fatura.mes,
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
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _lancamentosPeriodo = lancs;
      _lancById
        ..clear()
        ..addAll(byId);
      _faturaAtual = fat;
      _lancamentoFaturaGerado = lancFatura;
      _loading = false;
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                title: Text(l.descricao),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                vinc == null
                                                    ? Icons.link_off
                                                    : Icons.link,
                                                size: 16,
                                                color: badgeFg,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                vinc == null
                                                    ? 'Não associado'
                                                    : 'Associado: ${vinc.descricao}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: badgeFg,
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

    final candidatos = _lancamentosPeriodo
        .where((l) => (l.valor - item.valor).abs() <= 0.009)
        .where((l) => l.id == null || !jaAssociados.contains(l.id!))
        .toList();
    final lista =
        (candidatos.isEmpty
            ? _lancamentosPeriodo
                .where((l) => l.id == null || !jaAssociados.contains(l.id!))
                .toList()
            : candidatos);

    final escolhido = await showModalBottomSheet<Lancamento?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: lista.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Remover associação'),
                  onTap: () => Navigator.pop(context, null),
                );
              }
              final l = lista[i - 1];
              return ListTile(
                title: Text(l.descricao),
                subtitle: Text(
                  '${DateFormat('dd/MM HH:mm').format(l.dataHora)} • ${_money.format(l.valor)}',
                ),
                onTap: () => Navigator.pop(context, l),
              );
            },
          ),
        );
      },
    );

    await _repo.vincularItemComLancamento(
      idItem: itemId,
      idLancamentoLocal: escolhido?.id,
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
        children: [Text(label), Text(valor)],
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

