// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vox_finance/v2/app/router/app_router.dart';
import 'package:vox_finance/ui/core/nav/app_navigator.dart';
import 'package:vox_finance/ui/core/service/app_version_service.dart';

class V2Drawer extends StatefulWidget {
  const V2Drawer({super.key});

  @override
  State<V2Drawer> createState() => _V2DrawerState();
}

class _V2DrawerState extends State<V2Drawer> {
  String _nome = 'VoxFinance V2';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    // 1) tenta Firebase
    final u = FirebaseAuth.instance.currentUser;
    String? nome = u?.displayName;
    String? email = u?.email;

    // 2) fallback (se você guarda algo no SharedPreferences na V1)
    // ajuste as chaves abaixo para as que você usa no seu app
    final sp = await SharedPreferences.getInstance();
    nome ??= sp.getString('userName');
    email ??= sp.getString('userEmail');

    if (!mounted) return;

    setState(() {
      _nome =
          (nome != null && nome.trim().isNotEmpty) ? nome.trim() : 'Usuário';
      _email = (email != null && email.trim().isNotEmpty) ? email.trim() : '';
    });
  }

  String _iniciais(String nome) {
    final parts =
        nome.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _goTo(BuildContext context, String route) {
    if (Navigator.canPop(context)) Navigator.pop(context);

    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;

    Navigator.pushNamed(context, route);
  }

  Future<void> _trocarVersao(BuildContext context) async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    await AppVersionService.clearSelectedVersion();
    await AppNavigator.goToGateClearingStack();
  }

  Future<void> _logout(BuildContext context) async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final sp = await SharedPreferences.getInstance();
    await sp.setBool('isLoggedIn', false);
    await sp.remove('loginType');

    await AppVersionService.clearSelectedVersion();
    await AppNavigator.goToGateClearingStack();
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iniciais = _iniciais(_nome);

    return Material(
      color: cs.primary,
      child: InkWell(
        onTap: () {
          // opcional: abrir uma tela "Perfil" no futuro
          // _goTo(context, AppRouterV2.perfil);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.onPrimary.withOpacity(.18),
                child: Text(
                  iniciais,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email.isEmpty ? ' ' : _email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onPrimary.withOpacity(.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _treeGroup(
    BuildContext context, {
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

  Widget _subItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    TextStyle? titleStyle,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title, style: titleStyle),
      onTap: () => _goTo(context, route),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _header(context),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ✅ HOME (com fonte maior se você quiser)
                  _subItem(
                    context,
                    icon: Icons.home_outlined,
                    title: '🏠 Home',
                    route: AppRouterV2.home,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const Divider(),

                  _treeGroup(
                    context,
                    icon: Icons.dashboard_outlined,
                    title: '🧾 Diário e Visão Geral',
                    children: [
                      _subItem(
                        context,
                        icon: Icons.note_alt_outlined,
                        title: '🧠 Notas rápidas',
                        route: AppRouterV2.notasRapidas,
                      ),
                      _subItem(
                        context,
                        icon: Icons.insights_outlined,
                        title: '📊 Balanço do mês/ano',
                        route: AppRouterV2.balanco,
                      ),
                      _subItem(
                        context,
                        icon: Icons.pie_chart_outline,
                        title: '📊 Gastos por Categorias',
                        route: AppRouterV2.gastosCategorias,
                      ),
                      _subItem(
                        context,
                        icon: Icons.calendar_month_outlined,
                        title: '📅 Calendário de Vencimentos',
                        route: AppRouterV2.calendarioVencimentos,
                      ),
                    ],
                  ),

                  const Divider(),

                  _treeGroup(
                    context,
                    icon: Icons.swap_horiz_outlined,
                    title: '💵 Fluxo de dinheiro',
                    children: [
                      _subItem(
                        context,
                        icon: Icons.attach_money,
                        title: '💰 Meus Ganhos',
                        route: AppRouterV2.meusGanhos,
                      ),
                      _subItem(
                        context,
                        icon: Icons.home_outlined,
                        title: '🏠 Despesas Fixas',
                        route: AppRouterV2.despesasFixas,
                      ),
                      _subItem(
                        context,
                        icon: Icons.shopping_cart_outlined,
                        title: '🛒 Despesas Variáveis',
                        route: AppRouterV2.despesasVariaveis,
                      ),
                    ],
                  ),

                  const Divider(),

                  _treeGroup(
                    context,
                    icon: Icons.credit_card_outlined,
                    title: '💳 Pagamentos e obrigações',
                    children: [
                      _subItem(
                        context,
                        icon: Icons.account_balance_outlined,
                        title: '🏦 Minhas Formas de Pagamento',
                        route: AppRouterV2.formasPagamento,
                      ),
                      _subItem(
                        context,
                        icon: Icons.credit_card_outlined,
                        title: '💳 Controle de Parcelamento',
                        route: AppRouterV2.parcelamento,
                      ),
                      _subItem(
                        context,
                        icon: Icons.receipt_long_outlined,
                        title: '💸 Minhas Dívidas',
                        route: AppRouterV2.dividas,
                      ),
                      _subItem(
                        context,
                        icon: Icons.groups_outlined,
                        title: '👥 Pessoas que me devem',
                        route: AppRouterV2.pessoasMeDevem,
                      ),
                    ],
                  ),

                  const Divider(),

                  _treeGroup(
                    context,
                    icon: Icons.trending_up_outlined,
                    title: '📈 Patrimônio',
                    children: [
                      _subItem(
                        context,
                        icon: Icons.trending_up_outlined,
                        title: '📈 Meus Investimentos',
                        route: AppRouterV2.investimentos,
                      ),
                    ],
                  ),

                  const Divider(),

                  _treeGroup(
                    context,
                    icon: Icons.settings_outlined,
                    title: '⚙️ Configurações',
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.swap_horiz_outlined,
                          size: 20,
                        ),
                        title: const Text('🔁 Trocar versão (V1/V2)'),
                        onTap: () => _trocarVersao(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
