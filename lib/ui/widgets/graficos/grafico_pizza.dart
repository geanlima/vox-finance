// ignore_for_file: deprecated_member_use, unreachable_switch_default, no_leading_underscores_for_local_identifiers, unused_local_variable

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

// ⭐ NOVO: categorias personalizadas
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';

enum TipoAgrupamentoPizza { categoria, formaPagamento, dia }

enum PeriodoResumoPizza { mensal, semanal }

/// Grupo para resumo por forma/cartão
class _GrupoFormaPagamento {
  final String label;
  final IconData icon;
  double total;

  _GrupoFormaPagamento({
    required this.label,
    required this.icon,
    required this.total,
  });
}

/// ⭐ NOVO: grupo de categoria (nome + total + cor vinda do banco, se houver)
class _GrupoCategoria {
  final String label; // nome da categoria (tabela ou enum)
  double total;
  Color? corDefinida; // cor vinda do banco (pode ser null)

  _GrupoCategoria({required this.label, required this.total, this.corDefinida});
}

class _GrupoSubcategoria {
  final int? subcategoriaId; // null = sem subcategoria
  final String label;
  double total;

  _GrupoSubcategoria({
    required this.subcategoriaId,
    required this.label,
    required this.total,
  });
}

class GraficoPizzaComponent extends StatefulWidget {
  const GraficoPizzaComponent({
    super.key,
    this.considerarSomentePagos = true,
    this.ignorarPagamentoFatura = true,
    this.periodo = PeriodoResumoPizza.mensal,
  });

  final bool considerarSomentePagos;
  final bool ignorarPagamentoFatura;
  final PeriodoResumoPizza periodo;

  @override
  State<GraficoPizzaComponent> createState() => _GraficoPizzaComponentState();
}

class _GraficoPizzaComponentState extends State<GraficoPizzaComponent> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateHoraFormat = DateFormat('dd/MM HH:mm');
  final _dateDiaFormat = DateFormat('dd/MM');

  // 🔹 Ano / mês selecionados e anos disponíveis
  late int _anoSelecionado;
  int _mesSelecionado = DateTime.now().month;
  late final List<int> _anosDisponiveis;

  DateTime _dataReferenciaSemana = DateTime.now();

  TipoAgrupamentoPizza _tipo = TipoAgrupamentoPizza.categoria;

  bool _carregando = false;
  List<Lancamento> _lancamentos = [];

  // 🔹 Cartões carregados do banco
  List<CartaoCredito> _cartoes = [];

  // 🔹 Contas bancárias carregadas do banco
  List<ContaBancaria> _contas = [];

  // 🔹 Categorias personalizadas carregadas do banco
  final _categoriaRepo = CategoriaPersonalizadaRepository();
  List<CategoriaPersonalizada> _categoriasPersonalizadas = [];

  // 🔹 Subcategorias personalizadas carregadas do banco
  final _subcategoriaRepo = SubcategoriaPersonalizadaRepository();
  List<SubcategoriaPersonalizada> _subcategorias = [];

  final _lancamentoRepo = LancamentoRepository();

  final List<Color> _palette = const [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFFC107),
    Color(0xFFF44336),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFF3F51B5),
    Color(0xFF795548),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF8BC34A),
    Color(0xFF673AB7),
  ];

  final _random = Random(); // ⭐ para cores aleatórias

  Color _colorForIndex(int index) => _palette[index % _palette.length];

  // ⭐ Se tiver cor da categoria → usa
  //   Se não tiver → pega da paleta; se esgotar, gera uma aleatória
  Color _colorForGrupoCategoria(int index, Color? corDefinida) {
    if (corDefinida != null) {
      return corDefinida;
    }

    if (index < _palette.length) {
      return _palette[index];
    }

    // aleatória quando não tiver cor e estourar a paleta
    return Color.fromARGB(
      0xFF,
      _random.nextInt(256),
      _random.nextInt(256),
      _random.nextInt(256),
    );
  }

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _anoSelecionado = agora.year;
    _dataReferenciaSemana = agora;

    // 5 anos para trás + ano atual + 3 anos para frente = 9 anos
    const anosAtras = 5;
    const anosFrente = 3;
    _anosDisponiveis = List<int>.generate(
      anosAtras + anosFrente + 1,
      (i) => agora.year - anosAtras + i,
    );

    _carregarDados();
  }

  DateTime _inicioSemana(DateTime base) {
    // Semana padrão pt_BR: segunda (1) → domingo (7)
    final d = DateTime(base.year, base.month, base.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime _fimSemana(DateTime base) {
    final ini = _inicioSemana(base);
    return DateTime(ini.year, ini.month, ini.day + 6, 23, 59, 59);
  }

  String get _labelPeriodoAtual {
    if (widget.periodo == PeriodoResumoPizza.mensal) {
      return '${_nomeMes(_mesSelecionado)} / $_anoSelecionado';
    }
    final ini = _inicioSemana(_dataReferenciaSemana);
    final fim = _fimSemana(_dataReferenciaSemana);
    final fmt = DateFormat('dd/MM/yyyy');
    return 'Semana ${fmt.format(ini)} - ${fmt.format(fim)}';
  }

  String _nomeMes(int mes) {
    final dt = DateTime(2000, mes, 1);
    final nome = DateFormat.MMMM('pt_BR').format(dt);
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    final DateTime inicio;
    final DateTime fim;
    if (widget.periodo == PeriodoResumoPizza.mensal) {
      inicio = DateTime(_anoSelecionado, _mesSelecionado, 1);
      fim = DateTime(_anoSelecionado, _mesSelecionado + 1, 0, 23, 59, 59);
    } else {
      inicio = _inicioSemana(_dataReferenciaSemana);
      fim = _fimSemana(_dataReferenciaSemana);
    }

    final LancamentoRepository _repositoryLancamento = LancamentoRepository();
    final CartaoCreditoRepository _repositoryCartao = CartaoCreditoRepository();
    final ContaBancariaRepository _repositoryConta = ContaBancariaRepository();

    final lista = await _repositoryLancamento.getDespesasByPeriodo(inicio, fim);
    final cards = await _repositoryCartao.getCartoesCredito();
    final contas = await _repositoryConta.getContasBancarias();

    Iterable<Lancamento> filtrados = lista;

    if (widget.considerarSomentePagos) {
      filtrados = filtrados.where((l) => l.pago);
    }

    if (widget.ignorarPagamentoFatura) {
      filtrados = filtrados.where((l) => !l.pagamentoFatura);
    }

    final lancsFiltrados = filtrados.toList();

    // ⭐ Carrega categorias personalizadas apenas para os tipos usados
    final tiposUsados = lancsFiltrados.map((l) => l.tipoMovimento).toSet();
    final List<CategoriaPersonalizada> cats = [];
    for (final tipo in tiposUsados) {
      try {
        final listaTipo = await _categoriaRepo.listarPorTipo(tipo);
        cats.addAll(listaTipo);
      } catch (_) {
        // se o método não existir / der erro, ignoramos silenciosamente
      }
    }

    // ⭐ Subcategorias (para drill-down no resumo por categoria)
    List<SubcategoriaPersonalizada> subs = const [];
    try {
      subs = await _subcategoriaRepo.listarTodasComCategoriaTipo();
    } catch (_) {
      subs = const [];
    }

    setState(() {
      _lancamentos = lancsFiltrados;
      _cartoes = cards;
      _contas = contas;
      _categoriasPersonalizadas = cats;
      _subcategorias = subs;
      _carregando = false;
    });
  }

  // ======= HELPERS DE CATEGORIA PERSONALIZADA =======

  CategoriaPersonalizada? _categoriaPersPorId(int? id) {
    if (id == null) return null;
    try {
      return _categoriasPersonalizadas.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  int? _categoriaPersonalizadaIdByLabel(String label) {
    try {
      return _categoriasPersonalizadas.firstWhere((c) => c.nome == label).id;
    } catch (_) {
      return null;
    }
  }

  SubcategoriaPersonalizada? _subcategoriaPorId(int? id) {
    if (id == null) return null;
    try {
      return _subcategorias.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Mesmo mapeamento usado ao salvar lançamento na home (enum legado).
  Categoria _categoriaEnumFromNome(String nome) {
    switch (nome) {
      case 'Alimentação':
        return Categoria.alimentacao;
      case 'Educação':
        return Categoria.educacao;
      case 'Família':
        return Categoria.familia;
      case 'Finanças Pessoais':
        return Categoria.financasPessoais;
      case 'Impostos e Taxas':
        return Categoria.impostosETaxas;
      case 'Lazer e Entretenimento':
        return Categoria.lazerEEntretenimento;
      case 'Moradia':
        return Categoria.moradia;
      case 'Presentes e Doações':
        return Categoria.presentesEDoacoes;
      case 'Saúde':
        return Categoria.saude;
      case 'Seguros':
        return Categoria.seguros;
      case 'Tecnologia':
        return Categoria.tecnologia;
      case 'Transporte':
        return Categoria.transporte;
      case 'Vestuário':
        return Categoria.vestuario;
      case 'Outros':
      default:
        return Categoria.outros;
    }
  }

  String _labelCategoriaExibicao(Lancamento l) {
    final catPers = _categoriaPersPorId(l.idCategoriaPersonalizada);
    if (catPers != null) return catPers.nome;
    return CategoriaService.toName(l.categoria);
  }

  Color? _parseCorHex(String? corHex) {
    if (corHex == null) return null;
    var hex = corHex.trim();
    if (hex.isEmpty) return null;

    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;

    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;

    return Color(value);
  }

  // ======= TOTAIS =======

  // 🔹 Média diária considerando TODOS os dias do mês (inclusive sem gasto)
  double get _mediaDiariaMesCalendario {
    final diasNoMes =
        DateTime(_anoSelecionado, _mesSelecionado + 1, 0).day; // último dia

    if (diasNoMes == 0) return 0;

    final totalMes = _totalMes;
    return totalMes / diasNoMes;
  }

  // 🔹 Média de gasto diário considerando apenas os dias que tiveram gasto
  double get _mediaDiariaMes {
    final totaisDia = _totaisPorDia();

    if (totaisDia.isEmpty) return 0;

    final totalMes = totaisDia.values.fold<double>(0.0, (a, b) => a + b);
    final qtdeDiasComGasto = totaisDia.length;

    return qtdeDiasComGasto == 0 ? 0 : totalMes / qtdeDiasComGasto;
  }

  double get _totalMes {
    return _lancamentos.fold<double>(0.0, (acc, l) => acc + l.valor);
  }

  /// Mesma regra da tela de lançamentos: parcela de compra com mais de uma parcela.
  static bool _ehCompraParcelada(Lancamento l) =>
      l.parcelaTotal != null && (l.parcelaTotal ?? 0) > 1;

  /// Soma das parcelas de compras parceladas no mês.
  double get _totalMesParcelado {
    return _lancamentos
        .where(_ehCompraParcelada)
        .fold<double>(0.0, (a, l) => a + l.valor);
  }

  /// Demais despesas do mês (à vista, 1x, fixas, etc.).
  double get _totalMesDemais {
    return _lancamentos
        .where((l) => !_ehCompraParcelada(l))
        .fold<double>(0.0, (a, l) => a + l.valor);
  }

  /// 🔹 Agrupa por categoria considerando:
  /// - se tiver idCategoriaPersonalizada → usa nome + cor da tabela
  /// - senão → usa nome do enum Categoria
  Map<String, _GrupoCategoria> _totaisPorCategoriaAgrupado() {
    final Map<String, _GrupoCategoria> mapa = {};

    for (final l in _lancamentos) {
      String label;
      Color? corDb;

      final catPers = _categoriaPersPorId(l.idCategoriaPersonalizada);
      if (catPers != null) {
        label = catPers.nome;
        corDb = _parseCorHex(catPers.corHex);
      } else {
        // mantém compatibilidade com o enum antigo
        label = CategoriaService.toName(l.categoria);
        corDb = null;
      }

      if (mapa.containsKey(label)) {
        mapa[label]!.total += l.valor;
        if (corDb != null && mapa[label]!.corDefinida == null) {
          mapa[label]!.corDefinida = corDb;
        }
      } else {
        mapa[label] = _GrupoCategoria(
          label: label,
          total: l.valor,
          corDefinida: corDb,
        );
      }
    }

    return mapa;
  }

  /// 🔹 Mapa: label da categoria → lista de lançamentos
  Map<String, List<Lancamento>> _lancamentosPorCategoriaAgrupado() {
    final Map<String, List<Lancamento>> mapa = {};

    for (final l in _lancamentos) {
      String label;

      final catPers = _categoriaPersPorId(l.idCategoriaPersonalizada);
      if (catPers != null) {
        label = catPers.nome;
      } else {
        label = CategoriaService.toName(l.categoria);
      }

      mapa.putIfAbsent(label, () => []).add(l);
    }

    return mapa;
  }

  /// 🔹 Monta o label do grupo:
  /// - Crédito → por cartão (como já era antes)
  /// - Outras formas → por conta + forma pagamento (se tiver conta vinculada)
  String _labelGrupoForma(Lancamento l) {
    // Crédito: mantém a mesma lógica atual
    if (l.formaPagamento == FormaPagamento.credito) {
      CartaoCredito? cartao;
      if (l.idCartao != null) {
        try {
          cartao = _cartoes.firstWhere((c) => c.id == l.idCartao);
        } catch (_) {
          cartao = null;
        }
      }

      if (cartao != null) {
        return '${cartao.descricao} • ${cartao.bandeira} • **** ${cartao.ultimos4Digitos}';
      } else if (l.idCartao == null) {
        return 'Crédito (sem cartão vinculado)';
      } else {
        return 'Crédito (cartão id ${l.idCartao})';
      }
    }

    // Demais formas: tenta detalhar por CONTA
    ContaBancaria? conta;
    if (l.idConta != null) {
      try {
        conta = _contas.firstWhere((c) => c.id == l.idConta);
      } catch (_) {
        conta = null;
      }
    }

    final formaLabel = l.formaPagamento.label;

    if (conta != null) {
      // Ex.: "NuBank • Débito", "Itaú • Pix"
      return '${conta.descricao} • $formaLabel';
    }

    if (l.idConta == null) {
      return '$formaLabel (sem conta vinculada)';
    }

    // fallback se não achou a conta pelo id
    return '$formaLabel (conta id ${l.idConta})';
  }

  /// 🔹 Forma pagamento agrupada:
  /// - Crédito por CARTÃO
  /// - Demais por CONTA + forma (quando tiver conta)
  Map<String, _GrupoFormaPagamento> _totaisPorFormaPagamentoAgrupado() {
    final Map<String, _GrupoFormaPagamento> mapa = {};

    for (final l in _lancamentos) {
      final label = _labelGrupoForma(l);
      final bool isCredito = l.formaPagamento == FormaPagamento.credito;
      final icon = isCredito ? Icons.credit_card : l.formaPagamento.icon;

      if (mapa.containsKey(label)) {
        mapa[label]!.total += l.valor;
      } else {
        mapa[label] = _GrupoFormaPagamento(
          label: label,
          icon: icon,
          total: l.valor,
        );
      }
    }

    return mapa;
  }

  /// 🔹 Mapa: label (forma/cartão/conta) → lista de lançamentos
  Map<String, List<Lancamento>> _lancamentosPorGrupoFormaPagamento() {
    final Map<String, List<Lancamento>> mapa = {};

    for (final l in _lancamentos) {
      final label = _labelGrupoForma(l);
      mapa.putIfAbsent(label, () => []).add(l);
    }

    return mapa;
  }

  // 🔹 Total por dia do mês (cada dia é um "grupo")
  Map<DateTime, double> _totaisPorDia() {
    final Map<DateTime, double> totais = {};
    for (final l in _lancamentos) {
      final d = DateTime(l.dataHora.year, l.dataHora.month, l.dataHora.day);
      totais.update(d, (v) => v + l.valor, ifAbsent: () => l.valor);
    }
    // ordena por dia
    final entries =
        totais.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }

  /// 🔹 Mapa: dia → lista de lançamentos
  Map<DateTime, List<Lancamento>> _lancamentosPorDia() {
    final Map<DateTime, List<Lancamento>> mapa = {};
    for (final l in _lancamentos) {
      final d = DateTime(l.dataHora.year, l.dataHora.month, l.dataHora.day);
      mapa.putIfAbsent(d, () => []).add(l);
    }
    return mapa;
  }

  // ======= DIA MAIOR / MENOR GASTO =======

  DateTime? get _diaMaiorGasto {
    final mapa = _totaisPorDia();
    if (mapa.isEmpty) return null;
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  DateTime? get _diaMenorGasto {
    final mapa = _totaisPorDia();
    if (mapa.isEmpty) return null;
    return mapa.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  double get _valorDiaMaiorGasto {
    final dia = _diaMaiorGasto;
    if (dia == null) return 0;
    return _totaisPorDia()[dia] ?? 0;
  }

  double get _valorDiaMenorGasto {
    final dia = _diaMenorGasto;
    if (dia == null) return 0;
    return _totaisPorDia()[dia] ?? 0;
  }

  /// 🔹 Bottom sheet genérico para um dia (usado pelos cards maior/menor gasto)
  void _mostrarDetalheDoDia(DateTime dia) {
    final dataLancs = _lancamentosPorDia();
    final lancs = dataLancs[dia] ?? const <Lancamento>[];

    if (lancs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há lançamentos nesse dia para detalhar.'),
        ),
      );
      return;
    }

    final diaSoData = DateTime(dia.year, dia.month, dia.day);
    _mostrarDetalheLancamentos(
      titulo: 'Detalhe do dia',
      subtitulo: _dateDiaFormat.format(dia),
      lancamentos: lancs,
      manterNoGrupo: (atual) {
        final d = DateTime(
          atual.dataHora.year,
          atual.dataHora.month,
          atual.dataHora.day,
        );
        return d == diaSoData;
      },
    );
  }

  // ======= GRÁFICO =======

  List<PieChartSectionData> _buildSections() {
    if (_lancamentos.isEmpty) return [];

    if (_tipo == TipoAgrupamentoPizza.categoria) {
      // 🔹 Agora usando categorias da tabela + enum
      final data = _totaisPorCategoriaAgrupado();
      final total = data.values.fold<double>(0.0, (a, b) => a + b.total);
      if (total == 0) return [];

      final entries = data.values.toList();

      return List.generate(entries.length, (i) {
        final grupo = entries[i];
        final valor = grupo.total;
        final percent = (valor / total) * 100;
        final color = _colorForGrupoCategoria(i, grupo.corDefinida);

        return PieChartSectionData(
          value: valor,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 130,
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: color,
        );
      });
    } else if (_tipo == TipoAgrupamentoPizza.formaPagamento) {
      final data = _totaisPorFormaPagamentoAgrupado();
      final total = data.values.fold<double>(0.0, (a, b) => a + b.total);
      if (total == 0) return [];

      final entries = data.values.toList();

      return List.generate(entries.length, (i) {
        final grupo = entries[i];
        final valor = grupo.total;
        final percent = (valor / total) * 100;
        final color = _colorForIndex(i);

        return PieChartSectionData(
          value: valor,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 130,
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: color,
        );
      });
    } else {
      // 🔹 Agrupamento por DIA
      final data = _totaisPorDia();
      final total = data.values.fold<double>(0.0, (a, b) => a + b);
      if (total == 0) return [];

      final entries = data.entries.toList();

      return List.generate(entries.length, (i) {
        final entry = entries[i];
        final valor = entry.value;
        final percent = (valor / total) * 100;
        final color = _colorForIndex(i);

        return PieChartSectionData(
          value: valor,
          title: '${percent.toStringAsFixed(1)}%',
          radius: 130,
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: color,
        );
      });
    }
  }

  // ======= RESUMO POR FORMA (MÊS) =======

  // ======= RESUMO POR FORMA (MÊS) =======
  void _mostrarResumoPorFormaPagamentoMes() {
    if (_lancamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há lançamentos neste mês para detalhar.'),
        ),
      );
      return;
    }

    // resumo e lançamentos por grupo
    final totaisPorGrupo = _totaisPorFormaPagamentoAgrupado();
    final lancsPorGrupo = _lancamentosPorGrupoFormaPagamento();
    final grupos = totaisPorGrupo.values.toList();

    final mesAnoLabel = _labelPeriodoAtual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final tema = Theme.of(context);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cabeçalho
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gastos por forma de pagamento / cartão',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mesAnoLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Lista de cards (rolável)
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: grupos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final grupo = grupos[index];
                        final lancs =
                            lancsPorGrupo[grupo.label] ?? const <Lancamento>[];

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _mostrarDetalheLancamentos(
                              titulo: 'Detalhe por forma / cartão',
                              subtitulo: '${grupo.label} • $_labelPeriodoAtual',
                              lancamentos: lancs,
                              manterNoGrupo: (atual) =>
                                  _labelGrupoForma(atual) == grupo.label,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: tema.colorScheme.surfaceVariant
                                  .withOpacity(0.3),
                            ),
                            child: Row(
                              children: [
                                // ícone
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: tema.colorScheme.primary.withOpacity(
                                      0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    grupo.icon,
                                    size: 18,
                                    color: tema.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // label
                                Expanded(
                                  child: Text(
                                    grupo.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // total
                                Text(
                                  _currency.format(grupo.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
            );
          },
        );
      },
    );
  }

  // ======= DETALHAMENTO (VISUAL NOVO) =======

  void _mostrarDetalheLancamentos({
    required String titulo,
    required String subtitulo,
    required List<Lancamento> lancamentos,
    required bool Function(Lancamento atualizado) manterNoGrupo,
  }) {
    if (lancamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum lançamento para detalhar.')),
      );
      return;
    }

    final itens = List<Lancamento>.from(lancamentos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tema = Theme.of(sheetContext);
        final corPrimaria = tema.colorScheme.primary;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final total = itens.fold<double>(0.0, (a, b) => a + b.valor);

                Future<void> abrirReclassificar(Lancamento l) async {
                  if (l.id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Não é possível reclassificar este lançamento.',
                        ),
                      ),
                    );
                    return;
                  }
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => _ReclassificarLancamentoSheet(
                      lancamento: l,
                      categoriaRepo: _categoriaRepo,
                      subcategoriaRepo: _subcategoriaRepo,
                      lancamentoRepo: _lancamentoRepo,
                      categoriaEnumFromNome: _categoriaEnumFromNome,
                      onSaved: (id) async {
                        await _carregarDados();
                        if (!mounted) return;
                        final fresh = await _lancamentoRepo.getById(id);
                        setSheetState(() {
                          itens.removeWhere((x) => x.id == id);
                          if (fresh != null && manterNoGrupo(fresh)) {
                            itens.add(fresh);
                            itens.sort(
                              (a, b) => b.dataHora.compareTo(a.dataHora),
                            );
                          }
                        });
                      },
                    ),
                  );
                }

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

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: tema.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitulo,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                      Icons.pie_chart_rounded,
                                      color: corPrimaria,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        _currency.format(total),
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
                            const SizedBox(height: 12),
                            Text(
                              'Toque no lançamento para reclassificar',
                              style: tema.textTheme.labelMedium?.copyWith(
                                color: Colors.grey[700],
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: itens.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final l = itens[index];
                            final catPers = _categoriaPersPorId(
                              l.idCategoriaPersonalizada,
                            );
                            final labelCategoria =
                                catPers != null
                                    ? catPers.nome
                                    : CategoriaService.toName(l.categoria);
                            final sub = _subcategoriaPorId(
                              l.idSubcategoriaPersonalizada,
                            );
                            final linhaSub =
                                sub != null ? ' · ${sub.nome}' : '';

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => abrirReclassificar(l),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tema.colorScheme.surfaceVariant
                                        .withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: corPrimaria.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.descricao,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_dateHoraFormat.format(l.dataHora)} • $labelCategoria$linhaSub',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _currency.format(l.valor),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                );
              },
            );
          },
        );
      },
    );
  }

  // ======= DETALHE DO GRÁFICO (BOTTOM SHEET COM LEGENDA) =======

  String _tituloDetalhe() {
    switch (_tipo) {
      case TipoAgrupamentoPizza.categoria:
        return 'Detalhado por categoria';
      case TipoAgrupamentoPizza.formaPagamento:
        return 'Detalhado por forma / cartão';
      case TipoAgrupamentoPizza.dia:
      default:
        return 'Detalhado por dia';
    }
  }

  void _mostrarDetalhamentoGrafico() {
    if (_lancamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem lançamentos neste período para detalhar.'),
        ),
      );
      return;
    }

    final tema = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Widget detalheWidget;

        switch (_tipo) {
          case TipoAgrupamentoPizza.categoria:
            detalheWidget = _buildLegendaCategoria();
            break;
          case TipoAgrupamentoPizza.formaPagamento:
            detalheWidget = _buildLegendaFormaPagamento();
            break;
          case TipoAgrupamentoPizza.dia:
          default:
            detalheWidget = _buildLegendaDia();
            break;
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _tituloDetalhe(),
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_nomeMes(_mesSelecionado)} / $_anoSelecionado',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: detalheWidget,
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

  // ======= BUILD =======

  @override
  Widget build(BuildContext context) {
    final labelMesAno = _labelPeriodoAtual;
    final totalMesFormatado = _currency.format(_totalMes);
    final parceladoMesFormatado = _currency.format(_totalMesParcelado);
    final demaisMesFormatado = _currency.format(_totalMesDemais);
    final mediaDiariaFormatada = _currency.format(_mediaDiariaMes);
    final mediaDiariaMesCalendarioFormatada = _currency.format(
      _mediaDiariaMesCalendario,
    );

    final diaMaior = _diaMaiorGasto;
    final diaMenor = _diaMenorGasto;
    final valorMaior = _valorDiaMaiorGasto;
    final valorMenor = _valorDiaMenorGasto;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ====== LINHA 1: PERÍODO ======
                if (widget.periodo == PeriodoResumoPizza.mensal)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _mesSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Mês',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: List.generate(12, (i) {
                            final mes = i + 1;
                            return DropdownMenuItem(
                              value: mes,
                              child: Text(_nomeMes(mes)),
                            );
                          }),
                          onChanged: (novoMes) {
                            if (novoMes == null) return;
                            setState(() {
                              _mesSelecionado = novoMes;
                            });
                            _carregarDados();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _anoSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Ano',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items:
                              _anosDisponiveis
                                  .map(
                                    (ano) => DropdownMenuItem(
                                      value: ano,
                                      child: Text(ano.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (novoAno) {
                            if (novoAno == null) return;
                            setState(() {
                              _anoSelecionado = novoAno;
                            });
                            _carregarDados();
                          },
                        ),
                      ),
                    ],
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Semana',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: InkWell(
                      onTap: () async {
                        final base = _dataReferenciaSemana;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: base,
                          firstDate: DateTime(base.year - 5),
                          lastDate: DateTime(base.year + 5),
                        );
                        if (picked == null) return;
                        setState(() => _dataReferenciaSemana = picked);
                        _carregarDados();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(_labelPeriodoAtual)),
                            const Icon(Icons.calendar_today_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // ====== LINHA 2: TIPO (AGRUPAR POR) ======
                DropdownButtonFormField<TipoAgrupamentoPizza>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Agrupar por',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TipoAgrupamentoPizza.categoria,
                      child: Text('Categoria'),
                    ),
                    DropdownMenuItem(
                      value: TipoAgrupamentoPizza.formaPagamento,
                      child: Text('Forma pgto / Cartão'),
                    ),
                    DropdownMenuItem(
                      value: TipoAgrupamentoPizza.dia,
                      child: Text('Dia'),
                    ),
                  ],
                  onChanged: (novo) {
                    if (novo == null) return;
                    setState(() {
                      _tipo = novo;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // MÊS / ANO
                Text(
                  labelMesAno,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // ====== TOTAL GASTO NO MÊS (CLICÁVEL) ======
                InkWell(
                  onTap: _mostrarResumoPorFormaPagamentoMes,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.08),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.summarize,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Total gasto no mês:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          totalMesFormatado,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Composição: parcelado x demais — dois cards (mesmo padrão do "Total gasto no mês")
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Compras parceladas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        parceladoMesFormatado,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Demais gastos no mês',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        demaisMesFormatado,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 🔹 MÉDIA DIÁRIA (todos os dias do mês)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.06),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // 🔥 alinha verticalmente
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),

                      const SizedBox(width: 8),

                      const Expanded(
                        // 🔥 evita estourar e mantém alinhamento perfeito
                        child: Text(
                          'Média diária:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      Text(
                        mediaDiariaMesCalendarioFormatada,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ====== MÉDIA DIÁRIA COM GASTOS======
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.06),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timeline,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Média diária (dias com gasto):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          mediaDiariaFormatada,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ====== DIA QUE GASTEI MAIS / MENOS (MESMA LINHA) ======
                if (diaMaior != null || diaMenor != null) ...[
                  Row(
                    children: [
                      if (diaMaior != null)
                        Expanded(
                          child: _buildCardDiaExtremo(
                            titulo: 'Maior Gasto',
                            dia: diaMaior,
                            valor: valorMaior,
                            cor: Colors.redAccent,
                            icon: Icons.trending_up,
                            onTap: () => _mostrarDetalheDoDia(diaMaior),
                          ),
                        ),
                      if (diaMaior != null && diaMenor != null)
                        const SizedBox(width: 8),
                      if (diaMenor != null)
                        Expanded(
                          child: _buildCardDiaExtremo(
                            titulo: 'Menor Gasto',
                            dia: diaMenor,
                            valor: valorMenor,
                            cor: Colors.blueAccent,
                            icon: Icons.trending_down,
                            onTap: () => _mostrarDetalheDoDia(diaMenor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (_carregando)
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_lancamentos.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text('Sem lançamentos neste período.'),
                    ),
                  )
                else ...[
                  // Card com o gráfico – maior e clicável
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _mostrarDetalhamentoGrafico,
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 260, // gráfico maior
                          child: PieChart(
                            PieChartData(
                              sections: _buildSections(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Toque no gráfico para ver o detalhamento',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ======= LEGENDAS – VISUAL EM CARD =======

  Widget _buildLegendaCategoria() {
    final data = _totaisPorCategoriaAgrupado();
    final dataLancs = _lancamentosPorCategoriaAgrupado();
    final total = data.values.fold<double>(0.0, (a, b) => a + b.total);
    final entries = data.values.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final grupo = entries[index];
        final valor = grupo.total;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForGrupoCategoria(index, grupo.corDefinida);
        final lancs = dataLancs[grupo.label] ?? const <Lancamento>[];
        final categoriaId = _categoriaPersonalizadaIdByLabel(grupo.label);
        final temSubcategoriasNoBanco =
            categoriaId != null &&
            _subcategorias.any((s) => s.idCategoriaPersonalizada == categoriaId);
        final temSubcategoriaNoLancamento =
            lancs.any((l) => l.idSubcategoriaPersonalizada != null);
        final podeDetalharPorSubcategoria =
            (temSubcategoriasNoBanco || temSubcategoriaNoLancamento) &&
            categoriaId != null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (podeDetalharPorSubcategoria) {
                _mostrarSubcategoriasDaCategoria(
                  tituloCategoria: grupo.label,
                  categoriaId: categoriaId,
                  lancamentosDaCategoria: lancs,
                );
              } else {
                _mostrarDetalheLancamentos(
                  titulo: 'Detalhe por categoria',
                  subtitulo: '${grupo.label} • $_labelPeriodoAtual',
                  lancamentos: lancs,
                  manterNoGrupo: (atual) =>
                      _labelCategoriaExibicao(atual) == grupo.label,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.label,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(valor),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (podeDetalharPorSubcategoria) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarSubcategoriasDaCategoria({
    required String tituloCategoria,
    required int categoriaId,
    required List<Lancamento> lancamentosDaCategoria,
  }) {
    final Map<String, _GrupoSubcategoria> mapa = {};

    for (final l in lancamentosDaCategoria) {
      final subId = l.idSubcategoriaPersonalizada;
      final sub = _subcategoriaPorId(subId);

      final label = sub?.nome ?? 'Sem subcategoria';
      final key = '${subId ?? 0}|$label';

      if (mapa.containsKey(key)) {
        mapa[key]!.total += l.valor;
      } else {
        mapa[key] = _GrupoSubcategoria(
          subcategoriaId: subId,
          label: label,
          total: l.valor,
        );
      }
    }

    final entries = mapa.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final total = entries.fold<double>(0.0, (acc, g) => acc + g.total);

    final mesAno = _labelPeriodoAtual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final tema = Theme.of(context);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subcategorias',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$tituloCategoria • $mesAno',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final g = entries[index];
                        final percent = total == 0 ? 0 : (g.total / total) * 100;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final filtrados =
                                lancamentosDaCategoria.where((l) {
                                  if (g.subcategoriaId == null) {
                                    return l.idSubcategoriaPersonalizada == null;
                                  }
                                  return l.idSubcategoriaPersonalizada ==
                                      g.subcategoriaId;
                                }).toList();

                            _mostrarDetalheLancamentos(
                              titulo: 'Detalhe por subcategoria',
                              subtitulo: '${g.label} • $tituloCategoria • $mesAno',
                              lancamentos: filtrados,
                              manterNoGrupo: (atual) {
                                if (atual.idCategoriaPersonalizada !=
                                    categoriaId) {
                                  return false;
                                }
                                if (g.subcategoriaId == null) {
                                  return atual.idSubcategoriaPersonalizada ==
                                      null;
                                }
                                return atual.idSubcategoriaPersonalizada ==
                                    g.subcategoriaId;
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: tema.colorScheme.surfaceVariant.withOpacity(
                                0.3,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_tree_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${percent.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currency.format(g.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
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

  Widget _buildLegendaFormaPagamento() {
    final dataResumo = _totaisPorFormaPagamentoAgrupado();
    final dataLancs = _lancamentosPorGrupoFormaPagamento();
    final total = dataResumo.values.fold<double>(0.0, (a, b) => a + b.total);
    final entries = dataResumo.values.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final grupo = entries[index];
        final valor = grupo.total;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final lancs = dataLancs[grupo.label] ?? const <Lancamento>[];
              _mostrarDetalheLancamentos(
                titulo: 'Detalhe por forma / cartão',
                  subtitulo: '${grupo.label} • $_labelPeriodoAtual',
                lancamentos: lancs,
                manterNoGrupo: (atual) =>
                    _labelGrupoForma(atual) == grupo.label,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(grupo.icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.label,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
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
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Legenda quando agrupado por DIA
  Widget _buildLegendaDia() {
    final data = _totaisPorDia();
    final dataLancs = _lancamentosPorDia();
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final dia = entry.key;
        final valor = entry.value;
        final percent = total == 0 ? 0 : (valor / total) * 100;
        final color = _colorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final lancs = dataLancs[dia] ?? const <Lancamento>[];
              final diaSoData = DateTime(dia.year, dia.month, dia.day);
              _mostrarDetalheLancamentos(
                titulo: 'Detalhe do dia',
                subtitulo: _dateDiaFormat.format(dia),
                lancamentos: lancs,
                manterNoGrupo: (atual) {
                  final d = DateTime(
                    atual.dataHora.year,
                    atual.dataHora.month,
                    atual.dataHora.day,
                  );
                  return d == diaSoData;
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dia ${_dateDiaFormat.format(dia)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardDiaExtremo({
    required String titulo,
    required DateTime dia,
    required double valor,
    required Color cor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cor.withOpacity(0.08),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÍCONE
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cor, size: 18),
            ),

            const SizedBox(width: 8),

            // TEXTO (2 LINHAS)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TÍTULO
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // VALOR + DATA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // VALOR
                      Expanded(
                        child: Text(
                          _currency.format(valor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // DATA
                      Text(
                        _dateDiaFormat.format(dia),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
  }
}

class _ReclassificarLancamentoSheet extends StatefulWidget {
  const _ReclassificarLancamentoSheet({
    required this.lancamento,
    required this.categoriaRepo,
    required this.subcategoriaRepo,
    required this.lancamentoRepo,
    required this.categoriaEnumFromNome,
    required this.onSaved,
  });

  final Lancamento lancamento;
  final CategoriaPersonalizadaRepository categoriaRepo;
  final SubcategoriaPersonalizadaRepository subcategoriaRepo;
  final LancamentoRepository lancamentoRepo;
  final Categoria Function(String nome) categoriaEnumFromNome;
  final Future<void> Function(int idLancamento) onSaved;

  @override
  State<_ReclassificarLancamentoSheet> createState() =>
      _ReclassificarLancamentoSheetState();
}

class _ReclassificarLancamentoSheetState
    extends State<_ReclassificarLancamentoSheet> {
  bool _loading = true;
  bool _salvando = false;
  List<CategoriaPersonalizada> _cats = [];
  List<SubcategoriaPersonalizada> _subs = [];
  CategoriaPersonalizada? _cat;
  SubcategoriaPersonalizada? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  CategoriaPersonalizada? _categoriaCompatPorEnum(
    List<CategoriaPersonalizada> cats,
    Lancamento l,
  ) {
    if (cats.isEmpty) return null;
    final nomeEnum = CategoriaService.toName(l.categoria);
    try {
      return cats.firstWhere((c) => c.nome == nomeEnum);
    } catch (_) {
      return cats.first;
    }
  }

  Future<void> _load() async {
    final l = widget.lancamento;
    final cats = await widget.categoriaRepo.listarPorTipo(l.tipoMovimento);
    if (!mounted) return;

    CategoriaPersonalizada? cat;
    if (l.idCategoriaPersonalizada != null) {
      try {
        cat = cats.firstWhere((c) => c.id == l.idCategoriaPersonalizada);
      } catch (_) {
        cat = null;
      }
    }
    cat ??= _categoriaCompatPorEnum(cats, l);

    List<SubcategoriaPersonalizada> subs = [];
    if (cat?.id != null) {
      subs = await widget.subcategoriaRepo.listarPorCategoria(cat!.id!);
    }

    if (!mounted) return;

    SubcategoriaPersonalizada? sub;
    if (l.idSubcategoriaPersonalizada != null) {
      try {
        sub = subs.firstWhere((s) => s.id == l.idSubcategoriaPersonalizada);
      } catch (_) {
        sub = null;
      }
    }

    setState(() {
      _cats = cats;
      _subs = subs;
      _cat = cat;
      _sub = sub;
      _loading = false;
    });
  }

  Future<void> _onCatChanged(CategoriaPersonalizada? c) async {
    if (c == null) return;
    setState(() {
      _cat = c;
      _sub = null;
      _subs = [];
    });
    if (c.id != null) {
      final subs = await widget.subcategoriaRepo.listarPorCategoria(c.id!);
      if (mounted) setState(() => _subs = subs);
    }
  }

  CategoriaPersonalizada? get _catValid {
    final c = _cat;
    if (c?.id == null) return null;
    try {
      return _cats.firstWhere((x) => x.id == c!.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvar() async {
    final c = _catValid;
    final idLanc = widget.lancamento.id;
    if (c?.id == null || idLanc == null) return;

    setState(() => _salvando = true);
    try {
      final atualizado = widget.lancamento.copyWith(
        idCategoriaPersonalizada: c!.id,
        idSubcategoriaPersonalizada: _sub?.id,
        categoria: widget.categoriaEnumFromNome(c.nome),
      );
      await widget.lancamentoRepo.salvar(atualizado);
      if (!mounted) return;
      await widget.onSaved(idLanc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento reclassificado.')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.viewInsetsOf(context).bottom;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(bottom: padBottom),
        child: const SafeArea(
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_cats.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + padBottom),
        child: const Text(
          'Não há categorias cadastradas para este tipo de movimento.',
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + padBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reclassificar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.lancamento.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CategoriaPersonalizada>(
              value: _catValid,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items:
                  _cats
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.nome),
                        ),
                      )
                      .toList(),
              onChanged: _salvando ? null : _onCatChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SubcategoriaPersonalizada?>(
              value: _sub,
              decoration: const InputDecoration(
                labelText: 'Subcategoria',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<SubcategoriaPersonalizada?>(
                  value: null,
                  child: Text('Sem subcategoria'),
                ),
                ..._subs.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.nome),
                  ),
                ),
              ],
              onChanged:
                  _salvando
                      ? null
                      : (v) => setState(() => _sub = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _salvando || _catValid == null ? null : _salvar,
              child:
                  _salvando
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
