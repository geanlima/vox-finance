// lib/ui/pages/renda/minha_renda_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:vox_finance/ui/data/models/fonte_renda.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_repository.dart';
import 'package:vox_finance/ui/pages/renda/destinos_renda_page.dart';

class MinhaRendaPage extends StatefulWidget {
  static const routeName = '/minha-renda';

  const MinhaRendaPage({super.key});

  @override
  State<MinhaRendaPage> createState() => _MinhaRendaPageState();
}

class _MinhaRendaPageState extends State<MinhaRendaPage> {
  final _rendaRepository = RendaRepository();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _carregandoFontes = false;
  List<FonteRenda> _fontes = [];

  @override
  void initState() {
    super.initState();
    _carregarFontes();
  }

  // =====================================
  // FONTES DE RENDA
  // =====================================

  Future<void> _carregarFontes() async {
    setState(() => _carregandoFontes = true);

    final lista = await _rendaRepository.listarFontes();

    setState(() {
      _fontes = lista;
      _carregandoFontes = false;
    });
  }

  Future<void> _abrirFormFonte({FonteRenda? existente}) async {
    bool fixa = existente?.fixa ?? true;
    bool ativa = existente?.ativa ?? true;

    bool incluirNaRendaDiaria = existente?.incluirNaRendaDiaria ?? false;

    final nomeController = TextEditingController(text: existente?.nome ?? '');
    final valorController = TextEditingController(
      text: existente != null ? existente.valorBase.toStringAsFixed(2) : '',
    );
    final diaController = TextEditingController(
      text: existente?.diaPrevisto?.toString() ?? '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx2, scrollController) {
            final viewInsets = MediaQuery.of(ctx2).viewInsets;

            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx2).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  viewInsets.bottom + 16,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      existente == null
                          ? 'Nova fonte de renda'
                          : 'Editar fonte de renda',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da fonte',
                        hintText: 'Ex: Salário CLT, PJ, Aluguel',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor base mensal',
                        hintText: 'Ex: 3500.00',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Renda fixa (repete todo mês)'),
                      value: fixa,
                      onChanged: (v) {
                        fixa = v;
                        (ctx2 as Element).markNeedsBuild();
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Incluir no cálculo de renda diária'),
                      subtitle: const Text(
                        'Se ligado, entra no total de receitas do dia.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: incluirNaRendaDiaria,
                      onChanged: (v) {
                        incluirNaRendaDiaria = v;
                        (ctx2 as Element).markNeedsBuild();
                      },
                    ),
                    TextField(
                      controller: diaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia previsto (1 a 31) - opcional',
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Ativa'),
                      value: ativa,
                      onChanged: (v) {
                        ativa = v;
                        (ctx2 as Element).markNeedsBuild();
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx2, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final nome = nomeController.text.trim();
                            if (nome.isEmpty) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Informe o nome da fonte de renda.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final valorStr =
                                valorController.text
                                    .replaceAll(',', '.')
                                    .trim();
                            final valor = double.tryParse(valorStr) ?? 0.0;

                            int? diaPrevisto;
                            if (diaController.text.trim().isNotEmpty) {
                              diaPrevisto = int.tryParse(
                                diaController.text.trim(),
                              );
                            }

                            final fonte =
                                existente == null
                                    ? FonteRenda(
                                      nome: nome,
                                      valorBase: valor,
                                      fixa: fixa,
                                      diaPrevisto: diaPrevisto,
                                      ativa: ativa,
                                      incluirNaRendaDiaria:
                                          incluirNaRendaDiaria, // 👈 NOVO
                                    )
                                    : existente.copyWith(
                                      nome: nome,
                                      valorBase: valor,
                                      fixa: fixa,
                                      diaPrevisto: diaPrevisto,
                                      ativa: ativa,
                                      incluirNaRendaDiaria:
                                          incluirNaRendaDiaria, // 👈 NOVO
                                    );

                            await _rendaRepository.salvarFonte(fonte);
                            if (!ctx2.mounted) return;
                            Navigator.pop(ctx2, true);
                          },
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      await _carregarFontes();
    }
  }

  Future<void> _confirmarExcluir(FonteRenda fonte) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir fonte'),
            content: Text('Deseja realmente excluir "${fonte.nome}"?'),
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

    if (ok == true && fonte.id != null) {
      await _rendaRepository.deletarFonte(fonte.id!);
      await _carregarFontes();
    }
  }

  // =====================================
  // LISTA
  // =====================================

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fontes de renda')),

      body:
          _carregandoFontes
              ? const Center(child: CircularProgressIndicator())
              : _fontes.isEmpty
              ? const Center(
                child: Text(
                  'Nenhuma fonte cadastrada.\nCadastre seu salário, renda extra, etc.',
                  textAlign: TextAlign.center,
                ),
              )
              : RefreshIndicator(
                onRefresh: _carregarFontes,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _fontes.length,
                  itemBuilder: (context, index) {
                    final fonte = _fontes[index];
                    final valorLabel = _currency.format(fonte.valorBase);

                    String subtitulo =
                        fonte.fixa ? 'Renda fixa' : 'Renda variável';

                    if (fonte.diaPrevisto != null) {
                      subtitulo += ' • dia ${fonte.diaPrevisto}';
                    }
                    if (!fonte.ativa) {
                      subtitulo += ' • inativa';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Slidable(
                        key: ValueKey(fonte.id ?? fonte.nome),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.35,
                          children: [
                            SlidableAction(
                              onPressed:
                                  (_) async =>
                                      await _abrirFormFonte(existente: fonte),
                              icon: Icons.edit,
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                            SlidableAction(
                              onPressed:
                                  (_) async => await _confirmarExcluir(fonte),
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => DestinosRendaPage(fonte: fonte),
                                ),
                              );
                              await _carregarFontes();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: colors.primary.withOpacity(
                                      0.08,
                                    ),
                                    child: Icon(
                                      Icons.savings,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fonte.nome,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              valorLabel,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitulo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurface.withOpacity(
                                              0.7,
                                            ),
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
                      ),
                    );
                  },
                ),
              ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormFonte(),
        backgroundColor: colors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
