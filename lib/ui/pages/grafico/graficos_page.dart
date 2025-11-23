// ignore_for_file: unnecessary_const

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/widgets/graficos/grafico_pizza.dart';

class GraficosPage extends StatelessWidget {
  const GraficosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resumo do mês")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GraficoPizzaComponent(
                considerarSomentePagos: true,
                ignorarPagamentoFatura: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
