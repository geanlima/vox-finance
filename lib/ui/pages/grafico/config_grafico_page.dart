// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/enum/grafico_visao_inicial.dart';
import 'package:vox_finance/ui/core/service/preferencias_service.dart';
import 'package:vox_finance/ui/core/service/theme_controller.dart';
import '../../widgets/app_drawer.dart';

class ConfigGraficoPage extends StatefulWidget {
  const ConfigGraficoPage({super.key});

  @override
  State<ConfigGraficoPage> createState() => _ConfigGraficoPageState();
}

class _ConfigGraficoPageState extends State<ConfigGraficoPage> {
  GraficoVisaoInicial _visao = GraficoVisaoInicial.ano;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _visao = await PreferenciasService.carregarVisao();
    _themeMode = themeController.themeMode; // ✅ vem do singleton

    setState(() {});
  }

  Future<void> _salvarVisao(GraficoVisaoInicial nova) async {
    setState(() => _visao = nova);
    await PreferenciasService.salvarVisao(nova);
  }

  Future<void> _alterarTema(ThemeMode modo) async {
    setState(() => _themeMode = modo);
    await themeController.setThemeMode(modo); // ✅ salva + notifica app
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      drawer: const AppDrawer(currentRoute: '/config-grafico'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Visão inicial do gráfico",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 8),

          RadioListTile<GraficoVisaoInicial>(
            title: const Text("Ano"),
            value: GraficoVisaoInicial.ano,
            groupValue: _visao,
            onChanged: (v) => _salvarVisao(v!),
          ),
          RadioListTile<GraficoVisaoInicial>(
            title: const Text("Mês"),
            value: GraficoVisaoInicial.mes,
            groupValue: _visao,
            onChanged: (v) => _salvarVisao(v!),
          ),
          RadioListTile<GraficoVisaoInicial>(
            title: const Text("Dia"),
            value: GraficoVisaoInicial.dia,
            groupValue: _visao,
            onChanged: (v) => _salvarVisao(v!),
          ),

          const SizedBox(height: 24),
          Divider(color: colors.primary.withOpacity(0.3)),
          const SizedBox(height: 24),

          Text(
            "Tema do aplicativo",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 8),

          RadioListTile<ThemeMode>(
            title: const Text("Claro"),
            value: ThemeMode.light,
            groupValue: _themeMode,
            onChanged: (v) => _alterarTema(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Escuro"),
            value: ThemeMode.dark,
            groupValue: _themeMode,
            onChanged: (v) => _alterarTema(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Automático (Sistema)"),
            value: ThemeMode.system,
            groupValue: _themeMode,
            onChanged: (v) => _alterarTema(v!),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
