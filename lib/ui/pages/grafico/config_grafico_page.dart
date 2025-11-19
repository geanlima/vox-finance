import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/enum/tipo_grafico.dart';
import 'package:vox_finance/ui/core/service/grafico_preferencia_service.dart';

class ConfigGraficoPage extends StatefulWidget {
  const ConfigGraficoPage({super.key});

  @override
  State<ConfigGraficoPage> createState() => _ConfigGraficoPageState();
}

class _ConfigGraficoPageState extends State<ConfigGraficoPage> {
  final _service = GraficoPreferenciaService();
  TipoGrafico _selecionado = TipoGrafico.barra;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPreferencia();
  }

  Future<void> _carregarPreferencia() async {
    final tipo = await _service.carregarTipoGrafico();
    setState(() {
      _selecionado = tipo;
      _carregando = false;
    });
  }

  Future<void> _salvar(TipoGrafico tipo) async {
    setState(() => _selecionado = tipo);
    await _service.salvarTipoGrafico(tipo);
    // opcional: mostrar snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tipo de gráfico alterado para ${tipo.label}.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuração de Gráfico')),
      body: ListView(
        children: TipoGrafico.values.map((tipo) {
          return RadioListTile<TipoGrafico>(
            title: Text(tipo.label),
            value: tipo,
            groupValue: _selecionado,
            onChanged: (v) {
              if (v != null) _salvar(v);
            },
          );
        }).toList(),
      ),
    );
  }
}
