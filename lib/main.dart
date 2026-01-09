import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:vox_finance/ui/core/service/theme_controller.dart';
import 'package:vox_finance/ui/core/theme/app_theme.dart';

import 'package:vox_finance/ui/pages/auth/auth_gate_page.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/pages/categorias/categorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/renda/minha_renda_page.dart';
import 'package:vox_finance/ui/pages/cartao/cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/comparativo/comparativo_mes_page.dart';
import 'package:vox_finance/ui/pages/contas/contas_page.dart';
import 'package:vox_finance/ui/pages/contas_pagar/contas_pagar_page.dart';
import 'package:vox_finance/ui/pages/grafico/graficos_page.dart';
import 'package:vox_finance/ui/pages/settings/backup_restore_cloud_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // ignora duplicate-app em hot restart
  }

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
          themeMode: themeController.themeMode,
          initialRoute: '/gate',
          routes: _routes(),
        );
      },
    );
  }

  static Map<String, WidgetBuilder> _routes() {
    return {
      '/gate': (_) => const AuthGatePage(),
      '/login': (_) => const LoginUnificadoPage(),
      '/': (_) => const HomePage(),

      '/categorias-personalizadas': (_) => const CategoriasPersonalizadasPage(),
      '/contas-pagar': (_) => const ContasPagarPage(),
      '/cartoes-credito': (_) => const CartaoCreditoPage(),
      '/contas-bancarias': (_) => const ContasPage(),
      '/graficos': (_) => const GraficosPage(),
      '/comparativo-mes': (_) => const ComparativoMesPage(),
      '/minha-renda': (_) => const MinhaRendaPage(),
      '/backup-cloud': (_) => const BackupRestoreCloudPage(),
    };
  }
}
