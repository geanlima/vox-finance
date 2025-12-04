// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:vox_finance/ui/data/models/fonte_renda.dart';
import 'package:vox_finance/ui/data/models/destino_renda.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_repository.dart';

class DestinosRendaPage extends StatefulWidget {
  final FonteRenda fonte;

  const DestinosRendaPage({super.key, required this.fonte});

  @override
  State<DestinosRendaPage> createState() => _DestinosRendaPageState();
}

class _DestinosRendaPageState extends State<DestinosRendaPage> {
  final _repository = RendaRepository();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _carregando = false;
  List<DestinoRenda> _destinos = [];
  double _percentualTotal = 0.0;

  FonteRenda get fonte => widget.fonte;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final destinos = await _repository.listarDestinosDaFonte(fonte.id!);
    final perc = await _repository.somaPercentuaisDaFonte(fonte.id!);
    setState(() {
      _destinos = destinos;
      _percentualTotal = perc;
      _carregando = false;
    });
  }

  Future<void> _abrirFormDestino({DestinoRenda? existente}) async {
    final nomeController = TextEditingController(text: existente?.nome ?? '');
    final percController = TextEditingController(
      text: existente != null ? existente.percentual.toStringAsFixed(2) : '',
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;

        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existente == null
                      ? 'Novo destino de renda'
                      : 'Editar destino de renda',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do destino',
                    hintText: 'Ex: Investimentos, Reserva, Despesas fixas',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: percController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Percentual (%)',
                    hintText: 'Ex: 30.00',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final nome = nomeController.text.trim();
                        if (nome.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Informe o nome do destino.'),
                            ),
                          );
                          return;
                        }

                        final percStr =
                            percController.text.replaceAll(',', '.').trim();
                        final perc = double.tryParse(percStr);
                        if (perc == null || perc <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Informe um percentual maior que zero.',
                              ),
                            ),
                          );
                          return;
                        }

                        final destino =
                            existente == null
                                ? DestinoRenda(
                                  idFonte: fonte.id!,
                                  nome: nome,
                                  percentual: perc,
                                )
                                : existente.copyWith(
                                  nome: nome,
                                  percentual: perc,
                                );

                        await _repository.salvarDestino(destino);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      await _carregar();
    }
  }

  Future<void> _confirmarExcluir(DestinoRenda destino) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir destino'),
            content: Text('Deseja realmente excluir "${destino.nome}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );

    if (ok == true && destino.id != null) {
      await _repository.deletarDestino(destino.id!);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = fonte.valorBase;
    final valorDistribuido = base * _percentualTotal / 100.0;

    return Scaffold(
      appBar: AppBar(title: Text('Destinos - ${fonte.nome}')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fonte.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Renda base: ${_currency.format(base)}',
                      style: TextStyle(
                        fontSize: 13,
                        // ignore: deprecated_member_use
                        color: colors.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Percentual distribuído: ${_percentualTotal.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valor distribuído: ${_currency.format(valorDistribuido)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _destinos.isEmpty
                    ? const Center(
                      child: Text(
                        'Nenhum destino configurado.',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _destinos.length,
                        itemBuilder: (context, index) {
                          final destino = _destinos[index];
                          final perc = destino.percentual;
                          final valor = base * perc / 100.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Slidable(
                              key: ValueKey(destino.id ?? destino.nome),
                              endActionPane: ActionPane(
                                motion: const StretchMotion(),
                                extentRatio: 0.35,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await _abrirFormDestino(
                                        existente: destino,
                                      );
                                    },
                                    icon: Icons.edit,
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await _confirmarExcluir(destino);
                                    },
                                    icon: Icons.delete,
                                    backgroundColor: colors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                ],
                              ),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            colors.secondaryContainer,
                                        child: Icon(
                                          Icons.tune,
                                          color: colors.onSecondaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    destino.nome,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${perc.toStringAsFixed(2)}%',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Valor: ${_currency.format(valor)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormDestino(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
