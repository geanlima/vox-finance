// ignore_for_file: use_build_context_synchronously, deprecated_member_use, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/widgets/resumo_dia_card.dart';
import 'package:vox_finance/ui/widgets/lancamento_list.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

import 'home_ocr.dart';
import 'home_voice.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _imagePicker = ImagePicker();
  final List<Lancamento> _lancamentos = [];

  final _dbService = DbService();

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHoraFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _dateDiaFormat = DateFormat('dd/MM/yyyy');

  late stt.SpeechToText _speech;
  bool _speechDisponivel = false;

  DateTime _dataSelecionada = DateTime.now();

  // Cartões carregados do banco
  List<CartaoCredito> _cartoes = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _carregarDoBanco();
    _carregarCartoes();
  }

  Future<void> _initSpeech() async {
    _speechDisponivel = await _speech.initialize();
    setState(() {});
  }

  Future<void> _carregarDoBanco() async {
    final lista = await _dbService.getLancamentosByDay(_dataSelecionada);
    setState(() {
      _lancamentos
        ..clear()
        ..addAll(lista);
    });
  }

  Future<void> _carregarCartoes() async {
    final lista = await _dbService.getCartoesCredito();
    setState(() {
      _cartoes = lista;
    });
  }

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --------- totais / filtros ---------

  double get _totalGastoDia {
    return _lancamentos
        .where((l) => l.pago && !l.pagamentoFatura)
        .fold(0.0, (total, l) => total + l.valor);
  }

  double get _totalPagamentoFaturaDia {
    return _lancamentos
        .where((l) => l.pago && l.pagamentoFatura)
        .fold(0.0, (total, l) => total + l.valor);
  }

  List<Lancamento> get _lancamentosDoDia {
    final lista = [..._lancamentos];
    lista.sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return lista;
  }

  // ============================================================
  //  F I L T R A R   C A R T Õ E S   C O N F O R M E   R E G R A
  // ============================================================

  List<CartaoCredito> _filtrarCartoes(
    FormaPagamento? forma,
    bool pagamentoFatura,
  ) {
    // Pagamento de fatura → sempre cartão de CRÉDITO (ou ambos)
    if (pagamentoFatura) {
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    // Lançamento normal
    if (forma == FormaPagamento.debito) {
      // Só cartões de débito ou ambos
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.debito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    if (forma == FormaPagamento.credito) {
      // Só cartões de crédito ou ambos
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    // Outras formas não usam cartão
    return const [];
  }

  bool _cartaoControlaFatura(CartaoCredito? c) {
    if (c == null) return false;
    final ehCreditoLike =
        c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
    return ehCreditoLike &&
        c.controlaFatura &&
        c.diaFechamento != null &&
        c.diaVencimento != null;
  }

  // ============ AÇÕES BÁSICAS ============

  void _onAddLancamento() {
    _abrirFormLancamento();
  }

  Future<void> _abrirLancamentosFuturos() async {
    await Navigator.pushNamed(context, '/lancamentos-futuros');
    await _carregarDoBanco(); // ao voltar, atualiza o dia selecionado
  }

  Future<void> _onMicPressed() async {
    if (!_speechDisponivel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconhecimento de voz não disponível neste aparelho.'),
        ),
      );
      return;
    }

    final texto = await mostrarBottomSheetVoz(
      context: context,
      speech: _speech,
    );

    if (texto == null || texto.isEmpty) return;

    final lancInterpretado = interpretarComandoVoz(texto);
    if (lancInterpretado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não entendi o valor ou forma de pagamento.\n'
            'Tente algo como: "gastei 30 reais no mercado no débito".',
          ),
        ),
      );
      return;
    }

    _abrirFormLancamento(
      valorInicial: lancInterpretado.valor,
      descricaoInicial: lancInterpretado.descricao,
      formaInicial: lancInterpretado.formaPagamento,
      pagamentoFaturaInicial: lancInterpretado.pagamentoFatura,
    );
  }

  Future<void> _scannerComprovante() async {
    final fonte = await escolherFonteImagem(context);
    if (fonte == null) return;

    final resultado = await lerComprovante(
      context: context,
      picker: _imagePicker,
      fonte: fonte,
    );

    if (resultado == null) return;

    if (resultado.valor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não consegui identificar o valor no comprovante. '
            'Preencha manualmente.',
          ),
        ),
      );

      _abrirFormLancamento(
        descricaoInicial: resultado.descricao ?? 'Lançamento via comprovante',
        formaInicial: resultado.forma,
      );
      return;
    }

    _abrirFormLancamento(
      valorInicial: resultado.valor,
      descricaoInicial: resultado.descricao ?? 'Lançamento via comprovante',
      formaInicial: resultado.forma,
    );
  }

  Future<void> _diaAnterior() async {
    setState(() {
      _dataSelecionada = _dataSelecionada.subtract(const Duration(days: 1));
    });
    await _carregarDoBanco();
  }

  Future<void> _proximoDia() async {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(const Duration(days: 1));
    });
    await _carregarDoBanco();
  }

  Future<void> _selecionarDataNoCalendario() async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (novaData != null) {
      setState(() {
        _dataSelecionada = DateTime(
          novaData.year,
          novaData.month,
          novaData.day,
        );
      });
      await _carregarDoBanco();
    }
  }

  // ============ FORM ============

  Future<void> _abrirFormLancamento({
    Lancamento? existente,
    double? valorInicial,
    String? descricaoInicial,
    FormaPagamento? formaInicial,
    bool? pagamentoFaturaInicial,
  }) async {
    // garante que os cartões estão atualizados antes de abrir o form
    await _carregarCartoes();

    final valorController = TextEditingController(
      text: existente != null
          ? _currency.format(existente.valor)
          : (valorInicial != null ? _currency.format(valorInicial) : ''),
    );
    final descricaoController = TextEditingController(
      text: existente?.descricao ?? (descricaoInicial ?? ''),
    );

    FormaPagamento? formaSelecionada =
        existente?.formaPagamento ?? (formaInicial ?? FormaPagamento.credito);

    bool pagamentoFatura =
        existente?.pagamentoFatura ?? (pagamentoFaturaInicial ?? false);

    bool pago = existente?.pago ?? true;
    DateTime dataLancamento = existente?.dataHora ?? _dataSelecionada;

    final ehEdicao = existente != null;

    // Categoria selecionada
    Categoria? categoriaSelecionada = existente?.categoria;
    if (!ehEdicao && categoriaSelecionada == null) {
      final baseDesc = descricaoInicial ?? existente?.descricao ?? '';
      if (baseDesc.trim().isNotEmpty) {
        categoriaSelecionada = CategoriaService.fromDescricao(baseDesc);
      }
    }

    // Parcelamento (somente para NOVO lançamento)
    bool parcelado = false;
    final qtdParcelasController = TextEditingController(text: '2');

    // Cartão selecionado (se já vier do lançamento)
    CartaoCredito? cartaoSelecionado;
    if (existente?.idCartao != null && _cartoes.isNotEmpty) {
      try {
        cartaoSelecionado =
            _cartoes.firstWhere((c) => c.id == existente!.idCartao);
      } catch (_) {
        cartaoSelecionado = null;
      }
    }

    // lista inicial de cartões filtrados
    List<CartaoCredito> cartoesFiltrados =
        _filtrarCartoes(formaSelecionada, pagamentoFatura);

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
              void _recalcularCartoes() {
                cartoesFiltrados =
                    _filtrarCartoes(formaSelecionada, pagamentoFatura);

                // Se o cartão selecionado não estiver mais disponível, limpa
                if (cartaoSelecionado != null &&
                    !cartoesFiltrados
                        .any((c) => c.id == cartaoSelecionado!.id)) {
                  cartaoSelecionado = null;
                }
              }

              // Sempre recalcula no início do build desse frame
              _recalcularCartoes();

              // label do dropdown de cartão, mudando conforme o contexto
              String _labelCartao() {
                if (pagamentoFatura) {
                  return 'Cartão cuja fatura está sendo paga';
                }
                if (formaSelecionada == FormaPagamento.debito) {
                  return 'Cartão de débito';
                }
                if (formaSelecionada == FormaPagamento.credito) {
                  return 'Cartão de crédito';
                }
                return 'Cartão';
              }

              final bool deveMostrarSecaoCartao =
                  pagamentoFatura ||
                  formaSelecionada == FormaPagamento.debito ||
                  formaSelecionada == FormaPagamento.credito;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ehEdicao ? Icons.edit : Icons.add),
                        const SizedBox(width: 8),
                        Text(
                          ehEdicao ? 'Editar lançamento' : 'Novo lançamento',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Valor
                    TextField(
                      controller: valorController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Descrição
                    TextField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex: Mercado, Uber, Almoço...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Categoria
                    DropdownButtonFormField<Categoria>(
                      value: categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: Categoria.values.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(CategoriaService.toName(c)),
                        );
                      }).toList(),
                      onChanged: (nova) {
                        setModalState(() {
                          categoriaSelecionada = nova;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Forma de pagamento
                    DropdownButtonFormField<FormaPagamento>(
                      value: formaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pagamento',
                        border: OutlineInputBorder(),
                      ),
                      items: FormaPagamento.values.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Row(
                            children: [
                              Icon(f.icon, size: 18),
                              const SizedBox(width: 8),
                              Text(f.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (novo) {
                        setModalState(() {
                          formaSelecionada = novo;

                          // Ao mudar forma, recalcula cartões e zera seleção se não fizer mais sentido
                          _recalcularCartoes();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Pagamento de fatura
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pagamento de fatura de cartão'),
                      value: pagamentoFatura,
                      onChanged: (v) {
                        setModalState(() {
                          pagamentoFatura = v ?? false;
                          _recalcularCartoes();
                        });
                      },
                    ),

                    // Seção de cartão (para débito, crédito e/ou pagamento de fatura)
                    if (deveMostrarSecaoCartao) ...[
                      const SizedBox(height: 8),
                      if (_cartoes.isEmpty) ...[
                        const Text(
                          'Nenhum cartão cadastrado.\n'
                          'Cadastre em: Menu → Cartões.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ] else if (cartoesFiltrados.isEmpty) ...[
                        Text(
                          pagamentoFatura
                              ? 'Nenhum cartão de crédito (ou ambos) cadastrado para vincular a fatura.'
                              : 'Nenhum cartão compatível com essa forma de pagamento.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<CartaoCredito>(
                          value: cartaoSelecionado,
                          decoration: InputDecoration(
                            labelText: _labelCartao(),
                            border: const OutlineInputBorder(),
                          ),
                          items: cartoesFiltrados.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            );
                          }).toList(),
                          onChanged: (novoCartao) {
                            setModalState(() {
                              cartaoSelecionado = novoCartao;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    // Já está pago
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Já está pago'),
                      subtitle: const Text(
                        'Desmarque para deixar como lançamento futuro/pendente.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: pago,
                      onChanged: (v) {
                        setModalState(() {
                          pago = v ?? false;
                        });
                      },
                    ),

                    // Parcelamento (apenas novo lançamento)
                    if (!ehEdicao) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Lançamento parcelado?'),
                        value: parcelado,
                        onChanged: (v) {
                          setModalState(() {
                            parcelado = v;
                          });
                        },
                      ),
                      if (parcelado) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: qtdParcelasController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade de parcelas',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),

                    // Data
                    InkWell(
                      onTap: () async {
                        final novaData = await showDatePicker(
                          context: context,
                          initialDate: dataLancamento,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (novaData != null) {
                          setModalState(() {
                            dataLancamento = DateTime(
                              novaData.year,
                              novaData.month,
                              novaData.day,
                              dataLancamento.hour,
                              dataLancamento.minute,
                            );
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Data: ${_dateDiaFormat.format(dataLancamento)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botões
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
                            double? valor;
                            try {
                              valor = CurrencyInputFormatter.parse(
                                valorController.text,
                              );
                            } catch (_) {
                              valor = null;
                            }

                            if (valor == null || valor <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Informe um valor válido.'),
                                ),
                              );
                              return;
                            }

                            if (formaSelecionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Selecione a forma de pagamento.'),
                                ),
                              );
                              return;
                            }

                            if (categoriaSelecionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Selecione a categoria.'),
                                ),
                              );
                              return;
                            }

                            // Recalcula cartões antes da validação final
                            cartoesFiltrados =
                                _filtrarCartoes(formaSelecionada, pagamentoFatura);

                            // Regra de validação:
                            // 1) Se for CRÉDITO normal e existir cartão compatível → obriga escolher
                            // 2) Se for PAGAMENTO DE FATURA e existir cartão de crédito/ambos → obriga escolher
                            final bool temCartaoCompativel =
                                cartoesFiltrados.isNotEmpty;

                            final bool precisaCartao =
                                (formaSelecionada == FormaPagamento.credito &&
                                        temCartaoCompativel &&
                                        !pagamentoFatura) ||
                                    (pagamentoFatura && temCartaoCompativel);

                            if (precisaCartao && cartaoSelecionado == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    pagamentoFatura
                                        ? 'Selecione qual cartão você está pagando a fatura.'
                                        : 'Selecione o cartão de crédito usado.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final descricao =
                                descricaoController.text.trim().isNotEmpty
                                    ? descricaoController.text.trim()
                                    : 'Sem descrição';

                            final categoria = categoriaSelecionada!;

                            // lançamento base (compra / pagamento)
                            final Lancamento lanc = ehEdicao
                                ? existente.copyWith(
                                    valor: valor,
                                    descricao: descricao,
                                    formaPagamento: formaSelecionada!,
                                    dataHora: dataLancamento,
                                    pagamentoFatura: pagamentoFatura,
                                    categoria: categoria,
                                    pago: pago,
                                    dataPagamento: pago
                                        ? (existente.dataPagamento ??
                                            DateTime.now())
                                        : null,
                                    idCartao: cartaoSelecionado?.id,
                                  )
                                : Lancamento(
                                    valor: valor,
                                    descricao: descricao,
                                    formaPagamento: formaSelecionada!,
                                    dataHora: dataLancamento,
                                    pagamentoFatura: pagamentoFatura,
                                    categoria: categoria,
                                    pago: pago,
                                    dataPagamento:
                                        pago ? DateTime.now() : null,
                                    idCartao: cartaoSelecionado?.id,
                                  );

                            final bool ehCredito =
                                formaSelecionada == FormaPagamento.credito;
                            final bool ehCompraCreditoComCartao =
                                !pagamentoFatura &&
                                    !ehEdicao &&
                                    ehCredito &&
                                    cartaoSelecionado != null &&
                                    _cartaoControlaFatura(cartaoSelecionado);

                            // ======== LÓGICA DE SALVAR / PARCELAR ========
                            if (!ehEdicao && parcelado) {
                              final qtd =
                                  int.tryParse(qtdParcelasController.text) ?? 1;

                              if (qtd < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Informe uma quantidade de parcelas maior ou igual a 2.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // base sem info de parcela
                              final base = lanc.copyWith(
                                grupoParcelas: null,
                                parcelaNumero: null,
                                parcelaTotal: null,
                              );

                              if (ehCompraCreditoComCartao) {
                                // 1) REGISTRO DA COMPRA HOJE (valor total)
                                await _dbService.salvarLancamento(base);

                                // 2) LANÇAMENTOS PENDENTES DE FATURA (1 por parcela)
                                final baseFatura = base.copyWith(
                                  pagamentoFatura: true,
                                  pago: false,
                                  dataPagamento: null,
                                );

                                await _dbService
                                    .salvarLancamentosParceladosFuturos(
                                  baseFatura,
                                  qtd,
                                );
                              } else {
                                // comportamento padrão anterior
                                await _dbService
                                    .salvarLancamentosParceladosFuturos(
                                  base,
                                  qtd,
                                );
                              }
                            } else {
                              if (ehCompraCreditoComCartao) {
                                // Crédito à vista com cartão que controla fatura:

                                // 1) REGISTRA COMPRA NA DATA ESCOLHIDA (gasto normal)
                                await _dbService.salvarLancamento(
                                  lanc.copyWith(
                                    pagamentoFatura: false,
                                  ),
                                );

                                // 2) CRIA LANÇAMENTO PENDENTE NA DATA DA FATURA
                                final baseFatura = lanc.copyWith(
                                  pagamentoFatura: true,
                                  pago: false,
                                  dataPagamento: null,
                                );

                                await _dbService
                                    .salvarLancamentoDaFatura(baseFatura);
                              } else {
                                // Demais casos: salva normal
                                await _dbService.salvarLancamento(lanc);
                              }
                            }

                            await _carregarDoBanco();
                            Navigator.pop(context);
                          },
                          child: Text(
                            ehEdicao ? 'Salvar alterações' : 'Salvar',
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

  Future<void> _excluirLancamento(Lancamento lanc) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir lançamento'),
          content: Text(
            'Deseja excluir o lançamento de '
            '${_currency.format(lanc.valor)} (${lanc.descricao})?',
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

    if (confirmar == true && lanc.id != null) {
      await _dbService.deletarLancamento(lanc.id!);
      await _carregarDoBanco();
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final lancamentosDia = _lancamentosDoDia;
    final ehHoje = _mesmoDia(_dataSelecionada, DateTime.now());
    final dataFormatada = _dateDiaFormat.format(_dataSelecionada);

    final totalGastoFormatado = _currency.format(_totalGastoDia);
    final String totalPagamentoFaturaFormatado =
        _totalPagamentoFaturaDia > 0
            ? _currency.format(_totalPagamentoFaturaDia)
            : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoxFinance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            onPressed: _abrirLancamentosFuturos,
            tooltip: 'Lançamentos futuros',
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _onMicPressed,
            tooltip: 'Lançar por voz',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _scannerComprovante,
            tooltip: 'Lançar via comprovante',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/'),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddLancamento,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ResumoDiaCard(
              ehHoje: ehHoje,
              dataFormatada: dataFormatada,
              totalGastoFormatado: totalGastoFormatado,
              totalPagamentoFaturaFormatado: totalPagamentoFaturaFormatado,
              onDiaAnterior: _diaAnterior,
              onProximoDia: _proximoDia,
              onSelecionarData: _selecionarDataNoCalendario,
              onTapTotal: _mostrarResumoPorFormaPagamento,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LancamentoList(
                lancamentos: lancamentosDia,
                currency: _currency,
                dateHoraFormat: _dateHoraFormat,
                onEditar: (l) => _abrirFormLancamento(existente: l),
                onExcluir: _excluirLancamento,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================
  //   NOVO "Gastos detalhados do dia"
  //   (mesmo layout da tela Gráficos)
  // ===========================================
  Future<void> _mostrarResumoPorFormaPagamento() async {
    // somente gastos pagos e que NÃO são pagamento de fatura
    final lancamentosDia =
        _lancamentosDoDia.where((l) => l.pago && !l.pagamentoFatura).toList();

    if (lancamentosDia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há lançamentos nesse dia.')),
      );
      return;
    }

    // garante cartões atualizados
    await _carregarCartoes();

    // ===== AGRUPAMENTOS =====

    final Map<FormaPagamento, double> totaisOutros = {};
    final Map<int?, double> totaisPorCartao = {};

    for (final lanc in lancamentosDia) {
      if (lanc.formaPagamento == FormaPagamento.credito) {
        totaisPorCartao.update(
          lanc.idCartao,
          (v) => v + lanc.valor,
          ifAbsent: () => lanc.valor,
        );
      } else {
        totaisOutros.update(
          lanc.formaPagamento,
          (v) => v + lanc.valor,
          ifAbsent: () => lanc.valor,
        );
      }
    }

    final totalGeral = lancamentosDia.fold<double>(0.0, (a, b) => a + b.valor);

    final tema = Theme.of(context);
    final corPrimaria = tema.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CABEÇALHO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gastos detalhados',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateDiaFormat.format(_dataSelecionada),
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // CARD TOTAL
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: corPrimaria.withOpacity(0.06),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: corPrimaria.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.payments,
                                  color: corPrimaria,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total do dia',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    _currency.format(totalGeral),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Detalhado por forma de pagamento',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: Colors.grey[700],
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  // LISTA
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        // OUTRAS FORMAS
                        if (totaisOutros.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...totaisOutros.entries.map((entry) {
                            final forma = entry.key;
                            final valor = entry.value;

                            return _cardAgrupamentoItem(
                              icone: forma.icon,
                              titulo: forma.label,
                              valor: valor,
                              color: corPrimaria,
                            );
                          }),
                        ],

                        // CARTÕES
                        if (totaisPorCartao.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...totaisPorCartao.entries.map((entry) {
                            final idCartao = entry.key;
                            final valor = entry.value;

                            CartaoCredito? cartao;
                            if (idCartao != null) {
                              try {
                                cartao =
                                    _cartoes.firstWhere((c) => c.id == idCartao);
                              } catch (_) {
                                cartao = null;
                              }
                            }

                            final titulo =
                                cartao?.descricao ?? 'Cartão de crédito';

                            final sub = cartao != null
                                ? '${cartao.bandeira} • **** ${cartao.ultimos4Digitos}'
                                : (idCartao == null
                                    ? 'Sem cartão vinculado'
                                    : 'Cartão (id $idCartao)');

                            return _cardAgrupamentoItem(
                              icone: Icons.credit_card,
                              titulo: titulo,
                              subtitulo: sub,
                              valor: valor,
                              color: corPrimaria,
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================
  //   WIDGET PARA ITENS DO AGRUPAMENTO
  // ===========================================
  Widget _cardAgrupamentoItem({
    required IconData icone,
    required String titulo,
    required double valor,
    required Color color,
    String? subtitulo,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.06),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Text(
            _currency.format(valor),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
