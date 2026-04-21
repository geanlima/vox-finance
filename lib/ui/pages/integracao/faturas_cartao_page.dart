// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/service/integracao_cartoes_api_service.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/fatura_api_dto.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/integracao/integracao_fatura_cache_repository.dart';
import 'package:vox_finance/ui/pages/integracao/fatura_api_detalhe_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/pages/faturas_salvas/fatura_salva_detalhe_page.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

/// Faturas por cartão cadastrado e período (código de integração no cartão).
class FaturasCartaoPage extends StatefulWidget {
  const FaturasCartaoPage({super.key});

  static const routeName = '/integracao/faturas-cartao';

  @override
  State<FaturasCartaoPage> createState() => _FaturasCartaoPageState();
}

class _FaturasCartaoPageState extends State<FaturasCartaoPage> {
  final _repo = CartaoCreditoRepository();
  final _api = IntegracaoCartoesApiService.instance;
  final _cacheRepo = IntegracaoFaturaCacheRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _loadingCartoes = true;
  bool _loadingBusca = false;
  String? _erroCartoes;
  String? _erroBusca;

  List<CartaoCredito> _cartoes = [];
  int? _cartaoLocalId;

  late int _mes;
  late int _ano;

  List<FaturaApiDto> _faturas = [];
  bool _jaBuscou = false;
  int _qtdCartoesSemCodigo = 0;

  static final _mesNome = DateFormat.MMMM('pt_BR');

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = agora.month;
    _ano = agora.year;
    _carregarCartoes();
  }

  List<CartaoCredito> _filtrComCodigoApi(List<CartaoCredito> todos) {
    return todos
        .where(
          (c) =>
              c.id != null &&
              (c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos) &&
              (c.codigoCartaoApi?.trim().isNotEmpty ?? false),
        )
        .toList();
  }

  Future<void> _carregarCartoes() async {
    setState(() {
      _loadingCartoes = true;
      _erroCartoes = null;
      _erroBusca = null;
    });
    try {
      final todos = await _repo.getCartoesCredito();
      if (!mounted) return;

      final filtrados = _filtrComCodigoApi(todos);
      final manter = _cartaoLocalId;
      final aindaExiste =
          manter != null && filtrados.any((c) => c.id == manter);

      final semCodigoApi =
          todos
              .where(
                (c) =>
                    c.id != null &&
                    (c.tipo == TipoCartao.credito ||
                        c.tipo == TipoCartao.ambos) &&
                    (c.codigoCartaoApi?.trim().isEmpty ?? true),
              )
              .length;

      setState(() {
        _qtdCartoesSemCodigo = semCodigoApi;
        _cartoes = filtrados;
        _cartaoLocalId =
            aindaExiste
                ? manter
                : (filtrados.isEmpty ? null : filtrados.first.id!);
        _loadingCartoes = false;
        _faturas = [];
        _jaBuscou = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCartoes = e.toString();
        _loadingCartoes = false;
        _cartoes = [];
        _cartaoLocalId = null;
        _faturas = [];
        _jaBuscou = false;
        _qtdCartoesSemCodigo = 0;
      });
    }
  }

  Future<void> _buscarFaturas() async {
    final idLocal = _cartaoLocalId;
    if (idLocal == null) return;

    final idx = _cartoes.indexWhere((c) => c.id == idLocal);
    if (idx < 0) return;
    final cartao = _cartoes[idx];
    final codigoApi = cartao.codigoCartaoApi?.trim() ?? '';
    if (codigoApi.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loadingBusca = true;
      _erroBusca = null;
    });

    try {
      final lista = await _api.listarFaturasPorCartaoMes(
        idCartaoApi: codigoApi,
        ano: _ano,
        mes: _mes,
      );
      if (!mounted) return;
      setState(() {
        _faturas = lista;
        _loadingBusca = false;
        _jaBuscou = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroBusca = e.toString();
        _loadingBusca = false;
        _faturas = [];
        _jaBuscou = true;
      });
    }
  }

  double get _totalGeral =>
      _faturas.fold<double>(0, (a, f) => a + f.valorTotal);

  String get _periodoLabel {
    final raw = _mesNome.format(DateTime(_ano, _mes, 1));
    return raw[0].toUpperCase() + raw.substring(1);
  }

  CartaoCredito? get _cartaoAtual {
    final id = _cartaoLocalId;
    if (id == null) return null;
    try {
      return _cartoes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faturas de cartão'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingCartoes ? null : _carregarCartoes,
            tooltip: 'Recarregar cadastro',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: FaturasCartaoPage.routeName),
      body:
          _loadingCartoes
              ? const Center(child: CircularProgressIndicator())
              : _erroCartoes != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_erroCartoes!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _carregarCartoes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
              : _cartoes.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _qtdCartoesSemCodigo > 0
                            ? 'Nenhum cartão de crédito com código de integração. '
                                'Em Cadastro → Cartões, edite o cartão e preencha o '
                                'código do cartão na integração.'
                            : 'Cadastre um cartão de crédito (ou débito/crédito) e informe o '
                                'código de integração no cadastro para buscar faturas aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      if (_qtdCartoesSemCodigo > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Há $_qtdCartoesSemCodigo cartão(ões) sem esse código.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              : ListView(
                padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(16)),
                children: [
                  Text(
                    'Escolha o cartão cadastrado, o mês e o ano, depois toque em Buscar faturas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cartão cadastrado',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _cartaoLocalId,
                        items:
                            _cartoes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id!,
                                    child: Text(c.label),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          setState(() {
                            _cartaoLocalId = v;
                            _faturas = [];
                            _erroBusca = null;
                            _jaBuscou = false;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Mês',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _mes,
                              items: List.generate(12, (i) {
                                final m = i + 1;
                                final raw = _mesNome.format(
                                  DateTime(_ano, m, 1),
                                );
                                final label =
                                    raw[0].toUpperCase() + raw.substring(1);
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(label),
                                );
                              }),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _mes = v;
                                  _faturas = [];
                                  _erroBusca = null;
                                  _jaBuscou = false;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 0,
                        child: SizedBox(
                          width: 112,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Ano',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _ano,
                                items: _anosItems(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _ano = v;
                                    _faturas = [];
                                    _erroBusca = null;
                                    _jaBuscou = false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        (_loadingBusca || _cartaoLocalId == null)
                            ? null
                            : _buscarFaturas,
                    icon:
                        _loadingBusca
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.cloud_download_outlined),
                    label: const Text('Buscar faturas'),
                  ),
                  if (_erroBusca != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _erroBusca!,
                      style: TextStyle(color: cs.error),
                    ),
                  ],
                  if (!_loadingBusca && _erroBusca == null) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _totalLinha('Total da fatura', _totalGeral, cs.primary),
                          ],
                        ),
                      ),
                    ),
                    if (_faturas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Text(
                          _jaBuscou
                              ? 'Nenhuma fatura encontrada para $_periodoLabel de $_ano.'
                              : 'Toque em Buscar faturas para carregar os dados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    else ...[
                      Card(
                        color: cs.primaryContainer.withOpacity(0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 22,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Salvar fatura local: deslize o card para a esquerda ou abra a fatura e use o botão no detalhe. '
                                  'Associação aos lançamentos: menu → Movimentação → '
                                  'Fatura do cartão de crédito → abra a fatura salva.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._faturas.map((f) => _tileFatura(context, f)),
                    ],
                  ],
                ],
              ),
    );
  }

  List<DropdownMenuItem<int>> _anosItems() {
    final y = DateTime.now().year;
    return List.generate(9, (i) => y - 5 + i, growable: false)
        .map<DropdownMenuItem<int>>((a) {
      return DropdownMenuItem(value: a, child: Text('$a'));
    }).toList();
  }

  Widget _totalLinha(String label, double valor, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _money.format(valor),
            style: TextStyle(fontWeight: FontWeight.w700, color: cor),
          ),
        ],
      ),
    );
  }

  Widget _tileFatura(BuildContext context, FaturaApiDto f) {
    final cs = Theme.of(context).colorScheme;
    final cartao = _cartaoAtual;
    final sub = [
      if (f.dataVencimento != null)
        'Venc. ${DateFormat.yMMMd('pt_BR').format(f.dataVencimento!)}',
      if (f.pago != null) (f.pago! ? 'Paga' : 'Em aberto'),
      'Toque para ver itens · salvar fatura local',
    ].join(' · ');

    return Slidable(
      key: ValueKey('${_cartaoLocalId}_${_ano}_${_mes}_${f.id ?? f.valorTotal}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _salvarFaturaLocalmente(context, f),
            backgroundColor: cs.primary,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(
              Icons.save_alt,
              size: 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            '$_periodoLabel de $_ano',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: sub.isEmpty ? null : Text(sub),
          trailing: Text(
            _money.format(f.valorTotal),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color:
                  f.pago == true
                      ? cs.tertiary
                      : f.pago == false
                      ? cs.error
                      : cs.onSurface,
            ),
          ),
          onTap: () {
            if (cartao == null) return;
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder:
                    (_) => FaturaApiDetalhePage(
                      fatura: f,
                      periodoLabel: '$_periodoLabel de $_ano',
                      onSalvarLocalmente: () => _salvarFaturaLocalmente(context, f),
                    ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _salvarFaturaLocalmente(BuildContext context, FaturaApiDto f) async {
    final cartao = _cartaoAtual;
    if (cartao?.id == null) return;
    final codigoApi = cartao!.codigoCartaoApi?.trim() ?? '';
    if (codigoApi.isEmpty) return;

    final existentePeriodo = await _cacheRepo.getUltimaPorCartaoPeriodo(
      idCartaoLocal: cartao.id!,
      ano: _ano,
      mes: _mes,
    );

    final sourceKey = _cacheRepo.buildSourceKey(
      idCartaoLocal: cartao.id!,
      ano: _ano,
      mes: _mes,
      f: f,
    );
    final existente = await _cacheRepo.getBySourceKey(sourceKey);

    // Se já existe cache no período (mesmo que sourceKey tenha mudado),
    // oferecemos atualizar mantendo associações e abrir para revisar.
    if (existentePeriodo != null && existente == null) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Fatura local já existe'),
            content: const Text(
              'Já existe uma fatura salva localmente para este cartão e período.\n\n'
              'Você pode abrir a existente para associar itens, ou atualizar os dados '
              'mantendo as associações já feitas (quando o item da API for o mesmo).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancelar'),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'abrir'),
                child: const Text('Abrir existente'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'atualizar'),
                child: const Text('Atualizar'),
              ),
            ],
          );
        },
      );

      if (escolha == null || escolha == 'cancelar') return;

      if (escolha == 'abrir') {
        if (!context.mounted) return;
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FaturaSalvaDetalhePage(
              fatura: existentePeriodo,
              cartao: cartao,
              periodoLabel: '$_periodoLabel de $_ano',
            ),
          ),
        );
        return;
      }

      // atualizar (mantendo vínculos por item_api_id quando possível)
      final idCache = await _cacheRepo.salvarFaturaFromApi(
        idCartaoLocal: cartao.id!,
        codigoCartaoApi: codigoApi,
        ano: _ano,
        mes: _mes,
        f: f,
        overwrite: true,
      );

      final fat = await _cacheRepo.getById(idCache);
      if (!context.mounted) return;
      if (fat != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FaturaSalvaDetalhePage(
              fatura: fat,
              cartao: cartao,
              periodoLabel: '$_periodoLabel de $_ano',
            ),
          ),
        );
      }
      return;
    }

    bool overwrite = false;
    if (existente != null) {
      overwrite =
          (await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Sobrescrever fatura salva?'),
                content: const Text(
                  'Já existe uma fatura salva localmente para este cartão/período.\n\n'
                  'Se continuar, os dados salvos serão substituídos (mantendo associações quando possível).',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sobrescrever'),
                  ),
                ],
              );
            },
          )) ==
          true;
      if (!overwrite) return;
    }

    final idCache = await _cacheRepo.salvarFaturaFromApi(
      idCartaoLocal: cartao.id!,
      codigoCartaoApi: codigoApi,
      ano: _ano,
      mes: _mes,
      f: f,
      overwrite: overwrite,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existente == null ? 'Fatura salva localmente.' : 'Fatura atualizada.',
        ),
      ),
    );

    final fat = await _cacheRepo.getById(idCache);
    if (!context.mounted) return;
    if (fat != null) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FaturaSalvaDetalhePage(
            fatura: fat,
            cartao: cartao,
            periodoLabel: '$_periodoLabel de $_ano',
          ),
        ),
      );
    }
  }
}
