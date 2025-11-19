import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/enum/tipo_grafico.dart';
import 'package:vox_finance/ui/core/service/grafico_preferencia_service.dart';
// imports dos widgets de gráfico que você já tem (fl_chart etc.)

class GraficoMensalPage extends StatefulWidget {
  const GraficoMensalPage({super.key});

  @override
  State<GraficoMensalPage> createState() => _GraficoMensalPageState();
}

class _GraficoMensalPageState extends State<GraficoMensalPage> {
  final _prefService = GraficoPreferenciaService();
  TipoGrafico _tipo = TipoGrafico.barra;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarTipo();
  }

  Future<void> _carregarTipo() async {
    final tipo = await _prefService.carregarTipoGrafico();
    setState(() {
      _tipo = tipo;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gráfico Mensal (${_tipo.label})')),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildGrafico()),
    );
  }

  Widget _buildGrafico() {
    switch (_tipo) {
      case TipoGrafico.linha:
        return _buildGraficoLinha();
      case TipoGrafico.barra:
        return _buildGraficoBarra();
      case TipoGrafico.pizza:
        return _buildGraficoPizza();
      case TipoGrafico.histograma:
        return _buildGraficoHistograma();
    }
  }

  // Abaixo você implementa os 4 tipos, mesmo que no começo sejam simples:

  Widget _buildGraficoLinha() {
    // TODO: usar fl_chart ou outro widget de linha
    return const Center(child: Text('Gráfico de Linha (implementar)'));
  }

  Widget _buildGraficoBarra() {
    // TODO: barras
    return const Center(child: Text('Gráfico de Barras (implementar)'));
  }

  Widget _buildGraficoPizza() {
    // TODO: pizza
    return const Center(child: Text('Gráfico de Pizza (implementar)'));
  }

  Widget _buildGraficoHistograma() {
    // TODO: histograma (pode ser um gráfico de barras especial)
    return const Center(child: Text('Histograma (implementar)'));
  }
}
