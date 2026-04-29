import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/investimento_carteira.dart';
import 'package:vox_finance/ui/data/models/investimento_cdi_config.dart';
import 'package:vox_finance/ui/data/models/investimento_layout_catalog.dart';
import 'package:vox_finance/ui/data/modules/investimentos/carteira_investimento_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_config_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/pages/investimentos/bluminers/bluminers_page.dart';
import 'package:vox_finance/ui/pages/investimentos/cdi/cdi_carteira_page.dart';
import 'package:vox_finance/ui/pages/investimentos/cdi/cdi_movimentacoes_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

/// Lista de carteiras; cada uma usa um layout (ex.: Bluminers).
class CarteirasInvestimentoPage extends StatefulWidget {
  const CarteirasInvestimentoPage({super.key});

  @override
  State<CarteirasInvestimentoPage> createState() =>
      _CarteirasInvestimentoPageState();
}

class _CarteirasInvestimentoPageState extends State<CarteirasInvestimentoPage> {
  final _repo = CarteiraInvestimentoRepository();
  final _cdiCfgRepo = InvestimentoCdiConfigRepository();
  final _contasRepo = ContaBancariaRepository();
  final _fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

  bool _loading = true;
  List<InvestimentoCarteira> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listar();
    if (!mounted) return;
    setState(() {
      _itens = rows;
      _loading = false;
    });
  }

  Future<void> _abrirCarteira(InvestimentoCarteira c) async {
    if (c.id == null) return;

    switch (c.layout) {
      case 'bluminers':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder:
                (_) => BluminersPage(
                  idCarteira: c.id!,
                  nomeCarteira: c.nome,
                ),
          ),
        );
        await _load();
        return;
      case 'cdi_faixas':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder:
                (_) => CdiCarteiraPage(
                  idCarteira: c.id!,
                  nomeCarteira: c.nome,
                ),
          ),
        );
        await _load();
        return;
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Layout "${InvestimentoLayoutCatalog.tituloOuId(c.layout)}" ainda não está disponível no app.',
            ),
          ),
        );
    }
  }

  Future<void> _abrirMovimentacoes(InvestimentoCarteira c) async {
    if (c.id == null) return;
    if (c.layout != 'cdi_faixas') {
      // Por enquanto, movimentações detalhadas só no layout CDI.
      await _abrirCarteira(c);
      return;
    }

    final cfg = await _cdiCfgRepo.porCarteira(c.id!);
    final saldoInicial = cfg?.saldoBase ?? 0.0;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CdiMovimentacoesPage(
          idCarteira: c.id!,
          nomeCarteira: c.nome,
          saldoInicial: saldoInicial,
        ),
      ),
    );
  }

  Future<void> _openForm({InvestimentoCarteira? item}) async {
    final nomeCtrl = TextEditingController(text: item?.nome ?? '');
    var layoutId = item?.layout ?? InvestimentoLayoutCatalog.padraoId;
    if (!InvestimentoLayoutCatalog.existe(layoutId)) {
      layoutId = InvestimentoLayoutCatalog.padraoId;
    }

    // Campos extras (CDI)
    final limiteCtrl = TextEditingController();
    final saldoBaseCtrl = TextEditingController();
    final cdiBaseCtrl = TextEditingController();
    final pctAteCtrl = TextEditingController();
    final pctAcimaCtrl = TextEditingController();
    final taxaDiariaCtrl = TextEditingController();
    final aporteCtrl = TextEditingController();

    bool usarTaxaFixa = false;
    bool considerarFds = false;
    bool considerarFeriados = false;
    int? idContaSelecionada;
    List<ContaBancaria> contas = const [];

    double parseNumberPt(String s) {
      final raw = s.trim();
      if (raw.isEmpty) return 0;
      return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }

    // Pré-carrega dados do CDI quando editando carteira CDI
    if (item?.id != null && layoutId == 'cdi_faixas') {
      final cfg = await _cdiCfgRepo.porCarteira(item!.id!);
      contas = await _contasRepo.getContasBancarias(apenasAtivas: true);

      final fmt2 = NumberFormat('#,##0.00', 'pt_BR');
      limiteCtrl.text = fmt2.format(cfg?.limiteFaixa ?? 10000);
      saldoBaseCtrl.text = fmt2.format(cfg?.saldoBase ?? 0);
      cdiBaseCtrl.text = fmt2.format(cfg?.cdiBaseAnual ?? 0);
      pctAteCtrl.text = fmt2.format(cfg?.pctAteLimite ?? 0);
      pctAcimaCtrl.text = fmt2.format(cfg?.pctAcimaLimite ?? 0);
      taxaDiariaCtrl.text =
          NumberFormat('0.000000', 'pt_BR').format(cfg?.taxaDiariaFixa ?? 0.000433);
      aporteCtrl.text = fmt2.format(cfg?.aporteFixo ?? 2000);

      usarTaxaFixa = cfg?.usarTaxaFixa ?? false;
      considerarFds = cfg?.considerarFimSemana ?? false;
      considerarFeriados = cfg?.considerarFeriados ?? false;
      idContaSelecionada = cfg?.idContaBancaria;
    } else {
      // Defaults quando criar nova carteira CDI
      contas = await _contasRepo.getContasBancarias(apenasAtivas: true);
      final fmt2 = NumberFormat('#,##0.00', 'pt_BR');
      limiteCtrl.text = fmt2.format(10000);
      saldoBaseCtrl.text = fmt2.format(0);
      cdiBaseCtrl.text = fmt2.format(0);
      pctAteCtrl.text = fmt2.format(120);
      pctAcimaCtrl.text = fmt2.format(100);
      taxaDiariaCtrl.text = NumberFormat('0.000000', 'pt_BR').format(0.000433);
      aporteCtrl.text = fmt2.format(2000);
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            final def = InvestimentoLayoutCatalog.porId(layoutId);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + mq.viewInsets.bottom + mq.viewPadding.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    item == null ? 'Nova carteira' : 'Editar carteira',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    width: MediaQuery.sizeOf(ctx).width - 32,
                    initialSelection: layoutId,
                    label: const Text('Layout'),
                    dropdownMenuEntries:
                        InvestimentoLayoutCatalog.todos
                            .map(
                              (e) => DropdownMenuEntry<String>(
                                value: e.id,
                                label: e.titulo,
                              ),
                            )
                            .toList(),
                    onSelected: (v) {
                      if (v == null) return;
                      setModal(() => layoutId = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    def?.descricao ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (layoutId == 'cdi_faixas') ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modo de cálculo',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: usarTaxaFixa,
                              onChanged: (v) => setModal(() => usarTaxaFixa = v),
                              title: const Text('Usar taxa fixa (calibrada)'),
                              subtitle: const Text(
                                'Se ligado, usa (saldo + aporte) × taxa diária, e ignora CDI teórico.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: taxaDiariaCtrl,
                                    enabled: usarTaxaFixa,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Taxa diária fixa (decimal)',
                                      hintText: 'Ex: 0,000433',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: aporteCtrl,
                                    enabled: usarTaxaFixa,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Aporte fixo (R\$)',
                                      hintText: 'Ex: 2.000,00',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: idContaSelecionada,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Selecione...'),
                        ),
                        ...contas.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.descricao),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => idContaSelecionada = v),
                      decoration: const InputDecoration(
                        labelText: 'Conta bancária (onde lançar o rendimento)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cdiBaseCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'CDI atual anual (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: saldoBaseCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Saldo base (principal) (R\$)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limiteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Limite da faixa (R\$)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pctAteCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: '% do CDI (até o limite)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: pctAcimaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: '% do CDI (acima do limite)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: considerarFds,
                      onChanged: (v) => setModal(() => considerarFds = v),
                      title: const Text('Considerar fim de semana'),
                      subtitle: const Text('Se desmarcado, considera só dias úteis.'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: considerarFeriados,
                      onChanged: (v) => setModal(() => considerarFeriados = v),
                      title: const Text('Considerar feriados'),
                      subtitle: const Text('Se desmarcado, desconsidera feriados.'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: () async {
                      final nome = nomeCtrl.text.trim();
                      if (nome.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe o nome.')),
                        );
                        return;
                      }
                      if (!InvestimentoLayoutCatalog.existe(layoutId)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Selecione um layout válido.'),
                          ),
                        );
                        return;
                      }
                      final id = await _repo.salvar(
                        InvestimentoCarteira(
                          id: item?.id,
                          nome: nome,
                          layout: layoutId,
                          criadoEm: item?.criadoEm ?? DateTime.now(),
                        ),
                      );

                      if (layoutId == 'cdi_faixas') {
                        final limite = CurrencyInputFormatter.parse(limiteCtrl.text);
                        final saldoBase = CurrencyInputFormatter.parse(saldoBaseCtrl.text);
                        final cdiBase = CurrencyInputFormatter.parse(cdiBaseCtrl.text);
                        final pctAte = CurrencyInputFormatter.parse(pctAteCtrl.text);
                        final pctAcima = CurrencyInputFormatter.parse(pctAcimaCtrl.text);
                        final taxaDiariaFixa = parseNumberPt(taxaDiariaCtrl.text);
                        final aporteFixo = CurrencyInputFormatter.parse(aporteCtrl.text);

                        if (idContaSelecionada == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Selecione a conta bancária.')),
                          );
                          return;
                        }

                        await _cdiCfgRepo.upsert(
                          InvestimentoCdiConfig(
                            idCarteira: item?.id ?? id,
                            limiteFaixa: limite,
                            cdiBaseAnual: cdiBase,
                            pctAteLimite: pctAte,
                            pctAcimaLimite: pctAcima,
                            idContaBancaria: idContaSelecionada,
                            saldoBase: saldoBase,
                            usarTaxaFixa: usarTaxaFixa,
                            taxaDiariaFixa: taxaDiariaFixa,
                            aporteFixo: aporteFixo,
                            considerarFimSemana: considerarFds,
                            considerarFeriados: considerarFeriados,
                            criadoEm: DateTime.now(),
                          ),
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Salvar'),
                  ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    nomeCtrl.dispose();
    limiteCtrl.dispose();
    saldoBaseCtrl.dispose();
    cdiBaseCtrl.dispose();
    pctAteCtrl.dispose();
    pctAcimaCtrl.dispose();
    taxaDiariaCtrl.dispose();
    aporteCtrl.dispose();
    if (ok == true) await _load();
  }

  Future<void> _excluir(InvestimentoCarteira c) async {
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir carteira'),
            content: Text(
              'Isso apaga movimentações e configuração desta carteira. Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await _repo.deletar(c.id!);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = Colors.red.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteiras de investimento'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/investimentos/carteiras'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
              ? const Center(child: Text('Nenhuma carteira cadastrada.'))
              : ListView.builder(
                  padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(12)),
                  itemCount: _itens.length,
                  itemBuilder: (_, i) {
                    final c = _itens[i];
                    final layoutTitulo =
                        InvestimentoLayoutCatalog.tituloOuId(c.layout);
                    return Slidable(
                      key: ValueKey(c.id ?? i),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _abrirMovimentacoes(c),
                            backgroundColor: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.receipt_long,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _openForm(item: c),
                            backgroundColor: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.edit,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) {
                              _excluir(c);
                            },
                            backgroundColor: danger,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.delete,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet_outlined),
                          title: Text(c.nome),
                          subtitle: Text(
                            'Layout: $layoutTitulo • ${_fmt.format(c.criadoEm)}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Abrir carteira',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _abrirCarteira(c),
                          ),
                          onTap: () => _openForm(item: c),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
