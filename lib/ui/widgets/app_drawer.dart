// ignore_for_file: deprecated_member_use, unnecessary_null_comparison, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';
import 'package:vox_finance/ui/data/modules/usuarios/usuario_repository.dart';
import 'package:vox_finance/ui/pages/categorias/categorias_personalizadas_page.dart';
import 'package:vox_finance/ui/pages/configuracoes/config_tema_page.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final UsuarioRepository _repositoryUsuario = UsuarioRepository();

  Usuario? _usuarioLocal;
  fb.User? _usuarioFirebase;

  bool _carregandoUsuario = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  Future<void> _carregarUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginType = prefs.getString('loginType'); // 'firebase' | 'local'

      if (loginType == 'firebase') {
        final current = fb.FirebaseAuth.instance.currentUser;

        if (!mounted) return;
        setState(() {
          _usuarioFirebase = current;
          _usuarioLocal = null;
          _carregandoUsuario = false;
        });
        return;
      }

      final usuario = await _repositoryUsuario.obterPrimeiro();

      if (!mounted) return;
      setState(() {
        _usuarioLocal = usuario;
        _usuarioFirebase = null;
        _carregandoUsuario = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregandoUsuario = false);
    }
  }

  // ✅ helper: navegação que sempre fecha o drawer e evita empilhar rota igual
  void _go(String route) {
    Navigator.pop(context); // fecha drawer
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _logout() async {
    Navigator.pop(context);

    final prefs = await SharedPreferences.getInstance();
    final loginType = prefs.getString('loginType');

    if (loginType == 'firebase') {
      await FirebaseAuthService.instance.signOut();
    }

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loginType');

    // ✅ volta pro gate (ele decide login/home)
    Navigator.pushNamedAndRemoveUntil(context, '/gate', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final String nome;
    final String email;
    final String iniciais;

    if (_carregandoUsuario) {
      nome = 'Carregando...';
      email = '';
      iniciais = '';
    } else if (_usuarioFirebase != null) {
      nome =
          _usuarioFirebase!.displayName?.trim().isNotEmpty == true
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
    } else {
      nome = 'Bem-vindo';
      email = 'Faça login';
      iniciais = '';
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colors.primary),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.onPrimary.withOpacity(0.1),
                    child:
                        iniciais.isEmpty
                            ? Icon(
                              Icons.person,
                              color: colors.onPrimary,
                              size: 28,
                            )
                            : Text(
                              iniciais,
                              style: TextStyle(
                                color: colors.onPrimary,
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
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onPrimary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ✅ MENU
            _menuItem(
              context,
              icon: Icons.table_rows,
              label: 'Lançamentos',
              route: '/',
            ),
            _menuItem(
              context,
              icon: Icons.calendar_month,
              label: 'Resumo do mês (Gastos)',
              route: '/graficos',
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Comparativo de meses'),
              onTap: () => _go('/comparativo-mes'),
            ),
            _menuItem(
              context,
              icon: Icons.credit_card,
              label: 'Cartão',
              route: '/cartoes-credito',
            ),
            _menuItem(
              context,
              icon: Icons.receipt_long,
              label: 'Contas a pagar',
              route: '/contas-pagar',
            ),
            _menuItem(
              context,
              icon: Icons.account_balance,
              label: 'Contas bancárias',
              route: '/contas-bancarias',
            ),
            _menuItem(
              context,
              icon: Icons.savings,
              label: 'Minha renda',
              route: '/minha-renda',
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Minhas categorias'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  CategoriasPersonalizadasPage.routeName,
                );
              },
            ),

            const Divider(height: 24),

            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup na nuvem'),
              onTap: () => _go('/backup-cloud'),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Tema do aplicativo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConfigTemaPage()),
                );
              },
            ),

            const Divider(height: 24),

            ListTile(
              leading: Icon(Icons.logout, color: colors.error),
              title: Text(
                'Sair',
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _logout,
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onBackground.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iniciaisFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';

    final partes =
        t.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    if (partes.isEmpty) return '';

    if (partes.length == 1) {
      return partes.first.characters.first.toUpperCase();
    }
    return '${partes.first.characters.first.toUpperCase()}${partes.last.characters.first.toUpperCase()}';
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final selected = ModalRoute.of(context)?.settings.name == route;
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colors.primary : colors.onBackground.withOpacity(0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          color:
              selected ? colors.primary : colors.onBackground.withOpacity(0.85),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: colors.primary.withOpacity(0.08),
      onTap: () => _go(route),
    );
  }
}
