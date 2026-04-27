// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/cartao_credito_calendario.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class CartaoCreditoPage extends StatefulWidget {
  const CartaoCreditoPage({super.key});

  @override
  State<CartaoCreditoPage> createState() => _CartaoCreditoPageState();
}

class _CartaoCreditoPageState extends State<CartaoCreditoPage> {
  final CartaoCreditoRepository _repository = CartaoCreditoRepository();

  List<CartaoCredito> _cartoes = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    try {
      final lista = await _repository.getCartoesCredito();

      // se a tela já foi fechada, não tenta mais dar setState
      if (!mounted) return;

      setState(() {
        _cartoes = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _carregando = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar cartões: $e')));
    }
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

  String _tipoCartaoLabel(TipoCartao tipo) {
    switch (tipo) {
      case TipoCartao.credito:
        return 'Crédito';
      case TipoCartao.debito:
        return 'Débito';
      case TipoCartao.ambos:
        return 'Débito/Crédito';
    }
  }

  bool _ehCreditoLike(TipoCartao tipo) {
    // tudo que não for débito puro, consideramos que pode ter fatura
    return tipo == TipoCartao.credito || tipo == TipoCartao.ambos;
  }

  Future<void> _abrirForm({CartaoCredito? existente}) async {
    final descricaoCtrl = TextEditingController(
      text: existente?.descricao ?? '',
    );
    final bandeiraCtrl = TextEditingController(text: existente?.bandeira ?? '');
    final ultimos4Ctrl = TextEditingController(
      text: existente?.ultimos4Digitos ?? '',
    );
    final codigoApiCtrl = TextEditingController(
      text: existente?.codigoCartaoApi ?? '',
    );

    // novos campos
    String? fotoPath = existente?.fotoPath;
    int? diaVencimento = existente?.diaVencimento;
    int? diaFechamento = existente?.diaFechamento;
    double? limite = existente?.limite;

    final limiteCtrl = TextEditingController(
      text: limite != null ? limite.toStringAsFixed(2) : '',
    );

    TipoCartao tipoSelecionado =
        existente?.tipo ?? TipoCartao.credito; // default: crédito
    bool controlaFatura = existente?.controlaFatura ?? true;

    final ehEdicao = existente != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            // ========= ESCOLHER FOTO (CÂMERA OU GALERIA) =========
            Future<void> _escolherFoto() async {
              await showModalBottomSheet(
                context: modalContext,
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

            final bool mostraCamposFatura = _ehCreditoLike(tipoSelecionado);
            final bool precisaDiasObrigatorios =
                mostraCamposFatura && controlaFatura;

            Future<void> _abrirCalendarioMensal() async {
              final idCartao = existente?.id;
              if (idCartao == null) return;

              List<CartaoCreditoCalendario> itens =
                  await _repository.listarCalendarioPorCartao(idCartao);

              await showDialog<void>(
                context: modalContext,
                builder: (ctx) {
                  return StatefulBuilder(
                    builder: (ctx, setSt) {
                      Future<void> recarregar() async {
                        itens = await _repository.listarCalendarioPorCartao(
                          idCartao,
                        );
                        setSt(() {});
                      }

                      Future<void> editarOuAdicionar({
                        CartaoCreditoCalendario? existenteMes,
                      }) async {
                        DateTime ref =
                            existenteMes != null
                                ? DateTime(existenteMes.ano, existenteMes.mes, 1)
                                : DateTime(DateTime.now().year, DateTime.now().month, 1);
                        int diaFech =
                            existenteMes?.diaFechamento ??
                            (existente?.diaFechamento ?? 1);
                        int diaVenc =
                            existenteMes?.diaVencimento ??
                            (existente?.diaVencimento ?? 1);

                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (ctx2) {
                            return StatefulBuilder(
                              builder: (ctx2, set2) {
                                Future<void> pickMes() async {
                                  final d = await showDatePicker(
                                    context: ctx2,
                                    initialDate: ref,
                                    firstDate: DateTime(2000, 1, 1),
                                    lastDate: DateTime(2100, 12, 31),
                                    helpText:
                                        'Escolha uma data do mês desejado',
                                  );
                                  if (d == null) return;
                                  set2(() => ref = DateTime(d.year, d.month, 1));
                                }

                                return AlertDialog(
                                  title: Text(
                                    existenteMes == null
                                        ? 'Adicionar mês'
                                        : 'Editar mês',
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed:
                                            existenteMes == null ? pickMes : null,
                                        icon: const Icon(Icons.calendar_month),
                                        label: Text(
                                          '${ref.month.toString().padLeft(2, '0')}/${ref.year}',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int>(
                                        value: diaFech,
                                        decoration: const InputDecoration(
                                          labelText: 'Dia de fechamento',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: List.generate(
                                          31,
                                          (i) => DropdownMenuItem(
                                            value: i + 1,
                                            child: Text('${i + 1}'),
                                          ),
                                        ),
                                        onChanged: (v) {
                                          if (v == null) return;
                                          set2(() => diaFech = v);
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int>(
                                        value: diaVenc,
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
                                        onChanged: (v) {
                                          if (v == null) return;
                                          set2(() => diaVenc = v);
                                        },
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx2, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx2, true),
                                      child: const Text('Salvar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );

                        if (ok != true) return;

                        await _repository.upsertCalendarioMes(
                          idCartao: idCartao,
                          ano: ref.year,
                          mes: ref.month,
                          diaFechamento: diaFech,
                          diaVencimento: diaVenc,
                        );
                        await recarregar();
                      }

                      return AlertDialog(
                        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.primary
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.calendar_month,
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Calendário do cartão',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Defina fechamento/vencimento por mês. '
                                  'Se um mês não estiver aqui, o app usa o padrão do cartão.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (itens.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.info_outline,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Nenhum mês configurado ainda.\n'
                                          'Toque em “Adicionar” para cadastrar um mês.',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 380,
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: itens.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final it = itens[i];
                                      final periodo =
                                          '${it.mes.toString().padLeft(2, '0')}/${it.ano}';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                          color: Colors.white,
                                        ),
                                        child: Slidable(
                                          key: ValueKey('cal_${it.ano}_${it.mes}'),
                                          startActionPane: ActionPane(
                                            motion: const DrawerMotion(),
                                            extentRatio: 0.25,
                                            children: [
                                              SlidableAction(
                                                onPressed: (_) =>
                                                    editarOuAdicionar(
                                                  existenteMes: it,
                                                ),
                                                backgroundColor:
                                                    Theme.of(ctx)
                                                        .colorScheme
                                                        .primary,
                                                foregroundColor: Colors.white,
                                                icon: Icons.edit,
                                                label: 'Editar',
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ],
                                          ),
                                          endActionPane: ActionPane(
                                            motion: const DrawerMotion(),
                                            extentRatio: 0.25,
                                            children: [
                                              SlidableAction(
                                                onPressed: (_) async {
                                                  final confirmar =
                                                      await showDialog<bool>(
                                                    context: ctx,
                                                    builder: (c3) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                          'Excluir mês',
                                                        ),
                                                        content: Text(
                                                          'Deseja excluir a configuração de $periodo?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                              c3,
                                                              false,
                                                            ),
                                                            child: const Text(
                                                              'Cancelar',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                              c3,
                                                              true,
                                                            ),
                                                            child: const Text(
                                                              'Excluir',
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  if (confirmar != true) return;
                                                  await _repository
                                                      .deletarCalendarioMes(
                                                    idCartao: idCartao,
                                                    ano: it.ano,
                                                    mes: it.mes,
                                                  );
                                                  await recarregar();
                                                },
                                                backgroundColor:
                                                    Colors.red.shade600,
                                                foregroundColor: Colors.white,
                                                icon: Icons.delete_outline,
                                                label: 'Excluir',
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  Icons.event,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      periodo,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      children: [
                                                        Chip(
                                                          label: Text(
                                                            'Fecha dia ${it.diaFechamento}',
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                        Chip(
                                                          label: Text(
                                                            'Vence dia ${it.diaVencimento}',
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => editarOuAdicionar(),
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            Future<void> _regerarFaturasDoCartao() async {
              final idCartao = existente?.id;
              if (idCartao == null) return;

              final bool? regen = await showDialog<bool>(
                context: modalContext,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Regerar parcelas e faturas?'),
                    content: const Text(
                      'Isso recalcula vencimentos em contas a pagar e gera novamente as faturas do cartão.\n\n'
                      'Você pode limitar a um mês e também incluir os meses pagos.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Continuar'),
                      ),
                    ],
                  );
                },
              );
              if (regen != true) return;

              int? anoRef;
              int? mesRef;
              bool incluirPagos = false;

              final tipo = await showDialog<int>(
                context: modalContext,
                builder: (ctx) {
                  int modo = 1; // 1 = todos, 2 = um mês
                  DateTime? escolhido;
                  return StatefulBuilder(
                    builder: (ctx, setSt) {
                      Future<void> pick() async {
                        final agora = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate:
                              escolhido ?? DateTime(agora.year, agora.month, 1),
                          firstDate: DateTime(2000, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                          helpText: 'Selecione uma data do mês desejado',
                        );
                        if (d == null) return;
                        setSt(() => escolhido = d);
                      }

                      final labelMes =
                          escolhido == null
                              ? 'Selecionar mês/ano'
                              : '${escolhido!.month.toString().padLeft(2, '0')}/${escolhido!.year}';

                      return AlertDialog(
                        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.primary
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.refresh,
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Como regerar?',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Escolha o escopo e se deve incluir meses pagos.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.65),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .outlineVariant
                                      .withOpacity(0.6),
                                ),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<int>(
                                    contentPadding: EdgeInsets.zero,
                                    value: 1,
                                    groupValue: modo,
                                    onChanged: (v) =>
                                        setSt(() => modo = v ?? 1),
                                    title: const Text('Todos os meses'),
                                  ),
                                  if (modo == 1)
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Incluir meses pagos'),
                                      subtitle: Text(
                                        'Se o vencimento mudar, o app reabre automaticamente.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      value: incluirPagos,
                                      onChanged: (v) =>
                                          setSt(() => incluirPagos = v),
                                    ),
                                  const Divider(height: 1),
                                  RadioListTile<int>(
                                    contentPadding: EdgeInsets.zero,
                                    value: 2,
                                    groupValue: modo,
                                    onChanged: (v) =>
                                        setSt(() => modo = v ?? 2),
                                    title: const Text('Somente um mês'),
                                  ),
                                  if (modo == 2) ...[
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Incluir mês pago'),
                                      value: incluirPagos,
                                      onChanged: (v) =>
                                          setSt(() => incluirPagos = v),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: pick,
                                        icon:
                                            const Icon(Icons.calendar_month),
                                        label: Text(labelMes),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              if (modo == 2 && escolhido == null) return;
                              if (modo == 2) {
                                anoRef = escolhido!.year;
                                mesRef = escolhido!.month;
                              }
                              Navigator.pop(ctx, modo);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Regerar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              if (tipo == null) return;
              if (!mounted) return;

              // Usa os dias atuais do cartão como fallback (se o mês não tiver calendário).
              await _repository.regerarParcelasEFaturasAoAlterarDatas(
                idCartao: idCartao,
                novoDiaFechamento: diaFechamento,
                novoDiaVencimento: diaVencimento,
                anoReferencia: anoRef,
                mesReferencia: mesRef,
                incluirPagos: incluirPagos,
              );
            }

            final mq = MediaQuery.of(modalContext);
            final viewInsets = mq.viewInsets; // teclado
            final sysPadding = mq.padding; // barra/gestos

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: viewInsets.bottom + sysPadding.bottom,
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (sheetContext, scrollController) {
                    final sheetMq = MediaQuery.of(sheetContext);
                    final sysPadding = sheetMq.padding; // barra/gestos

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          // ---------- CONTEÚDO ROLÁVEL ----------
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // "pegador"
                                  Container(
                                    width: 50,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),

                                  // Título
                                  Row(
                                    children: [
                                      Icon(
                                        ehEdicao
                                            ? Icons.edit
                                            : Icons.credit_card,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        ehEdicao
                                            ? 'Editar cartão'
                                            : 'Novo cartão',
                                        style: Theme.of(
                                          sheetContext,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // ================== SEÇÃO IDENTIFICAÇÃO ==================
                                  Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Identificação',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: _escolherFoto,
                                                child: CircleAvatar(
                                                  radius: 32,
                                                  backgroundImage:
                                                      (fotoPath != null &&
                                                              fotoPath!
                                                                  .isNotEmpty)
                                                          ? FileImage(
                                                            File(fotoPath!),
                                                          )
                                                          : null,
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  child:
                                                      (fotoPath == null ||
                                                              fotoPath!.isEmpty)
                                                          ? const Icon(
                                                            Icons.camera_alt,
                                                            size: 26,
                                                          )
                                                          : null,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Toque para tirar uma foto ou escolher da galeria.\n'
                                                  'Ela será usada como ícone visual do cartão.',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: descricaoCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Nome do cartão',
                                              hintText:
                                                  'Ex: Nubank, Itaú Click...',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: bandeiraCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Bandeira',
                                              hintText:
                                                  'Ex: Visa, Master, Elo...',
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
                                          TextField(
                                            controller: codigoApiCtrl,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Código do cartão na integração (opcional)',
                                              hintText:
                                                  'Identificador do cartão no servidor',
                                              border: OutlineInputBorder(),
                                              helperText:
                                                  'Usado para buscar faturas em Integração.',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<TipoCartao>(
                                            value: tipoSelecionado,
                                            decoration: const InputDecoration(
                                              labelText: 'Tipo do cartão',
                                              border: OutlineInputBorder(),
                                            ),
                                            items:
                                                TipoCartao.values.map((t) {
                                                  return DropdownMenuItem(
                                                    value: t,
                                                    child: Text(
                                                      _tipoCartaoLabel(t),
                                                    ),
                                                  );
                                                }).toList(),
                                            onChanged: (novo) {
                                              if (novo == null) return;
                                              setModalState(() {
                                                tipoSelecionado = novo;

                                                // se virou débito puro, zera/oculta dados de fatura
                                                if (!_ehCreditoLike(
                                                  tipoSelecionado,
                                                )) {
                                                  controlaFatura = false;
                                                  diaFechamento = null;
                                                  diaVencimento = null;
                                                  limiteCtrl.text = '';
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // =============== SEÇÃO FATURA / LIMITE ==================
                                  if (mostraCamposFatura)
                                    Card(
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Fatura e limite',
                                                  style: Theme.of(sheetContext)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    color: Colors.blue.shade50,
                                                  ),
                                                  child: const Text(
                                                    'Crédito',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Essas informações ajudam o app a agrupar lançamentos por fatura e controlar melhor o uso do cartão.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SwitchListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text(
                                                'Controlar fatura neste app',
                                              ),
                                              subtitle: Text(
                                                'Se marcado, o app usa fechamento/vencimento para '
                                                'organizar os lançamentos na fatura.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              value: controlaFatura,
                                              onChanged: (v) {
                                                setModalState(() {
                                                  controlaFatura = v;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 8),

                                            // Limite (sempre opcional)
                                            TextField(
                                              controller: limiteCtrl,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Limite do cartão (opcional)',
                                                hintText: 'Ex: 2500.00',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 12),

                                            // Dia de fechamento
                                            DropdownButtonFormField<int>(
                                              value: diaFechamento,
                                              decoration: InputDecoration(
                                                labelText: 'Dia de fechamento',
                                                border:
                                                    const OutlineInputBorder(),
                                                errorText:
                                                    (precisaDiasObrigatorios &&
                                                            diaFechamento ==
                                                                null)
                                                        ? 'Obrigatório quando controlar fatura'
                                                        : null,
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
                                                  diaFechamento = value;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 12),

                                            // Dia de vencimento
                                            DropdownButtonFormField<int>(
                                              value: diaVencimento,
                                              decoration: InputDecoration(
                                                labelText: 'Dia de vencimento',
                                                border:
                                                    const OutlineInputBorder(),
                                                errorText:
                                                    (precisaDiasObrigatorios &&
                                                            diaVencimento ==
                                                                null)
                                                        ? 'Obrigatório quando controlar fatura'
                                                        : null,
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
                                            if (ehEdicao &&
                                                existente.id != null) ...[
                                              const SizedBox(height: 12),
                                              OutlinedButton.icon(
                                                onPressed: _abrirCalendarioMensal,
                                                icon: const Icon(
                                                  Icons.date_range,
                                                ),
                                                label: const Text(
                                                  'Configurar fechamento/vencimento por mês',
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              FilledButton.icon(
                                                onPressed: _regerarFaturasDoCartao,
                                                icon: const Icon(Icons.refresh),
                                                label: const Text(
                                                  'Regerar parcelas e faturas',
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Se um mês não estiver configurado aqui, o app usa os dias padrão do cartão.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),

                          // ---------- RODAPÉ FIXO COM BOTÕES ----------
                          const Divider(height: 1),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              8 + sysPadding.bottom,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(modalContext),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: Icon(ehEdicao ? Icons.save : Icons.add),
                                  label: Text(
                                    ehEdicao
                                        ? 'Salvar alterações'
                                        : 'Adicionar',
                                  ),
                                  onPressed: () async {
                                    final desc = descricaoCtrl.text.trim();
                                    final band = bandeiraCtrl.text.trim();
                                    final ult4 = ultimos4Ctrl.text.trim();

                                    if (desc.isEmpty ||
                                        band.isEmpty ||
                                        ult4.length != 4) {
                                      ScaffoldMessenger.of(
                                        modalContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Preencha nome, bandeira e 4 dígitos.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final bool ehCreditoLike = _ehCreditoLike(
                                      tipoSelecionado,
                                    );

                                    if (ehCreditoLike && controlaFatura) {
                                      if (diaFechamento == null ||
                                          diaVencimento == null) {
                                        ScaffoldMessenger.of(
                                          modalContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Informe dia de fechamento e dia de vencimento '
                                              'quando marcar "Controlar fatura".',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    double? limiteValor;
                                    if (limiteCtrl.text.trim().isNotEmpty) {
                                      final txt = limiteCtrl.text
                                          .trim()
                                          .replaceAll(',', '.');
                                      limiteValor = double.tryParse(txt);
                                    }

                                    final codigoApi = codigoApiCtrl.text.trim();
                                    final cartao = CartaoCredito(
                                      id: existente?.id,
                                      descricao: desc,
                                      bandeira: band,
                                      ultimos4Digitos: ult4,
                                      fotoPath: fotoPath,
                                      diaVencimento: diaVencimento,
                                      diaFechamento: diaFechamento,
                                      tipo: tipoSelecionado,
                                      controlaFatura:
                                          ehCreditoLike && controlaFatura,
                                      limite: limiteValor,
                                      codigoCartaoApi:
                                          codigoApi.isEmpty ? null : codigoApi,
                                    );

                                    await _repository.salvarCartaoCredito(
                                      cartao,
                                    );
                                    await _carregar();
                                    if (mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
      await _repository.deletarCartaoCredito(cartao.id!);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final qtd = _cartoes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões'),
        actions: const [],
      ),
      drawer: const AppDrawer(currentRoute: '/cartoes-credito'),
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
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
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

                                  final tipoLabel = _tipoCartaoLabel(c.tipo);
                                  final infoFatura = <String>[];
                                  if (c.diaFechamento != null) {
                                    infoFatura.add(
                                      'Fecha dia ${c.diaFechamento.toString()}',
                                    );
                                  }
                                  if (c.diaVencimento != null) {
                                    infoFatura.add(
                                      'Vence dia ${c.diaVencimento.toString()}',
                                    );
                                  }
                                  final faturaTexto =
                                      infoFatura.isEmpty
                                          ? null
                                          : infoFatura.join(' • ');

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
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          c.descricao,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade200,
                                                        ),
                                                        child: Text(
                                                          tipoLabel,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
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
                                                  if (c.codigoCartaoApi !=
                                                          null &&
                                                      c.codigoCartaoApi!
                                                          .trim()
                                                          .isNotEmpty)
                                                    Text(
                                                      'Integração: ${c.codigoCartaoApi}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.teal.shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  if (c.limite != null)
                                                    Text(
                                                      'Limite: R\$ ${c.limite!.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade700,
                                                      ),
                                                    ),
                                                  if (faturaTexto != null)
                                                    Text(
                                                      faturaTexto,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                  if (c.controlaFatura &&
                                                      _ehCreditoLike(c.tipo))
                                                    Text(
                                                      'Controlando fatura neste app',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade700,
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
                                                  tooltip: 'Excluir',
                                                  onPressed:
                                                      () =>
                                                          _confirmarExcluir(c),
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
