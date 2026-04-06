// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/theme_controller.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class ConfigTemaPage extends StatelessWidget {
  const ConfigTemaPage({super.key});

  static const routeName = '/configuracao-tema';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final ThemeMode atual = themeController.themeMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tema do aplicativo'),
          ),
          drawer: const AppDrawer(currentRoute: ConfigTemaPage.routeName),
          body: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Padrão do sistema'),
                value: ThemeMode.system,
                groupValue: atual,
                onChanged: (value) {
                  if (value != null) {
                    themeController.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Tema claro'),
                value: ThemeMode.light,
                groupValue: atual,
                onChanged: (value) {
                  if (value != null) {
                    themeController.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Tema escuro'),
                value: ThemeMode.dark,
                groupValue: atual,
                onChanged: (value) {
                  if (value != null) {
                    themeController.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
