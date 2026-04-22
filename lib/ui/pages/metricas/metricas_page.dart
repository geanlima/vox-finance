// ignore_for_file: control_flow_in_finally, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/metricas/metrica_limite_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class MetricasPage extends StatefulWidget {
  const MetricasPage({super.key});

  static const routeName = '/metricas';

  @override
  State<MetricasPage> createState() => _MetricasPageState();
}

class _MetricasPageState extends State<MetricasPage> {
  final _repo = MetricaLimiteRepository();
  final _catRepo = CategoriaPersonalizadaRepository();
  final _subRepo = SubcategoriaPersonalizadaRepository();
  final _cartaoRepo = CartaoCreditoRepository();

  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _mesAbrev = DateFormat('MMM/yyyy', 'pt_BR');
  final _dia = DateFormat('dd/MM/yyyy', 'pt_BR');

  bool _carregando = false;

  String _periodoTipo = 'mensal'; // 'mensal'|'semanal'
  DateTime _referencia = DateTime.now();

  List<MetricaLimite> _metricas = const [];
  List<CategoriaPersonalizada> _cats = const [];
  final Map<int, List<SubcategoriaPersonalizada>> _subsByCat = {};
  List<CartaoCredito> _cartoes = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final cats = await _catRepo.listarTodas();
      final cartoes = await _cartaoRepo.getCartoesCredito();

      _subsByCat.clear();
      for (final c in cats) {
        if (c.id == null) continue;
        _subsByCat[c.id!] = await _subRepo.listarPorCategoria(c.id!);
      }

      final metricas = await _repo.listarPorPeriodo(
        periodoTipo: _periodoTipo,
        ano: _referencia.year,
        mes: _periodoTipo == 'mensal' ? _referencia.month : null,
        semana:
            _periodoTipo == 'semanal' ? _repo.semanaDoAno(_referencia) : null,
      );

      if (!mounted) return;
      setState(() {
        _cats = cats;
        _cartoes = cartoes;
        _metricas = metricas;
      });
    } finally {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  CategoriaPersonalizada? _catById(int id) {
    try {
      return _cats.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  SubcategoriaPersonalizada? _subById(int catId, int subId) {
    final list = _subsByCat[catId] ?? const [];
    try {
      return list.firstWhere((s) => s.id == subId);
    } catch (_) {
      return null;
    }
  }

  String _cardTitle(MetricaLimite m, CategoriaPersonalizada? cat, SubcategoriaPersonalizada? sub) {
    if (m.escopo == 'forma') {
      final f =
          (m.formaPagamento != null &&
                  m.formaPagamento! >= 0 &&
                  m.formaPagamento! < FormaPagamento.values.length)
              ? FormaPagamento.values[m.formaPagamento!]
              : null;
      if (f == null) return 'Forma de pagamento';
      if (f == FormaPagamento.credito && m.idCartao != null) {
        try {
          final c = _cartoes.firstWhere((e) => e.id == m.idCartao);
          return '${f.label} • ${c.label}';
        } catch (_) {
          return '${f.label} • Cartão';
        }
      }
      return f.label;
    }

    final base = cat?.nome ?? 'Categoria';
    if (sub != null) return '$base • ${sub.nome}';
    return base;
  }

  String _cardSubtitle(MetricaLimite m) {
    final periodo = () {
      if (m.periodoTipo == 'semanal') {
        final sem = m.semana ?? _repo.semanaDoAno(_referencia);
        final (ini, fim) = _repo.intervaloDaSemana(ano: m.ano, semana: sem);
        return 'Semanal • Sem $sem • ${DateFormat('dd/MM').format(ini)}–${DateFormat('dd/MM').format(fim)}';
      }
      final mes = (m.mes ?? _referencia.month);
      return 'Mensal • ${_mesAbrev.format(DateTime(m.ano, mes, 1))}';
    }();

    final base = m.escopo == 'forma' ? 'Forma' : 'Categoria';
    return '$periodo • $base';
  }

  String get _periodoLabel {
    if (_periodoTipo == 'semanal') {
      final (ini, fim) = _repo.intervaloPeriodo(
        periodoTipo: 'semanal',
        referencia: _referencia,
      );
      return 'Semana • ${DateFormat('dd/MM').format(ini)}–${DateFormat('dd/MM').format(fim)}';
    }
    return '${DateFormat.MMMM('pt_BR').format(_referencia)[0].toUpperCase()}${DateFormat.MMMM('pt_BR').format(_referencia).substring(1)} / ${_referencia.year}';
  }

  Future<void> _selecionarReferencia() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _referencia,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nova == null) return;
    setState(() => _referencia = nova);
    await _carregar();
  }

  (DateTime inicio, DateTime fim) _intervaloBaseMetrica({
    required MetricaLimite metrica,
    required DateTime referenciaPeriodo,
  }) {
    if (metrica.periodoTipo == 'semanal') {
      final sem = metrica.semana ?? _repo.semanaDoAno(referenciaPeriodo);
      return _repo.intervaloDaSemana(ano: metrica.ano, semana: sem);
    }

    final mes = metrica.mes ?? referenciaPeriodo.month;
    final inicio = DateTime(metrica.ano, mes, 1);
    final fim = DateTime(metrica.ano, mes + 1, 1).subtract(
      const Duration(milliseconds: 1),
    );
    return (inicio, fim);
  }

  (DateTime inicio, DateTime fim) _intervaloEfetivoMetrica({
    required MetricaLimite metrica,
    required DateTime referenciaPeriodo,
  }) {
    final (inicio, fimBase) = _intervaloBaseMetrica(
      metrica: metrica,
      referenciaPeriodo: referenciaPeriodo,
    );
    if (metrica.incluirFuturos) return (inicio, fimBase);

    final now = DateTime.now();
    final fim = now.isBefore(fimBase) ? now : fimBase;
    return (inicio, fim);
  }

  Future<void> _mostrarPeriodoDoCard({
    required MetricaLimite metrica,
    required DateTime referenciaPeriodo,
    required String titulo,
  }) async {
    final (iniBase, fimBase) = _intervaloBaseMetrica(
      metrica: metrica,
      referenciaPeriodo: referenciaPeriodo,
    );
    final (iniEf, fimEf) = _intervaloEfetivoMetrica(
      metrica: metrica,
      referenciaPeriodo: referenciaPeriodo,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titulo,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Período base usado na soma',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_dia.format(iniBase)} até ${_dia.format(fimBase)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (!metrica.incluirFuturos) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Fim efetivo (sem futuros)',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_dia.format(iniEf)} até ${_dia.format(fimEf)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _abrirForm(existente: metrica);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar métrica'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirForm({MetricaLimite? existente}) async {
    final formKey = GlobalKey<FormState>();

    String periodoTipo = existente?.periodoTipo ?? _periodoTipo;
    DateTime referencia = _referencia;
    if (existente != null) {
      if (existente.periodoTipo == 'semanal') {
        final sem = existente.semana ?? _repo.semanaDoAno(_referencia);
        referencia = _repo.referenciaDaSemana(ano: existente.ano, semana: sem);
      } else {
        referencia = DateTime(
          existente.ano,
          (existente.mes ?? _referencia.month),
          1,
        );
      }
    }

    String escopoAtual = existente?.escopo ?? 'categoria'; // 'categoria'|'forma'

    int? categoriaId =
        (escopoAtual == 'categoria') ? existente?.idCategoriaPersonalizada : null;
    int? subcategoriaId =
        (escopoAtual == 'categoria') ? existente?.idSubcategoriaPersonalizada : null;

    int? formaPagamento = existente?.formaPagamento;
    int? idCartao = existente?.idCartao;

    final limiteCtrl = TextEditingController(
      text: existente != null ? existente.limiteValor.toStringAsFixed(2) : '',
    );

    bool considerarSomentePagos = existente?.considerarSomentePagos ?? true;
    bool incluirFuturos = existente?.incluirFuturos ?? false;
    bool ignorarPagamentoFatura = existente?.ignorarPagamentoFatura ?? true;

    final pct1Ctrl = TextEditingController(
      text: (existente?.alertaPct1 ?? 80).toString(),
    );
    final pct2Ctrl = TextEditingController(
      text: (existente?.alertaPct2 ?? 100).toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tema = Theme.of(sheetContext);
        final mq = MediaQuery.of(sheetContext);
        final bottomInset = mq.viewInsets.bottom;
        final safeBottom = mq.padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: StatefulBuilder(
              builder: (context, modalSetState) {
                final catsComId = _cats.where((c) => c.id != null).toList();
                final subs =
                    (categoriaId == null)
                        ? const <SubcategoriaPersonalizada>[]
                        : (_subsByCat[categoriaId!] ?? const []);
                final cartoesComId =
                    _cartoes.where((c) => c.id != null).toList();

                return Container(
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + safeBottom),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                existente == null
                                    ? 'Nova métrica'
                                    : 'Editar métrica',
                                style: tema.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Período (Mensal/Semanal) no estilo "botões"
                          Builder(
                            builder: (context) {
                              final cs = Theme.of(context).colorScheme;
                              return SegmentedButton<String>(
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  side: WidgetStateProperty.all(
                                    BorderSide(
                                      color: cs.outline.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.primaryContainer;
                                    }
                                    return cs.surfaceContainerHighest.withValues(
                                      alpha: 0.65,
                                    );
                                  }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.onPrimaryContainer;
                                    }
                                    return cs.onSurface;
                                  }),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: 'mensal',
                                    label: Text('Mensal'),
                                    icon: Icon(Icons.calendar_view_month),
                                  ),
                                  ButtonSegment(
                                    value: 'semanal',
                                    label: Text('Semanal'),
                                    icon: Icon(Icons.view_week_outlined),
                                  ),
                                ],
                                selected: {periodoTipo},
                                onSelectionChanged: (s) {
                                  final v = s.first;
                                  if (v == periodoTipo) return;
                                  modalSetState(() => periodoTipo = v);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          OutlinedButton.icon(
                            onPressed: () async {
                              final nova = await showDatePicker(
                                context: sheetContext,
                                initialDate: referencia,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (nova == null) return;
                              modalSetState(() => referencia = nova);
                            },
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              periodoTipo == 'semanal'
                                  ? 'Semana de ${DateFormat('dd/MM/yyyy').format(referencia)}'
                                  : 'Mês de ${DateFormat('MM/yyyy').format(referencia)}',
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            'Base do limite',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final cs = Theme.of(context).colorScheme;
                              return SegmentedButton<String>(
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  side: WidgetStateProperty.all(
                                    BorderSide(
                                      color: cs.outline.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.primaryContainer;
                                    }
                                    return cs.surfaceContainerHighest.withValues(
                                      alpha: 0.65,
                                    );
                                  }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.onPrimaryContainer;
                                    }
                                    return cs.onSurface;
                                  }),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: 'categoria',
                                    label: Text('Categoria'),
                                    icon: Icon(Icons.category_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'forma',
                                    label: Text('Forma'),
                                    icon: Icon(Icons.credit_card_outlined),
                                  ),
                                ],
                                selected: {escopoAtual},
                                onSelectionChanged: (s) {
                                  final v = s.first;
                                  if (v == escopoAtual) return;
                                  modalSetState(() {
                                    escopoAtual = v;
                                    if (escopoAtual == 'categoria') {
                                      formaPagamento = null;
                                      idCartao = null;
                                    } else {
                                      categoriaId = null;
                                      subcategoriaId = null;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          if (escopoAtual == 'forma') ...[
                            DropdownButtonFormField<int?>(
                              value: formaPagamento,
                              decoration: const InputDecoration(
                                labelText: 'Forma de pagamento',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('— Selecione —'),
                                ),
                                ...FormaPagamento.values.map(
                                  (f) => DropdownMenuItem<int?>(
                                    value: f.index,
                                    child: Text(f.label),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                modalSetState(() {
                                  formaPagamento = v;
                                  if (formaPagamento !=
                                      FormaPagamento.credito.index) {
                                    idCartao = null;
                                  }
                                });
                              },
                              validator: (v) {
                                if (escopoAtual == 'forma' && v == null) {
                                  return 'Selecione a forma de pagamento.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            if (formaPagamento == FormaPagamento.credito.index)
                              DropdownButtonFormField<int?>(
                                value: idCartao,
                                decoration: InputDecoration(
                                  labelText: 'Cartão (opcional)',
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      cartoesComId.isEmpty
                                          ? 'Nenhum cartão cadastrado.'
                                          : 'Selecione um cartão para limitar apenas nele.',
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('— Todos os cartões —'),
                                  ),
                                  ...cartoesComId.map(
                                    (c) => DropdownMenuItem<int?>(
                                      value: c.id,
                                      child: Text(c.label),
                                    ),
                                  ),
                                ],
                                onChanged: cartoesComId.isEmpty
                                    ? null
                                    : (v) => modalSetState(() => idCartao = v),
                              ),
                            if (formaPagamento == FormaPagamento.credito.index)
                              const SizedBox(height: 10),
                          ],

                          if (escopoAtual == 'categoria') ...[
                            DropdownButtonFormField<int>(
                              value: categoriaId,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  catsComId
                                      .map(
                                        (c) => DropdownMenuItem<int>(
                                          value: c.id!,
                                          child: Text(c.nome),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                modalSetState(() {
                                  categoriaId = v;
                                  subcategoriaId = null;
                                });
                              },
                              validator: (v) {
                                if (escopoAtual == 'categoria' && v == null) {
                                  return 'Selecione a categoria.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            DropdownButtonFormField<int?>(
                              value: subcategoriaId,
                              decoration: InputDecoration(
                                labelText: 'Subcategoria (opcional)',
                                border: const OutlineInputBorder(),
                                helperText:
                                    categoriaId == null
                                        ? 'Selecione uma categoria para ver as subcategorias.'
                                        : (subs.isEmpty
                                            ? 'Sem subcategorias para esta categoria.'
                                            : null),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('— Sem subcategoria —'),
                                ),
                                ...subs.map(
                                  (s) => DropdownMenuItem<int?>(
                                    value: s.id,
                                    child: Text(s.nome),
                                  ),
                                ),
                              ],
                              onChanged:
                                  (categoriaId == null || subs.isEmpty)
                                      ? null
                                      : (v) => modalSetState(
                                            () => subcategoriaId = v,
                                          ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          TextFormField(
                            controller: limiteCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Limite (R\$)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final txt = (v ?? '').trim().replaceAll(',', '.');
                              final val = double.tryParse(txt);
                              if (val == null || val <= 0) {
                                return 'Informe um limite válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Considerar somente pagos'),
                            value: considerarSomentePagos,
                            onChanged:
                                (v) => modalSetState(
                                  () => considerarSomentePagos = v,
                                ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Incluir lançamentos futuros'),
                            value: incluirFuturos,
                            onChanged:
                                (v) => modalSetState(() => incluirFuturos = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Ignorar pagamento de fatura'),
                            value: ignorarPagamentoFatura,
                            onChanged:
                                (v) => modalSetState(
                                  () => ignorarPagamentoFatura = v,
                                ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: pct1Ctrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Alerta 1 (%)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final n = int.tryParse((v ?? '').trim());
                                    if (n == null || n < 1 || n > 200) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: pct2Ctrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Alerta 2 (%)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final n = int.tryParse((v ?? '').trim());
                                    if (n == null || n < 1 || n > 300) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              final lim = double.parse(
                                limiteCtrl.text.trim().replaceAll(',', '.'),
                              );
                              final a1 = int.parse(pct1Ctrl.text.trim());
                              final a2 = int.parse(pct2Ctrl.text.trim());

                              final now = DateTime.now();
                              final m = MetricaLimite(
                                id: existente?.id,
                                ativo: true,
                                escopo: escopoAtual,
                                periodoTipo: periodoTipo,
                                ano: referencia.year,
                                mes:
                                    periodoTipo == 'mensal'
                                        ? referencia.month
                                        : null,
                                semana:
                                    periodoTipo == 'semanal'
                                        ? _repo.semanaDoAno(referencia)
                                        : null,
                                idCategoriaPersonalizada:
                                    escopoAtual == 'categoria'
                                        ? (categoriaId ?? 0)
                                        : 0,
                                idSubcategoriaPersonalizada:
                                    escopoAtual == 'categoria'
                                        ? subcategoriaId
                                        : null,
                                formaPagamento:
                                    escopoAtual == 'forma' ? formaPagamento : null,
                                idCartao:
                                    (escopoAtual == 'forma' &&
                                            formaPagamento ==
                                                FormaPagamento.credito.index)
                                        ? idCartao
                                        : null,
                                idConta: null,
                                limiteValor: lim,
                                considerarSomentePagos: considerarSomentePagos,
                                incluirFuturos: incluirFuturos,
                                ignorarPagamentoFatura: ignorarPagamentoFatura,
                                alertaPct1: a1,
                                alertaPct2: a2,
                                criadoEm: existente?.criadoEm ?? now,
                                atualizadoEm: now,
                              );

                              await _repo.salvar(m);

                              if (!mounted) return;
                              Navigator.pop(sheetContext);
                              await _carregar();
                            },
                            child: const Text('Salvar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    // O bottom sheet ainda pode estar animando/reconstruindo após o pop.
    // Se descartarmos os controllers imediatamente, o Flutter pode acusar
    // "used after being disposed". Descartamos no próximo frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      limiteCtrl.dispose();
      pct1Ctrl.dispose();
      pct2Ctrl.dispose();
    });
  }

  Future<void> _excluir(MetricaLimite m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir métrica'),
          content: const Text('Deseja excluir este limite?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (m.id == null) return;
    await _repo.deletar(m.id!);
    if (!mounted) return;
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _periodoTipo,
                            decoration: const InputDecoration(
                              labelText: 'Período',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'mensal',
                                child: Text('Mensal'),
                              ),
                              DropdownMenuItem(
                                value: 'semanal',
                                child: Text('Semanal'),
                              ),
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _periodoTipo = v);
                              await _carregar();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _selecionarReferencia,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(_periodoLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child:
                          _metricas.isEmpty
                              ? const Center(
                                child: Text('Nenhuma métrica cadastrada.'),
                              )
                              : ListView.separated(
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
                                itemCount: _metricas.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final m = _metricas[idx];
                                  final cat = _catById(
                                    m.idCategoriaPersonalizada,
                                  );
                                  final sub =
                                      m.idSubcategoriaPersonalizada == null
                                          ? null
                                          : _subById(
                                            m.idCategoriaPersonalizada,
                                            m.idSubcategoriaPersonalizada!,
                                          );

                                  return FutureBuilder<ConsumoMetrica>(
                                    future: _repo.calcularConsumo(
                                      metrica: m,
                                      referenciaPeriodo: _referencia,
                                    ),
                                    builder: (context, snap) {
                                      final consumo = snap.data;
                                      final pct = consumo?.percentual ?? 0.0;
                                      final total = consumo?.total ?? 0.0;
                                      final limite =
                                          consumo?.limite ?? m.limiteValor;

                                      final theme = Theme.of(context);
                                      final primary = theme.colorScheme.primary;
                                      final danger = Colors.red.shade400;

                                      return Slidable(
                                        key: ValueKey(m.id ?? idx),
                                        groupTag: 'metricas_limites',
                                        endActionPane: ActionPane(
                                          motion: const DrawerMotion(),
                                          extentRatio: 0.35,
                                          children: [
                                            CustomSlidableAction(
                                              onPressed:
                                                  (_) => _abrirForm(existente: m),
                                              backgroundColor:
                                                  theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Icon(
                                                Icons.edit,
                                                size: 28,
                                                color: primary,
                                              ),
                                            ),
                                            CustomSlidableAction(
                                              onPressed: (_) => _excluir(m),
                                              backgroundColor: danger,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: const Icon(
                                                Icons.delete,
                                                size: 28,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: Card(
                                          child: ListTile(
                                            title: Text(
                                              _cardTitle(m, cat, sub),
                                            ),
                                            subtitle: Text(
                                              _cardSubtitle(m),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${_money.format(total)} / ${_money.format(limite)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  '${pct.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    color:
                                                        pct >= 100
                                                            ? theme
                                                                .colorScheme
                                                                .error
                                                            : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap:
                                                () => _mostrarPeriodoDoCard(
                                                  metrica: m,
                                                  referenciaPeriodo: _referencia,
                                                  titulo: _cardTitle(m, cat, sub),
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
