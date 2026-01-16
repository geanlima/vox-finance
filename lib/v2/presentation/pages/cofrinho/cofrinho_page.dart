// ignore_for_file: deprecated_member_use, unused_element

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/cofrinho_repository.dart';

/// ✅ Classe auxiliar (fica aqui em cima, 1 vez só)
class _CofrinhoMesEditResult {
  final double meta;
  final double guardado;
  const _CofrinhoMesEditResult(this.meta, this.guardado);
}

class CofrinhoPage extends StatefulWidget {
  const CofrinhoPage({super.key});

  @override
  State<CofrinhoPage> createState() => _CofrinhoPageState();
}

class _CofrinhoPageState extends State<CofrinhoPage> {
  final _repo = InjectorV2.cofrinhoRepo;

  int _ano = DateTime.now().year;
  bool _loading = true;

  List<CofrinhoMensalRow> _mensal = const [];
  CofrinhoResumoAno? _resumo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    await _repo.seedAnoSeVazio(_ano, metaPadraoMes: 0);
    final mensal = await _repo.listarMensal(_ano);
    final resumo = await _repo.resumoAno(_ano);

    if (!mounted) return;
    setState(() {
      _mensal = mensal;
      _resumo = resumo;
      _loading = false;
    });
  }

  String _mesNome(int mes) {
    const nomes = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return nomes[mes - 1];
  }

  String _brl(double v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }

  double _parseMoney(String v) {
    return double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ??
        0.0;
  }

  String _calcStatus(double meta, double guardado) {
    if (meta <= 0) return 'Aguardando';
    if (guardado <= 0) return 'Aguardando';
    if (guardado >= meta) return 'Meta Batida';
    return 'Não Bati';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Meta Batida':
        return Colors.green;
      case 'Não Bati':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _editarMes(CofrinhoMensalRow m) async {
    double parse(String v) =>
        double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ??
        0.0;

    String calcStatus(double meta, double guardado) {
      if (meta <= 0) return 'Aguardando';
      if (guardado <= 0) return 'Aguardando';
      if (guardado >= meta) return 'Meta Batida';
      return 'Não Bati';
    }

    final result = await showDialog<_CofrinhoMesEditResult>(
      context: context,
      builder: (dialogContext) {
        // ✅ controllers VIVEM só dentro do dialog
        final metaCtrl = TextEditingController(
          text: m.metaMes.toStringAsFixed(2).replaceAll('.', ','),
        );
        final guardadoCtrl = TextEditingController(
          text: m.valorGuardado.toStringAsFixed(2).replaceAll('.', ','),
        );

        return StatefulBuilder(
          builder: (context, setLocal) {
            final meta = parse(metaCtrl.text);
            final guardado = parse(guardadoCtrl.text);
            final saldo = guardado - meta;
            final status = calcStatus(meta, guardado);

            return AlertDialog(
              title: Text('${_mesNome(m.mes)} / ${m.ano}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: metaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Meta do mês',
                        hintText: 'Ex: 1000,00',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guardadoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor guardado (no fim do mês)',
                        hintText: 'Ex: 800,00',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo'),
                        Text(
                          _brl(saldo),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: saldo >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(status),
                        backgroundColor: _statusColor(status).withOpacity(0.15),
                        side: BorderSide(
                          color: _statusColor(status).withOpacity(0.5),
                        ),
                      ),
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
                    final metaFinal = parse(metaCtrl.text);
                    final guardadoFinal = parse(guardadoCtrl.text);

                    Navigator.of(
                      dialogContext,
                    ).pop(_CofrinhoMesEditResult(metaFinal, guardadoFinal));
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await _repo.atualizarMetaMes(m.ano, m.mes, result.meta);
    await _repo.atualizarValorGuardado(m.ano, m.mes, result.guardado);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cofrinho'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ano:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _ano,
                          items: [
                            for (var a = _ano - 1; a <= _ano + 2; a++)
                              DropdownMenuItem(value: a, child: Text('$a')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _ano = v);
                            await _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cofrinho (mensal)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ..._mensal.map((m) {
                      final status = _calcStatus(m.metaMes, m.valorGuardado);
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${_mesNome(m.mes)}  •  Meta: ${_brl(m.metaMes)}',
                          ),
                          subtitle: Text(
                            'Guardado: ${_brl(m.valorGuardado)}  |  Saldo: ${_brl(m.saldo)}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _statusColor(status).withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _editarMes(m),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    const Text(
                      'Meta Cofrinho (anual - resumo)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (resumo != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ano ${resumo.ano}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Meta do ano: ${_brl(resumo.metaAno)}'),
                              Text(
                                'Valor guardado: ${_brl(resumo.valorGuardado)}',
                              ),
                              Text('Saldo: ${_brl(resumo.saldo)}'),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: resumo.progresso),
                              const SizedBox(height: 6),
                              Text(
                                '${(resumo.progresso * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
