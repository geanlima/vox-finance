// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colors.primary),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'VoxFinance',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),

            _menuItem(
              context,
              icon: Icons.table_rows,
              label: 'Lançamentos',
              route: '/',
            ),
            _menuItem(
              context,
              icon: Icons.bar_chart,
              label: 'Gráfico',
              route: '/graficos',
            ),
            _menuItem(
              context,
              icon: Icons.receipt_long,
              label: 'Contas a pagar',
              route: '/contas-pagar',
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
