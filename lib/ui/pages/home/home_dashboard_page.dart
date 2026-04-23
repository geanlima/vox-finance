// ignore_for_file: control_flow_in_finally, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/models/lembrete.dart';
import 'package:vox_finance/ui/data/modules/lembretes/lembrete_repository.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_service.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_aviso_service.dart';
import 'package:vox_finance/ui/core/service/metrica_alerta_service.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/metricas/metrica_limite_repository.dart';
import 'package:vox_finance/ui/pages/home/home_voice.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/pages/metricas/metricas_page.dart';
import 'package:vox_finance/ui/pages/metricas/metricas_analises_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class _FaturaCartaoHomeItem {
  final int idCartao;
  final String cartaoLabel;
  final DateTime vencimento;
  final double valor;
  final bool pago;

  const _FaturaCartaoHomeItem({
    required this.idCartao,
    required this.cartaoLabel,
    required this.vencimento,
    required this.valor,
    required this.pago,
  });
}

class _OrcamentoMesLinha {
  final MetricaLimite metrica;
  final String titulo;
  final ConsumoMetrica consumo;

  const _OrcamentoMesLinha({
    required this.metrica,
    required this.titulo,
    required this.consumo,
  });
}

String _tituloMetricaDashboard(
  MetricaLimite m,
  List<CategoriaPersonalizada> cats,
  Map<int, List<SubcategoriaPersonalizada>> subsByCat,
  List<CartaoCredito> cartoes,
) {
  if (m.escopo == 'forma') {
    final idx = m.formaPagamento;
    if (idx == null ||
        idx < 0 ||
        idx >= FormaPagamento.values.length) {
      return 'Forma de pagamento';
    }
    final f = FormaPagamento.values[idx];
    if (f == FormaPagamento.credito && m.idCartao != null) {
      try {
        final c = cartoes.firstWhere((e) => e.id == m.idCartao);
        return '${f.label} • ${c.label}';
      } catch (_) {
        return '${f.label} • Cartão';
      }
    }
    return f.label;
  }

  if (m.idCategoriaPersonalizada <= 0) {
    return 'Todas as despesas';
  }
  CategoriaPersonalizada? cat;
  try {
    cat = cats.firstWhere((c) => c.id == m.idCategoriaPersonalizada);
  } catch (_) {
    cat = null;
  }
  if (m.idSubcategoriaPersonalizada != null) {
    final subs = subsByCat[m.idCategoriaPersonalizada] ?? const [];
    SubcategoriaPersonalizada? sub;
    try {
      sub = subs.firstWhere((s) => s.id == m.idSubcategoriaPersonalizada);
    } catch (_) {
      sub = null;
    }
    if (sub != null) {
      return '${cat?.nome ?? 'Categoria'} • ${sub.nome}';
    }
  }
  return cat?.nome ?? 'Categoria';
}

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _contaRepo = ContaPagarRepository();
  final _lancRepo = LancamentoRepository();
  final _lembreteRepo = LembreteRepository();
  final _despesasFixasService = DespesasFixasService();
  final _metricaRepo = MetricaLimiteRepository();
  final _cartaoRepo = CartaoCreditoRepository();
  late final MetricaAlertaService _metricaAlertaService =
      MetricaAlertaService(_metricaRepo);
  final _speech = stt.SpeechToText();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _speechDisponivel = false;
  bool _loading = true;
  String? _error;
  List<ContaPagar> _vencimentosHoje = const [];
  List<ContaPagar> _vencidos = const [];
  List<Lembrete> _lembretesHoje = const [];
  List<Lembrete> _lembretesAtrasados = const [];
  List<AlertaMetricaItem> _alertasMetricas = const [];
  List<_OrcamentoMesLinha> _orcamentoMesLinhas = const [];
  List<_FaturaCartaoHomeItem> _faturasCartao = const [];
  String? _msgMetrica;
  DateTime? _parcelamentosAte;
  String? _baseUltimaFaturaLabel;
  int _qtdParcelamentosEmAberto = 0;
  /// Compras parceladas cuja última parcela vence no mês atual e ainda há pendência.
  int _qtdComprasFinalizandoMes = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _speechDisponivel = await _speech
          .initialize()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      _speechDisponivel = false;
    }

    if (!mounted) return;
    setState(() {});

    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 🔁 Gera métricas mensais recorrentes no mês atual (se necessário).
      final agora = DateTime.now();
      await _metricaRepo.gerarRecorrentesDoMesAtualSeNecessario(agora);

      // Garante que as despesas fixas automáticas do mês foram geradas
      // antes de montar as notificações de vencimento.
      await _despesasFixasService.gerarNoMesAtualSeNecessario();

      final inicioHoje = DateTime(agora.year, agora.month, agora.day);
      final fimHoje = DateTime(
        agora.year,
        agora.month,
        agora.day,
        23,
        59,
        59,
        999,
      );

      final pendentes = await _contaRepo.getPendentes();
      final deHoje =
          pendentes
              .where(
                (c) =>
                    !c.dataVencimento.isBefore(inicioHoje) &&
                    !c.dataVencimento.isAfter(fimHoje),
              )
              .toList();
      final vencidos =
          pendentes.where((c) => c.dataVencimento.isBefore(inicioHoje)).toList();

      // ✅ Aviso de parcelamentos: maior vencimento pendente de compras parceladas
      // (não considera grupos de fatura "FATURA_*").
      final parcelasPendentes =
          pendentes
              .where((c) => (c.parcelaTotal ?? 0) > 1)
              .where((c) => !(c.grupoParcelas).startsWith('FATURA_'))
              .toList();
      DateTime? parcelamentosAte;
      if (parcelasPendentes.isNotEmpty) {
        parcelasPendentes.sort(
          (a, b) => b.dataVencimento.compareTo(a.dataVencimento),
        );
        parcelamentosAte = parcelasPendentes.first.dataVencimento;
      }
      final qtdGruposParcelas =
          parcelasPendentes.map((c) => c.grupoParcelas).toSet().length;

      // Compras que “encerram” no mês corrente: última parcela do grupo vence neste mês/ano
      // e ainda existe parcela pendente (exclui FATURA_*).
      int qtdFinalizandoMes = 0;
      final todasContas = await _contaRepo.getTodas();
      final parceladasPorGrupo = <String, List<ContaPagar>>{};
      for (final c in todasContas) {
        if ((c.parcelaTotal ?? 0) <= 1) continue;
        if (c.grupoParcelas.startsWith('FATURA_')) continue;
        parceladasPorGrupo.putIfAbsent(c.grupoParcelas, () => []).add(c);
      }
      for (final itens in parceladasPorGrupo.values) {
        if (itens.isEmpty) continue;
        final ultimoVenc = itens
            .map((e) => e.dataVencimento)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final temPendente = itens.any((e) => !e.pago);
        if (ultimoVenc.year == agora.year &&
            ultimoVenc.month == agora.month &&
            temPendente) {
          qtdFinalizandoMes++;
        }
      }

      // Base: último mês com lançamento de pagamento de fatura (pagamento_fatura = 1)
      String? baseUltimaFatura;
      final db = await DatabaseInitializer.initialize();
      final rows = await db.query(
        'lancamentos',
        columns: ['data_hora'],
        where: 'pagamento_fatura = 1',
        orderBy: 'data_hora DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final ms = rows.first['data_hora'];
        if (ms is int) {
          baseUltimaFatura =
              DateFormat('MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));
        }
      }

      // ✅ Faturas de cartão: próxima fatura por cartão (vencimento >= hoje)
      final cartoes = await _cartaoRepo.getCartoesCredito();
      final cartoesValidos =
          cartoes
              .where((c) => c.id != null)
              .where(
                (c) =>
                    (c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos) &&
                    c.controlaFatura &&
                    c.diaVencimento != null &&
                    c.diaFechamento != null,
              )
              .toList();
      final inicioHojeMs = inicioHoje.millisecondsSinceEpoch;
      final faturasCartao = <_FaturaCartaoHomeItem>[];
      for (final c in cartoesValidos) {
        final idCartao = c.id!;
        final fatRows = await db.query(
          'lancamentos',
          columns: const ['data_hora', 'valor', 'pago'],
          where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora >= ?',
          whereArgs: [idCartao, inicioHojeMs],
          orderBy: 'data_hora ASC',
          limit: 1,
        );
        if (fatRows.isEmpty) continue;
        final ms = (fatRows.first['data_hora'] as num).toInt();
        final valor = (fatRows.first['valor'] as num).toDouble();
        final pago = (fatRows.first['pago'] as num?)?.toInt() == 1;
        faturasCartao.add(
          _FaturaCartaoHomeItem(
            idCartao: idCartao,
            cartaoLabel: c.label,
            vencimento: DateTime.fromMillisecondsSinceEpoch(ms),
            valor: valor,
            pago: pago,
          ),
        );
      }
      faturasCartao.sort((a, b) => a.vencimento.compareTo(b.vencimento));

      final lembretesHoje = await _lembreteRepo.pendentesNoIntervalo(
        inicioHoje,
        fimHoje,
      );
      final lembretesAtrasados = await _lembreteRepo.pendentesAte(
        inicioHoje.subtract(const Duration(milliseconds: 1)),
      );

      // ✅ Alertas de métricas (Home + notificação Android)
      String? msg;
      final alertas = await _metricaAlertaService.verificarEAlertar(
        agora: agora,
        onHomeMessage: (m) => msg ??= m,
      );

      var orcamentoLinhas = const <_OrcamentoMesLinha>[];
      try {
        final mensais = await _metricaRepo.listarPorPeriodo(
          periodoTipo: 'mensal',
          ano: agora.year,
          mes: agora.month,
          semana: null,
        );
        final ativos =
            mensais.where((m) => m.ativo && m.id != null).toList();
        if (ativos.isNotEmpty) {
          final catRepo = CategoriaPersonalizadaRepository();
          final subRepo = SubcategoriaPersonalizadaRepository();
          final cats = await catRepo.listarTodas();
          final cartoes = await _cartaoRepo.getCartoesCredito();
          final subsByCat = <int, List<SubcategoriaPersonalizada>>{};
          for (final c in cats) {
            if (c.id == null) continue;
            subsByCat[c.id!] = await subRepo.listarPorCategoria(c.id!);
          }
          final linhas = <_OrcamentoMesLinha>[];
          for (final m in ativos) {
            final consumo = await _metricaRepo.calcularConsumo(
              metrica: m,
              referenciaPeriodo: agora,
            );
            final titulo = _tituloMetricaDashboard(m, cats, subsByCat, cartoes);
            linhas.add(
              _OrcamentoMesLinha(
                metrica: m,
                titulo: titulo,
                consumo: consumo,
              ),
            );
          }
          linhas.sort(
            (a, b) => b.consumo.percentual.compareTo(a.consumo.percentual),
          );
          orcamentoLinhas = linhas;
        }
      } catch (_) {
        orcamentoLinhas = const [];
      }

      if (!mounted) return;
      setState(() {
        _vencimentosHoje = deHoje;
        _vencidos = vencidos;
        _parcelamentosAte = parcelamentosAte;
        _qtdParcelamentosEmAberto = qtdGruposParcelas;
        _qtdComprasFinalizandoMes = qtdFinalizandoMes;
        _baseUltimaFaturaLabel = baseUltimaFatura;
        _lembretesHoje = lembretesHoje;
        _lembretesAtrasados = lembretesAtrasados;
        _alertasMetricas = alertas;
        _orcamentoMesLinhas = orcamentoLinhas;
        _faturasCartao = faturasCartao;
        _msgMetrica = msg;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        DespesasFixasAvisoService.tentarMostrarAvisoMesAnteriorSeNecessario(
          context,
        );

        final m = _msgMetrica;
        if (m != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m)),
          );
          setState(() => _msgMetrica = null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _vencimentosHoje = const [];
        _vencidos = const [];
        _parcelamentosAte = null;
        _qtdParcelamentosEmAberto = 0;
        _qtdComprasFinalizandoMes = 0;
        _baseUltimaFaturaLabel = null;
        _lembretesHoje = const [];
        _lembretesAtrasados = const [];
        _orcamentoMesLinhas = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _faturasCartaoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_faturasCartao.isEmpty) {
      return _actionCard(
        context: context,
        icon: Icons.credit_card_outlined,
        title: 'Faturas do cartão',
        subtitle: 'Nenhuma fatura futura encontrada para acompanhar.',
        onTap: () => _goMain('/lancamentos'),
        ctaText: 'Ver',
        onCta: () => _goMain('/lancamentos'),
        accent: cs.primary,
      );
    }

    final prox = _faturasCartao.first;
    final qtd = _faturasCartao.length;
    final venc = DateFormat('dd/MM/yyyy').format(prox.vencimento);
    final sub = '$qtd cartão(ões) · próxima em $venc';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _goMainArgs('/lancamentos', prox.vencimento),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.receipt_long_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Faturas do cartão',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goMainArgs('/lancamentos', prox.vencimento),
                    child: const Text('Ver'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ..._faturasCartao.map((f) {
                final v = DateFormat('dd/MM').format(f.vencimento);
                final cor = f.pago ? Colors.green.shade700 : cs.error;
                final status = f.pago ? 'Paga' : 'Em aberto';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _goMainArgs('/lancamentos', f.vencimento),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.cartaoLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface.withOpacity(0.92),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Venc. $v · $status',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currency.format(f.valor),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f.pago ? 'OK' : 'Pendente',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMicPressed() async {
    if (!_speechDisponivel) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconhecimento de voz indisponível.')),
      );
      return;
    }

    final texto = await mostrarBottomSheetVoz(
      context: context,
      speech: _speech,
    );
    if (texto == null || texto.isEmpty) return;

    final lanc = interpretarComandoVoz(texto);
    if (lanc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não consegui entender valor e descrição.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar lançamento'),
            content: Text(
              'Descrição: ${lanc.descricao}\n'
              'Valor: ${_currency.format(lanc.valor)}\n'
              'Forma: ${lanc.formaPagamento.label}\n\n'
              'Deseja salvar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar'),
              ),
            ],
          ),
    );

    if (ok != true) return;
    await _lancRepo.salvar(lanc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento salvo com sucesso.')),
    );
    await _load();
  }

  void _goMain(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.pushNamed(context, route);
  }

  void _goMainArgs(String route, Object? args) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.pushNamed(context, route, arguments: args);
  }

  Widget _orcamentoMesMetricaTile({
    required BuildContext context,
    required _OrcamentoMesLinha linha,
  }) {
    final cs = Theme.of(context).colorScheme;
    final m = linha.metrica;
    final c = linha.consumo;
    final pctRaw = c.percentual;
    final pctBar = (pctRaw / 100.0).clamp(0.0, 1.0);

    Color barColor = cs.primary;
    if (pctRaw >= m.alertaPct2) {
      barColor = cs.error;
    } else if (pctRaw >= m.alertaPct1) {
      barColor = Colors.orange.shade800;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _goMain(MetricasPage.routeName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    linha.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${pctRaw.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color:
                        pctRaw >= m.alertaPct2
                            ? cs.error
                            : cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pctBar,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest.withOpacity(0.85),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currency.format(c.total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currency.format(c.limite),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orcamentoMesCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = DateTime.now();
    final mesLabel = DateFormat('MM/yyyy').format(ref);
    const maxLinhas = 4;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _goMain(MetricasPage.routeName),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.savings_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orçamento do mês ($mesLabel)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _orcamentoMesLinhas.isEmpty
                                ? 'Defina limites por categoria (ou geral), por forma de pagamento, e acompanhe o quanto já gastou.'
                                : '${_orcamentoMesLinhas.length} métrica(s) mensal(is) ativa(s).',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goMain(MetricasPage.routeName),
                    child: const Text('Gerenciar'),
                  ),
                  TextButton(
                    onPressed: () => _goMain(MetricasAnalisesPage.routeName),
                    child: const Text('Análises'),
                  ),
                ],
              ),
              if (_orcamentoMesLinhas.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itens = _orcamentoMesLinhas.take(maxLinhas).toList();

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: itens.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 4),
                      itemBuilder: (context, i) => _orcamentoMesMetricaTile(
                        context: context,
                        linha: itens[i],
                      ),
                    );
                  },
                ),
                if (_orcamentoMesLinhas.length > maxLinhas)
                  Text(
                    '+ ${_orcamentoMesLinhas.length - maxLinhas} outra(s) em Métricas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    String? ctaText,
    VoidCallback? onCta,
    Color? accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    final acc = accent ?? cs.primary;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: acc.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: acc),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (ctaText != null && onCta != null)
                TextButton(onPressed: onCta, child: Text(ctaText))
              else if (onTap != null)
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onMicPressed,
        icon: const Icon(Icons.mic),
        label: const Text('Lançar por voz'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não consegui carregar a Home.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
              : ListView(
                padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(16)),
                children: [
                  _orcamentoMesCard(context),
                  const SizedBox(height: 12),
                  _faturasCartaoCard(context),
                  const SizedBox(height: 12),
                  if (_alertasMetricas.isNotEmpty) ...[
                    _actionCard(
                      context: context,
                      icon: Icons.insights_outlined,
                      title:
                          _alertasMetricas.length == 1
                              ? '1 métrica em atenção'
                              : '${_alertasMetricas.length} métricas em atenção',
                      subtitle:
                          _alertasMetricas
                              .take(3)
                              .map(
                                (a) =>
                                    '${a.consumo.percentual.toStringAsFixed(0)}% do limite',
                              )
                              .join(' • '),
                      onTap: () => _goMain(MetricasPage.routeName),
                      ctaText: 'Ver',
                      onCta: () => _goMain(MetricasPage.routeName),
                      accent: Colors.orange.shade800,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_parcelamentosAte != null && _qtdParcelamentosEmAberto > 0) ...[
                    _actionCard(
                      context: context,
                      icon: Icons.view_timeline_outlined,
                      title:
                          _qtdParcelamentosEmAberto == 1
                              ? '1 parcelamento em aberto'
                              : '$_qtdParcelamentosEmAberto parcelamentos em aberto',
                      subtitle:
                          'Até ${DateFormat('dd/MM/yyyy').format(_parcelamentosAte!)}'
                          '${_baseUltimaFaturaLabel == null ? '' : ' · base: última fatura $_baseUltimaFaturaLabel'}',
                      onTap: () => _goMain('/parcelamentos'),
                      ctaText: 'Ver',
                      onCta: () => _goMain('/parcelamentos'),
                      accent: Colors.green.shade700,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_qtdComprasFinalizandoMes > 0) ...[
                    _actionCard(
                      context: context,
                      icon: Icons.event_available_outlined,
                      title:
                          _qtdComprasFinalizandoMes == 1
                              ? '1 compra finaliza este mês'
                              : '$_qtdComprasFinalizandoMes compras finalizam este mês',
                      subtitle:
                          'Última parcela em ${DateFormat('MM/yyyy').format(DateTime.now())}',
                      onTap: () => _goMainArgs(
                        '/parcelamentos',
                        { 'filtro': 'finalizandoMes' },
                      ),
                      ctaText: 'Ver',
                      onCta: () => _goMainArgs(
                        '/parcelamentos',
                        { 'filtro': 'finalizandoMes' },
                      ),
                      accent: Colors.teal.shade700,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _actionCard(
                    context: context,
                    icon: Icons.notifications_active_outlined,
                    title:
                        (_vencimentosHoje.isEmpty && _vencidos.isEmpty)
                            ? 'Nenhum vencimento para hoje'
                            : (_vencidos.isNotEmpty
                                ? '${_vencidos.length} vencido(s) • ${_vencimentosHoje.length} para hoje'
                                : '${_vencimentosHoje.length} vencimento(s) para hoje'),
                    subtitle:
                        (_vencimentosHoje.isEmpty && _vencidos.isEmpty)
                            ? 'Tudo certo por hoje.'
                            : [..._vencidos, ..._vencimentosHoje]
                                .take(3)
                                .map(
                                  (e) =>
                                      '${e.descricao} (${DateFormat('dd/MM').format(e.dataVencimento)})',
                                )
                                .join(' • '),
                    onTap: () => _goMain('/contas-pagar'),
                    ctaText: 'Ver',
                    onCta: () => _goMain('/contas-pagar'),
                    accent:
                        _vencidos.isNotEmpty
                            ? Theme.of(context).colorScheme.error
                            : Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    context: context,
                    icon: Icons.alarm,
                    title:
                        (_lembretesHoje.isEmpty && _lembretesAtrasados.isEmpty)
                            ? 'Nenhum lembrete pendente'
                            : (_lembretesAtrasados.isNotEmpty
                                ? '${_lembretesAtrasados.length} atrasado(s) • ${_lembretesHoje.length} para hoje'
                                : '${_lembretesHoje.length} lembrete(s) para hoje'),
                    subtitle:
                        (_lembretesHoje.isEmpty && _lembretesAtrasados.isEmpty)
                            ? 'Tudo certo por enquanto.'
                            : [..._lembretesAtrasados, ..._lembretesHoje]
                                .take(3)
                                .map(
                                  (e) =>
                                      '${e.titulo} (${DateFormat('dd/MM HH:mm').format(e.dataHora)})',
                                )
                                .join(' • '),
                    onTap: () => _goMain('/lembretes'),
                    ctaText: 'Ver',
                    onCta: () => _goMain('/lembretes'),
                    accent: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    context: context,
                    icon: Icons.table_rows,
                    title: 'Ir para lançamentos',
                    subtitle: 'Abrir tela de gastos/lançamentos',
                    onTap: () => _goMain('/lancamentos'),
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    context: context,
                    icon: Icons.home_work_outlined,
                    title: 'Despesas fixas',
                    subtitle: 'Gerenciar contas mensais automáticas',
                    onTap: () => _goMain('/despesas-fixas'),
                  ),
                ],
              ),
    );
  }
}
