// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:vox_finance/ui/data/models/bluminers_config.dart';
import 'package:vox_finance/ui/data/models/bluminers_movimento.dart';
import 'package:vox_finance/ui/data/models/bluminers_rentabilidade.dart';
import 'package:vox_finance/ui/data/modules/investimentos/bluminers/bluminers_repository.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class BluminersPage extends StatefulWidget {
  const BluminersPage({super.key});

  @override
  State<BluminersPage> createState() => _BluminersPageState();
}

class _BluminersPageState extends State<BluminersPage> {
  final _repo = BluminersRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  final _monthFmt = DateFormat('MMMM yyyy', 'pt_BR');

  bool _loading = true;
  BluminersConfig? _config;
  List<BluminersMovimento> _movs = const [];
  List<BluminersRentabilidade> _rents = const [];
  double _saldoTotal = 0;
  double _saldoInvestido = 0;
  double _saldoDisponivel = 0;
  DateTime _dashboardMesRef = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _pizzaAnoRef = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await _repo.getConfig();
    final movs = await _repo.listarMovimentos();
    final rents = await _repo.listarRentabilidade();
    final s = await _repo.saldosAte(DateTime.now());

    if (!mounted) return;
    setState(() {
      _config = cfg;
      _movs = movs;
      _rents = rents;
      _saldoInvestido = s.investido;
      _saldoDisponivel = s.disponivel;
      _saldoTotal = s.totalGeral;
      _loading = false;
    });
  }

  Future<void> _openConfig() async {
    final cfg = _config ?? await _repo.getConfig();
    final saldoCtrl = TextEditingController(
      text: cfg.saldoInicialInvestido.toStringAsFixed(2).replaceAll('.', ','),
    );
    final saldoDispCtrl = TextEditingController(
      text: cfg.saldoInicialDisponivel.toStringAsFixed(2).replaceAll('.', ','),
    );
    final aporteCtrl = TextEditingController(
      text: cfg.aporteMensal.toStringAsFixed(2).replaceAll('.', ','),
    );
    final metaCtrl = TextEditingController(
      text: (cfg.meta ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );
    bool metaAtiva = cfg.meta != null;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 +
                    MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Configuração Bluminers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: saldoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Saldo inicial (Total investido)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: saldoDispCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Saldo inicial (Disponível para saque)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aporteCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Aporte mensal (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar meta/objetivo'),
                    value: metaAtiva,
                    onChanged: (v) => setModal(() => metaAtiva = v),
                  ),
                  if (metaAtiva) ...[
                    TextField(
                      controller: metaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Meta (R\$)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        double parseMoney(String v) {
                          return double.tryParse(
                                v
                                    .trim()
                                    .replaceAll('.', '')
                                    .replaceAll(',', '.'),
                              ) ??
                              0;
                        }

                        final novo = BluminersConfig(
                          id: 1,
                          saldoInicialInvestido: parseMoney(saldoCtrl.text),
                          saldoInicialDisponivel: parseMoney(
                            saldoDispCtrl.text,
                          ),
                          aporteMensal: parseMoney(aporteCtrl.text),
                          meta: metaAtiva ? parseMoney(metaCtrl.text) : null,
                          criadoEm: cfg.criadoEm,
                        );
                        await _repo.saveConfig(novo);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _load();
  }

  Future<void> _openMovForm({BluminersMovimento? item}) async {
    final descCtrl = TextEditingController(text: item?.observacao ?? '');
    final valorCtrl = TextEditingController(
      text:
          item != null
              ? item.valor.toStringAsFixed(2).replaceAll('.', ',')
              : '',
    );
    final percCtrl = TextEditingController(text: '');
    DateTime data = item?.data ?? DateTime.now();
    BluminersMovimentoTipo tipo =
        item?.tipo ??
        (item == null
            ? BluminersMovimentoTipo.rendimento
            : BluminersMovimentoTipo.aporte);
    BluminersCarteira carteira =
        item?.carteira ??
        (tipo == BluminersMovimentoTipo.saque ||
                tipo == BluminersMovimentoTipo.rendimento
            ? BluminersCarteira.disponivel
            : BluminersCarteira.investido);
    bool rendimentoPorPercentual = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                28 + mq.viewInsets.bottom + mq.viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item == null ? 'Nova movimentação' : 'Editar movimentação',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Data'),
                    subtitle: Text(_date.format(data)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: data,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setModal(() => data = picked);
                    },
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<BluminersMovimentoTipo>(
                    value: tipo,
                    items: const [
                      DropdownMenuItem(
                        value: BluminersMovimentoTipo.aporte,
                        child: Text('Aporte (soma no total investido)'),
                      ),
                      DropdownMenuItem(
                        value: BluminersMovimentoTipo.saque,
                        child: Text('Saque (abate do disponível)'),
                      ),
                      DropdownMenuItem(
                        value: BluminersMovimentoTipo.rendimento,
                        child: Text('Rendimento (soma no disponível)'),
                      ),
                      DropdownMenuItem(
                        value: BluminersMovimentoTipo.ajuste,
                        child: Text('Ajuste'),
                      ),
                    ],
                    onChanged: (v) {
                      setModal(() {
                        tipo = v ?? BluminersMovimentoTipo.aporte;
                        if (tipo == BluminersMovimentoTipo.saque) {
                          carteira = BluminersCarteira.disponivel;
                        } else if (tipo == BluminersMovimentoTipo.aporte) {
                          carteira = BluminersCarteira.investido;
                        } else if (tipo == BluminersMovimentoTipo.rendimento) {
                          carteira = BluminersCarteira.disponivel;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tipo',
                    ),
                  ),
                  if (tipo == BluminersMovimentoTipo.ajuste) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<BluminersCarteira>(
                      value: carteira,
                      items: const [
                        DropdownMenuItem(
                          value: BluminersCarteira.investido,
                          child: Text('Ajuste no Total investido'),
                        ),
                        DropdownMenuItem(
                          value: BluminersCarteira.disponivel,
                          child: Text('Ajuste no Disponível'),
                        ),
                      ],
                      onChanged:
                          (v) => setModal(
                            () => carteira = v ?? BluminersCarteira.investido,
                          ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Onde aplicar',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (tipo == BluminersMovimentoTipo.rendimento) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('% do dia'),
                          icon: Icon(Icons.percent),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Valor'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                      ],
                      selected: {rendimentoPorPercentual},
                      onSelectionChanged: (v) {
                        setModal(() => rendimentoPorPercentual = v.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (rendimentoPorPercentual)
                      TextField(
                        controller: percCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Percentual do dia (%)',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      TextField(
                        controller: valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor do rendimento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                  ] else ...[
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        double parseMoney(String v) {
                          return double.tryParse(
                                v
                                    .trim()
                                    .replaceAll('.', '')
                                    .replaceAll(',', '.'),
                              ) ??
                              0;
                        }

                        double valor;
                        String? autoObs;

                        if (tipo == BluminersMovimentoTipo.rendimento &&
                            rendimentoPorPercentual) {
                          final p = parseMoney(percCtrl.text);
                          if (p == 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Informe um percentual válido.'),
                              ),
                            );
                            return;
                          }

                          final s = await _repo.saldosAte(data);
                          valor = s.totalGeral * (p / 100.0);
                          autoObs =
                              'Rendimento (${p.toStringAsFixed(3).replaceAll('.', ',')}%)';
                        } else {
                          valor = parseMoney(valorCtrl.text);
                          if (valor <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Informe um valor válido.'),
                              ),
                            );
                            return;
                          }
                        }

                        if (tipo == BluminersMovimentoTipo.saque) {
                          final s = await _repo.saldosAte(data);
                          if (valor > s.disponivel) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saque maior que o disponível (${_money.format(s.disponivel)}).',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        final mov = BluminersMovimento(
                          id: item?.id,
                          data: data,
                          tipo: tipo,
                          carteira: carteira,
                          valor: valor,
                          observacao:
                              (descCtrl.text.trim().isEmpty
                                  ? autoObs
                                  : descCtrl.text.trim()),
                          origem: item?.origem,
                          idOrigem: item?.idOrigem,
                          criadoEm: item?.criadoEm ?? DateTime.now(),
                        );
                        await _repo.salvarMovimento(mov);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _load();
  }

  Future<void> _deleteMov(BluminersMovimento item) async {
    if (item.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir movimentação'),
            content: const Text('Deseja excluir esta movimentação?'),
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
    await _repo.deletarMovimento(item.id!);
    await _load();
  }

  Future<void> _openRentForm({BluminersRentabilidade? item}) async {
    DateTime data = item?.data ?? DateTime.now();
    final percCtrl = TextEditingController(
      text:
          item != null
              ? item.percentual.toStringAsFixed(3).replaceAll('.', ',')
              : '',
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item == null
                        ? 'Rentabilidade diária'
                        : 'Editar rentabilidade',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Data'),
                    subtitle: Text(_date.format(data)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: data,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setModal(() => data = picked);
                    },
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: percCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Percentual do dia (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final p = double.tryParse(
                          percCtrl.text
                              .trim()
                              .replaceAll('.', '')
                              .replaceAll(',', '.'),
                        );
                        if (p == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Informe um percentual válido.'),
                            ),
                          );
                          return;
                        }

                        await _repo.salvarRentabilidade(
                          id: item?.id,
                          data: data,
                          percentual: p,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _load();
  }

  Future<void> _deleteRent(BluminersRentabilidade item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir rentabilidade'),
            content: const Text(
              'Deseja excluir este percentual do dia? (remove o rendimento automático também)',
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
    await _repo.deletarRentabilidade(item);
    await _load();
  }

  Future<void> _importarPercentuaisDiarios() async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Importar percentuais diários'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: ctrl,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText:
                    'Cole aqui linhas no formato:\n'
                    '05/03/2026  0,23%  R\$ 44,43\n'
                    '06/03/2026  0,21%  R\$ 40,66\n'
                    '\n'
                    'O app usa somente a Data e o %.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    int imported = 0;
    int skipped = 0;
    final errors = <String>[];

    double parseNumberPt(String v) {
      return double.tryParse(
            v.trim().replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          double.nan;
    }

    DateTime? parseDate(String v) {
      final parts = v.split('/');
      if (parts.length != 3) return null;
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return null;
      return DateTime(y, m, d);
    }

    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // aceita tab/espacos: "dd/MM/yyyy 0,23% R$ 44,43"
      final m = RegExp(
        r'^(\d{2}\/\d{2}\/\d{4})\s+([0-9]+(?:[.,][0-9]+)?)\s*%?.*$',
      ).firstMatch(line);
      if (m == null) {
        skipped++;
        errors.add('Linha ${i + 1}: formato inválido');
        continue;
      }

      final dt = parseDate(m.group(1)!);
      final p = parseNumberPt(m.group(2)!);
      if (dt == null || p.isNaN) {
        skipped++;
        errors.add('Linha ${i + 1}: data/% inválido');
        continue;
      }

      try {
        await _repo.salvarRentabilidade(data: dt, percentual: p);
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Linha ${i + 1}: erro $e');
      }
    }

    if (!mounted) return;
    await _load();

    final msg =
        'Importados: $imported'
        '${skipped > 0 ? ' • Ignorados: $skipped' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (errors.isNotEmpty && mounted) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Linhas ignoradas'),
              content: SingleChildScrollView(
                child: Text(errors.take(20).join('\n')),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildAnalises() {
    final cs = Theme.of(context).colorScheme;
    final mesRef = _dashboardMesRef;

    final mesesDisponiveis =
        <DateTime>{
            ..._rents.map((r) => DateTime(r.data.year, r.data.month, 1)),
            ..._movs.map((m) => DateTime(m.data.year, m.data.month, 1)),
          }.toList()
          ..sort((a, b) => b.compareTo(a));

    if (mesesDisponiveis.isNotEmpty &&
        !mesesDisponiveis.any(
          (m) => m.year == mesRef.year && m.month == mesRef.month,
        )) {
      _dashboardMesRef = mesesDisponiveis.first;
    }

    final movsMes =
        _movs
            .where(
              (m) => m.data.year == mesRef.year && m.data.month == mesRef.month,
            )
            .toList();

    final rentsMes =
        _rents
            .where(
              (r) => r.data.year == mesRef.year && r.data.month == mesRef.month,
            )
            .toList();

    double somaRendimento = 0;
    BluminersRentabilidade? melhor;
    BluminersRentabilidade? pior;

    // Rendimento do mês deve considerar TUDO que está em movimentações (manual + importado).
    for (final m in movsMes) {
      if (m.tipo == BluminersMovimentoTipo.rendimento) {
        somaRendimento += m.valor;
      }
    }

    // Total lançado no mês (net): aporte + ajuste + rendimento - saque
    double totalLancadoMes = 0;
    for (final m in movsMes) {
      switch (m.tipo) {
        case BluminersMovimentoTipo.aporte:
          totalLancadoMes += m.valor;
          break;
        case BluminersMovimentoTipo.ajuste:
          totalLancadoMes += m.valor;
          break;
        case BluminersMovimentoTipo.rendimento:
          totalLancadoMes += m.valor;
          break;
        case BluminersMovimentoTipo.saque:
          totalLancadoMes -= m.valor;
          break;
      }
    }

    // % / melhor / pior: usa tabela de rentabilidade (importada) e, se não existir,
    // tenta extrair % de rendimentos manuais pela observação.
    double? parsePercentFromObs(String? obs) {
      if (obs == null || obs.trim().isEmpty) return null;
      final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*%').firstMatch(obs);
      if (match == null) return null;
      final raw = match.group(1)!;
      return double.tryParse(raw.replaceAll(',', '.'));
    }

    final percentByDay = <DateTime, double>{};
    for (final r in rentsMes) {
      final d = DateTime(r.data.year, r.data.month, r.data.day);
      percentByDay[d] = r.percentual;
    }
    for (final m in movsMes) {
      if (m.tipo != BluminersMovimentoTipo.rendimento) continue;
      final d = DateTime(m.data.year, m.data.month, m.data.day);
      if (percentByDay.containsKey(d)) continue; // já tem o % importado
      final p = parsePercentFromObs(m.observacao);
      if (p != null) percentByDay[d] = p;
    }

    for (final e in percentByDay.entries) {
      final p = e.value;
      if (melhor == null || p > melhor.percentual) {
        // usa um "fake" só para carregar data/percentual
        melhor = BluminersRentabilidade(
          id: null,
          data: e.key,
          percentual: p,
          rendimentoValor: 0,
          criadoEm: DateTime.now(),
        );
      }
      if (pior == null || p < pior.percentual) {
        pior = BluminersRentabilidade(
          id: null,
          data: e.key,
          percentual: p,
          rendimentoValor: 0,
          criadoEm: DateTime.now(),
        );
      }
    }

    // Percentual total do mês (capitalização composta)
    double fator = 1.0;
    for (final p in percentByDay.values) {
      fator *= (1.0 + (p / 100.0));
    }
    final double percentualMes = (fator - 1.0) * 100.0;

    String fmtPct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Análises',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (mesesDisponiveis.isNotEmpty)
                        DropdownButtonHideUnderline(
                          child: DropdownButton<DateTime>(
                            value: mesesDisponiveis.firstWhere(
                              (m) =>
                                  m.year == mesRef.year &&
                                  m.month == mesRef.month,
                              orElse: () => mesesDisponiveis.first,
                            ),
                            items:
                                mesesDisponiveis
                                    .map(
                                      (m) => DropdownMenuItem<DateTime>(
                                        value: m,
                                        child: Text(_monthFmt.format(m)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(
                                () =>
                                    _dashboardMesRef = DateTime(
                                      v.year,
                                      v.month,
                                      1,
                                    ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${percentByDay.length} dias',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('% no mês', fmtPct(percentualMes), cs.primary),
                  _metric(
                    'Rendimento no mês',
                    _money.format(somaRendimento),
                    Colors.green,
                  ),
                  _metric(
                    'Total lançado no mês',
                    _money.format(totalLancadoMes),
                    cs.onSurface.withOpacity(0.75),
                  ),
                  if (melhor != null)
                    _metric(
                      'Melhor dia',
                      '${fmtPct(melhor.percentual)} • ${_date.format(melhor.data)}',
                      cs.onSurface.withOpacity(0.75),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPizzaMesesRendimento() {
    final cs = Theme.of(context).colorScheme;
    final anosDisponiveis =
        <int>{
            ..._rents.map((r) => r.data.year),
            ..._movs.map((m) => m.data.year),
          }.toList()
          ..sort((a, b) => b.compareTo(a));

    if (anosDisponiveis.isNotEmpty && !anosDisponiveis.contains(_pizzaAnoRef)) {
      _pizzaAnoRef = anosDisponiveis.first;
    }

    final byMonth = <int, double>{};
    // Pizza deve refletir tudo que está em movimentações (manual + importado)
    for (final m in _movs) {
      if (m.data.year != _pizzaAnoRef) continue;
      if (m.tipo != BluminersMovimentoTipo.rendimento) continue;
      byMonth[m.data.month] = (byMonth[m.data.month] ?? 0) + m.valor;
    }

    final total = byMonth.values.fold<double>(
      0,
      (sum, v) => sum + v.toDouble(),
    );

    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rendimento por mês (pizza)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (anosDisponiveis.isNotEmpty)
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pizzaAnoRef,
                          items:
                              anosDisponiveis
                                  .map(
                                    (y) => DropdownMenuItem<int>(
                                      value: y,
                                      child: Text(y.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _pizzaAnoRef = v);
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Sem dados de rentabilidade para ${_pizzaAnoRef}.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // paleta simples
    const colors = [
      Color(0xFF2E7D32),
      Color(0xFF1565C0),
      Color(0xFF6A1B9A),
      Color(0xFFEF6C00),
      Color(0xFF00897B),
      Color(0xFFAD1457),
      Color(0xFF283593),
      Color(0xFF0277BD),
      Color(0xFF7CB342),
      Color(0xFF5D4037),
      Color(0xFF8E24AA),
      Color(0xFF546E7A),
    ];

    // meses 1..12 (mostra todos na legenda; fatias só para valores > 0)
    final slices = <_PieSlice>[];
    final legend = <_PieSlice>[];
    for (var m = 1; m <= 12; m++) {
      final value = (byMonth[m] ?? 0).toDouble();
      final label = DateFormat(
        'MMM',
        'pt_BR',
      ).format(DateTime(_pizzaAnoRef, m, 1));
      final color = colors[(m - 1) % colors.length];
      final double pct = total == 0 ? 0.0 : (value / total).toDouble();
      final s = _PieSlice(
        label: label,
        value: value,
        percent: pct,
        color: color,
      );
      legend.add(s);
      if (value > 0) slices.add(s);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rendimento por mês (pizza)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  if (anosDisponiveis.isNotEmpty)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _pizzaAnoRef,
                        items:
                            anosDisponiveis
                                .map(
                                  (y) => DropdownMenuItem<int>(
                                    value: y,
                                    child: Text(y.toString()),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _pizzaAnoRef = v);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CustomPaint(painter: _PieChartPainter(slices)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (final s in legend)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  _money.format(s.value),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

  Future<void> _openRentabilidadesSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        final danger = Colors.red.shade400;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Rentabilidades',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Adicionar',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _openRentForm();
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child:
                      _rents.isEmpty
                          ? const Center(
                            child: Text('Nenhum percentual diário cadastrado.'),
                          )
                          : ListView.builder(
                            itemCount: _rents.length,
                            itemBuilder: (_, i) {
                              final r = _rents[i];
                              return Slidable(
                                key: ValueKey('rent_sheet_${r.id ?? i}'),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.35,
                                  children: [
                                    CustomSlidableAction(
                                      onPressed: (_) async {
                                        Navigator.pop(ctx);
                                        await _openRentForm(item: r);
                                      },
                                      backgroundColor:
                                          theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Icon(
                                        Icons.edit,
                                        size: 28,
                                        color: primary,
                                      ),
                                    ),
                                    CustomSlidableAction(
                                      onPressed: (_) async {
                                        Navigator.pop(ctx);
                                        await _deleteRent(r);
                                      },
                                      backgroundColor: danger,
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Icon(
                                        Icons.delete,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                child: Card(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.percent,
                                      color: primary,
                                    ),
                                    title: Text(
                                      '${r.percentual.toStringAsFixed(2).replaceAll('.', ',')}%',
                                    ),
                                    subtitle: Text(_date.format(r.data)),
                                    trailing: Text(
                                      _money.format(r.rendimentoValor),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
      },
    );
  }

  Widget _buildDashboard() {
    final cfg = _config;
    final cs = Theme.of(context).colorScheme;
    final meta = cfg?.meta;
    final double? metaPct =
        (meta != null && meta > 0)
            ? (_saldoTotal / meta).clamp(0.0, 1.0).toDouble()
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bluminers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    tooltip: 'Configurar',
                    onPressed: _openConfig,
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric(
                    'Total geral',
                    _money.format(_saldoTotal),
                    cs.primary,
                  ),
                  _metric(
                    'Total investido',
                    _money.format(_saldoInvestido),
                    cs.onSurface.withOpacity(0.75),
                  ),
                  _metric(
                    'Disponível para saque',
                    _money.format(_saldoDisponivel),
                    Colors.green,
                  ),
                  if (cfg != null)
                    _metric(
                      'Aporte mensal',
                      _money.format(cfg.aporteMensal),
                      cs.onSurface.withOpacity(0.75),
                    ),
                ],
              ),
              if (metaPct != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Meta: ${_money.format(meta)}',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: metaPct),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimentacoesTab({
    required ThemeData theme,
    required Color primary,
    required Color danger,
  }) {
    if (_movs.isEmpty) {
      return const Center(child: Text('Nenhuma movimentação cadastrada.'));
    }

    final cs = theme.colorScheme;
    final children = <Widget>[];

    int? currentYear;
    int? currentMonth;

    Widget monthHeader(DateTime d) {
      final text = _monthFmt.format(DateTime(d.year, d.month, 1));
      final label =
          text.isNotEmpty ? (text[0].toUpperCase() + text.substring(1)) : text;

      // Total do mês (somente rendimentos) para exibir no cabeçalho.
      final totalMes = _movs
          .where((m) => m.data.year == d.year && m.data.month == d.month)
          .where((m) => m.tipo == BluminersMovimentoTipo.rendimento)
          .fold<double>(0, (sum, m) => sum + m.valor);

      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withOpacity(0.75),
                ),
              ),
            ),
            if (totalMes > 0)
              Text(
                'Total: ${_money.format(totalMes)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
      );
    }

    Widget tableHeader() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 98,
              child: Text(
                'Data',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.55),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Taxa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.55),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                'Valor',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.55),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget row(BluminersMovimento m, int i) {
      final isAuto = m.origem == 'rentabilidade';
      final icon = switch (m.tipo) {
        BluminersMovimentoTipo.aporte => Icons.add_circle_outline,
        BluminersMovimentoTipo.saque => Icons.remove_circle_outline,
        BluminersMovimentoTipo.rendimento => Icons.trending_up,
        BluminersMovimentoTipo.ajuste => Icons.tune,
      };
      final color = switch (m.tipo) {
        BluminersMovimentoTipo.aporte => Colors.green,
        BluminersMovimentoTipo.saque => danger,
        BluminersMovimentoTipo.rendimento => primary,
        BluminersMovimentoTipo.ajuste => cs.onSurface.withOpacity(0.8),
      };

      String? percentText;
      if (m.tipo == BluminersMovimentoTipo.rendimento) {
        // 1) Se veio da tabela de rentabilidade, pega o % cadastrado
        if (m.origem == 'rentabilidade') {
          final r =
              _rents
                  .where(
                    (e) =>
                        (m.idOrigem != null && e.id == m.idOrigem) ||
                        (e.data.year == m.data.year &&
                            e.data.month == m.data.month &&
                            e.data.day == m.data.day),
                  )
                  .cast<BluminersRentabilidade?>()
                  .firstOrNull;
          if (r != null) {
            percentText =
                '${r.percentual.toStringAsFixed(2).replaceAll('.', ',')}%';
          }
        }

        // 2) Se for manual, tenta extrair o % da observação (ex: "Rendimento (0,20%)")
        percentText ??= () {
          final obs = m.observacao ?? '';
          final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*%').firstMatch(obs);
          if (match == null) return null;
          final raw = match.group(1)!;
          final p = double.tryParse(raw.replaceAll(',', '.'));
          if (p == null) return null;
          return '${p.toStringAsFixed(2).replaceAll('.', ',')}%';
        }();
      }

      final labelBase =
          m.observacao?.trim().isNotEmpty == true
              ? m.observacao!.trim()
              : (m.tipo == BluminersMovimentoTipo.aporte
                  ? 'Aporte'
                  : m.tipo == BluminersMovimentoTipo.saque
                  ? 'Saque'
                  : m.tipo == BluminersMovimentoTipo.rendimento
                  ? 'Rendimento'
                  : 'Ajuste');
      final label =
          (m.tipo == BluminersMovimentoTipo.rendimento && percentText != null)
              ? percentText
              : labelBase;

      final base = Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 98,
                child: Text(
                  _date.format(m.data),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          (m.tipo == BluminersMovimentoTipo.rendimento)
                              ? Center(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                              : Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  _money.format(m.valor),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );

      if (isAuto) return base;
      return Slidable(
        key: ValueKey('mov_${m.id ?? i}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.35,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _openMovForm(item: m),
              backgroundColor: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Icon(Icons.edit, size: 28, color: primary),
            ),
            CustomSlidableAction(
              onPressed: (_) => _deleteMov(m),
              backgroundColor: danger,
              borderRadius: BorderRadius.circular(12),
              child: const Icon(Icons.delete, size: 28, color: Colors.white),
            ),
          ],
        ),
        child: base,
      );
    }

    for (var i = 0; i < _movs.length; i++) {
      final m = _movs[i];
      if (currentYear != m.data.year || currentMonth != m.data.month) {
        currentYear = m.data.year;
        currentMonth = m.data.month;
        children.add(monthHeader(m.data));
        children.add(tableHeader());
      }
      children.add(row(m, i));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final danger = Colors.red.shade400;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Investimento • Bluminers'),
          actions: [
            IconButton(
              tooltip: 'Rentabilidades',
              icon: const Icon(Icons.percent),
              onPressed: _openRentabilidadesSheet,
            ),
            IconButton(
              tooltip: 'Importar % (colar)',
              icon: const Icon(Icons.playlist_add),
              onPressed: _importarPercentuaisDiarios,
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.75),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            tabs: const [Tab(text: 'Movimentações'), Tab(text: 'Dashboard')],
          ),
        ),
        drawer: const AppDrawer(currentRoute: '/investimentos/bluminers'),
        floatingActionButton:
            _loading
                ? null
                : Builder(
                  builder: (ctx) {
                    final tab = DefaultTabController.of(ctx).index;
                    final bottomSafe = MediaQuery.of(ctx).padding.bottom;
                    return Padding(
                      padding: EdgeInsets.only(bottom: bottomSafe),
                      child: FloatingActionButton(
                        onPressed: () {
                          // Mantém o + focado em lançar movimentação;
                          // no dashboard também faz sentido abrir o lançamento rápido.
                          if (tab == 0) {
                            _openMovForm();
                          } else {
                            _openMovForm();
                          }
                        },
                        child: const Icon(Icons.add),
                      ),
                    );
                  },
                ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    Column(
                      children: [
                        _buildDashboard(),
                        Expanded(
                          child: _buildMovimentacoesTab(
                            theme: theme,
                            primary: primary,
                            danger: danger,
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        _buildAnalises(),
                        _buildPizzaMesesRendimento(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }
}

class _PieSlice {
  final String label;
  final double value;
  final double percent;
  final Color color;

  const _PieSlice({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;

  const _PieChartPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              radius // vira "donut" sólido
          ..strokeCap = StrokeCap.butt;

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (math.pi * 2) * s.percent;
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}
