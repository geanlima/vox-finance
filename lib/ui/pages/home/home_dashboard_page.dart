import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/core/service/despesas_fixas_service.dart';
import 'package:vox_finance/ui/pages/home/home_voice.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _contaRepo = ContaPagarRepository();
  final _lancRepo = LancamentoRepository();
  final _despesasFixasService = DespesasFixasService();
  final _speech = stt.SpeechToText();
  final _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  bool _speechDisponivel = false;
  bool _loading = true;
  List<ContaPagar> _vencimentosHoje = const [];
  List<ContaPagar> _vencidos = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _speechDisponivel = await _speech.initialize();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Garante que as despesas fixas automáticas do mês foram geradas
    // antes de montar as notificações de vencimento.
    await _despesasFixasService.gerarNoMesAtualSeNecessario();

    final agora = DateTime.now();
    final inicioHoje = DateTime(agora.year, agora.month, agora.day);
    final fimHoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
      23,
      59,
      59,
      999,
    );

    final pendentes = await _contaRepo.getPendentes();
    final deHoje =
        pendentes
            .where(
              (c) =>
                  !c.dataVencimento.isBefore(inicioHoje) &&
                  !c.dataVencimento.isAfter(fimHoje),
            )
            .toList();
    final vencidos =
        pendentes.where((c) => c.dataVencimento.isBefore(inicioHoje)).toList();

    if (!mounted) return;
    setState(() {
      _vencimentosHoje = deHoje;
      _vencidos = vencidos;
      _loading = false;
    });
  }

  Future<void> _onMicPressed() async {
    if (!_speechDisponivel) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconhecimento de voz indisponível.')),
      );
      return;
    }

    final texto = await mostrarBottomSheetVoz(
      context: context,
      speech: _speech,
    );
    if (texto == null || texto.isEmpty) return;

    final lanc = interpretarComandoVoz(texto);
    if (lanc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não consegui entender valor e descrição.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar lançamento'),
            content: Text(
              'Descrição: ${lanc.descricao}\n'
              'Valor: ${_currency.format(lanc.valor)}\n'
              'Forma: ${lanc.formaPagamento.label}\n\n'
              'Deseja salvar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar'),
              ),
            ],
          ),
    );

    if (ok != true) return;
    await _lancRepo.salvar(lanc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento salvo com sucesso.')),
    );
    await _load();
  }

  void _goMain(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onMicPressed,
        icon: const Icon(Icons.mic),
        label: const Text('Lançar por voz'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(
                        (_vencimentosHoje.isEmpty && _vencidos.isEmpty)
                            ? 'Nenhum vencimento para hoje'
                            : (_vencidos.isNotEmpty
                                ? '${_vencidos.length} vencido(s) • ${_vencimentosHoje.length} para hoje'
                                : '${_vencimentosHoje.length} vencimento(s) para hoje'),
                      ),
                      subtitle:
                          (_vencimentosHoje.isEmpty && _vencidos.isEmpty)
                              ? const Text('Tudo certo por hoje.')
                              : Text(
                                [..._vencidos, ..._vencimentosHoje]
                                    .take(3)
                                    .map(
                                      (e) =>
                                          '${e.descricao} (${DateFormat('dd/MM').format(e.dataVencimento)})',
                                    )
                                    .join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      trailing: TextButton(
                        onPressed: () => _goMain('/contas-pagar'),
                        child: const Text('Ver'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.table_rows),
                      title: const Text('Ir para lançamentos'),
                      subtitle: const Text('Abrir tela de gastos/lançamentos'),
                      onTap: () => _goMain('/lancamentos'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.home_work_outlined),
                      title: const Text('Despesas fixas'),
                      subtitle: const Text(
                        'Gerenciar contas mensais automáticas',
                      ),
                      onTap: () => _goMain('/despesas-fixas'),
                    ),
                  ),
                ],
              ),
    );
  }
}
