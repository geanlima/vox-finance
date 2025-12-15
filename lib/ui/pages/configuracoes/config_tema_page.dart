// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/theme_controller.dart';

class ConfigTemaPage extends StatelessWidget {
  const ConfigTemaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeMode atual = themeController.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Tema do aplicativo')),
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
  }
}
