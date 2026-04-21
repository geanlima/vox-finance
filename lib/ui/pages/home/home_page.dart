// ignore_for_file: use_build_context_synchronously, deprecated_member_use, no_leading_underscores_for_local_identifiers, unused_local_variable, unused_element, unused_field

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/regra_cartao_parcelado_service.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_service.dart';
import 'package:vox_finance/ui/core/service/regra_outra_compra_parcelada_service.dart';

import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_repository.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_service.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';
import 'package:vox_finance/ui/widgets/resumo_dia_card.dart';
import 'package:vox_finance/ui/widgets/lancamento_list.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/pages/home/models/filtro_detalhe_resumo_home.dart';
import 'package:vox_finance/ui/pages/home/widgets/resumo_gastos_dia_bottom_sheet.dart';

import 'home_ocr.dart';
import 'home_voice.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

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

  final ContaPagarRepository _repositoryContaPagar = ContaPagarRepository();

  late final RegraOutraCompraParceladaService _regraOutraCompra;
  late final RegraCartaoParceladoService _regraCartaoParcelado;

  final _cartaoRepo = CartaoCreditoRepository();

  // 👇 NOVO: serviço de renda (fontes)
  final RendaService _rendaService = RendaService();

  late stt.SpeechToText _speech;
  bool _speechDisponivel = false;

  DateTime _dataSelecionada = DateTime.now();

  // Cartões e contas carregados do banco
  List<CartaoCredito> _cartoes = [];
  List<ContaBancaria> _contas = [];

  // 👇 NOVO: valor diário vindo das fontes de renda
  final RendaRepository _rendaRepository = RendaRepository();
  double _rendaDiaria = 0.0;
  final DespesasFixasService _despesasFixasService = DespesasFixasService();
  List<CartaoCredito> _cartoesFechandoSemFatura = const [];
  bool _aplicouDataInicialDaRota = false;

  DateTime? _readInitialDateFromRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) return null;
    if (args is DateTime) return args;
    if (args is int) return DateTime.fromMillisecondsSinceEpoch(args);
    if (args is Map) {
      final v = args['data'] ?? args['date'] ?? args['initialDate'];
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final ms = int.tryParse(v);
        if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _bootstrap();
    _carregarCartoes();
    _carregarContas();

    // ⬇️ inicializa as regras de pagamento/sincronização
    _regraOutraCompra = RegraOutraCompraParceladaService(
      lancRepo: _repositoryLancamento,
      contaPagarRepo: _repositoryContaPagar,
    );

    _regraCartaoParcelado = RegraCartaoParceladoService(
      lancRepo: _repositoryLancamento,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aplicouDataInicialDaRota) return;
    final dt = _readInitialDateFromRouteArgs();
    if (dt == null) return;

    _aplicouDataInicialDaRota = true;
    _dataSelecionada = DateTime(dt.year, dt.month, dt.day);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _carregarDoBanco();
      await _recalcularAvisoFechamento();
    });
  }

  Future<void> _bootstrap() async {
    await _despesasFixasService.gerarNoMesAtualSeNecessario();
    await _carregarDoBanco();
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
    // 1) Carrega os lançamentos do dia selecionado
    final lista = await _repositoryLancamento.getByDay(_dataSelecionada);

    // 2) Carrega as fontes de renda ativas
    final fontes = await _rendaRepository.listarFontes(apenasAtivas: true);

    // 3) Filtra só as que estão marcadas para entrar no cálculo diário
    final fontesParaDiario =
        fontes.where((f) => f.incluirNaRendaDiaria == true).toList();

    // 4) Descobre quantos dias tem no mês da data selecionada
    final diasMes =
        DateTime(_dataSelecionada.year, _dataSelecionada.month + 1, 0).day;

    // 5) Soma a renda diária de todas as fontes marcadas
    //    Ex: fonte 1 => 2000/30, fonte 2 => 1500/30, etc.
    final rendaDiaria = fontesParaDiario.fold<double>(
      0.0,
      (soma, f) => soma + (f.valorBase / diasMes),
    );

    setState(() {
      _lancamentos
        ..clear()
        ..addAll(lista);
      _rendaDiaria = rendaDiaria;
    });
  }

  Future<void> _carregarCartoes() async {
    final lista = await _repositoryCartaoCredito.getCartoesCredito();
    setState(() {
      _cartoes = lista;
    });
    await _recalcularAvisoFechamento();
  }

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _recalcularAvisoFechamento() async {
    // Aviso só faz sentido quando já carregou cartões
    if (_cartoes.isEmpty) {
      if (!mounted) return;
      setState(() => _cartoesFechandoSemFatura = const []);
      return;
    }

    final diaSel = _dataSelecionada;
    final cartoesFechandoNoDia =
        _cartoes.where((c) {
          final ehCreditoLike =
              c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
          return ehCreditoLike &&
              c.controlaFatura &&
              c.diaFechamento != null &&
              c.diaVencimento != null &&
              c.diaFechamento == diaSel.day;
        }).toList();

    if (cartoesFechandoNoDia.isEmpty) {
      if (!mounted) return;
      setState(() => _cartoesFechandoSemFatura = const []);
      return;
    }

    final db = await _dbService.db;
    final faltando = <CartaoCredito>[];

    for (final c in cartoesFechandoNoDia) {
      final id = c.id;
      final diaVenc = c.diaVencimento;
      if (id == null || diaVenc == null) continue;

      // Vencimento da fatura do mês de fechamento é no mês seguinte.
      final dataVencimento = DateTime(diaSel.year, diaSel.month + 1, diaVenc);
      final rows = await db.query(
        'lancamentos',
        where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?',
        whereArgs: [id, dataVencimento.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isEmpty) {
        faltando.add(c);
      }
    }

    if (!mounted) return;
    setState(() => _cartoesFechandoSemFatura = faltando);
  }

  // --------- totais / filtros ---------

  /// Total de RECEITAS (pagas) do dia vindo APENAS dos lançamentos
  double get _totalReceitaDia {
    return _lancamentos
        .where((l) => l.pago && l.tipoMovimento == TipoMovimento.receita)
        .fold(0.0, (total, l) => total + l.valor);
  }

  /// Total de GASTOS (despesas pagas, excluindo pagamento de fatura)
  double get _totalGastoDia {
    return _lancamentos
        .where(
          (l) =>
              l.pago &&
              !l.pagamentoFatura &&
              l.tipoMovimento == TipoMovimento.despesa,
        )
        .fold(0.0, (total, l) => total + l.valor);
  }

  static bool _ehDespesaDiaSemFatura(Lancamento l) =>
      l.pago &&
      !l.pagamentoFatura &&
      l.tipoMovimento == TipoMovimento.despesa;

  static bool _ehCompraParcelada(Lancamento l) =>
      l.parcelaTotal != null && (l.parcelaTotal ?? 0) > 1;

  /// Parcelas de compras parceladas (parcela_total > 1) no mesmo critério de [_totalGastoDia].
  double get _totalGastoDiaParcelado {
    return _lancamentos
        .where((l) => _ehDespesaDiaSemFatura(l) && _ehCompraParcelada(l))
        .fold(0.0, (total, l) => total + l.valor);
  }

  /// Demais despesas do dia (não parceladas ou parcela única), mesmo critério de [_totalGastoDia].
  double get _totalGastoDiaDemais {
    return _lancamentos
        .where((l) => _ehDespesaDiaSemFatura(l) && !_ehCompraParcelada(l))
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

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lançamento por voz'),
        content: Text(
          'Descrição: ${lancInterpretado.descricao}\n'
          'Valor: ${_currency.format(lancInterpretado.valor)}\n'
          'Forma: ${lancInterpretado.formaPagamento.label}\n\n'
          'Deseja lançar agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lançar agora'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _repositoryLancamento.salvar(lancInterpretado);
      await _carregarDoBanco();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lançamento salvo com sucesso.')),
        );
      }
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
    await _recalcularAvisoFechamento();
  }

  Future<void> _proximoDia() async {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(const Duration(days: 1));
    });
    await _carregarDoBanco();
    await _recalcularAvisoFechamento();
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
      await _recalcularAvisoFechamento();
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

  Future<void> _pagarLancamento(Lancamento lanc) async {
    if (lanc.id == null) return;

    final bool ehCartaoCredito =
        lanc.formaPagamento == FormaPagamento.credito && lanc.idCartao != null;

    // 1) Pergunta antes de pagar
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            ehCartaoCredito && lanc.pagamentoFatura
                ? 'Pagamento de fatura'
                : 'Marcar lançamento como pago',
          ),
          content: Text(
            ehCartaoCredito && lanc.pagamentoFatura
                ? 'Deseja registrar o pagamento desta fatura de '
                    '${_currency.format(lanc.valor)}?'
                : 'Deseja marcar como pago o lançamento de '
                    '${_currency.format(lanc.valor)} (${lanc.descricao})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    // 2) Regras de pagamento – lança em lancamentos + conta_pagar
    await _regraOutraCompra.marcarLancamentoComoPagoSincronizado(lanc, true);

    // 3) Recarrega os lançamentos do dia
    await _carregarDoBanco();
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final lancamentosDia = _lancamentosDoDia;
    final ehHoje = _mesmoDia(_dataSelecionada, DateTime.now());
    final dataFormatada = _dateDiaFormat.format(_dataSelecionada);
    final fechamentoNoDiaSelecionado = _diaSelecionadoEhFechamentoDeAlgumCartao;

    // total de receitas = lançamentos de receita pagos + renda diária das fontes marcadas
    final double totalReceitasComRenda = _totalReceitaDia + _rendaDiaria;
    // Saldo do dia (sem pagamento de fatura nas despesas — mesmo critério de antes)
    final double saldoDoDia = totalReceitasComRenda - _totalGastoDia;

    // 👇 se tiver renda diária > 0, mostramos a linha extra no card
    final String rendaDiariaFormatada =
        _rendaDiaria > 0 ? _currency.format(_rendaDiaria) : '';

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
      drawer: const AppDrawer(currentRoute: '/lancamentos'),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddLancamento,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Botão "Gerar fatura dos cartões" removido:
            // o fluxo agora é feito na manutenção de faturas.
            ResumoDiaCard(
              ehHoje: ehHoje,
              dataFormatada: dataFormatada,
              despesaDoDiaFormatado: _currency.format(_totalGastoDiaDemais),
              comprasParceladasFormatado:
                  _currency.format(_totalGastoDiaParcelado),
              receitaDoDiaFormatado: _currency.format(totalReceitasComRenda),
              totalDoDiaFormatado: _currency.format(saldoDoDia),
              saldoDoDiaNaoNegativo: saldoDoDia >= 0,
              rendaDiariaFormatada: rendaDiariaFormatada,
              totalPagamentoFaturaFormatado: totalPagamentoFaturaFormatado,
              onDiaAnterior: _diaAnterior,
              onProximoDia: _proximoDia,
              onSelecionarData: _selecionarDataNoCalendario,
              onTapDespesaDoDia: () =>
                  _mostrarDetalheResumo(FiltroDetalheResumoHome.despesaAvulsas),
              onTapComprasParceladas: () => _mostrarDetalheResumo(
                FiltroDetalheResumoHome.comprasParceladas,
              ),
              onTapReceitaNoDia: () =>
                  _mostrarDetalheResumo(FiltroDetalheResumoHome.receitasLancadas),
              onTapTotalDoDia: () =>
                  _mostrarDetalheResumo(FiltroDetalheResumoHome.todosGastos),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LancamentoList(
                lancamentos: lancamentosDia,
                currency: _currency,
                dateHoraFormat: _dateHoraFormat,
                onEditar: (l) => _abrirFormLancamento(existente: l),
                onExcluir: _excluirLancamento,
                onPagar: _pagarLancamento,
                onVerItensFatura: _verItensFatura,
              ),
            ),
            if (fechamentoNoDiaSelecionado &&
                _cartoesFechandoSemFatura.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        Navigator.pushNamed(context, '/faturas-salvas'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cartoesFechandoSemFatura.length == 1
                                  ? 'Fechamento hoje: ${_cartoesFechandoSemFatura.first.descricao}'
                                  : 'Fechamento hoje: ${_cartoesFechandoSemFatura.map((c) => c.descricao).join(', ')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'Abrir',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _descricaoComParcela(Lancamento l) {
    if (l.exibirRotuloParcelaNaLista &&
        l.parcelaNumero != null &&
        l.parcelaNumero! > 0) {
      // Ex.: Mercado (1/10)
      return '${l.descricao} (${l.parcelaNumero}/${l.parcelaTotal})';
    }
    return l.descricao;
  }

  Future<void> _mostrarDetalheResumo(FiltroDetalheResumoHome filtro) async {
    await _carregarCartoes();
    await _carregarContas();

    late final List<Lancamento> lista;
    late final String tituloModal;
    late final String rotuloTotal;
    late final ModoListaResumoMovimento modoLista;

    switch (filtro) {
      case FiltroDetalheResumoHome.despesaAvulsas:
        lista =
            _lancamentosDoDia
                .where(
                  (l) =>
                      l.pago &&
                      !l.pagamentoFatura &&
                      l.tipoMovimento == TipoMovimento.despesa &&
                      !_ehCompraParcelada(l),
                )
                .toList();
        tituloModal = 'Despesa do dia — avulsos e à vista';
        rotuloTotal = 'Subtotal';
        modoLista = ModoListaResumoMovimento.apenasDespesas;
        break;
      case FiltroDetalheResumoHome.comprasParceladas:
        lista =
            _lancamentosDoDia
                .where(
                  (l) =>
                      l.pago &&
                      !l.pagamentoFatura &&
                      l.tipoMovimento == TipoMovimento.despesa &&
                      _ehCompraParcelada(l),
                )
                .toList();
        tituloModal = 'Compras parceladas';
        rotuloTotal = 'Subtotal';
        modoLista = ModoListaResumoMovimento.apenasDespesas;
        break;
      case FiltroDetalheResumoHome.receitasLancadas:
        lista =
            _lancamentosDoDia
                .where(
                  (l) => l.pago && l.tipoMovimento == TipoMovimento.receita,
                )
                .toList();
        tituloModal = 'Receitas no dia';
        rotuloTotal = 'Total de receitas';
        modoLista = ModoListaResumoMovimento.apenasReceitas;
        break;
      case FiltroDetalheResumoHome.todosGastos:
        lista =
            _lancamentosDoDia
                .where(
                  (l) =>
                      l.pago &&
                      !l.pagamentoFatura &&
                      l.tipoMovimento == TipoMovimento.despesa,
                )
                .toList();
        tituloModal = 'Gastos detalhados';
        rotuloTotal = 'Total do dia';
        modoLista = ModoListaResumoMovimento.apenasDespesas;
        break;
    }

    if (lista.isEmpty) {
      if (filtro == FiltroDetalheResumoHome.receitasLancadas &&
          _rendaDiaria > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não há receitas lançadas neste dia. O valor do card pode incluir só a renda diária das fontes.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final String msg;
      switch (filtro) {
        case FiltroDetalheResumoHome.despesaAvulsas:
          msg = 'Não há despesas avulsas ou à vista neste dia.';
          break;
        case FiltroDetalheResumoHome.comprasParceladas:
          msg = 'Não há compras parceladas neste dia.';
          break;
        case FiltroDetalheResumoHome.receitasLancadas:
          msg = 'Não há receitas neste dia.';
          break;
        case FiltroDetalheResumoHome.todosGastos:
          msg = 'Não há gastos pagos neste dia para detalhar.';
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ResumoGastosDiaBottomSheet(
          dataSelecionada: _dataSelecionada,
          lancamentos: lista,
          cartoes: _cartoes,
          contas: _contas,
          currency: _currency,
          titulo: tituloModal,
          rotuloTotal: rotuloTotal,
          modoLista: modoLista,
        );
      },
    );
  }

  Future<void> _verItensFatura(Lancamento fatura) async {
    // Busca os itens da fatura no repositório
    final itens = await _cartaoRepo.getLancamentosDaFatura(fatura);

    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum lançamento associado a esta fatura.'),
        ),
      );
      return;
    }

    final parceladas = itens.where(_ehCompraParcelada).toList();
    final doMes = itens.where((l) => !_ehCompraParcelada(l)).toList();
    final totalParceladas =
        parceladas.fold<double>(0.0, (t, l) => t + l.valor);
    final totalDoMes = doMes.fold<double>(0.0, (t, l) => t + l.valor);
    final totalGeral = totalParceladas + totalDoMes;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        Widget cardLancamento(Lancamento lanc) {
          final linhaGrupo = lanc.linhaDetalheGrupoParcela;
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Icon(
                      lanc.formaPagamento.icon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lanc.descricao,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateHoraFormat.format(lanc.dataHora),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Forma de pagamento: '
                          '${lanc.formaPagamento.label.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (linhaGrupo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            linhaGrupo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currency.format(lanc.valor),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          builder: (ctx, scrollController) {
            final safeBottom = MediaQuery.of(ctx).padding.bottom;
            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                  const SizedBox(height: 8),
                  // “pegador” em cima
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    itens.length == 1
                        ? 'Lançamento vinculado'
                        : 'Lançamentos da fatura',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        0,
                        0,
                        0,
                        safeBottom + listExtraScrollEndPadding(),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHighest.withOpacity(0.5),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total da fatura',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        _currency.format(totalGeral),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: cs.primary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Parceladas (${parceladas.length})',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _currency.format(totalParceladas),
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Do mês / à vista (${doMes.length})',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _currency.format(totalDoMes),
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (parceladas.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                            child: Text(
                              'Parceladas',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ...parceladas.expand((l) sync* {
                            yield Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: cardLancamento(l),
                            );
                          }),
                        ],
                        if (doMes.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Text(
                              'Do mês / à vista',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ...doMes.expand((l) sync* {
                            yield Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: cardLancamento(l),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
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
}
