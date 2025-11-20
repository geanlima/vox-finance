// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _carregarDoBanco();
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

  // ============ FORM ============

  void _abrirFormLancamento({
    Lancamento? existente,
    double? valorInicial,
    String? descricaoInicial,
    FormaPagamento? formaInicial,
    bool? pagamentoFaturaInicial,
  }) {
    final valorController = TextEditingController(
      text:
          existente != null
              ? _currency.format(existente.valor)
              : (valorInicial != null ? _currency.format(valorInicial) : ''),
    );
    final descricaoController = TextEditingController(
      text: existente?.descricao ?? (descricaoInicial ?? ''),
    );

    FormaPagamento? formaSelecionada =
        existente?.formaPagamento ?? (formaInicial ?? FormaPagamento.debito);

    bool pagamentoFatura =
        existente?.pagamentoFatura ?? (pagamentoFaturaInicial ?? false);

    bool pago = existente?.pago ?? true;
    DateTime dataLancamento = existente?.dataHora ?? _dataSelecionada;

    final ehEdicao = existente != null;

    // 👇 Categoria selecionada
    Categoria? categoriaSelecionada = existente?.categoria;
    if (!ehEdicao && categoriaSelecionada == null) {
      // tenta sugerir categoria pela descrição inicial
      final baseDesc = descricaoInicial ?? existente?.descricao ?? '';
      if (baseDesc.trim().isNotEmpty) {
        categoriaSelecionada = CategoriaService.fromDescricao(baseDesc);
      }
    }

    // 👇 controles de parcelamento (somente para NOVO lançamento)
    bool parcelado = false;
    final qtdParcelasController = TextEditingController(text: '2');

    showModalBottomSheet(
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

                    // 👇 Categoria
                    DropdownButtonFormField<Categoria>(
                      value: categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          Categoria.values.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.name,
                              ), // se tiver c.label, pode trocar
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
                      items:
                          FormaPagamento.values.map((f) {
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
                        });
                      },
                    ),

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

                    // ------- PARCELAMENTO (apenas novo lançamento) -------
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
                                  content: Text(
                                    'Selecione a forma de pagamento.',
                                  ),
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

                            final descricao =
                                descricaoController.text.trim().isEmpty
                                    ? 'Sem descrição'
                                    : descricaoController.text.trim();

                            final categoria = categoriaSelecionada!;

                            // monta o objeto base
                            final Lancamento lanc =
                                ehEdicao
                                    ? existente.copyWith(
                                      valor: valor,
                                      descricao: descricao,
                                      formaPagamento: formaSelecionada!,
                                      dataHora: dataLancamento,
                                      pagamentoFatura: pagamentoFatura,
                                      categoria: categoria,
                                      pago: pago,
                                      dataPagamento:
                                          pago
                                              ? (existente.dataPagamento ??
                                                  DateTime.now())
                                              : null,
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
                                    );

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

                              // base para as parcelas: respeita "Já está pago"
                              final base = lanc.copyWith(
                                grupoParcelas: null,
                                parcelaNumero: null,
                                parcelaTotal: null,
                              );

                              await _dbService
                                  .salvarLancamentosParceladosFuturos(
                                    base,
                                    qtd,
                                  );
                            } else {
                              await _dbService.salvarLancamento(lanc);
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

  // ============ RESUMO POR FORMA / DETALHES ============

  void _mostrarResumoPorFormaPagamento() {
    final lancamentosDia =
        _lancamentosDoDia.where((l) => l.pago && !l.pagamentoFatura).toList();

    if (lancamentosDia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há lançamentos nesse dia.')),
      );
      return;
    }

    final Map<FormaPagamento, double> totaisPorForma = {};

    for (final lanc in lancamentosDia) {
      totaisPorForma.update(
        lanc.formaPagamento,
        (valorAtual) => valorAtual + lanc.valor,
        ifAbsent: () => lanc.valor,
      );
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gastos por forma de pagamento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _dateDiaFormat.format(_dataSelecionada),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...totaisPorForma.entries.map((entry) {
                final forma = entry.key;
                final valor = entry.value;

                return ListTile(
                  leading: CircleAvatar(child: Icon(forma.icon)),
                  title: Text(forma.label),
                  trailing: Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
