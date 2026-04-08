// ignore_for_file: control_flow_in_finally, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/metricas/metrica_limite_repository.dart';

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

  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _carregando = false;

  String _periodoTipo = 'mensal'; // 'mensal'|'semanal'
  DateTime _referencia = DateTime.now();

  List<MetricaLimite> _metricas = const [];
  List<CategoriaPersonalizada> _cats = const [];
  final Map<int, List<SubcategoriaPersonalizada>> _subsByCat = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final cats = await _catRepo.listarTodas();

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

  Future<void> _abrirForm({MetricaLimite? existente}) async {
    final formKey = GlobalKey<FormState>();

    String periodoTipo = existente?.periodoTipo ?? _periodoTipo;
    DateTime referencia = _referencia;

    int? categoriaId = existente?.idCategoriaPersonalizada;
    int? subcategoriaId = existente?.idSubcategoriaPersonalizada;

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

                          DropdownButtonFormField<String>(
                            value: periodoTipo,
                            decoration: const InputDecoration(
                              labelText: 'Período',
                              border: OutlineInputBorder(),
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
                            onChanged: (v) {
                              if (v == null) return;
                              modalSetState(() => periodoTipo = v);
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
                            validator:
                                (v) =>
                                    v == null ? 'Selecione a categoria.' : null,
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
                                    : (v) =>
                                        modalSetState(() => subcategoriaId = v),
                          ),
                          const SizedBox(height: 10),

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
                                idCategoriaPersonalizada: categoriaId!,
                                idSubcategoriaPersonalizada: subcategoriaId,
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

                                      return Card(
                                        child: ListTile(
                                          title: Text(
                                            sub != null
                                                ? '${cat?.nome ?? 'Categoria'} • ${sub.nome}'
                                                : (cat?.nome ?? 'Categoria'),
                                          ),
                                          subtitle: Text(
                                            '${m.periodoTipo} • pagos:${m.considerarSomentePagos ? 'sim' : 'não'} • futuros:${m.incluirFuturos ? 'sim' : 'não'}',
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
                                                          ? Theme.of(
                                                            context,
                                                          ).colorScheme.error
                                                          : Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () => _abrirForm(existente: m),
                                          onLongPress: () => _excluir(m),
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
