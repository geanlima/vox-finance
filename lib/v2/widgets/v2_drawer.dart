import 'package:flutter/material.dart';
import 'package:vox_finance/v2/app/router/app_router.dart';

class V2Drawer extends StatelessWidget {
  const V2Drawer({super.key});

  @override
  Widget build(BuildContext context) {
    void goTo(String route) {
      Navigator.pop(context);
      final current = ModalRoute.of(context)?.settings.name;
      if (current == route) return;
      Navigator.pushNamed(context, route);
    }

    Widget actionItem({
      required IconData icon,
      required String title,
      VoidCallback? onTap,
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        onTap: () {
          Navigator.pop(context);
          onTap?.call();
        },
      );
    }

    Widget treeGroup({
      required IconData icon,
      required String title,
      required List<Widget> children,
      bool initiallyExpanded = false,
    }) {
      final cs = Theme.of(context).colorScheme;

      return ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.only(left: 18),
        iconColor: cs.onSurfaceVariant,
        collapsedIconColor: cs.onSurfaceVariant,
        children: children,
      );
    }

    Widget subItem({
      required IconData icon,
      required String title,
      required String route,
    }) {
      return ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(title),
        onTap: () => goTo(route),
      );
    }

    // ✅ HEADER (fica fora do scroll)
    final header = Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      color: Theme.of(context).colorScheme.primary,
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(width: 12),
          Text(
            'VoxFinance V2',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            header,

            // ✅ PARTE QUE ROLA
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 🧾 Diário e Visão Geral (TREE)
                  treeGroup(
                    icon: Icons.dashboard_outlined,
                    title: '🧾 Diário e Visão Geral',
                    children: [
                      subItem(
                        icon: Icons.note_alt_outlined,
                        title: '🧠 Notas rápidas',
                        route: AppRouterV2.notasRapidas,
                      ),

                      // CATEGORIAS (TREE dentro do grupo diário) — opcional
                      ExpansionTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text(
                          '📚 Categorias',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        childrenPadding: const EdgeInsets.only(left: 18),
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.edit_outlined, size: 20),
                            title: const Text('Cadastro de categorias'),
                            onTap: () => goTo(AppRouterV2.categorias),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.pie_chart_outline,
                              size: 20,
                            ),
                            title: const Text('Limites / Gastos por categoria'),
                            onTap: () => goTo(AppRouterV2.gastosCategorias),
                          ),
                        ],
                      ),

                      subItem(
                        icon: Icons.insights_outlined,
                        title: '📊 Balanço do mês/ano',
                        route: AppRouterV2.balanco,
                      ),
                      subItem(
                        icon: Icons.pie_chart_outline,
                        title: '📊 Gastos por Categorias',
                        route: AppRouterV2.gastosCategorias,
                      ),
                      subItem(
                        icon: Icons.calendar_month_outlined,
                        title: '📅 Calendário de Vencimentos',
                        route: AppRouterV2.calendarioVencimentos,
                      ),
                    ],
                  ),

                  const Divider(),

                  // 💵 Fluxo de dinheiro (TREE)
                  treeGroup(
                    icon: Icons.swap_horiz_outlined,
                    title: '💵 Fluxo de dinheiro',
                    children: [
                      subItem(
                        icon: Icons.attach_money,
                        title: '💰 Meus Ganhos',
                        route: AppRouterV2.meusGanhos,
                      ),
                      subItem(
                        icon: Icons.home_outlined,
                        title: '🏠 Despesas Fixas',
                        route: AppRouterV2.despesasFixas,
                      ),
                      subItem(
                        icon: Icons.shopping_cart_outlined,
                        title: '🛒 Despesas Variáveis',
                        route: AppRouterV2.despesasVariaveis,
                      ),
                    ],
                  ),

                  const Divider(),

                  // 💳 Pagamentos e obrigações (TREE)
                  treeGroup(
                    icon: Icons.credit_card_outlined,
                    title: '💳 Pagamentos e obrigações',
                    children: [
                      subItem(
                        icon: Icons.account_balance_outlined,
                        title: '🏦 Minhas Formas de Pagamento',
                        route: AppRouterV2.formasPagamento,
                      ),
                      subItem(
                        icon: Icons.credit_card_outlined,
                        title: '💳 Controle de Parcelamento',
                        route: AppRouterV2.parcelamento,
                      ),
                      subItem(
                        icon: Icons.receipt_long_outlined,
                        title: '💸 Minhas Dívidas',
                        route: AppRouterV2.dividas,
                      ),
                      subItem(
                        icon: Icons.groups_outlined,
                        title: '👥 Pessoas que me devem',
                        route: AppRouterV2.pessoasMeDevem,
                      ),
                    ],
                  ),

                  const Divider(),

                  // 🎯 Metas, desejos e gamificação (TREE)
                  treeGroup(
                    icon: Icons.emoji_events_outlined,
                    title: '🎯 Metas, desejos e gamificação',
                    children: [
                      subItem(
                        icon: Icons.savings_outlined,
                        title: '🐷 Meu Cofrinho',
                        route: AppRouterV2.cofrinho,
                      ),
                      subItem(
                        icon: Icons.shopping_bag_outlined,
                        title: '🛍️ Desejo de Compras',
                        route: AppRouterV2.desejoCompras,
                      ),
                      subItem(
                        icon: Icons.search_outlined,
                        title: '🔎 Caça aos preços',
                        route: AppRouterV2.cacaPrecos,
                      ),
                      subItem(
                        icon: Icons.emoji_events_outlined,
                        title: '🎯 Mural dos Sonhos',
                        route: AppRouterV2.muralSonhos,
                      ),
                      subItem(
                        icon: Icons.fitness_center_outlined,
                        title: '💪 Desafio Financeiro',
                        route: AppRouterV2.desafioFinanceiro,
                      ),
                    ],
                  ),

                  const Divider(),

                  // 📈 Patrimônio (TREE)
                  treeGroup(
                    icon: Icons.trending_up_outlined,
                    title: '📈 Patrimônio',
                    children: [
                      subItem(
                        icon: Icons.trending_up_outlined,
                        title: '📈 Meus Investimentos',
                        route: AppRouterV2.investimentos,
                      ),
                    ],
                  ),

                  const Divider(),

                  // ⚙️ Configurações (TREE)
                  treeGroup(
                    icon: Icons.settings_outlined,
                    title: '⚙️ Configurações',
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.cloud_outlined, size: 20),
                        title: const Text('☁️ Backup na nuvem'),
                        onTap: () {
                          Navigator.pop(context);                          
                        },
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.palette_outlined, size: 20),
                        title: const Text('🎨 Tema do aplicativo'),
                        onTap: () {
                          Navigator.pop(context);                          
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ✅ RODAPÉ FIXO (Sair sempre no final)
            const Divider(height: 1),
            actionItem(
              icon: Icons.logout,
              title: 'Sair',
              color: Colors.red,
              onTap: () {
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('v2', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
