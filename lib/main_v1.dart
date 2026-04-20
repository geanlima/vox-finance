import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vox_finance/ui/core/service/theme_controller.dart';
import 'package:vox_finance/ui/core/theme/app_theme.dart';

import 'package:vox_finance/ui/pages/auth/auth_gate_page.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'package:vox_finance/ui/pages/home/home_dashboard_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/pages/categorias/categorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/categorias/subcategorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/metricas/metricas_page.dart';
import 'package:vox_finance/ui/pages/renda/minha_renda_page.dart';
import 'package:vox_finance/ui/pages/cartao/cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/comparativo/comparativo_mes_page.dart';
import 'package:vox_finance/ui/pages/contas/contas_page.dart';
import 'package:vox_finance/ui/pages/contas_pagar/contas_pagar_page.dart';
import 'package:vox_finance/ui/pages/despesas_fixas/despesas_fixas_page.dart';
import 'package:vox_finance/ui/pages/grafico/graficos_page.dart';
import 'package:vox_finance/ui/pages/settings/backup_restore_cloud_page.dart';
import 'package:vox_finance/ui/pages/investimentos/carteiras_investimento_page.dart';
import 'package:vox_finance/ui/pages/lembretes/lembretes_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/config_tema_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/parametros_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/sobre_page.dart';
import 'package:vox_finance/ui/pages/integracao/associacao_page.dart';
import 'package:vox_finance/ui/pages/integracao/associar_cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/integracao/faturas_cartao_page.dart';
import 'package:vox_finance/ui/pages/faturas_salvas/faturas_salvas_page.dart';
import 'package:vox_finance/ui/pages/parcelamentos/parcelamentos_page.dart';
import 'package:vox_finance/ui/pages/monitoramento_precos/monitoramento_precos_page.dart';
import 'package:vox_finance/ui/pages/planejamentos/planejamentos_despesa_list_page.dart';
import 'package:vox_finance/ui/pages/pessoas_me_devem/pessoas_me_devem_page.dart';

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
      '/': (_) => const HomeDashboardPage(),
      '/lancamentos': (_) => const HomePage(),

      '/categorias-personalizadas': (_) => const CategoriasPersonalizadasPage(),
      SubcategoriasPersonalizadasPage.routeName: (_) =>
          const SubcategoriasPersonalizadasPage(),
      MetricasPage.routeName: (_) => const MetricasPage(),
      '/contas-pagar': (_) => const ContasPagarPage(),
      ParcelamentosPage.routeName: (_) => const ParcelamentosPage(),
      '/cartoes-credito': (_) => const CartaoCreditoPage(),
      '/contas-bancarias': (_) => const ContasPage(),
      '/graficos': (_) => const GraficosPage(),
      '/comparativo-mes': (_) => const ComparativoMesPage(),
      '/minha-renda': (_) => const MinhaRendaPage(),
      BackupRestoreCloudPage.routeName: (_) => const BackupRestoreCloudPage(),

      '/despesas-fixas': (_) => const DespesasFixasPage(),
      '/investimentos/carteiras': (_) => const CarteirasInvestimentoPage(),
      // compat: antigo atalho "Bluminers" abre a lista de carteiras
      '/investimentos/bluminers': (_) => const CarteirasInvestimentoPage(),
      '/lembretes': (_) => const LembretesPage(),
      ConfigTemaPage.routeName: (_) => const ConfigTemaPage(),
      ParametrosPage.routeName: (_) => const ParametrosPage(),
      SobrePage.routeName: (_) => const SobrePage(),
      AssociacaoPage.routeName: (_) => const AssociacaoPage(),
      FaturasCartaoPage.routeName: (_) => const FaturasCartaoPage(),
      AssociarCartaoCreditoPage.routeName: (_) =>
          const AssociarCartaoCreditoPage(),
      FaturasSalvasPage.routeName: (_) => const FaturasSalvasPage(),
      MonitoramentoPrecosPage.routeName: (_) => const MonitoramentoPrecosPage(),
      PlanejamentosDespesaListPage.routeName: (_) =>
          const PlanejamentosDespesaListPage(),
      PessoasMeDevemPage.routeName: (_) => const PessoasMeDevemPage(),
    };
  }
}
