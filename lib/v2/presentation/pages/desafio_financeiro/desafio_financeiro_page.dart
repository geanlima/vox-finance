// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/desafio_financeiro_repository.dart';

class DesafioFinanceiroPage extends StatefulWidget {
  const DesafioFinanceiroPage({super.key});

  @override
  State<DesafioFinanceiroPage> createState() => _DesafioFinanceiroPageState();
}

class _DesafioFinanceiroPageState extends State<DesafioFinanceiroPage> {
  final DesafioFinanceiroRepository _repo = InjectorV2.desafioFinanceiroRepo;

  bool _loading = true;
  late int _ano;
  List<DesafioFinanceiroRow> _itens = const [];

  @override
  void initState() {
    super.initState();
    _ano = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final itens = await _repo.listar(ano: _ano);
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _loading = false;
    });
  }

  Color _statusColor(int s) {
    switch (s) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _seedAnoSeVazio() async {
    if (_itens.isNotEmpty) return;

    // exemplo baseado no seu print
    final desafios = <int, String>{
      1: 'Vou anotar 100% dos meus gastos',
      2: 'Vou passar 7 dias sem pedir delivery',
      3: 'Vou cancelar uma assinatura que não faz mais sentido',
      4: 'Vou definir um limite realista para gastos com lazer e respeitar',
      5: 'Vou separar R\$10 por dia durante 30 dias',
      6: 'Vou planejar quanto preciso para montar minha reserva de emergência',
      7: 'Vou ler um livro sobre finanças',
      8: 'Vou revisar todas as minhas despesas fixas',
      9: 'Vou registrar cada compra parcelada que eu tenho atualmente',
      10: 'Vou criar metas financeiras claras para os próximos 3 meses',
      11: 'Vou deixar meu cartão fora da carteira por uma semana',
      12: 'Vou planejar todos os meus gastos extras de fim de ano',
    };

    for (final m in desafios.keys) {
      await _repo.inserir(
        mes: m,
        ano: _ano,
        desafio: desafios[m]!,
        status: 0,
        metaAtingida: false,
      );
    }

    await _load();
  }

  Future<void> _edit(DesafioFinanceiroRow item) async {
    final desafioCtrl = TextEditingController(text: item.desafio);
    final obsCtrl = TextEditingController(text: item.observacoes ?? '');

    int status = item.status;
    bool meta = item.metaAtingida;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('${item.mesLabel} / $_ano'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: desafioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Desafio'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Não iniciada')),
                        DropdownMenuItem(value: 1, child: Text('Em andamento')),
                        DropdownMenuItem(value: 2, child: Text('Concluído')),
                      ],
                      onChanged: (v) => setLocal(() => status = v ?? 0),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: meta,
                      onChanged: (v) => setLocal(() => meta = v),
                      title: const Text('Meta atingida?'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observações e reflexões',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      await _repo.atualizar(
        id: item.id,
        mes: item.mes,
        ano: item.ano,
        desafio: desafioCtrl.text.trim(),
        status: status,
        metaAtingida: meta,
        observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final anoLabel = '$_ano';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desafio Financeiro'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<int>(
            onSelected: (v) async {
              if (v == 1) {
                setState(() => _ano = _ano - 1);
                await _load();
              } else if (v == 2) {
                setState(() => _ano = _ano + 1);
                await _load();
              } else if (v == 3) {
                await _seedAnoSeVazio();
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: 1, child: Text('Ano anterior')),
                  const PopupMenuItem(value: 2, child: Text('Próximo ano')),
                  const PopupMenuItem(
                    value: 3,
                    child: Text('Gerar desafios padrão'),
                  ),
                ],
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Nenhum desafio em $anoLabel'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _seedAnoSeVazio,
                        child: const Text('Gerar desafios padrão'),
                      ),
                    ],
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _itens.length,
                itemBuilder: (_, i) {
                  final item = _itens[i];
                  final sc = _statusColor(item.status);

                  return Card(
                    child: ListTile(
                      onTap: () => _edit(item),
                      title: Text(
                        '${item.mesLabel} • ${item.statusLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.desafio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: sc.withOpacity(0.45)),
                            ),
                            child: Text(
                              item.statusLabel,
                              style: TextStyle(
                                color: sc,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            item.metaAtingida
                                ? Icons.check_circle
                                : Icons.cancel,
                            color:
                                item.metaAtingida ? Colors.green : Colors.grey,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
