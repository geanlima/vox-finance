import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vox_finance/ui/core/theme/app_theme.dart';
import 'package:vox_finance/ui/pages/auth/login_page.dart'; // 👈 IMPORTANTE
import 'package:vox_finance/ui/pages/cartao/cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/pages/contas_pagar/contas_pagar_page.dart';
import 'package:vox_finance/ui/pages/grafico/graficos_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  runApp(const VoxFinanceApp());
}

class VoxFinanceApp extends StatelessWidget {
  const VoxFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxFinance',
      debugShowCheckedModeBanner: false,

      // 🎨 Tema sempre CLARO
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // 🧹 Remove a barra de rolagem padrão do Flutter
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),

      // 👉 PRIMEIRA TELA DO APP
      initialRoute: '/login',

      routes: {
        '/login': (_) => LoginPage(),
        '/': (_) => const HomePage(),
        '/contas-pagar': (_) => const ContasPagarPage(),
        '/cartoes-credito': (_) => const CartaoCreditoPage(),
        '/graficos': (_) => const GraficosPage(),
      },
    );
  }
}
