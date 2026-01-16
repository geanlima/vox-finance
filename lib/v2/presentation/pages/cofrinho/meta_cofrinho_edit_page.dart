import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';

class MetaCofrinhoEditPage extends StatefulWidget {
  final int ano;

  const MetaCofrinhoEditPage({super.key, required this.ano});

  @override
  State<MetaCofrinhoEditPage> createState() => _MetaCofrinhoEditPageState();
}

class _MetaCofrinhoEditPageState extends State<MetaCofrinhoEditPage> {
  final _repo = InjectorV2.cofrinhoRepo;

  final _metaAnoCtrl = TextEditingController();

  double _valorGuardado = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _metaAnoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _repo.seedAnoSeVazio(widget.ano);

    final resumo = await _repo.resumoAno(widget.ano);

    if (resumo != null) {
      _metaAnoCtrl.text = resumo.metaAno
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _valorGuardado = resumo.valorGuardado;
    } else {
      _metaAnoCtrl.text = '0,00';
      _valorGuardado = 0.0;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _salvar() async {
    final metaAno = _parse(_metaAnoCtrl.text);
    final metaMes = metaAno / 12.0;

    for (var mes = 1; mes <= 12; mes++) {
      await _repo.atualizarMetaMes(widget.ano, mes, metaMes);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final metaAno = _parse(_metaAnoCtrl.text);
    final saldo = _valorGuardado - metaAno;

    final double progresso =
        metaAno <= 0.0
            ? 0.0
            : (_valorGuardado / metaAno).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta Cofrinho'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _salvar)],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Ano ${widget.ano}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _metaAnoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Meta do ano',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      // recalcula progresso/saldo ao digitar
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 16),

                  ListTile(
                    title: const Text('Valor guardado'),
                    trailing: Text(
                      _brl(_valorGuardado),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  ListTile(
                    title: const Text('Saldo'),
                    trailing: Text(
                      _brl(saldo),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saldo >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(value: progresso),
                  const SizedBox(height: 6),
                  Text('${(progresso * 100).toStringAsFixed(0)}% concluído'),

                  const SizedBox(height: 24),

                  Chip(
                    label: Text(
                      saldo >= 0 ? '🎯 Meta batida' : '⏳ Em andamento',
                    ),
                    backgroundColor:
                        saldo >= 0
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                  ),
                ],
              ),
    );
  }
}
