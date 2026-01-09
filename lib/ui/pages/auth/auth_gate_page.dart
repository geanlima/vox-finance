import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_unificado_page.dart';
import '../home/home_page.dart';

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final logged = snap.data ?? false;
        return logged ? const HomePage() : const LoginUnificadoPage();
      },
    );
  }
}
