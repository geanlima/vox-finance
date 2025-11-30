// ignore_for_file: use_build_context_synchronously, deprecated_member_use, no_leading_underscores_for_local_identifiers, unused_local_variable, unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';
import 'package:vox_finance/ui/widgets/resumo_dia_card.dart';
import 'package:vox_finance/ui/widgets/lancamento_list.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/pages/home/widgets/resumo_gastos_dia_bottom_sheet.dart';

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
  final LancamentoRepository _repositoryLancamento = LancamentoRepository();
  final CartaoCreditoRepository _repositoryCartaoCredito =
      CartaoCreditoRepository();

  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHoraFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _dateDiaFormat = DateFormat('dd/MM/yyyy');
  final ContaBancariaRepository _repositoryContaBancaria =
      ContaBancariaRepository();

  late stt.SpeechToText _speech;
  bool _speechDisponivel = false;

  DateTime _dataSelecionada = DateTime.now();

  // Cartões carregados do banco
  List<CartaoCredito> _cartoes = [];
  List<ContaBancaria> _contas = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _carregarDoBanco();
    _carregarCartoes();
    _carregarContas();
  }

  Future<void> _carregarContas() async {
    final lista = await _repositoryContaBancaria.getContasBancarias(
      apenasAtivas: true,
    );
    setState(() {
      _contas = lista;
    });
  }

  Future<void> _initSpeech() async {
    _speechDisponivel = await _speech.initialize();
    setState(() {});
  }

  Future<void> _carregarDoBanco() async {
    final lista = await _repositoryLancamento.getByDay(_dataSelecionada);
    setState(() {
      _lancamentos
        ..clear()
        ..addAll(lista);
    });
  }

  Future<void> _carregarCartoes() async {
    final lista = await _repositoryCartaoCredito.getCartoesCredito();
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
  //  R E G R A   P /   M O S T R A R   B O T Ã O   D E   F A T U R A
  //  (usa o DIA SELECIONADO, não o "hoje" do aparelho)
  // ============================================================

  /// Verdadeiro se o DIA SELECIONADO é dia de fechamento
  /// de pelo menos um cartão de crédito que controla fatura.
  bool get _diaSelecionadoEhFechamentoDeAlgumCartao {
    final diaSelecionado = _dataSelecionada.day;

    return _cartoes.any((c) {
      final ehCreditoLike =
          c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;

      return ehCreditoLike &&
          c.controlaFatura &&
          c.diaFechamento != null &&
          c.diaVencimento != null &&
          c.diaFechamento == diaSelecionado;
    });
  }

  Future<void> _gerarFaturasDoDiaSelecionado() async {
    final diaSelecionado = _dataSelecionada;

    final cartoesFechandoNoDia =
        _cartoes.where((c) {
          final ehCreditoLike =
              c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;

          return ehCreditoLike &&
              c.controlaFatura &&
              c.diaFechamento != null &&
              c.diaVencimento != null &&
              c.diaFechamento == diaSelecionado.day;
        }).toList();

    if (cartoesFechandoNoDia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma fatura para gerar nesse dia.')),
      );
      return;
    }

    for (final c in cartoesFechandoNoDia) {
      if (c.id != null) {
        await _repositoryCartaoCredito.gerarFaturaDoCartao(
          c.id!,
          referencia: diaSelecionado,
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fatura(s) gerada(s) com sucesso.')),
    );

    await _carregarDoBanco();
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
    // garante cartões atualizados
    await _carregarCartoes();

    // carrega contas bancárias ativas
    final List<ContaBancaria> contas = await _repositoryContaBancaria
        .getContasBancarias(apenasAtivas: true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return LancamentoFormBottomSheet(
          existente: existente,
          valorInicial: valorInicial,
          descricaoInicial: descricaoInicial,
          formaInicial: formaInicial,
          pagamentoFaturaInicial: pagamentoFaturaInicial,
          dataSelecionada: _dataSelecionada,
          currency: _currency,
          dateDiaFormat: _dateDiaFormat,
          dbService: _dbService,
          cartoes: _cartoes,
          contas: contas,
          onSaved: _carregarDoBanco,
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
      await _repositoryLancamento.deletar(lanc.id!);
      await _carregarDoBanco();
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final lancamentosDia = _lancamentosDoDia;
    final ehHoje = _mesmoDia(_dataSelecionada, DateTime.now());
    final dataFormatada = _dateDiaFormat.format(_dataSelecionada);
    final fechamentoNoDiaSelecionado = _diaSelecionadoEhFechamentoDeAlgumCartao;

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
            if (fechamentoNoDiaSelecionado)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Gerar fatura dos cartões'),
                    onPressed: _gerarFaturasDoDiaSelecionado,
                  ),
                ),
              ),
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

  String _descricaoComParcela(Lancamento l) {
    if (l.parcelaTotal != null &&
        l.parcelaTotal! > 1 &&
        l.parcelaNumero != null &&
        l.parcelaNumero! > 0) {
      // Ex.: Mercado (1/10)
      return '${l.descricao} (${l.parcelaNumero}/${l.parcelaTotal})';
    }
    return l.descricao;
  }

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

    await _carregarCartoes();
    await _carregarContas();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ResumoGastosDiaBottomSheet(
          dataSelecionada: _dataSelecionada,
          lancamentos: lancamentosDia,
          cartoes: _cartoes,
          contas: _contas,
          currency: _currency,
        );
      },
    );
  }
}
