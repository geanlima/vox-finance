// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/pessoas_devedoras_repository.dart';

class PessoasQueMeDevemPage extends StatefulWidget {
  const PessoasQueMeDevemPage({super.key});

  @override
  State<PessoasQueMeDevemPage> createState() => _PessoasQueMeDevemPageState();
}

class _PessoasQueMeDevemPageState extends State<PessoasQueMeDevemPage> {
  final _repo = InjectorV2.pessoasDevedorasRepo;

  bool _loading = true;
  int _totalPendente = 0;
  List<PessoaDevedoraRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final itens = await _repo.listar();
    final total = await _repo.totalPendente();

    if (!mounted) return;
    setState(() {
      _itens = itens;
      _totalPendente = total;
      _loading = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _money(int c) =>
      'R\$ ${(c / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtDatePt(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👀 Pessoas que me Devem'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _novo),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Total pendente'),
                        trailing: Text(
                          _money(_totalPendente),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_itens.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('Nenhum valor a receber.')),
                      )
                    else
                      ..._itens.map(_item).toList(),
                  ],
                ),
              ),
    );
  }

  Widget _item(PessoaDevedoraRow r) {
    final cs = Theme.of(context).colorScheme;
    final isPago = r.isPago;

    final badgeBg =
        isPago
            ? Colors.green.withOpacity(.15)
            : cs.errorContainer.withOpacity(.65);
    final badgeFg = isPago ? Colors.green : cs.onErrorContainer;

    return Card(
      child: ListTile(
        title: Text(r.nomeDevedor),
        subtitle: Text(
          '${_fmtDatePt(r.dataEmprestimoIso)} • ${r.descricao}'
          '${r.combinado?.isNotEmpty == true ? ' • ${r.combinado}' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(r.valorTotalCentavos),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'Pago: ${_money(r.valorPagoCentavos)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Pendente: ${_money(r.valorPendenteCentavos)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: badgeBg,
              ),
              child: Text(
                isPago ? 'PAGO' : 'PENDENTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
        onTap: isPago ? null : () => _registrarPagamento(r),
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder:
                (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isPago)
                        ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text('Registrar pagamento'),
                          onTap: () => Navigator.pop(ctx, 'pay'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text('Marcar como pago'),
                        onTap: () => Navigator.pop(ctx, 'mark'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Excluir'),
                        onTap: () => Navigator.pop(ctx, 'delete'),
                      ),
                    ],
                  ),
                ),
          );

          if (action == null) return;

          if (action == 'delete') {
            await _repo.deletar(r.id);
            await _load();
            _snack('Registro removido.');
          }

          if (action == 'mark') {
            await _repo.marcarComoPago(r.id);
            await _load();
          }

          if (action == 'pay') {
            await _registrarPagamento(r);
          }
        },
      ),
    );
  }

  Future<void> _novo() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PessoaDevedoraModal(repo: _repo),
    );

    if (ok == true) {
      await _load();
      _snack('Registro salvo!');
    }
  }

  Future<void> _registrarPagamento(PessoaDevedoraRow r) async {
    final cents = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RegistrarPagamentoModal(nome: r.nomeDevedor),
    );

    if (cents == null || cents <= 0) return;

    await _repo.registrarPagamento(r.id, cents);
    await _load();
    _snack('Pagamento registrado!');
  }
}

/// =======================
/// Modal: Novo valor
/// =======================
class _PessoaDevedoraModal extends StatefulWidget {
  final PessoasDevedorasRepository repo;

  const _PessoaDevedoraModal({required this.repo});

  @override
  State<_PessoaDevedoraModal> createState() => _PessoaDevedoraModalState();
}

class _PessoaDevedoraModalState extends State<_PessoaDevedoraModal> {
  final nomeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final combCtrl = TextEditingController();
  final valorCtrl = TextEditingController();

  DateTime data = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    nomeCtrl.dispose();
    descCtrl.dispose();
    combCtrl.dispose();
    valorCtrl.dispose();
    super.dispose();
  }

  int _parseMoney(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll('R\$', '').replaceAll(' ', '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s) ?? 0.0;
    return (v * 100).round();
  }

  Future<void> _salvar() async {
    if (_saving) return;

    final nome = nomeCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final valor = _parseMoney(valorCtrl.text);

    if (nome.isEmpty || desc.isEmpty || valor <= 0) return;

    setState(() => _saving = true);
    await widget.repo.inserir(
      nomeDevedor: nome,
      dataEmprestimo: data,
      descricao: desc,
      combinado: combCtrl.text.trim().isEmpty ? null : combCtrl.text.trim(),
      valorTotalCentavos: valor,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final safe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Novo valor a receber',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do devedor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$)',
                          border: OutlineInputBorder(),
                          prefixText: 'R\$ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'O que?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: combCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Combinado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safe),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _salvar,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Modal: Pagamento
/// =======================
class _RegistrarPagamentoModal extends StatefulWidget {
  final String nome;

  const _RegistrarPagamentoModal({required this.nome});

  @override
  State<_RegistrarPagamentoModal> createState() =>
      _RegistrarPagamentoModalState();
}

class _RegistrarPagamentoModalState extends State<_RegistrarPagamentoModal> {
  final valorCtrl = TextEditingController();

  @override
  void dispose() {
    valorCtrl.dispose();
    super.dispose();
  }

  int _parseMoney(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll('R\$', '').replaceAll(' ', '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s) ?? 0.0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Registrar pagamento • ${widget.nome}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor pago (R\$)',
              border: OutlineInputBorder(),
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
              onPressed: () {
                final cents = _parseMoney(valorCtrl.text);
                Navigator.pop(context, cents);
              },
            ),
          ),
        ],
      ),
    );
  }
}
