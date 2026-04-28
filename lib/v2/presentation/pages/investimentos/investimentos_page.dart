// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/investimentos_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class InvestimentosPage extends StatefulWidget {
  const InvestimentosPage({super.key});

  @override
  State<InvestimentosPage> createState() => _InvestimentosPageState();
}

class _InvestimentosPageState extends State<InvestimentosPage> {
  final InvestimentosRepository _repo = InjectorV2.investimentosRepo;

  bool _loading = true;
  bool _somenteAtivos = true;
  List<InvestimentoRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  Color _tipoColor(int tipo) {
    switch (tipo) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _tipoLabel(int tipo) {
    switch (tipo) {
      case 1:
        return 'Renda Fixa';
      case 2:
        return 'Renda Variável';
      case 3:
        return 'Cripto';
      default:
        return 'Outros';
    }
  }

  Color _statusColor(bool ativo) => ativo ? Colors.green : Colors.red;
  String _statusLabel(bool ativo) => ativo ? 'Ativo' : 'Inativo';

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final itens = await _repo.listar();
    if (!mounted) return;

    setState(() {
      _itens =
          _somenteAtivos ? itens.where((e) => e.ativoFlag).toList() : itens;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _InvestimentoModal(
            titulo: 'Novo investimento',
            onSave: (r) async {
              await _repo.inserir(
                tipo: r.tipo,
                instituicao: r.instituicao,
                ativo: r.ativo,
                categoria: r.categoria,
                valorAplicado: r.valorAplicado,
                quantidade: r.quantidade,
                precoMedio: r.precoMedio,
                dataAporte: r.dataAporte,
                vencimento: r.vencimento,
                rentabilidadeTipo: r.rentabilidadeTipo,
                rentabilidadeValor: r.rentabilidadeValor,
                cdiPctAte10k: r.cdiPctAte10k,
                cdiPctAcima10k: r.cdiPctAcima10k,
                cdiLimiteFaixa: r.cdiLimiteFaixa,
                contaCorrente: r.contaCorrente,
                considerarFimSemana: r.considerarFimSemana,
                considerarFeriados: r.considerarFeriados,
                observacoes: r.observacoes,
                ativoFlag: r.ativoFlag,
              );
            },
          ),
    );

    if (ok == true) {
      await _load();
      _snack('Investimento salvo!');
    }
  }

  Future<void> _edit(InvestimentoRow item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _InvestimentoModal(
            titulo: 'Editar investimento',
            initial: _InvestimentoEditResult(
              tipo: item.tipo,
              instituicao: item.instituicao,
              ativo: item.ativo,
              categoria: item.categoria,
              valorAplicado: item.valorAplicado,
              quantidade: item.quantidade,
              precoMedio: item.precoMedio,
              dataAporte: item.dataAporte,
              vencimento: item.vencimento,
              rentabilidadeTipo: item.rentabilidadeTipo,
              rentabilidadeValor: item.rentabilidadeValor,
              cdiPctAte10k: item.cdiPctAte10k,
              cdiPctAcima10k: item.cdiPctAcima10k,
              cdiLimiteFaixa: item.cdiLimiteFaixa,
              contaCorrente: item.contaCorrente,
              considerarFimSemana: item.considerarFimSemana,
              considerarFeriados: item.considerarFeriados,
              observacoes: item.observacoes,
              ativoFlag: item.ativoFlag,
            ),
            onSave: (r) async {
              await _repo.atualizar(
                id: item.id,
                tipo: r.tipo,
                instituicao: r.instituicao,
                ativo: r.ativo,
                categoria: r.categoria,
                valorAplicado: r.valorAplicado,
                quantidade: r.quantidade,
                precoMedio: r.precoMedio,
                dataAporte: r.dataAporte,
                vencimento: r.vencimento,
                rentabilidadeTipo: r.rentabilidadeTipo,
                rentabilidadeValor: r.rentabilidadeValor,
                cdiPctAte10k: r.cdiPctAte10k,
                cdiPctAcima10k: r.cdiPctAcima10k,
                cdiLimiteFaixa: r.cdiLimiteFaixa,
                contaCorrente: r.contaCorrente,
                considerarFimSemana: r.considerarFimSemana,
                considerarFeriados: r.considerarFeriados,
                observacoes: r.observacoes,
                ativoFlag: r.ativoFlag,
              );
            },
          ),
    );

    if (ok == true) {
      await _load();
      _snack('Investimento atualizado!');
    }
  }

  Future<void> _remove(InvestimentoRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remover'),
            content: Text('Remover "${item.ativo}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _repo.remover(item.id);
      await _load();
      _snack('Investimento removido.');
    }
  }

  String _buildSubtitle(InvestimentoRow item) {
    final linhas = <String>[];

    final inst = (item.instituicao ?? '').trim();
    if (inst.isNotEmpty) linhas.add('Instituição: $inst');

    linhas.add(
      'Aplicado: ${_brl(item.valorAplicado)}  •  '
      'Qtd: ${_num(item.quantidade)}  •  '
      'PM: ${_brl(item.precoMedio)}',
    );

    if (item.rentabilidadeTipo == 3) {
      final pct =
          (item.valorAplicado <= item.cdiLimiteFaixa)
              ? item.cdiPctAte10k
              : item.cdiPctAcima10k;
      linhas.add(
        'CDI: ${_num(pct)}% (faixas, limite ${_brl(item.cdiLimiteFaixa)})  •  '
        '${item.considerarFimSemana ? 'considera FDS' : 'desconsidera FDS'}  •  '
        '${item.considerarFeriados ? 'considera feriados' : 'desconsidera feriados'}',
      );
      final cc = (item.contaCorrente ?? '').trim();
      if (cc.isNotEmpty) linhas.add('Conta corrente: $cc');
    }

    final venc = (item.vencimento ?? '').trim();
    if (venc.isNotEmpty) linhas.add('Vencimento: $venc');

    return linhas.join('\n');
  }

  Widget _buildTrailing(InvestimentoRow item) {
    final tipoColor = _tipoColor(item.tipo);
    final statusColor = _statusColor(item.ativoFlag);

    return SizedBox(
      width: 110,
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _ChipTag(
              text: _tipoLabel(item.tipo),
              color: tipoColor,
              dense: true,
            ),
            _ChipTag(
              text: _statusLabel(item.ativoFlag),
              color: statusColor,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _somenteAtivos,
              onChanged: (v) async {
                setState(() => _somenteAtivos = v);
                await _load();
              },
              title: const Text('Somente ativos'),
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _itens.isEmpty
                    ? const Center(
                      child: Text('Nenhum investimento cadastrado'),
                    )
                    : ListView.builder(
                      padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(12)),
                      itemCount: _itens.length,
                      itemBuilder: (context, index) {
                        final item = _itens[index];

                        return Slidable(
                          key: ValueKey(item.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.58,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _edit(item),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Editar',
                              ),
                              SlidableAction(
                                onPressed: (_) => _remove(item),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Apagar',
                              ),
                            ],
                          ),
                          child: Card(
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -1),
                              title: Text(
                                item.ativo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _buildSubtitle(item),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: _buildTrailing(item),
                              onTap: () => _edit(item),
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

class _InvestimentoEditResult {
  final int tipo;
  final String? instituicao;
  final String ativo;
  final String? categoria;

  final double valorAplicado;
  final double quantidade;
  final double precoMedio;

  final String? dataAporte;
  final String? vencimento;

  final int rentabilidadeTipo;
  final double rentabilidadeValor;

  // CDI (faixas)
  final double cdiPctAte10k;
  final double cdiPctAcima10k;
  final double cdiLimiteFaixa;
  final String? contaCorrente;
  final bool considerarFimSemana;
  final bool considerarFeriados;

  final String? observacoes;
  final bool ativoFlag;

  const _InvestimentoEditResult({
    required this.tipo,
    required this.instituicao,
    required this.ativo,
    required this.categoria,
    required this.valorAplicado,
    required this.quantidade,
    required this.precoMedio,
    required this.dataAporte,
    required this.vencimento,
    required this.rentabilidadeTipo,
    required this.rentabilidadeValor,
    required this.cdiPctAte10k,
    required this.cdiPctAcima10k,
    required this.cdiLimiteFaixa,
    required this.contaCorrente,
    required this.considerarFimSemana,
    required this.considerarFeriados,
    required this.observacoes,
    required this.ativoFlag,
  });
}

class _ChipTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool dense;

  const _ChipTag({required this.text, required this.color, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1.1, // ajuda a caber melhor
        ),
      ),
    );
  }
}

class _InvestimentoModal extends StatefulWidget {
  final String titulo;
  final _InvestimentoEditResult? initial;
  final Future<void> Function(_InvestimentoEditResult r) onSave;

  const _InvestimentoModal({
    required this.titulo,
    required this.onSave,
    this.initial,
  });

  @override
  State<_InvestimentoModal> createState() => _InvestimentoModalState();
}

class _InvestimentoModalState extends State<_InvestimentoModal> {
  late final TextEditingController ativoCtrl;
  late final TextEditingController instCtrl;
  late final TextEditingController catCtrl;
  late final TextEditingController valorCtrl;
  late final TextEditingController qtdCtrl;
  late final TextEditingController pmCtrl;
  late final TextEditingController aporteCtrl;
  late final TextEditingController vencCtrl;
  late final TextEditingController rentCtrl;
  late final TextEditingController cdiAteCtrl;
  late final TextEditingController cdiAcimaCtrl;
  late final TextEditingController cdiLimiteCtrl;
  late final TextEditingController contaCorrenteCtrl;
  late final TextEditingController obsCtrl;

  int tipoLocal = 1;
  int rentTipoLocal = 0;
  bool ativoFlagLocal = true;
  bool considerarFimSemanaLocal = false;
  bool considerarFeriadosLocal = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;

    tipoLocal = i?.tipo ?? 1;
    rentTipoLocal = i?.rentabilidadeTipo ?? 0;
    ativoFlagLocal = i?.ativoFlag ?? true;
    considerarFimSemanaLocal = i?.considerarFimSemana ?? false;
    considerarFeriadosLocal = i?.considerarFeriados ?? false;

    ativoCtrl = TextEditingController(text: i?.ativo ?? '');
    instCtrl = TextEditingController(text: i?.instituicao ?? '');
    catCtrl = TextEditingController(text: i?.categoria ?? '');
    valorCtrl = TextEditingController(text: _num(i?.valorAplicado ?? 0));
    qtdCtrl = TextEditingController(text: _num(i?.quantidade ?? 0));
    pmCtrl = TextEditingController(text: _num(i?.precoMedio ?? 0));
    aporteCtrl = TextEditingController(text: i?.dataAporte ?? '');
    vencCtrl = TextEditingController(text: i?.vencimento ?? '');
    rentCtrl = TextEditingController(text: _num(i?.rentabilidadeValor ?? 0));
    cdiAteCtrl = TextEditingController(text: _num(i?.cdiPctAte10k ?? 0));
    cdiAcimaCtrl = TextEditingController(text: _num(i?.cdiPctAcima10k ?? 0));
    cdiLimiteCtrl = TextEditingController(text: _num(i?.cdiLimiteFaixa ?? 10000));
    contaCorrenteCtrl = TextEditingController(text: i?.contaCorrente ?? '');
    obsCtrl = TextEditingController(text: i?.observacoes ?? '');
  }

  @override
  void dispose() {
    ativoCtrl.dispose();
    instCtrl.dispose();
    catCtrl.dispose();
    valorCtrl.dispose();
    qtdCtrl.dispose();
    pmCtrl.dispose();
    aporteCtrl.dispose();
    vencCtrl.dispose();
    rentCtrl.dispose();
    cdiAteCtrl.dispose();
    cdiAcimaCtrl.dispose();
    cdiLimiteCtrl.dispose();
    contaCorrenteCtrl.dispose();
    obsCtrl.dispose();
    super.dispose();
  }

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double _parseDouble(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  String? _cleanStr(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;

    final a = ativoCtrl.text.trim();
    if (a.isEmpty) return;

    final r = _InvestimentoEditResult(
      tipo: tipoLocal,
      instituicao: _cleanStr(instCtrl.text),
      ativo: a,
      categoria: _cleanStr(catCtrl.text),
      valorAplicado: _parseDouble(valorCtrl.text),
      quantidade: _parseDouble(qtdCtrl.text),
      precoMedio: _parseDouble(pmCtrl.text),
      dataAporte: _cleanStr(aporteCtrl.text),
      vencimento: _cleanStr(vencCtrl.text),
      rentabilidadeTipo: rentTipoLocal,
      rentabilidadeValor: _parseDouble(rentCtrl.text),
      cdiPctAte10k: _parseDouble(cdiAteCtrl.text),
      cdiPctAcima10k: _parseDouble(cdiAcimaCtrl.text),
      cdiLimiteFaixa: _parseDouble(cdiLimiteCtrl.text),
      contaCorrente: _cleanStr(contaCorrenteCtrl.text),
      considerarFimSemana: considerarFimSemanaLocal,
      considerarFeriados: considerarFeriadosLocal,
      observacoes: _cleanStr(obsCtrl.text),
      ativoFlag: ativoFlagLocal,
    );

    setState(() => _saving = true);
    try {
      await widget.onSave(r);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final safe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.90, // ✅ modal alto
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        value: tipoLocal,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Renda Fixa')),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Renda Variável'),
                          ),
                          DropdownMenuItem(value: 3, child: Text('Cripto')),
                          DropdownMenuItem(value: 4, child: Text('Outros')),
                        ],
                        onChanged: (v) => setState(() => tipoLocal = v ?? 1),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: ativoCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ativo (ex: PETR4, BTC, CDB)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: instCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Instituição',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: catCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor aplicado',
                          hintText: 'Ex: 1500,00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtdCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Quantidade',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: pmCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Preço médio',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: aporteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Data do aporte',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: vencCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Vencimento',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<int>(
                        value: rentTipoLocal,
                        decoration: const InputDecoration(
                          labelText: 'Rentabilidade',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Nenhuma')),
                          DropdownMenuItem(
                            value: 1,
                            child: Text('% (percentual)'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('R\$ (valor)'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('CDI (faixas — até 10k / acima)'),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() => rentTipoLocal = v ?? 0),
                      ),
                      const SizedBox(height: 10),

                      if (rentTipoLocal != 3)
                        TextField(
                          controller: rentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Rentabilidade (valor)',
                            border: OutlineInputBorder(),
                          ),
                        )
                      else ...[
                        Text(
                          'Configuração CDI (faixas): até um limite usa um %, acima usa outro %.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: cdiLimiteCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Limite da faixa (R\$)',
                            hintText: 'Ex: 10000,00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: cdiAteCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '% do CDI (até o limite)',
                                  hintText: 'Ex: 110,00',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: cdiAcimaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '% do CDI (acima do limite)',
                                  hintText: 'Ex: 120,00',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: contaCorrenteCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Conta corrente (opcional)',
                            hintText: 'Ex: Itaú • CC 1234-5',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: considerarFimSemanaLocal,
                          onChanged: (v) =>
                              setState(() => considerarFimSemanaLocal = v),
                          title: const Text('Considerar fim de semana'),
                          subtitle: const Text(
                            'Se desmarcado, rendimento é considerado só em dias úteis.',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: considerarFeriadosLocal,
                          onChanged: (v) =>
                              setState(() => considerarFeriadosLocal = v),
                          title: const Text('Considerar feriados'),
                          subtitle: const Text(
                            'Configuração guardada para o cálculo (quando aplicável).',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      TextField(
                        controller: obsCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: ativoFlagLocal,
                        onChanged: (v) => setState(() => ativoFlagLocal = v),
                        title: const Text('Ativo?'),
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safe),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save),
                    label: Text(_saving ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
