// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';

class CartaoCreditoPage extends StatefulWidget {
  const CartaoCreditoPage({super.key});

  @override
  State<CartaoCreditoPage> createState() => _CartaoCreditoPageState();
}

class _CartaoCreditoPageState extends State<CartaoCreditoPage> {
  final _db = DbService();
  List<CartaoCredito> _cartoes = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await _db.getCartoesCredito();
    setState(() {
      _cartoes = lista;
      _carregando = false;
    });
  }

  Future<void> _abrirForm({CartaoCredito? existente}) async {
    final descricaoCtrl = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final bandeiraCtrl = TextEditingController(text: existente?.bandeira ?? '');
    final ultimos4Ctrl = TextEditingController(
      text: existente?.ultimos4Digitos ?? '',
    );

    final ehEdicao = existente != null;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(ehEdicao ? Icons.edit : Icons.credit_card),
                    const SizedBox(width: 8),
                    Text(
                      ehEdicao ? 'Editar cartão' : 'Novo cartão',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descricaoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do cartão',
                    hintText: 'Ex: Nubank, Itaú Gold...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bandeiraCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bandeira',
                    hintText: 'Ex: Visa, MasterCard...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ultimos4Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Últimos 4 dígitos',
                    hintText: 'Ex: 1234',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 4,
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
                        final desc = descricaoCtrl.text.trim();
                        final band = bandeiraCtrl.text.trim();
                        final ult4 = ultimos4Ctrl.text.trim();

                        if (desc.isEmpty || band.isEmpty || ult4.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Preencha descrição, bandeira e 4 dígitos.',
                              ),
                            ),
                          );
                          return;
                        }

                        final cartao = CartaoCredito(
                          id: existente?.id,
                          descricao: desc,
                          bandeira: band,
                          ultimos4Digitos: ult4,
                        );

                        await _db.salvarCartaoCredito(cartao);
                        await _carregar();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(ehEdicao ? 'Salvar' : 'Adicionar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarExcluir(CartaoCredito cartao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cartão'),
          content: Text(
            'Deseja excluir o cartão "${cartao.descricao}" '
            '(${cartao.bandeira} • **** ${cartao.ultimos4Digitos})?',
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

    if (confirmar == true && cartao.id != null) {
      await _db.deletarCartaoCredito(cartao.id!);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de crédito')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _cartoes.isEmpty
              ? const Center(child: Text('Nenhum cartão cadastrado.'))
              : ListView.builder(
                itemCount: _cartoes.length,
                itemBuilder: (context, index) {
                  final c = _cartoes[index];
                  return ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: Text(c.descricao),
                    subtitle: Text('${c.bandeira} • **** ${c.ultimos4Digitos}'),
                    onTap: () => _abrirForm(existente: c),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmarExcluir(c),
                    ),
                  );
                },
              ),
    );
  }
}
