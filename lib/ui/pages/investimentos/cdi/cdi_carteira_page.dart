import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/core/service/investimento_cdi_service.dart';
import 'package:vox_finance/ui/data/models/investimento_cdi_config.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/modules/contas_bancarias/conta_bancaria_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_config_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_rendimentos_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_movimentos_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';
import 'package:vox_finance/ui/pages/investimentos/cdi/cdi_movimentacoes_page.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class CdiCarteiraPage extends StatefulWidget {
  final int idCarteira;
  final String nomeCarteira;

  const CdiCarteiraPage({
    super.key,
    required this.idCarteira,
    required this.nomeCarteira,
  });

  @override
  State<CdiCarteiraPage> createState() => _CdiCarteiraPageState();
}

class _CdiCarteiraPageState extends State<CdiCarteiraPage> {
  final _repo = InvestimentoCdiConfigRepository();
  final _contasRepo = ContaBancariaRepository();
  final _svc = InvestimentoCdiService();
  final _rendRepo = InvestimentoCdiRendimentosRepository();
  final _movRepo = InvestimentoCdiMovimentosRepository();
  final _lancRepo = LancamentoRepository();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

  bool _loading = true;
  bool _saving = false;
  bool _processando = false;
  bool _recalculando = false;
  List<InvestimentoCdiRendimentoRow> _rendimentos = const [];
  List<({int ano, int mes, double total})> _rendimentosPorMes = const [];
  List<InvestimentoCdiMovimentoRow> _movimentos = const [];
  double _saldoBaseAtual = 0;

  final _limiteCtrl = TextEditingController();
  final _saldoBaseCtrl = TextEditingController();
  final _cdiBaseCtrl = TextEditingController();
  final _pctAteCtrl = TextEditingController();
  final _pctAcimaCtrl = TextEditingController();
  final _taxaDiariaCtrl = TextEditingController();
  final _aporteCtrl = TextEditingController();

  bool _considerarFds = false;
  bool _considerarFeriados = false;
  bool _usarTaxaFixa = false;
  int? _idContaSelecionada;
  List<ContaBancaria> _contas = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _limiteCtrl.dispose();
    _saldoBaseCtrl.dispose();
    _cdiBaseCtrl.dispose();
    _pctAteCtrl.dispose();
    _pctAcimaCtrl.dispose();
    _taxaDiariaCtrl.dispose();
    _aporteCtrl.dispose();
    super.dispose();
  }

  double _parseNumberPt(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  Future<void> _editarRendimentoDia(InvestimentoCdiRendimentoRow r) async {
    final ctrl = TextEditingController(
      text: NumberFormat('#,##0.00', 'pt_BR').format(r.rendimentoValor),
    );
    final novo = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar rendimento — ${_dateFmt.format(r.data)}'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rendeu (R\$)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = CurrencyInputFormatter.parse(ctrl.text);
                Navigator.pop(ctx, v);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (novo == null) return;

    await _rendRepo.atualizarRendimentoValor(id: r.id, rendimentoValor: novo);
    final idLanc = r.idLancamento;
    if (idLanc != null) {
      final lanc = await _lancRepo.getById(idLanc);
      if (lanc != null) {
        lanc.valor = novo;
        await _lancRepo.salvar(lanc);
      }
    }

    final rend = await _rendRepo.listarPorCarteira(widget.idCarteira);
    final porMes = await _rendRepo.totalPorMes(widget.idCarteira);
    final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
    if (!mounted) return;
    setState(() {
      _rendimentos = rend;
      _rendimentosPorMes = porMes;
      _movimentos = movs;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rendimento do dia atualizado.')),
    );
  }

  List<Widget> _buildPorMesCards(BuildContext context) {
    if (_rendimentosPorMes.isEmpty) return const [];
    final fmt = DateFormat('MMM/yyyy', 'pt_BR');
    final out = <Widget>[];
    for (final m in _rendimentosPorMes) {
      final ref = DateTime(m.ano, m.mes, 1);
      out.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            dense: true,
            title: Text(fmt.format(ref)),
            trailing: Text(
              _currency.format(m.total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }
    return out;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await _repo.porCarteira(widget.idCarteira);
    final contas = await _contasRepo.getContasBancarias(apenasAtivas: true);
    final rend = await _rendRepo.listarPorCarteira(widget.idCarteira);
    final porMes = await _rendRepo.totalPorMes(widget.idCarteira);
    final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
    if (!mounted) return;

    final limite = cfg?.limiteFaixa ?? 10000;
    _saldoBaseAtual = cfg?.saldoBase ?? 0;
    _limiteCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(limite);
    _saldoBaseCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(
      cfg?.saldoBase ?? 0,
    );
    _cdiBaseCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(
      cfg?.cdiBaseAnual ?? 0,
    );
    _pctAteCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(
      cfg?.pctAteLimite ?? 0,
    );
    _pctAcimaCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(
      cfg?.pctAcimaLimite ?? 0,
    );
    _taxaDiariaCtrl.text = NumberFormat('0.000000', 'pt_BR').format(
      cfg?.taxaDiariaFixa ?? 0.000433,
    );
    _aporteCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(
      cfg?.aporteFixo ?? 2000,
    );
    _idContaSelecionada = cfg?.idContaBancaria;
    _considerarFds = cfg?.considerarFimSemana ?? false;
    _considerarFeriados = cfg?.considerarFeriados ?? false;
    _usarTaxaFixa = cfg?.usarTaxaFixa ?? false;

    setState(() {
      _contas = contas;
      _rendimentos = rend;
      _rendimentosPorMes = porMes;
      _movimentos = movs;
      _loading = false;
    });

    // tenta processar automaticamente (se tiver config completa)
    await _processar();
  }

  Future<void> _save() async {
    if (_saving) return;
    final limite = CurrencyInputFormatter.parse(_limiteCtrl.text);
    final saldoBase = CurrencyInputFormatter.parse(_saldoBaseCtrl.text);
    final cdiBase = CurrencyInputFormatter.parse(_cdiBaseCtrl.text);
    final pctAte = CurrencyInputFormatter.parse(_pctAteCtrl.text);
    final pctAcima = CurrencyInputFormatter.parse(_pctAcimaCtrl.text);
    final taxaDiariaFixa = _parseNumberPt(_taxaDiariaCtrl.text);
    final aporteFixo = CurrencyInputFormatter.parse(_aporteCtrl.text);

    if (limite <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um limite válido.')),
      );
      return;
    }
    if (cdiBase <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o CDI atual anual (%).')),
      );
      return;
    }
    if (pctAte <= 0 || pctAcima <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o % do CDI nas duas faixas.')),
      );
      return;
    }
    if (saldoBase <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o saldo base (principal).')),
      );
      return;
    }
    if (_usarTaxaFixa && taxaDiariaFixa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma taxa diária fixa válida.')),
      );
      return;
    }
    if (_idContaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a conta bancária.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      _saldoBaseAtual = saldoBase;
      await _repo.upsert(
        InvestimentoCdiConfig(
          idCarteira: widget.idCarteira,
          limiteFaixa: limite,
          cdiBaseAnual: cdiBase,
          pctAteLimite: pctAte,
          pctAcimaLimite: pctAcima,
          idContaBancaria: _idContaSelecionada,
          saldoBase: saldoBase,
          usarTaxaFixa: _usarTaxaFixa,
          taxaDiariaFixa: taxaDiariaFixa,
          aporteFixo: aporteFixo,
          considerarFimSemana: _considerarFds,
          considerarFeriados: _considerarFeriados,
          criadoEm: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configuração salva. Limite: ${_currency.format(limite)}',
          ),
        ),
      );
      await _recalcularAoSalvar(
        usarTaxaFixa: _usarTaxaFixa,
        taxaDiariaFixa: taxaDiariaFixa,
        aporteFixo: aporteFixo,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recalcularAoSalvar({
    required bool usarTaxaFixa,
    required double taxaDiariaFixa,
    required double aporteFixo,
  }) async {
    if (_recalculando) return;
    setState(() => _recalculando = true);
    try {
      final idsLanc = await _rendRepo.listarIdsLancamentoPorCarteira(
        widget.idCarteira,
      );
      for (final id in idsLanc) {
        await _lancRepo.deletar(id);
      }
      await _rendRepo.deletarPorCarteira(widget.idCarteira);

      if (usarTaxaFixa) {
        await _svc.processarAteHoje(
          idCarteira: widget.idCarteira,
          nomeCarteira: widget.nomeCarteira,
          taxaDiariaFixa: taxaDiariaFixa,
          aporteFixo: aporteFixo,
        );
      } else {
        await _svc.processarAteHoje(
          idCarteira: widget.idCarteira,
          nomeCarteira: widget.nomeCarteira,
        );
      }

      final rend = await _rendRepo.listarPorCarteira(widget.idCarteira);
      final porMes = await _rendRepo.totalPorMes(widget.idCarteira);
      final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
      if (!mounted) return;
      setState(() {
        _rendimentos = rend;
        _rendimentosPorMes = porMes;
        _movimentos = movs;
      });
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  Future<void> _registrarSaque() async {
    if (_loading || _saving || _recalculando) return;

    final ctrl = TextEditingController(text: '0,00');
    final saque = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Registrar saque'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor do saque (R\$)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = CurrencyInputFormatter.parse(ctrl.text);
                Navigator.pop(ctx, v);
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
    // Não damos dispose aqui para evitar "used after disposed" durante
    // o teardown do dialog (pode rebuildar 1 frame após pop).
    if (saque == null) return;
    if (saque <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor de saque válido.')),
      );
      return;
    }

    final saldoAtual = CurrencyInputFormatter.parse(_saldoBaseCtrl.text);
    final novoSaldo = (saldoAtual - saque);
    if (novoSaldo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saque maior que o saldo base.')),
      );
      return;
    }

    // Atualiza o campo e persiste, depois recalcula para refletir juros compostos
    _saldoBaseCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(novoSaldo);
    _saldoBaseAtual = novoSaldo;
    if (mounted) setState(() {});

    final limite = CurrencyInputFormatter.parse(_limiteCtrl.text);
    final cdiBase = CurrencyInputFormatter.parse(_cdiBaseCtrl.text);
    final pctAte = CurrencyInputFormatter.parse(_pctAteCtrl.text);
    final pctAcima = CurrencyInputFormatter.parse(_pctAcimaCtrl.text);
    final taxaDiariaFixa = _parseNumberPt(_taxaDiariaCtrl.text);
    final aporteFixo = CurrencyInputFormatter.parse(_aporteCtrl.text);

    setState(() => _saving = true);
    try {
      await _repo.upsert(
        InvestimentoCdiConfig(
          idCarteira: widget.idCarteira,
          limiteFaixa: limite,
          cdiBaseAnual: cdiBase,
          pctAteLimite: pctAte,
          pctAcimaLimite: pctAcima,
          idContaBancaria: _idContaSelecionada,
          saldoBase: novoSaldo,
          usarTaxaFixa: _usarTaxaFixa,
          taxaDiariaFixa: taxaDiariaFixa,
          aporteFixo: aporteFixo,
          considerarFimSemana: _considerarFds,
          considerarFeriados: _considerarFeriados,
          criadoEm: DateTime.now(),
        ),
      );

      await _movRepo.inserir(
        idCarteira: widget.idCarteira,
        data: DateTime.now(),
        tipo: InvestimentoCdiMovimentoTipo.saque,
        valor: saque,
      );

      await _recalcularAoSalvar(
        usarTaxaFixa: _usarTaxaFixa,
        taxaDiariaFixa: taxaDiariaFixa,
        aporteFixo: aporteFixo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saque aplicado: ${_currency.format(saque)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmarExcluirMovimento(int? idMov, String tipo) async {
    if (idMov == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Excluir movimentação'),
          content: Text(
            'Isso vai excluir este ${tipo == 'saque' ? 'saque' : 'aporte'} e recalcular o histórico.\n\nContinuar?',
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
        );
      },
    );
    if (ok != true) return;

    // desfaz o efeito no saldo base (undo)
    final cfg = await _repo.porCarteira(widget.idCarteira);
    if (cfg == null) return;

    final mov = _movimentos.firstWhere((m) => m.id == idMov);
    final novoSaldo = mov.tipo == InvestimentoCdiMovimentoTipo.saque
        ? (cfg.saldoBase + mov.valor)
        : (cfg.saldoBase - mov.valor);

    _saldoBaseAtual = novoSaldo;
    _saldoBaseCtrl.text = NumberFormat('#,##0.00', 'pt_BR').format(novoSaldo);

    setState(() => _saving = true);
    try {
      await _movRepo.deletar(idMov);
      await _repo.upsert(
        InvestimentoCdiConfig(
          idCarteira: cfg.idCarteira,
          limiteFaixa: cfg.limiteFaixa,
          cdiBaseAnual: cfg.cdiBaseAnual,
          pctAteLimite: cfg.pctAteLimite,
          pctAcimaLimite: cfg.pctAcimaLimite,
          idContaBancaria: cfg.idContaBancaria,
          saldoBase: novoSaldo,
          usarTaxaFixa: cfg.usarTaxaFixa,
          taxaDiariaFixa: cfg.taxaDiariaFixa,
          aporteFixo: cfg.aporteFixo,
          considerarFimSemana: cfg.considerarFimSemana,
          considerarFeriados: cfg.considerarFeriados,
          criadoEm: DateTime.now(),
        ),
      );

      await _recalcularAoSalvar(
        usarTaxaFixa: cfg.usarTaxaFixa,
        taxaDiariaFixa: cfg.taxaDiariaFixa,
        aporteFixo: cfg.aporteFixo,
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmarExcluirRendimento(InvestimentoCdiRendimentoRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Excluir rendimento'),
          content: Text(
            'Excluir o rendimento de ${_dateFmt.format(r.data)} e o lançamento vinculado.\n\nContinuar?',
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
        );
      },
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final idLanc = r.idLancamento;
      if (idLanc != null) {
        await _lancRepo.deletar(idLanc);
      }
      await _rendRepo.deletar(r.id);

      final rend = await _rendRepo.listarPorCarteira(widget.idCarteira);
      final porMes = await _rendRepo.totalPorMes(widget.idCarteira);
      final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
      if (!mounted) return;
      setState(() {
        _rendimentos = rend;
        _rendimentosPorMes = porMes;
        _movimentos = movs;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _processar() async {
    if (_processando) return;
    setState(() => _processando = true);
    try {
      final n = await _svc.processarAteHoje(
        idCarteira: widget.idCarteira,
        nomeCarteira: widget.nomeCarteira,
      );
      if (!mounted) return;
      final rend = await _rendRepo.listarPorCarteira(widget.idCarteira);
      final porMes = await _rendRepo.totalPorMes(widget.idCarteira);
      final movs = await _movRepo.listarPorCarteira(widget.idCarteira);
      if (!mounted) return;
      setState(() {
        _rendimentos = rend;
        _rendimentosPorMes = porMes;
        _movimentos = movs;
      });
      if (n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gerados $n lançamento(s) de rendimento.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _recalcularHistorico() async {
    if (_recalculando) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Recalcular histórico'),
          content: const Text(
            'Isso vai apagar os lançamentos de rendimento já gerados desta carteira '
            'e recalcular tudo novamente.\n\nContinuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Recalcular'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    // Reusa o mesmo fluxo que apaga lançamentos + histórico + recalcula,
    // garantindo que os lançamentos fiquem sempre consistentes com o cálculo atual.
    final taxaDiariaFixa = _parseNumberPt(_taxaDiariaCtrl.text);
    final aporteFixo = CurrencyInputFormatter.parse(_aporteCtrl.text);
    await _recalcularAoSalvar(
      usarTaxaFixa: _usarTaxaFixa,
      taxaDiariaFixa: taxaDiariaFixa,
      aporteFixo: aporteFixo,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('CDI — ${widget.nomeCarteira}'),
        actions: [
          IconButton(
            tooltip: 'Registrar saque (abate do saldo base)',
            onPressed: _loading ? null : _registrarSaque,
            icon: const Icon(Icons.outbox_outlined),
          ),
          IconButton(
            tooltip: 'Recalcular histórico',
            onPressed: _loading ? null : _recalcularHistorico,
            icon: _recalculando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Processar rendimentos',
            onPressed: _loading ? null : _processar,
            icon: _processando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt),
          ),
          IconButton(
            tooltip: 'Salvar',
            onPressed: _loading ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: listViewPaddingWithBottomInset(
                context,
                const EdgeInsets.all(16),
              ),
              children: [
                _ResumoCdiCard(
                  totalRendido: _rendimentos.fold<double>(
                    0,
                    (s, r) => s + r.rendimentoValor,
                  ),
                  saldoAtual:
                      _saldoBaseAtual +
                      _rendimentos.fold<double>(0, (s, r) => s + r.rendimentoValor),
                  onTap: () async {
                    final saldoInicial =
                        _saldoBaseAtual;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CdiMovimentacoesPage(
                          idCarteira: widget.idCarteira,
                          nomeCarteira: widget.nomeCarteira,
                          saldoInicial: saldoInicial,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Configurações da carteira',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Regra: até o limite usa um % do CDI, acima usa outro.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Modo de cálculo',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _usarTaxaFixa,
                          onChanged: (v) => setState(() => _usarTaxaFixa = v),
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
                                controller: _taxaDiariaCtrl,
                                enabled: _usarTaxaFixa,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                controller: _aporteCtrl,
                                enabled: _usarTaxaFixa,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _idContaSelecionada,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Selecione...'),
                    ),
                    ..._contas.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.descricao),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _idContaSelecionada = v),
                  decoration: const InputDecoration(
                    labelText: 'Conta bancária (onde lançar o rendimento)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cdiBaseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'CDI atual anual (%)',
                    hintText: 'Ex: 14,79',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _saldoBaseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo base (principal) (R\$)',
                    hintText: 'Ex: 15000,00',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _limiteCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Limite da faixa (R\$)',
                    hintText: 'Ex: 10000,00',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pctAteCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '% do CDI (até o limite)',
                          hintText: 'Ex: 100,00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pctAcimaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '% do CDI (acima do limite)',
                          hintText: 'Ex: 100,00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _considerarFds,
                  onChanged: (v) => setState(() => _considerarFds = v),
                  title: const Text('Considerar fim de semana'),
                  subtitle: const Text('Se desmarcado, considera só dias úteis.'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _considerarFeriados,
                  onChanged: (v) => setState(() => _considerarFeriados = v),
                  title: const Text('Considerar feriados'),
                  subtitle: const Text('Se desmarcado, desconsidera feriados.'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando...' : 'Salvar configurações'),
                ),

                const SizedBox(height: 18),
                Text(
                  'Rendeu por mês',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Soma de rendimentos por mês (baseado no histórico).',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (_rendimentosPorMes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sem dados mensais ainda.'),
                  )
                else
                  ..._buildPorMesCards(context),

                const SizedBox(height: 18),
                Text(
                  'Histórico (dia a dia)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Data, taxa aplicada, quanto rendeu e saldo após o dia.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (_rendimentos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sem rendimentos lançados ainda.'),
                  )
                else
                  ..._buildHistoricoCards(context),
              ],
            ),
    );
  }

  List<Widget> _buildHistoricoCards(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final events = <({DateTime data, String tipo, double valor, int? idRend, int? idMov})>[];

    for (final r in _rendimentos) {
      events.add((
        data: r.data,
        tipo: 'rendimento',
        valor: r.rendimentoValor,
        idRend: r.id,
        idMov: null,
      ));
    }
    for (final m in _movimentos) {
      final tipo =
          (m.tipo == InvestimentoCdiMovimentoTipo.saque) ? 'saque' : 'aporte';
      final valor =
          (m.tipo == InvestimentoCdiMovimentoTipo.saque) ? -m.valor : m.valor;
      events.add((data: m.data, tipo: tipo, valor: valor, idRend: null, idMov: m.id));
    }

    // Saldo após o dia: mantém o mesmo comportamento antigo (só rendimentos),
    // para evitar dupla-contagem quando houver "saque" (o saldoBase já foi abatido).
    final ascRend = List<InvestimentoCdiRendimentoRow>.from(_rendimentos)
      ..sort((a, b) => a.data.compareTo(b.data));
    double saldo = CurrencyInputFormatter.parse(_saldoBaseCtrl.text);
    final saldoAposPorRendId = <int, double>{};
    for (final r in ascRend) {
      saldo += r.rendimentoValor;
      saldoAposPorRendId[r.id] = saldo;
    }

    // Render como lista DESC (mais recente no topo).
    final desc = List.of(events)..sort((a, b) => b.data.compareTo(a.data));
    final out = <Widget>[];
    for (final e in desc) {
      final isRendimento = e.tipo == 'rendimento';
      final titulo = _dateFmt.format(e.data);

      Text? subtitle;
      VoidCallback? onLongPress;

      if (!isRendimento) {
        subtitle = Text(
          e.tipo == 'saque' ? 'Saque' : 'Aporte',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        );
      } else {
        final r = _rendimentos.firstWhere((x) => x.id == e.idRend);
        subtitle = Text(
          'Taxa aplicada: ${r.pctCdi.toStringAsFixed(4).replaceAll('.', ',')}%',
          style: TextStyle(color: cs.onSurfaceVariant),
        );
        onLongPress = () => _editarRendimentoDia(r); // fallback
      }

      final saldoApos =
          isRendimento ? (saldoAposPorRendId[e.idRend!] ?? 0) : null;

      final Widget tile = Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          dense: true,
          title: Text(titulo),
          subtitle: subtitle,
          onLongPress: onLongPress,
          trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(e.valor),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: e.valor < 0 ? Colors.red.shade700 : null,
                  ),
                ),
                if (saldoApos != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Saldo: ${_currency.format(saldoApos)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
        ),
      );

      final actions = <Widget>[];
      if (isRendimento && e.idRend != null) {
        final r = _rendimentos.firstWhere((x) => x.id == e.idRend);
        actions.addAll([
          CustomSlidableAction(
            onPressed: (_) => _editarRendimentoDia(r),
            backgroundColor: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.edit,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _confirmarExcluirRendimento(r),
            backgroundColor: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(Icons.delete, size: 28, color: Colors.white),
          ),
        ]);
      } else if (!isRendimento && e.idMov != null) {
        actions.addAll([
          CustomSlidableAction(
            onPressed: (_) => _confirmarExcluirMovimento(e.idMov, e.tipo),
            backgroundColor: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(Icons.delete, size: 28, color: Colors.white),
          ),
        ]);
      }

      out.add(
        actions.isEmpty
            ? tile
            : Slidable(
                key: ValueKey('cdi_hist_${e.tipo}_${e.idRend ?? e.idMov ?? titulo}'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: actions.length == 1 ? 0.22 : 0.40,
                  children: actions,
                ),
                child: tile,
              ),
      );
    }
    return out;
  }
}

class _ResumoCdiCard extends StatelessWidget {
  final double totalRendido;
  final double saldoAtual;
  final VoidCallback onTap;

  const _ResumoCdiCard({
    required this.totalRendido,
    required this.saldoAtual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CDI (faixas)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniTile(
                      label: 'Saldo atual',
                      value: currency.format(saldoAtual),
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniTile(
                      label: 'Total rendido',
                      value: currency.format(totalRendido),
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Toque para ver as movimentações.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

