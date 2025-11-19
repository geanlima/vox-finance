import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vox_finance/ui/core/theme/app_theme.dart';
import 'package:vox_finance/ui/core/service/theme_controller.dart';
import 'package:vox_finance/ui/pages/grafico/config_grafico_page.dart';
import 'package:vox_finance/ui/pages/grafico/grafico_mensal_page.dart';

import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/pages/contas_pagar/contas_pagar_page.dart';
import 'package:vox_finance/ui/pages/lancamento_futuro/lancamento_futuro_page.dart';

// 👇 instancia GLOBAL, é essa que você usa no ConfigGraficoPage
final themeController = ThemeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  runApp(const VoxFinanceApp());
}

class VoxFinanceApp extends StatelessWidget {
  const VoxFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'VoxFinance',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          // 👇 AQUI É O SEGREDO: usa o valor do controller
          themeMode: themeController.themeMode,

          initialRoute: '/',
          routes: {
            '/': (_) => const HomePage(),
            '/grafico-mensal': (_) => const GraficoMensalPage(),
            '/config-grafico': (_) => const ConfigGraficoPage(),
            '/contas-pagar': (_) => const ContasPagarPage(),
            '/lancamentos-futuros': (_) => const LancamentosFuturosPage(),
          },
        );
      },
    );
  }
}
