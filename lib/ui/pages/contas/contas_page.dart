// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';

import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';

class ContasPage extends StatefulWidget {
  const ContasPage({super.key});

  @override
  State<ContasPage> createState() => _ContasPageState();
}

class _ContasPageState extends State<ContasPage> {
  final _db = DbService();
  List<ContaBancaria> _contas = [];

  @override
  void initState() {
    super.initState();
    _carregarContas();
  }

  Future<void> _carregarContas() async {
    final lista = await _db.getContasBancarias();
    setState(() {
      _contas = lista;
    });
  }

  Future<void> _abrirForm({ContaBancaria? existente}) async {
    String tipoSelecionado = existente?.tipo ?? 'corrente';
    final descricaoController = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final bancoController = TextEditingController(text: existente?.banco ?? '');
    final agenciaController = TextEditingController(
      text: existente?.agencia ?? '',
    );
    final numeroController = TextEditingController(
      text: existente?.numero ?? '',
    );
    final tipoController = TextEditingController(text: existente?.tipo ?? '');
    bool ativa = existente?.ativa ?? true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(existente == null ? Icons.add : Icons.edit),
                        const SizedBox(width: 8),
                        Text(
                          existente == null
                              ? 'Nova conta bancária'
                              : 'Editar conta bancária',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex.: Nubank, Itaú, Caixa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: bancoController,
                      decoration: const InputDecoration(
                        labelText: 'Banco',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: agenciaController,
                      decoration: const InputDecoration(
                        labelText: 'Agência',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: numeroController,
                      decoration: const InputDecoration(
                        labelText: 'Número da conta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tipo da conta (Corrente / Poupança / Investimento)
                    DropdownButtonFormField<String>(
                      value: tipoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Tipo da conta',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'corrente',
                          child: Text('Conta Corrente'),
                        ),
                        DropdownMenuItem(
                          value: 'poupanca',
                          child: Text('Conta Poupança'),
                        ),
                        DropdownMenuItem(
                          value: 'investimento',
                          child: Text('Conta de Investimento'),
                        ),
                      ],
                      onChanged: (valor) {
                        setModalState(() {
                          tipoSelecionado = valor!;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Conta ativa'),
                      value: ativa,
                      onChanged: (v) {
                        setModalState(() {
                          ativa = v;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final desc = descricaoController.text.trim();
                            if (desc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Informe uma descrição para a conta.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final conta =
                                existente ?? ContaBancaria(descricao: desc);

                            conta
                              ..descricao = desc
                              ..banco =
                                  bancoController.text.trim().isEmpty
                                      ? null
                                      : bancoController.text.trim()
                              ..agencia =
                                  agenciaController.text.trim().isEmpty
                                      ? null
                                      : agenciaController.text.trim()
                              ..numero =
                                  numeroController.text.trim().isEmpty
                                      ? null
                                      : numeroController.text.trim()
                              ..tipo =
                                  tipoController.text.trim().isEmpty
                                      ? null
                                      : tipoController.text.trim()
                              ..ativa = ativa;

                            await _db.salvarContaBancaria(conta);
                            await _carregarContas();
                            Navigator.pop(context);
                          },
                          child: Text(
                            existente == null ? 'Salvar' : 'Salvar alterações',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmarExcluir(ContaBancaria conta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conta'),
          content: Text(
            'Deseja excluir a conta "${conta.descricao}"?\n'
            '⚠ Isso não apaga os lançamentos antigos, apenas a conta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && conta.id != null) {
      await _db.deletarContaBancaria(conta.id!);
      await _carregarContas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas bancárias')),
      drawer: const AppDrawer(currentRoute: '/contas'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _contas.isEmpty
              ? const Center(child: Text('Nenhuma conta cadastrada ainda.'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _contas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = _contas[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.account_balance,
                        color: c.ativa ? Colors.green : Colors.grey,
                      ),
                      title: Text(c.descricao),
                      subtitle: Text(
                        [
                          if (c.banco != null && c.banco!.isNotEmpty) c.banco!,
                          if (c.agencia != null && c.agencia!.isNotEmpty)
                            'Ag. ${c.agencia}',
                          if (c.numero != null && c.numero!.isNotEmpty)
                            'Conta ${c.numero}',
                          if (c.tipo != null && c.tipo!.isNotEmpty) c.tipo!,
                        ].join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!c.ativa)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.pause_circle, size: 18),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _abrirForm(existente: c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _confirmarExcluir(c),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
