// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  Color _corBandeira(String bandeira) {
    final b = bandeira.toLowerCase();
    if (b.contains('visa')) return Colors.blue.shade700;
    if (b.contains('master')) return Colors.red.shade700;
    if (b.contains('elo')) return Colors.orange.shade700;
    if (b.contains('amex') || b.contains('american')) {
      return Colors.teal.shade700;
    }
    return Colors.grey.shade700;
  }

  IconData _iconeBandeira(String bandeira) {
    final b = bandeira.toLowerCase();
    if (b.contains('visa')) return Icons.credit_card;
    if (b.contains('master')) return Icons.credit_card;
    if (b.contains('elo')) return Icons.credit_card;
    if (b.contains('amex') || b.contains('american')) {
      return Icons.credit_card;
    }
    return Icons.credit_card_outlined;
  }

  Future<void> _abrirForm({CartaoCredito? existente}) async {
    final descricaoCtrl = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final bandeiraCtrl = TextEditingController(text: existente?.bandeira ?? '');
    final ultimos4Ctrl = TextEditingController(
      text: existente?.ultimos4Digitos ?? '',
    );

    // 👇 novos campos (foto + vencimento)
    String? fotoPath = existente?.fotoPath;
    int? diaVencimento = existente?.diaVencimento;

    final ehEdicao = existente != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // ========= ESCOLHER FOTO (CÂMERA OU GALERIA) =========
            Future<void> _escolherFoto() async {
              await showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selecionar foto do cartão',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Tirar foto com a câmera'),
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? imagem = await picker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 1024,
                            );
                            if (imagem != null) {
                              setModalState(() {
                                fotoPath = imagem.path;
                              });
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Escolher da galeria'),
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? imagem = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1024,
                            );
                            if (imagem != null) {
                              setModalState(() {
                                fotoPath = imagem.path;
                              });
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );
            }

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

                    // ================== FOTO DO CARTÃO ==================
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _escolherFoto,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundImage:
                                (fotoPath != null && fotoPath!.isNotEmpty)
                                    ? FileImage(File(fotoPath!))
                                    : null,
                            backgroundColor: Colors.grey.shade200,
                            child:
                                (fotoPath == null || fotoPath!.isEmpty)
                                    ? const Icon(Icons.camera_alt, size: 28)
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Toque para tirar uma foto ou escolher da galeria.\n'
                            'Ela será usada como ícone do cartão.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ================== CAMPOS TEXTO ==================
                    TextField(
                      controller: descricaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cartão',
                        hintText: 'Ex: Itaú Click, Nubank, C6...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bandeiraCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bandeira',
                        hintText: 'Ex: Visa, Master, Elo...',
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
                    const SizedBox(height: 12),

                    // ================== DIA DE VENCIMENTO ==================
                    DropdownButtonFormField<int>(
                      value: diaVencimento,
                      decoration: const InputDecoration(
                        labelText: 'Dia de vencimento',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        31,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          diaVencimento = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'O dia de vencimento ajuda a organizar a fatura e alertas futuros.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Esses dados são usados só para identificar o cartão nos lançamentos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ================== BOTÕES ==================
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

                            if (desc.isEmpty ||
                                band.isEmpty ||
                                ult4.length != 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Preencha nome, bandeira e 4 dígitos.',
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
                              fotoPath: fotoPath,
                              diaVencimento: diaVencimento,
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
            '(${cartao.bandeira} • **** ${cartao.ultimos4Digitos})?\n\n'
            'Lançamentos antigos continuarão existindo, apenas sem o vínculo com este cartão.',
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
    final qtd = _cartoes.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de crédito')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho / resumo
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wallet, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meus cartões',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    qtd == 0
                                        ? 'Nenhum cartão cadastrado ainda.'
                                        : '$qtd cartão(s) cadastrado(s). Toque em um para editar.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Lista
                    Expanded(
                      child:
                          qtd == 0
                              ? const Center(
                                child: Text(
                                  'Você ainda não cadastrou nenhum cartão.\n'
                                  'Use o botão + para adicionar.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                              : ListView.separated(
                                itemCount: _cartoes.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final c = _cartoes[index];
                                  final cor = _corBandeira(c.bandeira);

                                  Widget leading;
                                  if (c.fotoPath != null &&
                                      c.fotoPath!.isNotEmpty) {
                                    leading = CircleAvatar(
                                      radius: 22,
                                      backgroundImage: FileImage(
                                        File(c.fotoPath!),
                                      ),
                                    );
                                  } else {
                                    leading = CircleAvatar(
                                      radius: 22,
                                      backgroundColor: cor.withOpacity(0.15),
                                      foregroundColor: cor,
                                      child: Icon(
                                        _iconeBandeira(c.bandeira),
                                        size: 20,
                                      ),
                                    );
                                  }

                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _abrirForm(existente: c),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            leading,
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.descricao,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${c.bandeira} • **** ${c.ultimos4Digitos}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  if (c.diaVencimento != null)
                                                    Text(
                                                      'Vencimento: dia ${c.diaVencimento}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  tooltip: 'Editar',
                                                  onPressed:
                                                      () => _abrirForm(
                                                        existente: c,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _confirmarExcluir(c),
                                                  tooltip: 'Excluir',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
