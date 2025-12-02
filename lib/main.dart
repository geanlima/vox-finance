import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'firebase_options.dart';

import 'package:vox_finance/ui/core/theme/app_theme.dart';

import 'package:vox_finance/ui/pages/cartao/cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/comparativo/comparativo_mes_page.dart';
import 'package:vox_finance/ui/pages/contas/contas_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/pages/contas_pagar/contas_pagar_page.dart';
import 'package:vox_finance/ui/pages/grafico/graficos_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Inicializa o Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      routes: {
        '/login': (_) => const LoginUnificadoPage(),
        '/': (_) => const HomePage(),
        '/contas-pagar': (_) => const ContasPagarPage(),
        '/cartoes-credito': (_) => const CartaoCreditoPage(),
        '/contas-bancarias': (_) => const ContasPage(),
        '/graficos': (_) => const GraficosPage(),
        '/comparativo-mes': (_) => const ComparativoMesPage(),
      },
    );
  }
}
