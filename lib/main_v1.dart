import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

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

class VoxFinanceApp extends StatelessWidget {
  const VoxFinanceApp({super.key});

  // se você preferir, pode mover isso pro main.dart (único)
  static final Future<void> _intlFuture = initializeDateFormatting(
    'pt_BR',
    null,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _intlFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

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

      // ⚠️ NÃO importe página do v2 aqui (evita acoplamento/side effects)
      // '/despesas-fixas': (_) => const DespesasFixasPage(),
    };
  }
}
