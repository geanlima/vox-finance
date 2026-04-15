// lib/ui/pages/parcelamentos/parcelamentos_page.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/pages/contas_pagar/conta_pagar_detalhe.dart';

enum ParcelamentosFiltro { emAberto, finalizandoMes, todos }

/// Chave estável para agregar pendência: cartão (`c:id`), forma (`f:idx` ou `f:idx@b:contaId`), ou `x`.
///
/// Usa [ContaPagar] e, quando houver, o [Lancamento] vinculado.
/// Prioriza forma/cartão/conta do **lançamento** (é o que o usuário edita no formulário).
String _chaveOrigem(ContaPagar c, Lancamento? l) {
  // Lançamento é o que o usuário altera no formulário; conta_pagar pode ficar defasada.
  FormaPagamento? forma = l?.formaPagamento ?? c.formaPagamento;
  if (forma == null) return 'x';

  final idCartao = l?.idCartao ?? c.idCartao;
  if (forma == FormaPagamento.credito && idCartao != null) {
    return 'c:$idCartao';
  }

  // Prioriza a conta do lançamento (é o que o usuário edita).
  final idConta = l?.idConta ?? c.idConta;
  if (idConta != null) {
    return 'f:${forma.index}@b:$idConta';
  }
  return 'f:${forma.index}';
}

class _OrigemResumoLinha {
  const _OrigemResumoLinha({
    required this.titulo,
    this.subtitulo,
    required this.icon,
    required this.valor,
  });

  final String titulo;
  final String? subtitulo;
  final IconData icon;
  final double valor;
}

class ParcelamentoResumo {
  final String grupoParcelas;
  final String descricao;
  final double valorTotal;
  final double valorPendente;
  final int quantidadeParcelas;
  final int qtdPagas;
  final int qtdPendentes;
  final DateTime primeiroVencimento;
  final DateTime ultimoVencimento;
  final String? formaDescricao;

  const ParcelamentoResumo({
    required this.grupoParcelas,
    required this.descricao,
    required this.valorTotal,
    required this.valorPendente,
    required this.quantidadeParcelas,
    required this.qtdPagas,
    required this.qtdPendentes,
    required this.primeiroVencimento,
    required this.ultimoVencimento,
    required this.formaDescricao,
   });
}

/// Pendência em meses além do atual e do próximo (para o bottom sheet).
class ParcelamentoMesPendente {
  final int ano;
  final int mes;
  final double total;
  final Map<String, double> porOrigem;

  const ParcelamentoMesPendente({
    required this.ano,
    required this.mes,
    required this.total,
    required this.porOrigem,
  });

  DateTime get inicioMes => DateTime(ano, mes, 1);
}

class ParcelamentosPage extends StatefulWidget {
  const ParcelamentosPage({super.key});

  static const routeName = '/parcelamentos';
  static const argFiltro = 'filtro';

  @override
  State<ParcelamentosPage> createState() => _ParcelamentosPageState();
}

class _ParcelamentosPageState extends State<ParcelamentosPage> {
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _contaRepo = ContaPagarRepository();
  final _lancRepo = LancamentoRepository();
  final _cartaoRepo = CartaoCreditoRepository();
  final _contaBancariaRepo = ContaBancariaRepository();

  bool _carregando = false;
  ParcelamentosFiltro _filtro = ParcelamentosFiltro.emAberto;
  bool _aplicouFiltroDaRota = false;
  DateTime _refFatura = DateTime.now();

  List<ParcelamentoResumo> _resumos = const [];
  /// Soma de todas as parcelas pendentes (parcelado, exc. FATURA_*).
  double _totalEmAbertoGeral = 0.0;
  /// Parcelas pendentes com vencimento no mês corrente.
  double _totalNesteMes = 0.0;
  /// Parcelas pendentes com vencimento no mês seguinte.
  double _totalProximoMes = 0.0;
  /// Soma do pendente só dos grupos exibidos (no filtro "finalizando este mês").
  Map<String, double> _abertoPorOrigemChave = const {};
  Map<String, double> _nesteMesPorOrigemChave = const {};
  Map<String, double> _proximoMesPorOrigemChave = const {};
  /// Mapa do último vencimento por grupo (para filtrar "somente última parcela").
  Map<String, DateTime> _ultimoVencimentoPorGrupo = const {};
  /// Para "finalizando": soma somente a ÚLTIMA parcela de cada grupo por mês de término.
  Map<int, double> _finalizandoUltimaParcelaPorMes = const {};
  Map<int, Map<String, double>> _finalizandoUltimaParcelaPorMesPorOrigemChave =
      const {};
  List<ParcelamentoMesPendente> _outrosMeses = const [];
  /// Soma do pendente com vencimento após o próximo mês.
  double _totalDemaisMeses = 0.0;
  bool _demaisMesesExpandido = false;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _refFatura = DateTime(agora.year, agora.month, 1);
    _carregar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aplicouFiltroDaRota) return;
    _aplicouFiltroDaRota = true;

    final filtroAntes = _filtro;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args[ParcelamentosPage.argFiltro];
      if (v == 'finalizandoMes') {
        _filtro = ParcelamentosFiltro.finalizandoMes;
      } else if (v == 'todos') {
        _filtro = ParcelamentosFiltro.todos;
      } else if (v == 'emAberto') {
        _filtro = ParcelamentosFiltro.emAberto;
      }
    }

    // Se a rota pediu um filtro diferente do padrão, recarrega para que
    // lista/totalizadores/modal reflitam o filtro já na primeira abertura.
    if (filtroAntes != _filtro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _carregar();
      });
    }
  }

  bool _ehGrupoFatura(String grupo) => grupo.startsWith('FATURA_');

  static int _chaveAnoMes(DateTime d) => d.year * 100 + d.month;

  Widget _kv({
    required String label,
    required String value,
    required ColorScheme cs,
    Color? valueColor,
    double labelFontSize = 11,
    double valueFontSize = 16,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: labelFontSize,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w900,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required ColorScheme cs,
    Color? bg,
    Color? fg,
  }) {
    final background = bg ?? cs.primary.withOpacity(0.10);
    final foreground = fg ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardParcelamento(
    BuildContext context,
    ColorScheme cs,
    ParcelamentoResumo r,
    double pct,
  ) {
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.55),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ContaPagarDetalhePage(
                grupoParcelas: r.grupoParcelas,
              ),
            ),
          ).then((_) => _carregar());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (r.formaDescricao != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.formaDescricao!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    icon: Icons.event_available_outlined,
                    text: 'Início ${_dateFormat.format(r.primeiroVencimento)}',
                    cs: cs,
                    bg: cs.secondary.withOpacity(0.10),
                    fg: cs.secondary,
                  ),
                  _pill(
                    icon: Icons.event_outlined,
                    text: 'Término ${_dateFormat.format(r.ultimoVencimento)}',
                    cs: cs,
                    bg: cs.tertiary.withOpacity(0.10),
                    fg: cs.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _pill(
                    icon: Icons.payments_outlined,
                    text: '${r.qtdPagas}/${r.quantidadeParcelas} pagas',
                    cs: cs,
                    bg: cs.primary.withOpacity(0.10),
                    fg: cs.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Em aberto',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _currency.format(r.valorPendente),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: r.valorPendente > 0 ? cs.error : cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _obterDescricaoFormaPagamento(String grupoParcelas) async {
    final lancs = await _lancRepo.getParcelasPorGrupo(grupoParcelas);
    if (lancs.isEmpty) return null;

    final l = lancs.first;
    if (l.formaPagamento == FormaPagamento.credito && l.idCartao != null) {
      final CartaoCredito? cartao = await _cartaoRepo.getCartaoCreditoById(
        l.idCartao!,
      );
      if (cartao != null) {
        final ultimos =
            cartao.ultimos4Digitos.isNotEmpty ? cartao.ultimos4Digitos : '****';
        return 'Crédito - ${cartao.descricao} • **** $ultimos';
      }
    }
    if (l.idConta != null) {
      final contas = await _contaBancariaRepo.getContasBancarias();
      for (final cb in contas) {
        if (cb.id == l.idConta) {
          return '${l.formaPagamento.label} • ${cb.descricao}';
        }
      }
    }
    return l.formaPagamento.label;
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    // Importante: para calcular corretamente "x/y pagas" precisamos carregar
    // todas as parcelas (pagas + pendentes). O filtro "somente pendentes"
    // será aplicado por grupo, com base no valor pendente do grupo.
    final todas = await _contaRepo.getTodas();

    // Somente compras parceladas (parcela_total > 1) e não inclui as contas da FATURA_*
    final parceladas =
        todas
            .where((c) => (c.parcelaTotal ?? 0) > 1)
            .where((c) => !_ehGrupoFatura(c.grupoParcelas))
            .toList();

    // Total pendente por origem (cartão / forma / conta) para o detalhamento
    final abertoPorOrigem = <String, double>{};
    final agora = DateTime.now();
    final inicioMes = DateTime(_refFatura.year, _refFatura.month, 1);
    final inicioProximoMes = DateTime(_refFatura.year, _refFatura.month + 1, 1);
    final chaveMesAtual = _chaveAnoMes(inicioMes);
    final chaveProximoMes = _chaveAnoMes(inicioProximoMes);

    /// Por mês de vencimento (yyyyMM): total e por origem (só pendentes).
    final totalPorMes = <int, double>{};
    final porOrigemPorMes = <int, Map<String, double>>{};

    final idsLancParcelas =
        parceladas
            .where((c) => c.idLancamento != null)
            .map((c) => c.idLancamento!)
            .toSet();
    final lancPorId = await _lancRepo.getByIds(idsLancParcelas);

    double totalGeral = 0.0;
    for (final c in parceladas) {
      if (c.pago) continue;
      final idL = c.idLancamento;
      final origem = _chaveOrigem(
        c,
        idL != null ? lancPorId[idL] : null,
      );
      abertoPorOrigem[origem] = (abertoPorOrigem[origem] ?? 0.0) + c.valor;
      totalGeral += c.valor;
      final v = c.dataVencimento;
      final chaveMes = _chaveAnoMes(v);
      totalPorMes[chaveMes] = (totalPorMes[chaveMes] ?? 0.0) + c.valor;
      porOrigemPorMes.putIfAbsent(chaveMes, () => <String, double>{});
      final bucket = porOrigemPorMes[chaveMes]!;
      bucket[origem] = (bucket[origem] ?? 0.0) + c.valor;
    }

    // Se a “fatura atual” ficou zerada (após pagar), avança automaticamente
    // para a próxima fatura que ainda tenha pendência.
    var chaveAtual = chaveMesAtual;
    var chaveProx = chaveProximoMes;
    var refAtual = inicioMes;
    var refProx = inicioProximoMes;
    if (totalPorMes.isNotEmpty) {
      // máximo 24 avanços por segurança (2 anos)
      for (var i = 0; i < 24; i++) {
        final vAtual = totalPorMes[chaveAtual] ?? 0.0;
        if (vAtual > 0.009) break;
        // encontra próximo mês com valor > 0
        final proximos =
            totalPorMes.keys.where((k) => k > chaveAtual).toList()..sort();
        final next = proximos.firstWhere(
          (k) => (totalPorMes[k] ?? 0.0) > 0.009,
          orElse: () => -1,
        );
        if (next == -1) break;
        final y = next ~/ 100;
        final m = next % 100;
        refAtual = DateTime(y, m, 1);
        refProx = DateTime(y, m + 1, 1);
        chaveAtual = next;
        chaveProx = _chaveAnoMes(refProx);
      }
    }

    final nesteMes = totalPorMes[chaveAtual] ?? 0.0;
    final proximoMes = totalPorMes[chaveProx] ?? 0.0;
    final nesteMesPorOrigem = porOrigemPorMes[chaveAtual] ?? <String, double>{};
    final proximoMesPorOrigem = porOrigemPorMes[chaveProx] ?? <String, double>{};

    final outrosMeses = <ParcelamentoMesPendente>[];
    for (final e in totalPorMes.entries) {
      if (e.key == chaveAtual || e.key == chaveProx) continue;
      if (e.value <= 0.009) continue;
      final y = e.key ~/ 100;
      final m = e.key % 100;
      outrosMeses.add(
        ParcelamentoMesPendente(
          ano: y,
          mes: m,
          total: e.value,
          porOrigem: Map<String, double>.from(porOrigemPorMes[e.key] ?? {}),
        ),
      );
    }
    outrosMeses.sort(
      (a, b) => _chaveAnoMes(a.inicioMes).compareTo(_chaveAnoMes(b.inicioMes)),
    );
    final totalDemaisMeses =
        outrosMeses.fold<double>(0.0, (a, x) => a + x.total);

    final mapa = <String, List<ContaPagar>>{};
    for (final c in parceladas) {
      mapa.putIfAbsent(c.grupoParcelas, () => []).add(c);
    }

    final resumos = <ParcelamentoResumo>[];
    final finalizandoMesPorOrigem = <String, double>{};
    final finalizandoUltimaParcelaPorMes = <int, double>{};
    final finalizandoUltimaParcelaPorMesPorOrigem = <int, Map<String, double>>{};
    final ultimoVencPorGrupo = <String, DateTime>{};

    for (final entry in mapa.entries) {
      final grupo = entry.key;
      final itens = [...entry.value]..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
      if (itens.isEmpty) continue;

      final total = itens.fold<double>(0.0, (a, c) => a + c.valor);
      final pendente = itens.where((c) => !c.pago).fold<double>(0.0, (a, c) => a + c.valor);
      final qtdPagas = itens.where((c) => c.pago).length;
      final qtdPend = itens.length - qtdPagas;
      final qtdParcelas = itens.map((c) => c.parcelaTotal ?? 0).fold<int>(0, (a, v) => v > a ? v : a);
      final primeiro = itens.first.dataVencimento;
      final ultimo = itens.last.dataVencimento;
      ultimoVencPorGrupo[grupo] = ultimo;

      // Filtros (aplicados por GRUPO)
      if (_filtro == ParcelamentosFiltro.emAberto && pendente <= 0) continue;
      if (_filtro == ParcelamentosFiltro.finalizandoMes) {
        final chaveFinaliza = _chaveAnoMes(DateTime(ultimo.year, ultimo.month, 1));
        final chaveAgora = _chaveAnoMes(DateTime(agora.year, agora.month, 1));
        final temPendente = pendente > 0.009;
        if (!temPendente) continue;
        // inclui o mês atual e os próximos meses (para ver o que termina em cada mês)
        if (chaveFinaliza < chaveAgora) continue;
      }

      // Se o filtro ativo for "finalizando este mês", o detalhamento por origem
      // precisa refletir somente os grupos exibidos.
      if (_filtro == ParcelamentosFiltro.finalizandoMes) {
        // "Finalizando" = somente a ÚLTIMA parcela do grupo no mês de término.
        final ultimaParcela = itens.last;
        if (!ultimaParcela.pago) {
          final chaveFinaliza =
              _chaveAnoMes(DateTime(ultimo.year, ultimo.month, 1));
          final idL = ultimaParcela.idLancamento;
          final k = _chaveOrigem(
            ultimaParcela,
            idL != null ? lancPorId[idL] : null,
          );
          finalizandoMesPorOrigem[k] =
              (finalizandoMesPorOrigem[k] ?? 0.0) + ultimaParcela.valor;

          finalizandoUltimaParcelaPorMes[chaveFinaliza] =
              (finalizandoUltimaParcelaPorMes[chaveFinaliza] ?? 0.0) +
                  ultimaParcela.valor;
          finalizandoUltimaParcelaPorMesPorOrigem.putIfAbsent(
            chaveFinaliza,
            () => <String, double>{},
          );
          final bucket = finalizandoUltimaParcelaPorMesPorOrigem[chaveFinaliza]!;
          bucket[k] = (bucket[k] ?? 0.0) + ultimaParcela.valor;
        }
      }

      resumos.add(
        ParcelamentoResumo(
          grupoParcelas: grupo,
          descricao: itens.first.descricao,
          valorTotal: total,
          valorPendente: pendente,
          quantidadeParcelas: qtdParcelas == 0 ? itens.length : qtdParcelas,
          qtdPagas: qtdPagas,
          qtdPendentes: qtdPend,
          primeiroVencimento: primeiro,
          ultimoVencimento: ultimo,
          formaDescricao: await _obterDescricaoFormaPagamento(grupo),
        ),
      );
    }

    resumos.sort((a, b) => b.valorPendente.compareTo(a.valorPendente));

    if (!mounted) return;
    setState(() {
      _resumos = resumos;
      _totalEmAbertoGeral = totalGeral;
      _totalNesteMes = nesteMes;
      _totalProximoMes = proximoMes;
      _abertoPorOrigemChave = abertoPorOrigem;
      _nesteMesPorOrigemChave = nesteMesPorOrigem;
      _proximoMesPorOrigemChave = proximoMesPorOrigem;
      _ultimoVencimentoPorGrupo = Map<String, DateTime>.from(ultimoVencPorGrupo);
      _finalizandoUltimaParcelaPorMes =
          Map<int, double>.from(finalizandoUltimaParcelaPorMes);
      _finalizandoUltimaParcelaPorMesPorOrigemChave = {
        for (final e in finalizandoUltimaParcelaPorMesPorOrigem.entries)
          e.key: Map<String, double>.from(e.value),
      };
      _outrosMeses = outrosMeses;
      _totalDemaisMeses = totalDemaisMeses;
      _demaisMesesExpandido = false;
      _refFatura = refAtual;
      _carregando = false;
    });
  }

  Future<_OrigemResumoLinha> _linhaParaChaveOrigem(
    String chave,
    double valor,
  ) async {
    if (chave.startsWith('c:')) {
      final id = int.tryParse(chave.substring(2));
      if (id != null) {
        final cartao = await _cartaoRepo.getCartaoCreditoById(id);
        if (cartao != null) {
          final ultimos =
              cartao.ultimos4Digitos.isNotEmpty ? cartao.ultimos4Digitos : null;
          return _OrigemResumoLinha(
            titulo: cartao.descricao,
            subtitulo: ultimos == null ? 'Crédito' : 'Crédito • **** $ultimos',
            icon: Icons.credit_card,
            valor: valor,
          );
        }
        return _OrigemResumoLinha(
          titulo: 'Cartão #$id',
          subtitulo: 'Crédito',
          icon: Icons.credit_card,
          valor: valor,
        );
      }
    }

    final mForma = RegExp(r'^f:(\d+)(?:@b:(\d+))?$').firstMatch(chave);
    if (mForma != null) {
      final idx = int.tryParse(mForma.group(1)!) ?? -1;
      final contaIdStr = mForma.group(2);
      FormaPagamento? forma;
      if (idx >= 0 && idx < FormaPagamento.values.length) {
        forma = FormaPagamento.values[idx];
      }
      final tituloBase = forma?.label ?? 'Forma $idx';
      IconData icon = forma?.icon ?? Icons.payment;
      String? subtitulo;
      if (contaIdStr != null) {
        final contaId = int.tryParse(contaIdStr);
        if (contaId != null) {
          final contas = await _contaBancariaRepo.getContasBancarias();
          for (final cb in contas) {
            if (cb.id == contaId) {
              subtitulo = cb.descricao;
              break;
            }
          }
        }
      }
      return _OrigemResumoLinha(
        titulo: tituloBase,
        subtitulo: subtitulo,
        icon: icon,
        valor: valor,
      );
    }

    return _OrigemResumoLinha(
      titulo: 'Outros / não informado',
      subtitulo: 'Cadastre forma de pagamento nas parcelas para detalhar',
      icon: Icons.help_outline,
      valor: valor,
    );
  }

  Future<void> _mostrarResumoPorOrigem(
    BuildContext context, {
    required String titulo,
    required Map<String, double> valoresPorOrigem,
    DateTime? inicio, // inclusivo (vencimento)
    DateTime? fim, // exclusivo (vencimento)
    Set<String>? somenteGrupos, // filtra por grupo_parcelas quando necessário
    bool somenteUltimaParcela = false,
  }) async {
    if (valoresPorOrigem.isEmpty) return;

    final entries = valoresPorOrigem.entries.toList()
      ..sort((a, b) => (b.value).compareTo(a.value));

    final linhas = <_OrigemResumoLinha>[];
    for (final e in entries) {
      linhas.add(await _linhaParaChaveOrigem(e.key, e.value));
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: linhas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final linha = linhas[i];
                      final chave = entries[i].key;
                      return ListTile(
                        leading: Icon(linha.icon, color: cs.primary),
                        title: Text(linha.titulo),
                        subtitle:
                            linha.subtitulo == null
                                ? null
                                : Text(linha.subtitulo!),
                        trailing: Text(
                          _currency.format(linha.valor),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                linha.valor > 0 ? cs.error : cs.primary,
                          ),
                        ),
                        onTap: () async {
                          if (_carregando || linha.valor <= 0) return;
                          await _mostrarLancamentosDaOrigem(
                            ctx,
                            chaveOrigem: chave,
                            titulo: linha.titulo,
                            subtitulo: linha.subtitulo,
                            inicio: inicio,
                            fim: fim,
                            somenteGrupos: somenteGrupos,
                            somenteUltimaParcela: somenteUltimaParcela,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarLancamentosDaOrigem(
    BuildContext context, {
    required String chaveOrigem,
    required String titulo,
    String? subtitulo,
    DateTime? inicio, // inclusivo (vencimento)
    DateTime? fim, // exclusivo (vencimento)
    Set<String>? somenteGrupos,
    bool somenteUltimaParcela = false,
  }) async {
    // Recalcula a origem usando conta_pagar + lançamento (quando existir),
    // e filtra pelas mesmas regras do totalizador.
    final todas = await _contaRepo.getTodas();
    final parcelas =
        todas
            .where((c) => (c.parcelaTotal ?? 0) > 1)
            .where((c) => !_ehGrupoFatura(c.grupoParcelas))
            .where((c) => !c.pago)
            .toList();

    final filtradas = <ContaPagar>[];
    for (final c in parcelas) {
      if (somenteGrupos != null && !somenteGrupos.contains(c.grupoParcelas)) {
        continue;
      }
      if (somenteUltimaParcela) {
        final ultimo = _ultimoVencimentoPorGrupo[c.grupoParcelas];
        if (ultimo == null) continue;
        if (c.dataVencimento.millisecondsSinceEpoch !=
            ultimo.millisecondsSinceEpoch) {
          continue;
        }
      }
      if (inicio != null || fim != null) {
        final v = c.dataVencimento;
        if (inicio != null && v.isBefore(inicio)) continue;
        if (fim != null && !v.isBefore(fim)) continue; // fim exclusivo
      }
      filtradas.add(c);
    }

    final ids =
        filtradas
            .where((c) => c.idLancamento != null)
            .map((c) => c.idLancamento!)
            .toSet();
    final lancPorId = await _lancRepo.getByIds(ids);

    // Itens que compõem esta origem. Mantemos uma lista “mista”:
    // - quando há lançamento, mostramos o lançamento
    // - quando não há, mostramos a própria parcela como fallback
    final itensLanc = <Lancamento>[];
    final itensSemLanc = <ContaPagar>[];
    for (final c in filtradas) {
      final idL = c.idLancamento;
      final l = idL == null ? null : lancPorId[idL];
      final origem = _chaveOrigem(c, l);
      if (origem != chaveOrigem) continue;
      if (l != null) {
        itensLanc.add(l);
      } else {
        itensSemLanc.add(c);
      }
    }
    itensLanc.sort((a, b) => a.dataHora.compareTo(b.dataHora));
    itensSemLanc.sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));

    if (!context.mounted) return;
    if (itensLanc.isEmpty && itensSemLanc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum lançamento encontrado.')),
      );
      return;
    }

    final date = DateFormat('dd/MM/yyyy');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.70;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (subtitulo != null)
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: ListView.separated(
                    itemCount: itensLanc.length + itensSemLanc.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      if (i < itensLanc.length) {
                        final l = itensLanc[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            l.descricao,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(date.format(l.dataHora)),
                          trailing: Text(
                            _currency.format(l.valor),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      }
                      final c = itensSemLanc[i - itensLanc.length];
                      return ListTile(
                        dense: true,
                        title: Text(
                          c.descricao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Sem lançamento • venc. ${date.format(c.dataVencimento)}',
                        ),
                        trailing: Text(
                          _currency.format(c.valor),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = DateTime(_refFatura.year, _refFatura.month, 1);
    final proxMesRef = DateTime(_refFatura.year, _refFatura.month + 1, 1);

    // Totais por mês (para o card do topo) quando filtro = finalizando.
    final agora = DateTime.now();
    final refFinalizando = DateTime(agora.year, agora.month, 1);
    final kFinalizandoAtual = _chaveAnoMes(refFinalizando);
    // Para o card "finalizando", usamos o mês de TÉRMINO (último vencimento do grupo)
    // e somamos SOMENTE a última parcela de cada compra parcelada.
    final totalFinalizandoAtual =
        _finalizandoUltimaParcelaPorMes[kFinalizandoAtual] ?? 0.0;
    final demaisFinalizando = _finalizandoUltimaParcelaPorMes.keys
        .where((k) => k != kFinalizandoAtual)
        .where((k) => (_finalizandoUltimaParcelaPorMes[k] ?? 0.0) > 0.009)
        .toList()
      ..sort();

    final proximos2 = demaisFinalizando.take(2).toList();
    final restantes = demaisFinalizando.skip(2).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelamentos'),
        actions: [
          IconButton(
            icon: Icon(
              _filtro == ParcelamentosFiltro.emAberto
                  ? Icons.filter_alt
                  : (_filtro == ParcelamentosFiltro.finalizandoMes
                      ? Icons.event_available_outlined
                      : Icons.filter_alt_outlined),
            ),
            tooltip: switch (_filtro) {
              ParcelamentosFiltro.emAberto => 'Mostrando: em aberto',
              ParcelamentosFiltro.finalizandoMes =>
                'Mostrando: finalizando (próximos meses)',
              ParcelamentosFiltro.todos => 'Mostrando: todos',
            },
            onPressed:
                _carregando
                    ? null
                    : () {
                      setState(() {
                        _filtro = switch (_filtro) {
                          ParcelamentosFiltro.emAberto => ParcelamentosFiltro.finalizandoMes,
                          ParcelamentosFiltro.finalizandoMes => ParcelamentosFiltro.todos,
                          ParcelamentosFiltro.todos => ParcelamentosFiltro.emAberto,
                        };
                      });
                      _carregar();
                    },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: ParcelamentosPage.routeName),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final t =
                          _filtro == ParcelamentosFiltro.finalizandoMes
                              ? totalFinalizandoAtual
                              : _totalEmAbertoGeral;
                      if (_carregando || t <= 0) return;
                      _mostrarResumoPorOrigem(
                        context,
                        titulo:
                            _filtro == ParcelamentosFiltro.finalizandoMes
                                ? 'Finalizando (${DateFormat('MM/yyyy').format(refFinalizando)}) por forma de pagamento'
                                : 'Em aberto por forma de pagamento',
                        valoresPorOrigem:
                            _filtro == ParcelamentosFiltro.finalizandoMes
                                ? (_finalizandoUltimaParcelaPorMesPorOrigemChave[
                                        kFinalizandoAtual] ??
                                    const <String, double>{})
                                : _abertoPorOrigemChave,
                        inicio: refFinalizando,
                        fim: DateTime(refFinalizando.year, refFinalizando.month + 1, 1),
                        somenteUltimaParcela:
                            _filtro == ParcelamentosFiltro.finalizandoMes,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child:
                          _filtro == ParcelamentosFiltro.finalizandoMes
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: cs.tertiary.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.event_available_outlined,
                                            color: cs.tertiary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _kv(
                                            label:
                                                'Total finalizando este mês (${DateFormat('MM/yyyy').format(refFinalizando)})',
                                            value: _currency.format(
                                              totalFinalizandoAtual,
                                            ),
                                            cs: cs,
                                            valueColor: cs.primary,
                                            labelFontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Divider(
                                      height: 18,
                                      color:
                                          cs.outlineVariant.withOpacity(0.5),
                                    ),
                                    if (proximos2.isNotEmpty || restantes.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      // Próximos 2 meses (sempre 2 colunas, como no card da imagem)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (var i = 0; i < 2; i++) ...[
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  if (i >= proximos2.length) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final k = proximos2[i];
                                                  final y = k ~/ 100;
                                                  final m = k % 100;
                                                  final dt = DateTime(y, m, 1);
                                                  final totalMes =
                                                      _finalizandoUltimaParcelaPorMes[k] ??
                                                          0.0;
                                                  return InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    onTap: totalMes <= 0.009
                                                        ? null
                                                        : () {
                                                            final vals =
                                                                _finalizandoUltimaParcelaPorMesPorOrigemChave[
                                                                        k] ??
                                                                    const <String, double>{};
                                                            _mostrarResumoPorOrigem(
                                                              context,
                                                              titulo:
                                                                  'Finalizando (${DateFormat('MM/yyyy').format(dt)}) por forma de pagamento',
                                                              valoresPorOrigem: vals,
                                                              inicio: dt,
                                                              fim: DateTime(y, m + 1, 1),
                                                              somenteUltimaParcela: true,
                                                            );
                                                          },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                      child: _kv(
                                                        label:
                                                            'Finalizando (${DateFormat('MM/yyyy').format(dt)})',
                                                        value: _currency.format(
                                                          totalMes,
                                                        ),
                                                        cs: cs,
                                                        valueColor: cs.primary,
                                                        labelFontSize: 10.5,
                                                        valueFontSize: 14,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            if (i == 0) const SizedBox(width: 12),
                                          ],
                                        ],
                                      ),

                                      Divider(
                                        height: 14,
                                        color:
                                            cs.outlineVariant.withOpacity(0.5),
                                      ),
                                      if (restantes.isNotEmpty) ...[
                                        Align(
                                          alignment: Alignment.center,
                                          child: IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 22,
                                            color: cs.onSurfaceVariant,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints.tightFor(
                                              width: 34,
                                              height: 34,
                                            ),
                                            onPressed: () => setState(() {
                                              _demaisMesesExpandido =
                                                  !_demaisMesesExpandido;
                                            }),
                                            icon: Icon(
                                              _demaisMesesExpandido
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                            ),
                                          ),
                                        ),
                                        if (_demaisMesesExpandido) ...[
                                          const SizedBox(height: 6),
                                          const Divider(height: 1),
                                          ...restantes.map((k) {
                                            final y = k ~/ 100;
                                            final m = k % 100;
                                            final dt = DateTime(y, m, 1);
                                            final totalMes =
                                                _finalizandoUltimaParcelaPorMes[
                                                        k] ??
                                                    0.0;
                                            return Column(
                                              children: [
                                                InkWell(
                                                  onTap: totalMes <= 0.009
                                                      ? null
                                                      : () {
                                                          final vals =
                                                              _finalizandoUltimaParcelaPorMesPorOrigemChave[
                                                                      k] ??
                                                                  const <String, double>{};
                                                          _mostrarResumoPorOrigem(
                                                            context,
                                                            titulo:
                                                                'Finalizando (${DateFormat('MM/yyyy').format(dt)}) por forma de pagamento',
                                                            valoresPorOrigem: vals,
                                                            inicio: dt,
                                                            fim: DateTime(y, m + 1, 1),
                                                            somenteUltimaParcela: true,
                                                          );
                                                        },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Finalizando (${DateFormat('MM/yyyy').format(dt)})',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          _currency.format(
                                                            totalMes,
                                                          ),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: cs.error,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                              ],
                                            );
                                          }),
                                        ],
                                      ],
                                    ],
                                  ],
                                )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.view_timeline_outlined,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _kv(
                                          label: 'Total em aberto',
                                          value: _currency.format(
                                            _totalEmAbertoGeral,
                                          ),
                                          cs: cs,
                                          valueColor: cs.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    height: 24,
                                    color: cs.outlineVariant.withOpacity(0.5),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            if (_carregando ||
                                                _totalNesteMes <= 0) {
                                              return;
                                            }
                                            final inicio = ref;
                                            final fim = proxMesRef;
                                            _mostrarResumoPorOrigem(
                                              context,
                                              titulo:
                                                  'Fatura atual por forma de pagamento',
                                              valoresPorOrigem:
                                                  _nesteMesPorOrigemChave,
                                              inicio: inicio,
                                              fim: fim,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: _kv(
                                              label:
                                                  'Fatura atual (${DateFormat('MM/yyyy').format(ref)})',
                                              value: _currency.format(
                                                _totalNesteMes,
                                              ),
                                              cs: cs,
                                              valueColor: cs.error,
                                              labelFontSize: 10,
                                              valueFontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            if (_carregando ||
                                                _totalProximoMes <= 0) {
                                              return;
                                            }
                                            final inicio = proxMesRef;
                                            final fim = DateTime(
                                              proxMesRef.year,
                                              proxMesRef.month + 1,
                                              1,
                                            );
                                            _mostrarResumoPorOrigem(
                                              context,
                                              titulo:
                                                  'Próxima fatura por forma de pagamento',
                                              valoresPorOrigem:
                                                  _proximoMesPorOrigemChave,
                                              inicio: inicio,
                                              fim: fim,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: _kv(
                                              label:
                                                  'Próxima fatura (${DateFormat('MM/yyyy').format(proxMesRef)})',
                                              value: _currency.format(
                                                _totalProximoMes,
                                              ),
                                              cs: cs,
                                              valueColor: cs.tertiary,
                                              labelFontSize: 10,
                                              valueFontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_outrosMeses.isNotEmpty) ...[
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: cs.outlineVariant.withOpacity(0.5),
                                    ),
                                    TapRegion(
                                      onTapOutside: (_) {
                                        if (_demaisMesesExpandido) {
                                          setState(
                                            () => _demaisMesesExpandido = false,
                                          );
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Tooltip(
                                            message:
                                                'Demais faturas (${_outrosMeses.length})',
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap:
                                                  _carregando
                                                      ? null
                                                      : () => setState(
                                                        () =>
                                                            _demaisMesesExpandido =
                                                                !_demaisMesesExpandido,
                                                      ),
                                              child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 12,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  AnimatedRotation(
                                                    turns:
                                                        _demaisMesesExpandido
                                                            ? 0.5
                                                            : 0,
                                                    duration: const Duration(
                                                      milliseconds: 220,
                                                    ),
                                                    curve: Curves.easeInOut,
                                                    child: Icon(
                                                      Icons.expand_more,
                                                      size: 24,
                                                      color: cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ),
                                          ),
                                          AnimatedSize(
                                            duration: const Duration(
                                              milliseconds: 260,
                                            ),
                                            alignment: Alignment.topCenter,
                                            curve: Curves.easeInOut,
                                            child:
                                                _demaisMesesExpandido
                                                    ? Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .fromLTRB(
                                                                    12,
                                                                    4,
                                                                    12,
                                                                    10,
                                                                  ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .stretch,
                                                            children: [
                                                              Text(
                                                                'DEMAIS MESES (${_outrosMeses.length})',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  letterSpacing:
                                                                      0.35,
                                                                  color: cs
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Text(
                                                                _currency.format(
                                                                  _totalDemaisMeses,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: cs
                                                                      .onSurface,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Divider(
                                                          height: 1,
                                                          color: cs
                                                              .outlineVariant
                                                              .withOpacity(0.45),
                                                        ),
                                                        ConstrainedBox(
                                                          constraints:
                                                              BoxConstraints(
                                                                maxHeight: min(
                                                                  280,
                                                                  MediaQuery.sizeOf(
                                                                    context,
                                                                  ).height *
                                                                      0.38,
                                                                ),
                                                              ),
                                                          child: ListView.separated(
                                                            shrinkWrap: true,
                                                            physics:
                                                                const ClampingScrollPhysics(),
                                                            itemCount:
                                                                _outrosMeses
                                                                    .length,
                                                            separatorBuilder:
                                                                (
                                                                  _,
                                                                  __,
                                                                ) => Divider(
                                                                  height: 1,
                                                                  color: cs
                                                                      .outlineVariant
                                                                      .withOpacity(
                                                                        0.35,
                                                                      ),
                                                                ),
                                                            itemBuilder: (
                                                              ctx,
                                                              i,
                                                            ) {
                                                              final item =
                                                                  _outrosMeses[i];
                                                              final label =
                                                                  DateFormat(
                                                                    'MM/yyyy',
                                                                  ).format(
                                                                    item.inicioMes,
                                                                  );
                                                              return ListTile(
                                                                dense: true,
                                                                visualDensity:
                                                                    VisualDensity
                                                                        .compact,
                                                                title: Text(
                                                                  'A pagar em $label',
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize: 13,
                                                                  ),
                                                                ),
                                                                trailing: Text(
                                                                  _currency.format(
                                                                    item.total,
                                                                  ),
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight.w800,
                                                                    color: cs.error,
                                                                    fontSize: 13,
                                                                  ),
                                                                ),
                                                                onTap: () {
                                                                  if (item.total <=
                                                                      0) {
                                                                    return;
                                                                  }
                                                                  final inicio =
                                                                      DateTime(
                                                                        item.ano,
                                                                        item.mes,
                                                                        1,
                                                                      );
                                                                  final fim =
                                                                      DateTime(
                                                                        item.ano,
                                                                        item.mes +
                                                                            1,
                                                                        1,
                                                                      );
                                                                  _mostrarResumoPorOrigem(
                                                                    context,
                                                                    titulo:
                                                                        'A pagar em $label',
                                                                    valoresPorOrigem:
                                                                        item.porOrigem,
                                                                    inicio:
                                                                        inicio,
                                                                    fim: fim,
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                    : const SizedBox(
                                                      width: double.infinity,
                                                    ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                    ),
                  ),
                ),
                Expanded(
                  child: _resumos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              switch (_filtro) {
                                ParcelamentosFiltro.emAberto =>
                                  'Nenhum parcelamento em aberto.',
                                ParcelamentosFiltro.finalizandoMes =>
                                  'Nenhuma compra finalizando nos próximos meses.',
                                ParcelamentosFiltro.todos =>
                                  'Nenhum parcelamento encontrado.',
                              },
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _resumos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final r = _resumos[i];
                                final pct = r.quantidadeParcelas == 0
                                    ? 0.0
                                    : (r.qtdPagas / r.quantidadeParcelas)
                                        .clamp(0.0, 1.0);
                                return _cardParcelamento(context, cs, r, pct);
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

