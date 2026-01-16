// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/investimentos_repository.dart';

class _InvestimentoEditResult {
  final int tipo;
  final String? instituicao;
  final String ativo;
  final String? categoria;

  final double valorAplicado;
  final double quantidade;
  final double precoMedio;

  final String? dataAporte; // yyyy-mm-dd (ou seu padrão)
  final String? vencimento;

  final int rentabilidadeTipo; // 0 nenhum / 1 % / 2 valor
  final double rentabilidadeValor;

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
    required this.observacoes,
    required this.ativoFlag,
  });
}

class _ChipTag extends StatelessWidget {
  final String text;
  final Color color;

  const _ChipTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        ),
      ),
    );
  }
}

class InvestimentosPage extends StatefulWidget {
  const InvestimentosPage({super.key});

  @override
  State<InvestimentosPage> createState() => _InvestimentosPageState();
}

class _InvestimentosPageState extends State<InvestimentosPage> {
  final InvestimentosRepository _repo = InjectorV2.investimentosRepo;

  bool _loading = true;
  List<InvestimentoRow> _itens = const [];

  bool _somenteAtivos = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double _parseDouble(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  String? _cleanStr(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Color _tipoColor(int tipo) {
    switch (tipo) {
      case 1:
        return Colors.blue; // Renda fixa
      case 2:
        return Colors.purple; // Ações/FIIs
      case 3:
        return Colors.orange; // Cripto
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
    setState(() => _loading = true);

    final itens = await _repo.listar(); // <- ajuste se seu listar recebe filtro
    if (!mounted) return;

    setState(() {
      _itens =
          _somenteAtivos ? itens.where((e) => e.ativoFlag).toList() : itens;
      _loading = false;
    });
  }

  Future<_InvestimentoEditResult?> _openEditor({
    required String titulo,
    int tipo = 1,
    String? instituicao,
    String ativo = '',
    String? categoria,
    double valorAplicado = 0,
    double quantidade = 0,
    double precoMedio = 0,
    String? dataAporte,
    String? vencimento,
    int rentabilidadeTipo = 0,
    double rentabilidadeValor = 0,
    String? observacoes,
    bool ativoFlag = true,
  }) async {
    return showDialog<_InvestimentoEditResult>(
      context: context,
      builder: (dialogContext) {
        final ativoCtrl = TextEditingController(text: ativo);
        final instCtrl = TextEditingController(text: instituicao ?? '');
        final catCtrl = TextEditingController(text: categoria ?? '');
        final valorCtrl = TextEditingController(text: _num(valorAplicado));
        final qtdCtrl = TextEditingController(text: _num(quantidade));
        final pmCtrl = TextEditingController(text: _num(precoMedio));
        final aporteCtrl = TextEditingController(text: dataAporte ?? '');
        final vencCtrl = TextEditingController(text: vencimento ?? '');
        final rentCtrl = TextEditingController(text: _num(rentabilidadeValor));
        final obsCtrl = TextEditingController(text: observacoes ?? '');

        int tipoLocal = tipo;
        int rentTipoLocal = rentabilidadeTipo;
        bool ativoFlagLocal = ativoFlag;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(titulo),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: tipoLocal,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Renda Fixa')),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Renda Variável'),
                        ),
                        DropdownMenuItem(value: 3, child: Text('Cripto')),
                        DropdownMenuItem(value: 4, child: Text('Outros')),
                      ],
                      onChanged: (v) => setLocal(() => tipoLocal = v ?? 1),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ativoCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ativo (ex: PETR4, BTC, CDB)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: instCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Instituição',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: catCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Categoria'),
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
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtdCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantidade',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: pmCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Preço médio',
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
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Nenhuma')),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('% (percentual)'),
                        ),
                        DropdownMenuItem(value: 2, child: Text('R\$ (valor)')),
                      ],
                      onChanged: (v) => setLocal(() => rentTipoLocal = v ?? 0),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rentabilidade (valor)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: obsCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: ativoFlagLocal,
                      onChanged: (v) => setLocal(() => ativoFlagLocal = v),
                      title: const Text('Ativo?'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final a = ativoCtrl.text.trim();
                    if (a.isEmpty) return;

                    Navigator.of(dialogContext).pop(
                      _InvestimentoEditResult(
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
                        observacoes: _cleanStr(obsCtrl.text),
                        ativoFlag: ativoFlagLocal,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _add() async {
    final r = await _openEditor(titulo: 'Novo investimento');
    if (r == null) return;

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
      observacoes: r.observacoes,
      ativoFlag: r.ativoFlag,
    );

    await _load();
  }

  Future<void> _edit(InvestimentoRow item) async {
    final r = await _openEditor(
      titulo: 'Editar investimento',
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
      observacoes: item.observacoes,
      ativoFlag: item.ativoFlag,
    );
    if (r == null) return;

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
      observacoes: r.observacoes,
      ativoFlag: r.ativoFlag,
    );

    await _load();
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
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _repo.remover(item.id);
      await _load();
    }
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
            child: Row(
              children: [
                Expanded(
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
              ],
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
                    : ListView(
                      padding: const EdgeInsets.all(12),
                      children:
                          _itens.map((item) {
                            final tipoColor = _tipoColor(item.tipo);
                            final statusColor = _statusColor(item.ativoFlag);

                            final sub1 =
                                (item.instituicao ?? '').isNotEmpty
                                    ? 'Instituição: ${item.instituicao}'
                                    : null;

                            final sub2 =
                                'Aplicado: ${_brl(item.valorAplicado)}'
                                '  •  Qtd: ${_num(item.quantidade)}'
                                '  •  PM: ${_brl(item.precoMedio)}';

                            final sub3 =
                                (item.vencimento ?? '').isNotEmpty
                                    ? 'Vencimento: ${item.vencimento}'
                                    : null;

                            return Card(
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(
                                  item.ativo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_tipoLabel(item.tipo)),
                                    if (sub1 != null)
                                      Text(
                                        sub1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      sub2,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (sub3 != null)
                                      Text(
                                        sub3,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: SizedBox(
                                  width: 120,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: _ChipTag(
                                          text: _tipoLabel(item.tipo),
                                          color: tipoColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: _ChipTag(
                                          text: _statusLabel(item.ativoFlag),
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _edit(item),
                                onLongPress: () => _remove(item),
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}
