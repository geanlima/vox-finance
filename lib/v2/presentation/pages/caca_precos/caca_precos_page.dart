// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/caca_precos_repository.dart';

/// Resultado do dialog (novo/editar)
class _CacaPrecoEditResult {
  final String produto;
  final String loja;
  final String link;
  final double precoAVista;
  final double precoParcelado;
  final int numParcelas;
  final double valorParcela;
  final double frete;
  final String observacoes;
  final bool escolhido;

  const _CacaPrecoEditResult({
    required this.produto,
    required this.loja,
    required this.link,
    required this.precoAVista,
    required this.precoParcelado,
    required this.numParcelas,
    required this.valorParcela,
    required this.frete,
    required this.observacoes,
    required this.escolhido,
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

class CacaPrecosPage extends StatefulWidget {
  const CacaPrecosPage({super.key});

  @override
  State<CacaPrecosPage> createState() => _CacaPrecosPageState();
}

class _CacaPrecosPageState extends State<CacaPrecosPage> {
  final CacaPrecosRepository _repo = InjectorV2.cacaPrecosRepo;

  bool _loading = true;
  List<CacaPrecoRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final itens = await _repo.listar(); // ORDER BY escolhido DESC, total ASC, id DESC
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _loading = false;
    });
  }

  // ========================= helpers =========================

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  double _parseMoney(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  int _parseInt(String v) => int.tryParse(v.trim()) ?? 0;

  double _totalAVista(double preco, double frete) => (preco + frete);

  double _totalParcelado(double precoParcelado, double frete) =>
      (precoParcelado + frete);

  String _decisaoLabel(bool escolhido) => escolhido ? 'Escolhido' : 'Não escolhido';

  Color _decisaoColor(bool escolhido) => escolhido ? Colors.green : Colors.orange;

  // ========================= dialog =========================

  Future<_CacaPrecoEditResult?> _openEditor({
    required String titulo,
    String produto = '',
    String loja = '',
    String link = '',
    double precoAVista = 0,
    double precoParcelado = 0,
    int numParcelas = 0,
    double valorParcela = 0,
    double frete = 0,
    String observacoes = '',
    bool escolhido = false,
    bool allowEscolhido = true,
  }) async {
    final res = await showDialog<_CacaPrecoEditResult>(
      context: context,
      builder: (dialogContext) {
        final produtoCtrl = TextEditingController(text: produto);
        final lojaCtrl = TextEditingController(text: loja);
        final linkCtrl = TextEditingController(text: link);

        final aVistaCtrl = TextEditingController(
          text: precoAVista.toStringAsFixed(2).replaceAll('.', ','),
        );
        final parceladoCtrl = TextEditingController(
          text: precoParcelado.toStringAsFixed(2).replaceAll('.', ','),
        );
        final numParcelasCtrl = TextEditingController(text: numParcelas.toString());
        final valorParcelaCtrl = TextEditingController(
          text: valorParcela.toStringAsFixed(2).replaceAll('.', ','),
        );
        final freteCtrl = TextEditingController(
          text: frete.toStringAsFixed(2).replaceAll('.', ','),
        );

        final obsCtrl = TextEditingController(text: observacoes);

        bool escolhidoLocal = escolhido;

        return StatefulBuilder(
          builder: (context, setLocal) {
            final aVista = _parseMoney(aVistaCtrl.text);
            final parceladoV = _parseMoney(parceladoCtrl.text);
            final nParc = _parseInt(numParcelasCtrl.text);
            final vParc = _parseMoney(valorParcelaCtrl.text);
            final fr = _parseMoney(freteCtrl.text);

            // se usuário preencher valorParcela + numParcelas, ajuda a sugerir precoParcelado
            final calcParcelado = (nParc > 0 && vParc > 0) ? (nParc * vParc) : parceladoV;

            final totalAVista = _totalAVista(aVista, fr);
            final totalParcelado = _totalParcelado(calcParcelado, fr);

            return AlertDialog(
              title: Text(titulo),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: produtoCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Produto'),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lojaCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Loja'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Link'),
                    ),
                    const SizedBox(height: 14),

                    // Preço à vista
                    TextField(
                      controller: aVistaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço à vista',
                        hintText: 'Ex: 199,90',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Parcelado
                    TextField(
                      controller: parceladoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço parcelado (total)',
                        hintText: 'Ex: 249,90',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: numParcelasCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Nº parcelas',
                              hintText: 'Ex: 10',
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: valorParcelaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Valor parcela',
                              hintText: 'Ex: 24,99',
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: freteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Frete',
                        hintText: 'Ex: 19,90',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),

                    const SizedBox(height: 14),

                    // Totais calculados
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total à vista'),
                              Text(
                                _brl(totalAVista),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total parcelado'),
                              Text(
                                _brl(totalParcelado),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: obsCtrl,
                      decoration: const InputDecoration(labelText: 'Observações'),
                      maxLines: 2,
                    ),

                    if (allowEscolhido) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: escolhidoLocal,
                        onChanged: (v) => setLocal(() => escolhidoLocal = v),
                        title: const Text('Escolhido'),
                      ),
                    ],
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
                    final p = produtoCtrl.text.trim();
                    if (p.isEmpty) return;

                    final aVistaFinal = _parseMoney(aVistaCtrl.text);
                    final frFinal = _parseMoney(freteCtrl.text);

                    final nParcFinal = _parseInt(numParcelasCtrl.text);
                    final vParcFinal = _parseMoney(valorParcelaCtrl.text);

                    final parceladoTotal =
                        (nParcFinal > 0 && vParcFinal > 0)
                            ? (nParcFinal * vParcFinal)
                            : _parseMoney(parceladoCtrl.text);

                    Navigator.of(dialogContext).pop(
                      _CacaPrecoEditResult(
                        produto: p,
                        loja: lojaCtrl.text.trim(),
                        link: linkCtrl.text.trim(),
                        precoAVista: aVistaFinal,
                        precoParcelado: parceladoTotal,
                        numParcelas: nParcFinal,
                        valorParcela: vParcFinal,
                        frete: frFinal,
                        observacoes: obsCtrl.text.trim(),
                        escolhido: escolhidoLocal,
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

    return res;
  }

  // ========================= actions =========================

  Future<void> _add() async {
    final r = await _openEditor(titulo: 'Nova pesquisa de preço');
    if (r == null) return;

    final id = await _repo.inserir(
      produto: r.produto,
      loja: r.loja.isEmpty ? null : r.loja,
      link: r.link.isEmpty ? null : r.link,
      precoAvista: r.precoAVista,
      precoParcelado: r.precoParcelado,
      numParcelas: r.numParcelas,
      valorParcela: r.valorParcela,
      frete: r.frete,
      observacoes: r.observacoes.isEmpty ? null : r.observacoes,
    );

    if (r.escolhido) {
      await _repo.setEscolhido(id, true);
    }

    await _load();
  }

  Future<void> _edit(CacaPrecoRow item) async {
    final r = await _openEditor(
      titulo: 'Editar pesquisa',
      produto: item.produto,
      loja: item.loja ?? '',
      link: item.link ?? '',
      precoAVista: item.precoAvista,
      precoParcelado: item.precoParcelado,
      numParcelas: item.numParcelas,
      valorParcela: item.valorParcela,
      frete: item.frete,
      observacoes: item.observacoes ?? '',
      escolhido: item.escolhido,
    );
    if (r == null) return;

    await _repo.atualizar(
      id: item.id,
      produto: r.produto,
      loja: r.loja.isEmpty ? null : r.loja,
      link: r.link.isEmpty ? null : r.link,
      precoAvista: r.precoAVista,
      precoParcelado: r.precoParcelado,
      numParcelas: r.numParcelas,
      valorParcela: r.valorParcela,
      frete: r.frete,
      observacoes: r.observacoes.isEmpty ? null : r.observacoes,
    );

    await _repo.setEscolhido(item.id, r.escolhido);
    await _load();
  }

  Future<void> _remove(CacaPrecoRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover'),
        content: Text('Remover "${item.produto}"?'),
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

  Future<void> _toggleEscolhido(CacaPrecoRow item) async {
    await _repo.setEscolhido(item.id, !item.escolhido);
    await _load();
  }

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caça aos preços'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty
              ? const Center(child: Text('Nenhuma pesquisa cadastrada'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: _itens.map((item) {
                    final totalAVista = _totalAVista(item.precoAvista, item.frete);
                    final totalParcelado =
                        _totalParcelado(item.precoParcelado, item.frete);

                    final decisaoColor = _decisaoColor(item.escolhido);

                    return Card(
                      child: ListTile(
                        title: Text(
                          item.produto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((item.loja ?? '').isNotEmpty)
                              Text('Loja: ${item.loja}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),

                            if ((item.link ?? '').isNotEmpty)
                              Text('Link: ${item.link}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),

                            const SizedBox(height: 6),
                            Text('Preço à vista: ${_brl(item.precoAvista)}'),
                            Text('Preço parcelado: ${_brl(item.precoParcelado)}'),
                            Text('Frete: ${_brl(item.frete)}'),
                            const SizedBox(height: 6),
                            Text('Total à vista: ${_brl(totalAVista)}'),
                            Text('Total parcelado: ${_brl(totalParcelado)}'),

                            if ((item.observacoes ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Obs: ${item.observacoes}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
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
                                  text: _decisaoLabel(item.escolhido),
                                  color: decisaoColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              IconButton(
                                tooltip: item.escolhido ? 'Desmarcar' : 'Marcar escolhido',
                                onPressed: () => _toggleEscolhido(item),
                                icon: Icon(
                                  item.escolhido ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: decisaoColor,
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
    );
  }
}
