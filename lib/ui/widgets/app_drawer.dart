// ignore_for_file: deprecated_member_use, unused_field, unnecessary_null_comparison, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Usuario? _usuario;
  bool _carregandoUsuario = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  Future<void> _carregarUsuario() async {
    try {
      final usuario = await DbService.instance.obterUsuario();
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _carregandoUsuario = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoUsuario = false;
      });
    }
  }

  Future<void> _logout() async {
    Navigator.pop(context);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final String nomeOuEmail;
    final String subtitulo;

    if (_usuario == null) {
      nomeOuEmail = 'Bem-vindo';
      subtitulo = 'Toque em "Criar conta" ou faça login';
    } else {
      nomeOuEmail =
          (_usuario!.nome != null && _usuario!.nome.trim().isNotEmpty)
              ? _usuario!.nome
              : _usuario!.email;
      subtitulo = _usuario!.email;
    }

    // Iniciais para o avatar
    String iniciais = '';
    if (_usuario != null) {
      final base =
          (_usuario!.nome != null && _usuario!.nome.trim().isNotEmpty)
              ? _usuario!.nome.trim()
              : _usuario!.email.trim();
      final partes = base.split(' ');
      if (partes.length == 1) {
        iniciais = partes.first.characters.first.toUpperCase();
      } else {
        iniciais =
            '${partes.first.characters.first.toUpperCase()}${partes.last.characters.first.toUpperCase()}';
      }
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        _usuario == null
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
                          nomeOuEmail,
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
                          subtitulo,
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

            // ==========================
            // 📌 ÍTENS DO MENU
            // ==========================
            _menuItem(
              context,
              icon: Icons.table_rows,
              label: 'Lançamentos',
              route: '/',
            ),

            _menuItem(
              context,
              icon: Icons.calendar_month,
              label: 'Resumo do mês',
              route: '/graficos',
            ),

            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Comparativo de meses'),
              onTap: () {
                Navigator.pushNamed(context, '/comparativo-mes');
              },
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

            // ➕ NOVO MENU AQUI
            _menuItem(
              context,
              icon: Icons.account_balance,
              label: 'Contas bancárias',
              route: '/contas-bancarias',
            ),

            const Spacer(),

            // ==========================
            // 🚪 SAIR
            // ==========================
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
      onTap: () {
        Navigator.pop(context);
        if (ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
