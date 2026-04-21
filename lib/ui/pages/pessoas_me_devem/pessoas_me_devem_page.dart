// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/models/pessoa_me_deve.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/pessoas_me_devem/pessoa_me_deve_repository.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart' show TipoMovimento;
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/pages/home/widgets/lancamento_form_bottom_sheet.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class PessoasMeDevemPage extends StatefulWidget {
  const PessoasMeDevemPage({super.key});

  static const routeName = '/pessoas-me-devem';

  @override
  State<PessoasMeDevemPage> createState() => _PessoasMeDevemPageState();
}

class _PessoasMeDevemPageState extends State<PessoasMeDevemPage> {
  final _repo = PessoaMeDeveRepository();
  final _contaRepo = ContaBancariaRepository();
  final _cartaoRepo = CartaoCreditoRepository();
  final _lancRepo = LancamentoRepository();

  final _fmtMoney = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _fmtData = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<PessoaMeDeve> _itens = const [];
  double _totalPendente = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final itens = await _repo.listar();
    final tot = await _repo.totalPendente();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _totalPendente = tot;
      _loading = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _parseValor(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll('R\$', '').replaceAll(' ', '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  Future<void> _novo() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _CadastroPessoaSheet(fmtData: _fmtData, parseValor: _parseValor),
    );
    if (ok == true) {
      await _load();
      _snack('Registro salvo.');
    }
  }

  Future<void> _receber(PessoaMeDeve p) async {
    if (p.id == null || p.quitado) return;
    final contas = await _contaRepo.getContasBancarias(apenasAtivas: true);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (ctx) => _RecebimentoSheet(
            pessoa: p,
            contas: contas,
            fmtMoney: _fmtMoney,
            fmtData: _fmtData,
            parseValor: _parseValor,
          ),
    );
    if (ok == true) {
      await _load();
      _snack('Lançamento de receita registrado.');
    }
  }

  Future<void> _editar(PessoaMeDeve p) async {
    if (p.id == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (ctx) => _CadastroPessoaSheet(
            inicial: p,
            bloquearValorTotal: p.valorRecebido > 0.009,
            fmtData: _fmtData,
            parseValor: _parseValor,
          ),
    );
    if (ok == true) {
      await _load();
      _snack('Registro atualizado.');
    }
  }

  Future<void> _registrarCompraNoCartao(PessoaMeDeve p) async {
    // 1) Carrega combos do form de lançamento (igual ao fluxo da Home)
    final cartoes = await _cartaoRepo.getCartoesCredito();
    final contas = await _contaRepo.getContasBancarias(apenasAtivas: true);

    final grupoDespesa = 'PMD_COMPRA_${DateTime.now().millisecondsSinceEpoch}';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return LancamentoFormBottomSheet(
          dataSelecionada: DateTime.now(),
          currency: _fmtMoney,
          dateDiaFormat: _fmtData,
          dbService: DbService.instance,
          cartoes: cartoes,
          contas: contas,
          tipoInicial: TipoMovimento.despesa,
          formaInicial: FormaPagamento.credito,
          pagamentoFaturaInicial: false,
          descricaoInicial: 'Compra para ${p.nome}',
          grupoParcelasForcado: grupoDespesa,
          onSaved: () async {
            // nada aqui; o repo do form já salva
          },
          onSavedLancamento: (_) {},
        );
      },
    );

    // 2) Depois do fechamento do sheet, tenta localizar as parcelas criadas pelo grupo
    final parcelas = await _lancRepo.getParcelasPorGrupo(grupoDespesa);
    if (parcelas.isEmpty) return;

    // pega base do grupo
    final base = parcelas.first;
    final qtd = parcelas.length;
    final total = parcelas.fold<double>(0, (s, e) => s + e.valor);
    final idCartao = base.idCartao;
    if (idCartao == null) return;

    final cartao = await _cartaoRepo.getCartaoCreditoById(idCartao);
    if (cartao == null || cartao.diaFechamento == null || cartao.diaVencimento == null) {
      return;
    }

    // 3) Gera receitas parceladas (previstas) no vencimento do cartão
    final grupoReceitas = 'PMD_RECEITA_$grupoDespesa';
    await _repo.gerarReceitasParceladasCompraCartao(
      nomePessoa: p.nome,
      observacao: base.descricao,
      valorTotal: double.parse(total.toStringAsFixed(2)),
      dataCompra: base.dataHora,
      parcelasTotal: qtd,
      diaFechamento: cartao.diaFechamento!,
      diaVencimento: cartao.diaVencimento!,
      grupoParcelas: grupoReceitas,
    );

    await _repo.gerarDespesasParceladasNoVencimentoCartao(
      nomePessoa: p.nome,
      observacao: base.descricao,
      valorTotal: double.parse(total.toStringAsFixed(2)),
      dataCompra: base.dataHora,
      parcelasTotal: qtd,
      idCartao: idCartao,
      diaFechamento: cartao.diaFechamento!,
      diaVencimento: cartao.diaVencimento!,
      grupoParcelasPrefixo: grupoReceitas,
    );

    // 4) Registra um item em "pessoas que me devem" como controle desse parcelado
    await _repo.inserir(
      nome: p.nome,
      dataEmprestimo: base.dataHora,
      valorTotal: double.parse(total.toStringAsFixed(2)),
      observacao: base.descricao,
      compraCartao: true,
      idCartao: idCartao,
      parcelasTotal: qtd,
      grupoReceitas: grupoReceitas,
    );

    await _load();
    _snack('Compra registrada e receitas parceladas geradas.');
  }

  Future<void> _confirmarExcluir(PessoaMeDeve p) async {
    if (p.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir registro?'),
            content: Text('Remover "${p.nome}" da lista de quem te deve?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
            ],
          ),
    );
    if (ok != true) return;
    await _repo.deletar(p.id!);
    await _load();
    _snack('Registro removido.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pessoas que me devem'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      drawer: const AppDrawer(currentRoute: PessoasMeDevemPage.routeName),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Novo'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: SlidableAutoCloseBehavior(
                  child: ListView(
                    padding: listViewPaddingWithBottomInset(
                      context,
                      const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    ),
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text('Total a receber'),
                          trailing: Text(
                            _fmtMoney.format(_totalPendente),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_itens.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: Text('Nenhum cadastro ainda.')),
                        )
                      else
                        ..._itens.map(_tile),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _tile(PessoaMeDeve p) {
    final pendente = p.valorPendente;
    final cs = Theme.of(context).colorScheme;

    String? cartaoLabel() {
      final id = p.idCartao;
      if (id == null) return null;
      try {
        // _CadastroPessoaSheet carrega os cartões, mas aqui não.
        // Exibe só o id caso ainda não esteja carregado em memória.
        return 'Cartão #$id';
      } catch (_) {
        return 'Cartão #$id';
      }
    }

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(p.nome),
        subtitle: Text(
          [
            (p.compraCartao
                ? 'Compra: ${_fmtData.format(p.dataEmprestimo)}'
                : 'Empréstimo: ${_fmtData.format(p.dataEmprestimo)}'),
            if (p.observacao != null && p.observacao!.isNotEmpty) p.observacao!,
            if (p.compraCartao && p.parcelasTotal != null)
              'No cartão • ${p.parcelasTotal}x'
              '${p.idCartao == null ? '' : ' • ${cartaoLabel()}'}',
            'Emprestado: ${_fmtMoney.format(p.valorTotal)}',
            if (p.valorRecebido > 0.009)
              'Recebido: ${_fmtMoney.format(p.valorRecebido)}',
          ].join(' · '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _fmtMoney.format(pendente),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    p.quitado
                        ? Colors.green.withValues(alpha: 0.15)
                        : cs.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                p.quitado ? 'Quitado' : 'Pendente',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      p.quitado
                          ? Colors.green.shade800
                          : cs.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        onTap: p.quitado ? null : () => _receber(p),
      ),
    );

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final success = Colors.green.shade600;
    final danger = Colors.red.shade400;

    return Slidable(
      key: ValueKey('pessoa-me-deve-${p.id}'),
      groupTag: 'pessoas_me_devem',
      startActionPane:
          p.quitado
              ? null
              : ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.40,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => _receber(p),
                    backgroundColor: success,
                    borderRadius: BorderRadius.circular(12),
                    child: const Icon(
                      Icons.check_circle,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  CustomSlidableAction(
                    onPressed: (_) => _registrarCompraNoCartao(p),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _editar(p),
            backgroundColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Icon(Icons.edit, size: 28, color: primary),
          ),
          CustomSlidableAction(
            onPressed: (_) => _confirmarExcluir(p),
            backgroundColor: danger,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(Icons.delete, size: 28, color: Colors.white),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _CadastroPessoaSheet extends StatefulWidget {
  final PessoaMeDeve? inicial;
  final bool bloquearValorTotal;
  final DateFormat fmtData;
  final double Function(String) parseValor;

  const _CadastroPessoaSheet({
    this.inicial,
    this.bloquearValorTotal = false,
    required this.fmtData,
    required this.parseValor,
  });

  @override
  State<_CadastroPessoaSheet> createState() => _CadastroPessoaSheetState();
}

class _CadastroPessoaSheetState extends State<_CadastroPessoaSheet> {
  late final TextEditingController _nome;
  late final TextEditingController _valor;
  late final TextEditingController _obs;
  late final TextEditingController _parcelas;
  late DateTime _data;
  bool _saving = false;
  bool _compraCartao = false;
  CartaoCredito? _cartao;
  List<CartaoCredito> _cartoes = const [];

  final _repo = PessoaMeDeveRepository();
  final _cartaoRepo = CartaoCreditoRepository();

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nome = TextEditingController(text: i?.nome ?? '');
    _valor = TextEditingController(
      text: i != null ? i.valorTotal.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _obs = TextEditingController(text: i?.observacao ?? '');
    _parcelas = TextEditingController(
      text: (i?.parcelasTotal ?? 8).toString(),
    );
    _data = i?.dataEmprestimo ?? DateTime.now();
    _compraCartao = i?.compraCartao ?? false;
    _loadCartoes();
  }

  Future<void> _loadCartoes() async {
    final list = await _cartaoRepo.getCartoesCredito();
    if (!mounted) return;
    setState(() {
      _cartoes = list.where((c) => c.id != null && c.diaVencimento != null && c.diaFechamento != null).toList();
      final initId = widget.inicial?.idCartao;
      if (initId != null) {
        try {
          _cartao = _cartoes.firstWhere((c) => c.id == initId);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _valor.dispose();
    _obs.dispose();
    _parcelas.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _salvar() async {
    if (_saving) return;
    final nome = _nome.text.trim();
    final v = widget.bloquearValorTotal
        ? (widget.inicial?.valorTotal ?? 0)
        : widget.parseValor(_valor.text);
    if (nome.isEmpty || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e valor válidos.')),
      );
      return;
    }

    final i = widget.inicial;
    final parcelas = int.tryParse(_parcelas.text.trim()) ?? 0;
    if (_compraCartao) {
      if (_cartao?.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o cartão.')),
        );
        return;
      }
      if (parcelas < 2 || parcelas > 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um número de parcelas válido (2..60).')),
        );
        return;
      }
      if (_cartao!.diaFechamento == null || _cartao!.diaVencimento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cartão sem dia de fechamento/vencimento configurado.')),
        );
        return;
      }
    }
    if (i?.id != null &&
        !widget.bloquearValorTotal &&
        v < i!.valorRecebido - 0.009) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O valor total não pode ser menor que o já recebido (${i.valorRecebido.toStringAsFixed(2)}).',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final obs = _obs.text.trim();

    if (i?.id != null) {
      await _repo.atualizar(
        PessoaMeDeve(
          id: i!.id,
          nome: nome,
          dataEmprestimo: _data,
          valorTotal: v,
          valorRecebido: i.valorRecebido,
          observacao: obs.isEmpty ? null : obs,
          compraCartao: i.compraCartao,
          idCartao: i.idCartao,
          parcelasTotal: i.parcelasTotal,
          grupoReceitas: i.grupoReceitas,
          criadoEm: i.criadoEm,
        ),
      );
    } else {
      if (_compraCartao) {
        final grupo = 'PMD_${DateTime.now().millisecondsSinceEpoch}';
        await _repo.inserir(
          nome: nome,
          dataEmprestimo: _data,
          valorTotal: v,
          observacao: obs.isEmpty ? null : obs,
          compraCartao: true,
          idCartao: _cartao!.id,
          parcelasTotal: parcelas,
          grupoReceitas: grupo,
        );

        await _repo.gerarReceitasParceladasCompraCartao(
          nomePessoa: nome,
          observacao: obs.isEmpty ? null : obs,
          valorTotal: v,
          dataCompra: _data,
          parcelasTotal: parcelas,
          diaFechamento: _cartao!.diaFechamento!,
          diaVencimento: _cartao!.diaVencimento!,
          grupoParcelas: grupo,
        );

        await _repo.gerarDespesasParceladasNoVencimentoCartao(
          nomePessoa: nome,
          observacao: obs.isEmpty ? null : obs,
          valorTotal: v,
          dataCompra: _data,
          parcelasTotal: parcelas,
          idCartao: _cartao!.id!,
          diaFechamento: _cartao!.diaFechamento!,
          diaVencimento: _cartao!.diaVencimento!,
          grupoParcelasPrefixo: grupo,
        );
      } else {
        await _repo.inserir(
          nome: nome,
          dataEmprestimo: _data,
          valorTotal: v,
          observacao: obs.isEmpty ? null : obs,
        );
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.inicial == null ? 'Novo — quem te deve' : 'Editar',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nome,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compra no meu cartão (parcelado)'),
                subtitle: const Text('Gera lançamentos de receita parcelados no vencimento do cartão.'),
                value: _compraCartao,
                onChanged:
                    widget.inicial != null
                        ? null
                        : (v) => setState(() => _compraCartao = v),
              ),
              if (_compraCartao) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CartaoCredito?>(
                      isExpanded: true,
                      value: _cartao,
                      items: [
                        const DropdownMenuItem<CartaoCredito?>(
                          value: null,
                          child: Text('Selecione'),
                        ),
                        ..._cartoes.map(
                          (c) => DropdownMenuItem<CartaoCredito?>(
                            value: c,
                            child: Text(c.label),
                          ),
                        ),
                      ],
                      onChanged:
                          (v) => setState(() => _cartao = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _parcelas,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Parcelas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_compraCartao ? 'Data da compra' : 'Data do empréstimo'),
                subtitle: Text(widget.fmtData.format(_data)),
                trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickData),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valor,
                readOnly: widget.bloquearValorTotal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor',
                  border: const OutlineInputBorder(),
                  prefixText: r'R$ ',
                  helperText:
                      widget.bloquearValorTotal
                          ? 'Valor total bloqueado após recebimentos.'
                          : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _obs,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _salvar,
                icon: const Icon(Icons.save_outlined),
                label: Text(widget.inicial == null ? 'Salvar' : 'Atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecebimentoSheet extends StatefulWidget {
  final PessoaMeDeve pessoa;
  final List<ContaBancaria> contas;
  final NumberFormat fmtMoney;
  final DateFormat fmtData;
  final double Function(String) parseValor;

  const _RecebimentoSheet({
    required this.pessoa,
    required this.contas,
    required this.fmtMoney,
    required this.fmtData,
    required this.parseValor,
  });

  @override
  State<_RecebimentoSheet> createState() => _RecebimentoSheetState();
}

class _RecebimentoSheetState extends State<_RecebimentoSheet> {
  late final TextEditingController _valor;
  late DateTime _data;
  FormaPagamento _forma = FormaPagamento.pix;
  int? _idConta;
  bool _saving = false;

  final _repo = PessoaMeDeveRepository();

  @override
  void initState() {
    super.initState();
    final p = widget.pessoa.valorPendente;
    _valor = TextEditingController(text: p.toStringAsFixed(2).replaceAll('.', ','));
    _data = DateTime.now();
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _confirmar() async {
    if (_saving) return;
    final v = widget.parseValor(_valor.text);
    if (v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.registrarRecebimentoComLancamento(
        idPessoa: widget.pessoa.id!,
        valor: v,
        dataRecebimento: _data,
        formaPagamento: _forma,
        idConta: _idConta,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final pendente = widget.pessoa.valorPendente;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recebimento — ${widget.pessoa.nome}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Pendente: ${widget.fmtMoney.format(pendente)} · Empréstimo: ${widget.fmtData.format(widget.pessoa.dataEmprestimo)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor recebido',
                  border: OutlineInputBorder(),
                  prefixText: r'R$ ',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data do recebimento'),
                subtitle: Text(widget.fmtData.format(_data)),
                trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickData),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Forma de recebimento',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<FormaPagamento>(
                    isExpanded: true,
                    value: _forma,
                    items: [
                      FormaPagamento.pix,
                      FormaPagamento.dinheiro,
                      FormaPagamento.debito,
                      FormaPagamento.transferencia,
                      FormaPagamento.outros,
                    ].map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
                    onChanged: (v) => setState(() => _forma = v ?? _forma),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Conta bancária (opcional)',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _idConta,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Não vincular')),
                      ...widget.contas.map(
                        (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.descricao)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _idConta = v),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Será criado um lançamento de receita (pago) na data escolhida.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _confirmar,
                icon: const Icon(Icons.check),
                label: const Text('Confirmar recebimento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
