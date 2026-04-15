// ignore_for_file: unnecessary_const

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/widgets/graficos/grafico_pizza.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class GraficosPage extends StatefulWidget {
  const GraficosPage({super.key});

  @override
  State<GraficosPage> createState() => _GraficosPageState();
}

class _GraficosPageState extends State<GraficosPage> {
  PeriodoResumoPizza _periodo = PeriodoResumoPizza.mensal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo')),
      drawer: const AppDrawer(currentRoute: '/graficos'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<PeriodoResumoPizza>(
              showSelectedIcon: false,
              style: ButtonStyle(
                side: WidgetStateProperty.all(
                  BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.primaryContainer;
                  }
                  return cs.surfaceContainerHighest.withValues(alpha: 0.65);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.onPrimaryContainer;
                  }
                  return cs.onSurface;
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return cs.onPrimaryContainer;
                  }
                  return cs.onSurfaceVariant;
                }),
              ),
              segments: const [
                ButtonSegment(
                  value: PeriodoResumoPizza.mensal,
                  label: Text('Mensal'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: PeriodoResumoPizza.semanal,
                  label: Text('Semanal'),
                  icon: Icon(Icons.view_week_outlined),
                ),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) => setState(() => _periodo = s.first),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GraficoPizzaComponent(
                considerarSomentePagos: true,
                ignorarPagamentoFatura: true,
                periodo: _periodo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
