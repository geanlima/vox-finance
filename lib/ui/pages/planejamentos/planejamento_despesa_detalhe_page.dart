// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/planejamento_despesa.dart';
import 'package:vox_finance/ui/data/models/planejamento_despesa_item.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/planejamentos/planejamento_despesa_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';

class PlanejamentoDespesaDetalhePage extends StatefulWidget {
  const PlanejamentoDespesaDetalhePage({
    super.key,
    required this.planejamentoId,
  });

  final int planejamentoId;

  @override
  State<PlanejamentoDespesaDetalhePage> createState() =>
      _PlanejamentoDespesaDetalhePageState();
}

class _PlanejamentoDespesaDetalhePageState
    extends State<PlanejamentoDespesaDetalhePage> {
  final _repo = PlanejamentoDespesaRepository();
  final _lancRepo = LancamentoRepository();
  final _catRepo = CategoriaPersonalizadaRepository();
  final _subRepo = SubcategoriaPersonalizadaRepository();

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _df = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  PlanejamentoDespesa? _planejamento;
  List<PlanejamentoDespesaItem> _itens = const [];
  List<CategoriaPersonalizada> _categorias = const [];
  final Map<int, List<SubcategoriaPersonalizada>> _subsPorCat = {};
  /// [id item planejamento] → lançamento vinculado
  Map<int, Lancamento> _lancVinculadoPorItemId = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final p = await _repo.getPorId(widget.planejamentoId);
      final itens = await _repo.listarItens(widget.planejamentoId);
      final cats = await _catRepo.listarPorTipo(TipoMovimento.despesa);
      final subs = <int, List<SubcategoriaPersonalizada>>{};
      for (final c in cats) {
        if (c.id == null) continue;
        subs[c.id!] = await _subRepo.listarPorCategoria(c.id!);
      }
      final idsLanc = itens.map((e) => e.idLancamento).whereType<int>().toSet();
      final lancMap =
          idsLanc.isEmpty
              ? const <int, Lancamento>{}
              : await _lancRepo.getByIds(idsLanc);
      final porItem = <int, Lancamento>{};
      for (final it in itens) {
        final iid = it.id;
        final lid = it.idLancamento;
        if (iid != null && lid != null) {
          final l = lancMap[lid];
          if (l != null) {
            porItem[iid] = l;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _planejamento = p;
        _itens = itens;
        _categorias = cats;
        _subsPorCat
          ..clear()
          ..addAll(subs);
        _lancVinculadoPorItemId = porItem;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _total =>
      _itens.fold<double>(0, (s, e) => s + e.valor);

  String _rotuloItem(PlanejamentoDespesaItem it) {
    if (it.idCategoriaPersonalizada == null) return '';
    CategoriaPersonalizada? cat;
    try {
      cat = _categorias.firstWhere((c) => c.id == it.idCategoriaPersonalizada);
    } catch (_) {
      cat = null;
    }
    if (it.idSubcategoriaPersonalizada != null) {
      final subs = _subsPorCat[it.idCategoriaPersonalizada!] ?? const [];
      try {
        final sub = subs.firstWhere((s) => s.id == it.idSubcategoriaPersonalizada);
        return '${cat?.nome ?? 'Categoria'} • ${sub.nome}';
      } catch (_) {
        return cat?.nome ?? '';
      }
    }
    return cat?.nome ?? '';
  }

  Future<void> _abrirItem({PlanejamentoDespesaItem? existente}) async {
    final descCtrl = TextEditingController(text: existente?.descricao ?? '');
    final valorCtrl = TextEditingController(
      text:
          existente != null && existente.valor > 0
              ? existente.valor.toStringAsFixed(2)
              : '',
    );
    int? catId = existente?.idCategoriaPersonalizada;
    int? subId = existente?.idSubcategoriaPersonalizada;
    DateTime? dataRef = existente?.dataReferencia;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            final bottom = mq.viewInsets.bottom + mq.padding.bottom;
            final subs =
                catId == null ? const <SubcategoriaPersonalizada>[] : (_subsPorCat[catId] ?? const []);
            if (subId != null && subs.every((s) => s.id != subId)) {
              subId = null;
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existente == null ? 'Nova despesa prevista' : 'Editar item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descrição (ex.: Hotel, Carne, Uber)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor previsto (R\$)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        key: ValueKey<String>('cat-$catId'),
                        initialValue: catId,
                        decoration: const InputDecoration(
                          labelText: 'Categoria (despesa)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Nenhuma —'),
                          ),
                          ..._categorias.where((c) => c.id != null).map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.nome),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setModal(() {
                            catId = v;
                            subId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        key: ValueKey<String>('sub-$catId-$subId'),
                        initialValue: subId,
                        decoration: const InputDecoration(
                          labelText: 'Subcategoria (opcional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Nenhuma —'),
                          ),
                          ...subs.where((s) => s.id != null).map(
                            (s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.nome),
                            ),
                          ),
                        ],
                        onChanged: catId == null ? null : (v) => setModal(() => subId = v),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dataRef ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) {
                            setModal(() => dataRef = d);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(
                          dataRef == null
                              ? 'Data de referência (opcional)'
                              : 'Data: ${_df.format(dataRef!)}',
                        ),
                      ),
                      if (dataRef != null)
                        TextButton(
                          onPressed: () => setModal(() => dataRef = null),
                          child: const Text('Limpar data'),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          if (descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Informe a descrição.'),
                              ),
                            );
                            return;
                          }
                          final v = double.tryParse(
                            valorCtrl.text.replaceAll(',', '.').trim(),
                          );
                          if (v == null || v < 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Valor inválido.'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Salvar item'),
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

    if (ok != true || !mounted) {
      descCtrl.dispose();
      valorCtrl.dispose();
      return;
    }

    final v = double.tryParse(
      valorCtrl.text.replaceAll(',', '.').trim(),
    )!;
    final ordem =
        existente?.ordem ?? await _repo.proximaOrdem(widget.planejamentoId);
    final item = PlanejamentoDespesaItem(
      id: existente?.id,
      planejamentoId: widget.planejamentoId,
      descricao: descCtrl.text.trim(),
      valor: v,
      idCategoriaPersonalizada: catId,
      idSubcategoriaPersonalizada: subId,
      dataReferencia: dataRef,
      ordem: ordem,
      criadoEm: existente?.criadoEm ?? DateTime.now(),
      idLancamento: existente?.idLancamento,
    );
    await _repo.salvarItem(item);
    descCtrl.dispose();
    valorCtrl.dispose();
    await _carregar();
  }

  Future<void> _excluirItem(PlanejamentoDespesaItem it) async {
    final id = it.id;
    if (id == null) return;
    final sim = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir item?'),
            content: Text(it.descricao),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
    if (sim != true) return;
    await _repo.excluirItem(id);
    await _carregar();
  }

  Future<void> _gerarLancamento(PlanejamentoDespesaItem it) async {
    final itemId = it.id;
    if (itemId == null) return;
    if (it.idLancamento != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este item já tem lançamento. Desvincule antes de gerar outro.',
          ),
        ),
      );
      return;
    }
    final p = _planejamento;
    if (p == null) return;

    // Abre o MESMO formulário do cadastro de lançamento (Home)
    final dbService = DbService();
    final cartoesRepo = CartaoCreditoRepository(dbService: dbService);
    final contasRepo = ContaBancariaRepository(dbService: dbService);

    final List<CartaoCredito> cartoes = await cartoesRepo.getCartoesCredito();
    final List<ContaBancaria> contas =
        await contasRepo.getContasBancarias(apenasAtivas: true);

    final dataBase =
        it.dataReferencia != null
            ? DateTime(
              it.dataReferencia!.year,
              it.dataReferencia!.month,
              it.dataReferencia!.day,
            )
            : DateTime(p.dataInicio.year, p.dataInicio.month, p.dataInicio.day);

    Lancamento? salvo;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return LancamentoFormBottomSheet(
          valorInicial: it.valor,
          descricaoInicial: '${p.titulo}: ${it.descricao}',
          formaInicial: FormaPagamento.credito,
          pagamentoFaturaInicial: false,
          tipoInicial: TipoMovimento.despesa,
          dataSelecionada: dataBase,
          currency: _currency,
          dateDiaFormat: _df,
          dbService: dbService,
          cartoes: cartoes,
          contas: contas,
          onSaved: () async {},
          onSavedLancamento: (l) => salvo = l,
        );
      },
    );

    final idLanc = salvo?.id;
    if (idLanc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lançamento salvo, mas não consegui vincular automaticamente (ex.: parcelado).',
          ),
        ),
      );
      await _carregar();
      return;
    }

    await _repo.definirLancamentoDoItem(itemId: itemId, idLancamento: idLanc);
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento criado e vinculado.')),
    );
  }

  Future<void> _vincularLancamento(PlanejamentoDespesaItem it) async {
    final itemId = it.id;
    if (itemId == null) return;
    if (it.idLancamento != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desvincule antes de escolher outro lançamento.'),
        ),
      );
      return;
    }
    final p = _planejamento;
    if (p == null) return;

    final base = it.dataReferencia != null
        ? DateTime(
            it.dataReferencia!.year,
            it.dataReferencia!.month,
            it.dataReferencia!.day,
          )
        : DateTime(p.dataInicio.year, p.dataInicio.month, p.dataInicio.day);

    final escolhido = await showModalBottomSheet<Lancamento>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final bottom = mq.padding.bottom;
        final sec = Theme.of(ctx).colorScheme.secondary;

        DateTime dia = DateTime(base.year, base.month, base.day);
        var carregando = true;
        var despesasDoDia = const <Lancamento>[];
        var candidatos = const <Lancamento>[];
        String? msgVazio;

        Future<void> carregarDia(BuildContext ctx, StateSetter setModal) async {
          if (!ctx.mounted) return;
          setModal(() {
            carregando = true;
            msgVazio = null;
          });
          final despesas = await _lancRepo.getDespesasByDay(dia);

          final ocupados = <int>{};
          for (final x in _itens) {
            if (x.id == itemId) continue;
            if (x.idLancamento != null) {
              ocupados.add(x.idLancamento!);
            }
          }
          final cand =
              despesas
                  .where((l) => l.id != null && !ocupados.contains(l.id!))
                  .toList();

          if (!ctx.mounted) return;
          setModal(() {
            despesasDoDia = despesas;
            candidatos = cand;
            carregando = false;
            if (cand.isEmpty) {
              msgVazio =
                  despesasDoDia.isEmpty
                      ? 'Nenhuma despesa em ${_df.format(dia)}.'
                      : 'Todas as despesas desse dia já estão em outros itens.';
            }
          });
        }

        var iniciou = false;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            if (!iniciou) {
              iniciou = true;
              Future.microtask(() => carregarDia(ctx, setModal));
            }

            Future<void> selecionarData() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: dia,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                useRootNavigator: true,
              );
              if (picked == null) return;
              if (!ctx.mounted) return;
              setModal(() {
                dia = DateTime(picked.year, picked.month, picked.day);
              });
              await carregarDia(ctx, setModal);
            }

            Future<void> mudarDia(int delta) async {
              if (!ctx.mounted) return;
              setModal(() {
                dia = DateTime(dia.year, dia.month, dia.day + delta);
              });
              await carregarDia(ctx, setModal);
            }

            return SafeArea(
              top: false,
              child: SizedBox(
                height: mq.size.height * 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: sec,
                            radius: 20,
                            child: const Icon(
                              Icons.link,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Vincular lançamento',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(ctx)
                                .colorScheme
                                .outlineVariant
                                .withOpacity(0.55),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed:
                                    carregando ? null : () => mudarDia(-1),
                                icon: const Icon(Icons.chevron_left),
                                tooltip: 'Dia anterior',
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: carregando ? null : selecionarData,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _df.format(dia),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    carregando ? null : () => mudarDia(1),
                                icon: const Icon(Icons.chevron_right),
                                tooltip: 'Próximo dia',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (carregando)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child:
                          msgVazio != null
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    msgVazio!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              : ListView.separated(
                                padding:
                                    EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
                                itemCount: candidatos.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final l = candidatos[i];
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    elevation: 1.5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        l.descricao,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${_df.format(l.dataHora)} · ${l.formaPagamento.label}',
                                      ),
                                      trailing: Text(
                                        _currency.format(l.valor),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(ctx, l),
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
      },
    );

    if (escolhido?.id == null || !mounted) return;
    final lid = escolhido!.id!;
    final conflito = await _repo.outroItemDoPlanejamentoUsaLancamento(
      planejamentoId: widget.planejamentoId,
      idLancamento: lid,
      excetoItemId: itemId,
    );
    if (conflito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este lançamento já está em outro item.'),
        ),
      );
      return;
    }
    await _repo.definirLancamentoDoItem(itemId: itemId, idLancamento: lid);
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vinculado com sucesso.')),
    );
  }

  Future<void> _desvincular(PlanejamentoDespesaItem it) async {
    final itemId = it.id;
    if (itemId == null || it.idLancamento == null) return;
    await _repo.definirLancamentoDoItem(itemId: itemId, idLancamento: null);
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vínculo removido. O lançamento continua na lista de movimentação.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;
    final danger = Colors.red.shade400;
    final success = Colors.green.shade600;
    final p = _planejamento;

    return Scaffold(
      appBar: AppBar(
        title: Text(p?.titulo ?? 'Planejamento'),
      ),
      floatingActionButton: p == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirItem(),
              icon: const Icon(Icons.add),
              label: const Text('Despesa'),
            ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : p == null
              ? Center(
                child: Text(
                  'Planejamento não encontrado.',
                  style: TextStyle(color: cs.error),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.local != null && p.local!.isNotEmpty)
                            Text(
                              p.local!,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          if (p.local != null && p.local!.isNotEmpty)
                            const SizedBox(height: 8),
                          Text(
                            '${_df.format(p.dataInicio)} — ${_df.format(p.dataFim)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (p.notas != null && p.notas!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              p.notas!,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total previsto',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _currency.format(_total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Despesas previstas',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_itens.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Toque em "Despesa" para incluir itens. '
                        'Arraste para a esquerda: editar ou excluir. '
                        'Arraste para a direita: gerar lançamento ou vincular.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                      ),
                    )
                  else
                    ..._itens.map((it) {
                      final rot = _rotuloItem(it);
                      final lVinc =
                          it.id != null
                              ? _lancVinculadoPorItemId[it.id!]
                              : null;
                      final vinculado = it.idLancamento != null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
                          key: ValueKey(
                            'planej_item_${it.id}_${it.planejamentoId}',
                          ),
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: vinculado ? 0.20 : 0.35,
                            children:
                                vinculado
                                    ? [
                                      CustomSlidableAction(
                                        onPressed: (_) => _desvincular(it),
                                        backgroundColor: Colors.orange.shade800,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Icon(
                                          Icons.link_off,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ]
                                    : [
                                      CustomSlidableAction(
                                        onPressed: (_) => _gerarLancamento(it),
                                        backgroundColor: success,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Icon(
                                          Icons.post_add,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      CustomSlidableAction(
                                        onPressed: (_) => _vincularLancamento(it),
                                        backgroundColor: secondary,
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
                            extentRatio: 0.35,
                            children: [
                              CustomSlidableAction(
                                onPressed: (_) => _abrirItem(existente: it),
                                backgroundColor: cs.surface,
                                borderRadius: BorderRadius.circular(12),
                                child: Icon(
                                  Icons.edit,
                                  size: 28,
                                  color: primary,
                                ),
                              ),
                              CustomSlidableAction(
                                onPressed: (_) => _excluirItem(it),
                                backgroundColor: danger,
                                borderRadius: BorderRadius.circular(12),
                                child: const Icon(
                                  Icons.delete,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          lVinc != null
                                              ? cs.tertiary.withOpacity(0.15)
                                              : cs.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      lVinc != null
                                          ? Icons.receipt_long_outlined
                                          : Icons.savings_outlined,
                                      color:
                                          lVinc != null
                                              ? cs.tertiary
                                              : cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.descricao,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (rot.isNotEmpty ||
                                            it.dataReferencia != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (rot.isNotEmpty) rot,
                                              if (it.dataReferencia != null)
                                                _df.format(it.dataReferencia!),
                                            ].join(' · '),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (lVinc != null) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest
                                                  .withOpacity(0.65),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: 16,
                                                  color: cs.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${_currency.format(lVinc.valor)} · ${_df.format(lVinc.dataHora)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: cs.onSurface,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currency.format(it.valor),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
    );
  }
}
