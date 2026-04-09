// lib/ui/pages/parcelamentos/parcelamentos_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/widgets/sync_icon_button.dart';
import 'package:vox_finance/ui/pages/contas_pagar/conta_pagar_detalhe.dart';

enum ParcelamentosFiltro { emAberto, finalizandoMes, todos }

class ParcelamentoResumo {
  final String grupoParcelas;
  final String descricao;
  final double valorTotal;
  final double valorPendente;
  final int quantidadeParcelas;
  final int qtdPagas;
  final int qtdPendentes;
  final DateTime primeiroVencimento;
  final DateTime ultimoVencimento;
  final String? formaDescricao;

  const ParcelamentoResumo({
    required this.grupoParcelas,
    required this.descricao,
    required this.valorTotal,
    required this.valorPendente,
    required this.quantidadeParcelas,
    required this.qtdPagas,
    required this.qtdPendentes,
    required this.primeiroVencimento,
    required this.ultimoVencimento,
    required this.formaDescricao,
  });
}

class ParcelamentosPage extends StatefulWidget {
  const ParcelamentosPage({super.key});

  static const routeName = '/parcelamentos';
  static const argFiltro = 'filtro';

  @override
  State<ParcelamentosPage> createState() => _ParcelamentosPageState();
}

class _ParcelamentosPageState extends State<ParcelamentosPage> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _contaRepo = ContaPagarRepository();
  final _lancRepo = LancamentoRepository();
  final _cartaoRepo = CartaoCreditoRepository();

  bool _carregando = false;
  ParcelamentosFiltro _filtro = ParcelamentosFiltro.emAberto;
  bool _aplicouFiltroDaRota = false;

  List<ParcelamentoResumo> _resumos = const [];
  /// Soma de todas as parcelas pendentes (parcelado, exc. FATURA_*).
  double _totalEmAbertoGeral = 0.0;
  /// Parcelas pendentes com vencimento no mês corrente.
  double _totalNesteMes = 0.0;
  /// Parcelas pendentes com vencimento no mês seguinte.
  double _totalProximoMes = 0.0;
  /// Soma do pendente só dos grupos exibidos (no filtro "finalizando este mês").
  double _totalPendenteLista = 0.0;
  Map<int?, double> _pendentePorCartaoId = const {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aplicouFiltroDaRota) return;
    _aplicouFiltroDaRota = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args[ParcelamentosPage.argFiltro];
      if (v == 'finalizandoMes') {
        _filtro = ParcelamentosFiltro.finalizandoMes;
      } else if (v == 'todos') {
        _filtro = ParcelamentosFiltro.todos;
      } else if (v == 'emAberto') {
        _filtro = ParcelamentosFiltro.emAberto;
      }
    }
  }

  bool _ehGrupoFatura(String grupo) => grupo.startsWith('FATURA_');

  Widget _kv({
    required String label,
    required String value,
    required ColorScheme cs,
    Color? valueColor,
    double labelFontSize = 11,
    double valueFontSize = 16,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: labelFontSize,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w900,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required ColorScheme cs,
    Color? bg,
    Color? fg,
  }) {
    final background = bg ?? cs.primary.withOpacity(0.10);
    final foreground = fg ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _obterDescricaoFormaPagamento(String grupoParcelas) async {
    final lancs = await _lancRepo.getParcelasPorGrupo(grupoParcelas);
    if (lancs.isEmpty) return null;

    final l = lancs.first;
    if (l.idCartao != null) {
      final CartaoCredito? cartao = await _cartaoRepo.getCartaoCreditoById(
        l.idCartao!,
      );
      if (cartao != null) {
        final ultimos =
            cartao.ultimos4Digitos.isNotEmpty ? cartao.ultimos4Digitos : '****';
        return 'Crédito - ${cartao.descricao} • **** $ultimos';
      }
    }
    return l.formaPagamento.label;
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    // Importante: para calcular corretamente "x/y pagas" precisamos carregar
    // todas as parcelas (pagas + pendentes). O filtro "somente pendentes"
    // será aplicado por grupo, com base no valor pendente do grupo.
    final todas = await _contaRepo.getTodas();

    // Somente compras parceladas (parcela_total > 1) e não inclui as contas da FATURA_*
    final parceladas =
        todas
            .where((c) => (c.parcelaTotal ?? 0) > 1)
            .where((c) => !_ehGrupoFatura(c.grupoParcelas))
            .toList();

    // Total pendente por cartão (para o resumo "por cartão")
    final pendentePorCartao = <int?, double>{};
    final agora = DateTime.now();
    final inicioProximoMes = DateTime(agora.year, agora.month + 1, 1);
    double totalGeral = 0.0;
    double nesteMes = 0.0;
    double proximoMes = 0.0;
    for (final c in parceladas) {
      if (c.pago) continue;
      final k = c.idCartao; // pode ser null em bases antigas
      pendentePorCartao[k] = (pendentePorCartao[k] ?? 0.0) + c.valor;
      totalGeral += c.valor;
      final v = c.dataVencimento;
      if (v.year == agora.year && v.month == agora.month) {
        nesteMes += c.valor;
      }
      if (v.year == inicioProximoMes.year && v.month == inicioProximoMes.month) {
        proximoMes += c.valor;
      }
    }

    final mapa = <String, List<ContaPagar>>{};
    for (final c in parceladas) {
      mapa.putIfAbsent(c.grupoParcelas, () => []).add(c);
    }

    final resumos = <ParcelamentoResumo>[];
    final pendentePorCartaoDaLista = <int?, double>{};

    for (final entry in mapa.entries) {
      final grupo = entry.key;
      final itens = [...entry.value]..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
      if (itens.isEmpty) continue;

      final total = itens.fold<double>(0.0, (a, c) => a + c.valor);
      final pendente = itens.where((c) => !c.pago).fold<double>(0.0, (a, c) => a + c.valor);
      final qtdPagas = itens.where((c) => c.pago).length;
      final qtdPend = itens.length - qtdPagas;
      final qtdParcelas = itens.map((c) => c.parcelaTotal ?? 0).fold<int>(0, (a, v) => v > a ? v : a);
      final primeiro = itens.first.dataVencimento;
      final ultimo = itens.last.dataVencimento;

      // Filtros (aplicados por GRUPO)
      if (_filtro == ParcelamentosFiltro.emAberto && pendente <= 0) continue;
      if (_filtro == ParcelamentosFiltro.finalizandoMes) {
        final finalizaEsteMes = ultimo.year == agora.year && ultimo.month == agora.month;
        final temPendente = pendente > 0;
        if (!finalizaEsteMes || !temPendente) continue;
      }

      for (final c in itens.where((x) => !x.pago)) {
        final k = c.idCartao;
        pendentePorCartaoDaLista[k] =
            (pendentePorCartaoDaLista[k] ?? 0.0) + c.valor;
      }

      resumos.add(
        ParcelamentoResumo(
          grupoParcelas: grupo,
          descricao: itens.first.descricao,
          valorTotal: total,
          valorPendente: pendente,
          quantidadeParcelas: qtdParcelas == 0 ? itens.length : qtdParcelas,
          qtdPagas: qtdPagas,
          qtdPendentes: qtdPend,
          primeiroVencimento: primeiro,
          ultimoVencimento: ultimo,
          formaDescricao: await _obterDescricaoFormaPagamento(grupo),
        ),
      );
    }

    resumos.sort((a, b) => b.valorPendente.compareTo(a.valorPendente));

    final totalPendenteLista =
        resumos.fold<double>(0.0, (a, r) => a + r.valorPendente);
    final mapaCartaoModal =
        _filtro == ParcelamentosFiltro.finalizandoMes
            ? pendentePorCartaoDaLista
            : pendentePorCartao;

    if (!mounted) return;
    setState(() {
      _resumos = resumos;
      _totalEmAbertoGeral = totalGeral;
      _totalNesteMes = nesteMes;
      _totalProximoMes = proximoMes;
      _totalPendenteLista = totalPendenteLista;
      _pendentePorCartaoId = mapaCartaoModal;
      _carregando = false;
    });
  }

  Future<void> _mostrarResumoPorCartao(BuildContext context) async {
    if (_pendentePorCartaoId.isEmpty) return;

    final entries = _pendentePorCartaoId.entries.toList()
      ..sort((a, b) => (b.value).compareTo(a.value));

    // Busca descrições dos cartões para ids != null
    final cardMap = <int, CartaoCredito>{};
    for (final e in entries) {
      final id = e.key;
      if (id == null) continue;
      final c = await _cartaoRepo.getCartaoCreditoById(id);
      if (c != null) cardMap[id] = c;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _filtro == ParcelamentosFiltro.finalizandoMes
                          ? 'Finalizando este mês por cartão'
                          : 'Em aberto por cartão',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final e = entries[i];
                      final id = e.key;
                      final valor = e.value;
                      final cartao = id == null ? null : cardMap[id];

                      final title =
                          cartao == null
                              ? (id == null ? 'Sem cartão' : 'Cartão $id')
                              : cartao.descricao;
                      final ultimos =
                          cartao?.ultimos4Digitos.isNotEmpty == true
                              ? cartao!.ultimos4Digitos
                              : null;

                      return ListTile(
                        leading: Icon(Icons.credit_card, color: cs.primary),
                        title: Text(title),
                        subtitle:
                            ultimos == null ? null : Text('**** $ultimos'),
                        trailing: Text(
                          _currency.format(valor),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: valor > 0 ? cs.error : cs.primary,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = DateTime.now();
    final proxMesRef = DateTime(ref.year, ref.month + 1, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelamentos'),
        actions: [
          const SyncIconButton(),
          IconButton(
            icon: Icon(
              _filtro == ParcelamentosFiltro.emAberto
                  ? Icons.filter_alt
                  : (_filtro == ParcelamentosFiltro.finalizandoMes
                      ? Icons.event_available_outlined
                      : Icons.filter_alt_outlined),
            ),
            tooltip: switch (_filtro) {
              ParcelamentosFiltro.emAberto => 'Mostrando: em aberto',
              ParcelamentosFiltro.finalizandoMes => 'Mostrando: finalizando este mês',
              ParcelamentosFiltro.todos => 'Mostrando: todos',
            },
            onPressed:
                _carregando
                    ? null
                    : () {
                      setState(() {
                        _filtro = switch (_filtro) {
                          ParcelamentosFiltro.emAberto => ParcelamentosFiltro.finalizandoMes,
                          ParcelamentosFiltro.finalizandoMes => ParcelamentosFiltro.todos,
                          ParcelamentosFiltro.todos => ParcelamentosFiltro.emAberto,
                        };
                      });
                      _carregar();
                    },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: ParcelamentosPage.routeName),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final t =
                          _filtro == ParcelamentosFiltro.finalizandoMes
                              ? _totalPendenteLista
                              : _totalEmAbertoGeral;
                      if (_carregando || t <= 0) return;
                      _mostrarResumoPorCartao(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          _filtro == ParcelamentosFiltro.finalizandoMes
                              ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: cs.tertiary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.event_available_outlined,
                                      color: cs.tertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kv(
                                      label:
                                          'Total finalizando este mês (${DateFormat('MM/yyyy').format(ref)})',
                                      value: _currency.format(_totalPendenteLista),
                                      cs: cs,
                                      valueColor: cs.primary,
                                    ),
                                  ),
                                  if (_totalPendenteLista > 0)
                                    Icon(
                                      Icons.chevron_right,
                                      color: cs.onSurfaceVariant,
                                    ),
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.view_timeline_outlined,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _kv(
                                          label: 'Total em aberto',
                                          value: _currency.format(
                                            _totalEmAbertoGeral,
                                          ),
                                          cs: cs,
                                          valueColor: cs.primary,
                                        ),
                                      ),
                                      if (_totalEmAbertoGeral > 0)
                                        Icon(
                                          Icons.chevron_right,
                                          color: cs.onSurfaceVariant,
                                        ),
                                    ],
                                  ),
                                  Divider(
                                    height: 24,
                                    color: cs.outlineVariant.withOpacity(0.5),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _kv(
                                          label:
                                              'A pagar neste mês (${DateFormat('MM/yyyy').format(ref)})',
                                          value: _currency.format(
                                            _totalNesteMes,
                                          ),
                                          cs: cs,
                                          valueColor: cs.error,
                                          labelFontSize: 10,
                                          valueFontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _kv(
                                          label:
                                              'A pagar próximo mês (${DateFormat('MM/yyyy').format(proxMesRef)})',
                                          value: _currency.format(
                                            _totalProximoMes,
                                          ),
                                          cs: cs,
                                          valueColor: cs.tertiary,
                                          labelFontSize: 10,
                                          valueFontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
                Expanded(
                  child: _resumos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              switch (_filtro) {
                                ParcelamentosFiltro.emAberto =>
                                  'Nenhum parcelamento em aberto.',
                                ParcelamentosFiltro.finalizandoMes =>
                                  'Nenhuma compra finalizando este mês.',
                                ParcelamentosFiltro.todos =>
                                  'Nenhum parcelamento encontrado.',
                              },
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _resumos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final r = _resumos[i];
                            final pct =
                                r.quantidadeParcelas == 0
                                    ? 0.0
                                    : (r.qtdPagas / r.quantidadeParcelas).clamp(0.0, 1.0);

                            return Card(
                              elevation: 0,
                              color: cs.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: cs.outlineVariant.withOpacity(0.55),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ContaPagarDetalhePage(
                                        grupoParcelas: r.grupoParcelas,
                                      ),
                                    ),
                                  ).then((_) => _carregar());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              r.descricao,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.chevron_right,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                      if (r.formaDescricao != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          r.formaDescricao!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _pill(
                                            icon: Icons.event_available_outlined,
                                            text:
                                                'Início ${_dateFormat.format(r.primeiroVencimento)}',
                                            cs: cs,
                                            bg: cs.secondary.withOpacity(0.10),
                                            fg: cs.secondary,
                                          ),
                                          _pill(
                                            icon: Icons.event_outlined,
                                            text:
                                                'Término ${_dateFormat.format(r.ultimoVencimento)}',
                                            cs: cs,
                                            bg: cs.tertiary.withOpacity(0.10),
                                            fg: cs.tertiary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: pct,
                                                minHeight: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          _pill(
                                            icon: Icons.payments_outlined,
                                            text:
                                                '${r.qtdPagas}/${r.quantidadeParcelas} pagas',
                                            cs: cs,
                                            bg: cs.primary.withOpacity(0.10),
                                            fg: cs.primary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Em aberto',
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            _currency.format(r.valorPendente),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color:
                                                  r.valorPendente > 0
                                                      ? cs.error
                                                      : cs.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
}

