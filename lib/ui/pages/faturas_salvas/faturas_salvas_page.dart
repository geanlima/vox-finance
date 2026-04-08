import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/integracao_fatura_cache.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/integracao/integracao_fatura_cache_repository.dart';
import 'package:vox_finance/ui/pages/faturas_salvas/fatura_salva_detalhe_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class FaturasSalvasPage extends StatefulWidget {
  const FaturasSalvasPage({super.key});

  static const routeName = '/faturas-salvas';

  @override
  State<FaturasSalvasPage> createState() => _FaturasSalvasPageState();
}

class _FaturasSalvasPageState extends State<FaturasSalvasPage> {
  final _cartaoRepo = CartaoCreditoRepository();
  final _cacheRepo = IntegracaoFaturaCacheRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _loading = true;
  String? _erro;

  List<CartaoCredito> _cartoes = const [];
  int? _cartaoId;

  late int _ano;
  late int _mes;

  List<IntegracaoFaturaCache> _faturas = const [];

  static final _mesNome = DateFormat.MMMM('pt_BR');

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _ano = agora.year;
    _mes = agora.month;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final cards = await _cartaoRepo.getCartoesCredito();
      final cartoes = cards.where((c) => c.id != null).toList();

      final manter = _cartaoId;
      final ainda = manter != null && cartoes.any((c) => c.id == manter);
      final id = ainda ? manter : (cartoes.isEmpty ? null : cartoes.first.id);

      List<IntegracaoFaturaCache> faturas = const [];
      if (id != null) {
        faturas = await _cacheRepo.listarPorCartaoPeriodo(
          idCartaoLocal: id,
          ano: _ano,
          mes: _mes,
        );
      }

      if (!mounted) return;
      setState(() {
        _cartoes = cartoes;
        _cartaoId = id;
        _faturas = faturas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
      });
    }
  }

  String get _periodoLabel {
    final raw = _mesNome.format(DateTime(_ano, _mes, 1));
    return raw[0].toUpperCase() + raw.substring(1);
  }

  CartaoCredito? get _cartaoAtual {
    final id = _cartaoId;
    if (id == null) return null;
    try {
      return _cartoes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DropdownMenuItem<int>> _anosItems() {
    final agora = DateTime.now();
    final anos = List<int>.generate(9, (i) => agora.year - 5 + i);
    return anos.map((a) => DropdownMenuItem(value: a, child: Text('$a'))).toList();
  }

  Future<void> _confirmarExcluir(IntegracaoFaturaCache f) async {
    final id = f.id;
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir fatura salva'),
          content: const Text(
            'Deseja excluir esta fatura salva localmente?\n\n'
            'Isso remove também os lançamentos salvos dentro dela.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    await _cacheRepo.deletarFaturaCache(id);
    if (!mounted) return;
    await _carregar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fatura excluída.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faturas salvas'),
        actions: [
          IconButton(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: FaturasSalvasPage.routeName),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_erro!, textAlign: TextAlign.center),
                  ),
                )
              : _cartoes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Cadastre um cartão para ver faturas salvas.'),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            value: _cartaoId,
                            decoration: const InputDecoration(
                              labelText: 'Cartão',
                              border: OutlineInputBorder(),
                            ),
                            items: _cartoes
                                .map(
                                  (c) => DropdownMenuItem<int>(
                                    value: c.id!,
                                    child: Text(c.descricao),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _cartaoId = v);
                              await _carregar();
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _mes,
                                  decoration: const InputDecoration(
                                    labelText: 'Mês',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: List.generate(
                                    12,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1}'.padLeft(2, '0')),
                                    ),
                                  ),
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    setState(() => _mes = v);
                                    await _carregar();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _ano,
                                  decoration: const InputDecoration(
                                    labelText: 'Ano',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _anosItems(),
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    setState(() => _ano = v);
                                    await _carregar();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _faturas.isEmpty
                                ? Center(
                                    child: Text(
                                      'Nenhuma fatura salva para $_periodoLabel de $_ano.',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _faturas.length,
                                    itemBuilder: (context, idx) {
                                      final f = _faturas[idx];
                                      final cartao = _cartaoAtual;
                                      final sub = [
                                        if (f.dataVencimento != null)
                                          'Venc. ${DateFormat.yMMMd('pt_BR').format(f.dataVencimento!)}',
                                        if (f.pago != null)
                                          (f.pago! ? 'Paga' : 'Em aberto'),
                                        'Importado ${DateFormat('dd/MM HH:mm').format(f.importadoEm)}',
                                      ].join(' · ');

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Slidable(
                                          key: ValueKey(f.id ?? idx),
                                          endActionPane: ActionPane(
                                            motion: const DrawerMotion(),
                                            extentRatio: 0.22,
                                            children: [
                                              CustomSlidableAction(
                                                onPressed: (_) =>
                                                    _confirmarExcluir(f),
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: const Icon(
                                                  Icons.delete,
                                                  size: 28,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            title: Text(
                                              '$_periodoLabel de $_ano',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(sub),
                                            trailing: Text(
                                              _money.format(f.valorTotal),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.push<void>(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      FaturaSalvaDetalhePage(
                                                    fatura: f,
                                                    cartao: cartao,
                                                    periodoLabel:
                                                        '$_periodoLabel de $_ano',
                                                  ),
                                                ),
                                              );
                                            },
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

