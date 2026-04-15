// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_null_comparison, unused_element

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vox_finance/ui/core/nav/app_navigator.dart';
import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/core/service/app_version_service.dart';

import 'package:vox_finance/ui/data/models/usuario.dart';
import 'package:vox_finance/ui/data/modules/usuarios/usuario_repository.dart';

import 'package:vox_finance/ui/pages/categorias/categorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/categorias/subcategorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/metricas/metricas_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/config_tema_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/parametros_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/sobre_page.dart';
import 'package:vox_finance/ui/pages/integracao/associacao_page.dart';
import 'package:vox_finance/ui/pages/integracao/faturas_cartao_page.dart';
import 'package:vox_finance/ui/pages/faturas_salvas/faturas_salvas_page.dart';
import 'package:vox_finance/ui/pages/settings/backup_restore_cloud_page.dart';
import 'package:vox_finance/ui/pages/parcelamentos/parcelamentos_page.dart';
import 'package:vox_finance/ui/pages/monitoramento_precos/monitoramento_precos_page.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;
  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final UsuarioRepository _repoUsuario = UsuarioRepository();

  Usuario? _usuarioLocal;
  fb.User? _usuarioFirebase;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final loginType = sp.getString('loginType'); // 'firebase' | 'local'

      if (loginType == 'firebase') {
        final current = fb.FirebaseAuth.instance.currentUser;
        if (!mounted) return;
        setState(() {
          _usuarioFirebase = current;
          _usuarioLocal = null;
          _loadingUser = false;
        });
        return;
      }

      final usuario = await _repoUsuario.obterPrimeiro();
      if (!mounted) return;
      setState(() {
        _usuarioLocal = usuario;
        _usuarioFirebase = null;
        _loadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUser = false);
    }
  }

  void _go(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (Navigator.canPop(context)) Navigator.pop(context); // fecha drawer
    if (current == route) return;
    // Evita "duplicar" a Home no stack:
    // Ex.: Home -> Despesas fixas -> (Drawer) Home.
    // Se usarmos pushReplacement aqui, fica uma Home antiga embaixo e o voltar
    // aparenta ter "duas homes". Para a Home, limpamos o stack.
    if (route == '/') {
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
      return;
    }

    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _trocarVersao() async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    // não desloga, só limpa versão
    await AppVersionService.clearSelectedVersion();

    // volta pro Gate pelo ROOT navigator
    await AppNavigator.goToGateClearingStack();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmReset(String label) async {
    return (await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar reset do banco'),
            content: Text(
              'Isso vai apagar os dados do banco local ($label). Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Zerar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _logout() async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    final sp = await SharedPreferences.getInstance();
    final loginType = sp.getString('loginType');

    if (loginType == 'firebase') {
      try {
        await FirebaseAuthService.instance.signOut();
      } catch (_) {}
    }

    await sp.setBool('isLoggedIn', false);
    await sp.remove('loginType');

    // recomendado: limpar versão ao sair
    await AppVersionService.clearSelectedVersion();

    // volta pro Gate pelo ROOT navigator
    await AppNavigator.goToGateClearingStack();
  }

  String _iniciaisFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final partes =
        t.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return '${partes.first.characters.first.toUpperCase()}${partes.last.characters.first.toUpperCase()}';
  }

  Widget _treeGroup({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      leading: Icon(icon, color: cs.onBackground.withOpacity(0.75)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.only(left: 18),
      children: children,
    );
  }

  Widget _subItem({
    required IconData icon,
    required String title,
    required String route,
  }) {
    final selected = ModalRoute.of(context)?.settings.name == route;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: selected ? cs.primary : cs.onBackground.withOpacity(0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? cs.primary : cs.onBackground.withOpacity(0.85),
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: cs.primary.withOpacity(0.08),
      onTap: () => _go(route),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    final selected = ModalRoute.of(context)?.settings.name == route;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? cs.primary : cs.onBackground.withOpacity(0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? cs.primary : cs.onBackground.withOpacity(0.85),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: cs.primary.withOpacity(0.08),
      onTap: () => _go(route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String nome = 'Bem-vindo';
    String email = 'Faça login';
    String iniciais = '';

    if (_loadingUser) {
      nome = 'Carregando...';
      email = '';
    } else if (_usuarioFirebase != null) {
      nome =
          (_usuarioFirebase!.displayName?.trim().isNotEmpty == true)
              ? _usuarioFirebase!.displayName!.trim()
              : 'Usuário Google';
      email = _usuarioFirebase!.email ?? '';
      iniciais = _iniciaisFromText(nome.isNotEmpty ? nome : email);
    } else if (_usuarioLocal != null) {
      nome =
          (_usuarioLocal!.nome != null && _usuarioLocal!.nome.trim().isNotEmpty)
              ? _usuarioLocal!.nome.trim()
              : 'Usuário local';
      email = _usuarioLocal!.email;
      iniciais = _iniciaisFromText(nome.isNotEmpty ? nome : email);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.primary),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.onPrimary.withOpacity(0.1),
                    child:
                        iniciais.isEmpty
                            ? Icon(Icons.person, color: cs.onPrimary, size: 28)
                            : Text(
                              iniciais,
                              style: TextStyle(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _menuItem(icon: Icons.home_outlined, label: 'Home', route: '/'),
            _treeGroup(
              icon: Icons.how_to_reg,
              title: 'Cadastro',
              children: [
                _subItem(
                  icon: Icons.account_balance,
                  title: 'Contas bancárias',
                  route: '/contas-bancarias',
                ),
                _subItem(
                  icon: Icons.credit_card,
                  title: 'Cartão',
                  route: '/cartoes-credito',
                ),
                _subItem(
                  icon: Icons.savings,
                  title: 'Minha renda',
                  route: '/minha-renda',
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.category, size: 20),
                  title: const Text('Minhas categorias'),
                  onTap: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      CategoriasPersonalizadasPage.routeName,
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.account_tree_outlined, size: 20),
                  title: const Text('Subcategorias'),
                  onTap: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      SubcategoriasPersonalizadasPage.routeName,
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.insights_outlined, size: 20),
                  title: const Text('Métricas (limites)'),
                  onTap: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    Navigator.pushNamed(context, MetricasPage.routeName);
                  },
                ),
              ],
            ),
            _treeGroup(
              icon: Icons.swap_vert_circle_outlined,
              title: 'Movimentação',
              children: [
                _subItem(
                  icon: Icons.table_rows,
                  title: 'Lançamentos',
                  route: '/lancamentos',
                ),
                _subItem(
                  icon: Icons.view_timeline_outlined,
                  title: 'Parcelamentos',
                  route: ParcelamentosPage.routeName,
                ),
                _subItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Fatura do cartão de crédito',
                  route: FaturasSalvasPage.routeName,
                ),
                _subItem(
                  icon: Icons.home_work_outlined,
                  title: 'Despesas fixas',
                  route: '/despesas-fixas',
                ),
                _subItem(
                  icon: Icons.receipt_long,
                  title: 'Contas a pagar',
                  route: '/contas-pagar',
                ),
              ],
            ),
            _treeGroup(
              icon: Icons.build_outlined,
              title: 'Manutenção',
              children: [
                _subItem(
                  icon: Icons.local_offer_outlined,
                  title: 'Monitoramento de preços',
                  route: MonitoramentoPrecosPage.routeName,
                ),
              ],
            ),
            _treeGroup(
              icon: Icons.trending_up,
              title: 'Investimento',
              children: [
                _subItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Carteiras',
                  route: '/investimentos/carteiras',
                ),
              ],
            ),
            _menuItem(
              icon: Icons.calendar_month,
              label: 'Resumo do mês (Gastos)',
              route: '/graficos',
            ),
            _menuItem(
              icon: Icons.compare_arrows,
              label: 'Comparativo de meses',
              route: '/comparativo-mes',
            ),
            _treeGroup(
              icon: Icons.integration_instructions_outlined,
              title: 'Integração',
              children: [
                _subItem(
                  icon: Icons.link,
                  title: 'Associação',
                  route: AssociacaoPage.routeName,
                ),
                _subItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Faturas de cartão',
                  route: FaturasCartaoPage.routeName,
                ),
              ],
            ),
            _treeGroup(
              icon: Icons.settings_outlined,
              title: 'Configuração',
              children: [
                _subItem(
                  icon: Icons.color_lens_outlined,
                  title: 'Tema do aplicativo',
                  route: ConfigTemaPage.routeName,
                ),
                _subItem(
                  icon: Icons.tune_outlined,
                  title: 'Parâmetros',
                  route: ParametrosPage.routeName,
                ),
                _subItem(
                  icon: Icons.backup_outlined,
                  title: 'Backup na nuvem',
                  route: BackupRestoreCloudPage.routeName,
                ),
              ],
            ),
            _menuItem(
              icon: Icons.info_outline,
              label: 'Sobre',
              route: SobrePage.routeName,
            ),

            const Divider(height: 24),

            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text(
                'Sair',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w500),
              ),
              onTap: _logout,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
