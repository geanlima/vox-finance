// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/service/session_service.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'package:vox_finance/main_v1.dart' show VoxFinanceApp;

import 'package:vox_finance/ui/core/service/app_version_service.dart';

/// Ponto único de entrada após login: sempre a app V1 (`lib/ui`, `main_v1.dart`).
class AppGatePage extends StatefulWidget {
  const AppGatePage({super.key});

  @override
  State<AppGatePage> createState() => _AppGatePageState();
}

class _AppGatePageState extends State<AppGatePage> {
  bool _loading = true;
  bool _isLogged = false;

  Future<User?> _getFirebaseUserWithWarmup({
    // No cold start, o primeiro evento de authStateChanges pode ser null antes
    // da persistência nativa terminar de restaurar o usuário — especialmente em
    // aparelhos físicos. Não basta usar .first: isso "congela" como deslogado.
    Duration streamTimeout = const Duration(seconds: 12),
    Duration graceAfterNullEvent = const Duration(seconds: 2),
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;

    User? firstEvent;
    try {
      firstEvent = await auth.authStateChanges().first.timeout(streamTimeout);
    } on TimeoutException {
      return auth.currentUser;
    }

    if (firstEvent != null) return firstEvent;

    // firstEvent == null: ainda pode estar restaurando OU sessão inexistente.
    final until = DateTime.now().add(graceAfterNullEvent);
    while (DateTime.now().isBefore(until)) {
      final u = auth.currentUser;
      if (u != null) return u;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return auth.currentUser;
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final logged = await _checkLogged();
    if (logged) {
      // Sempre V1: normaliza prefs antigas (v2 / null).
      await AppVersionService.setSelectedVersion('v1');
    }

    if (!mounted) return;
    setState(() {
      _isLogged = logged;
      _loading = false;
    });
  }

  Future<bool> _checkLogged() async {
    final logged = await SessionService.instance.isLoggedIn();
    final loginType = await SessionService.instance.getLoginType();

    // Login local segue só por prefs
    if (logged && loginType == 'local') return true;

    // Login Firebase: aguarda restauração da sessão (pode demorar no cold start).
    // Não depende apenas da flag em prefs, porque o Firebase precisa restaurar o usuário.
    if (logged && loginType == 'firebase') {
      final fbUser = await _getFirebaseUserWithWarmup();
      if (fbUser != null) {
        await SessionService.instance.saveLogin(
          loginType: 'firebase',
          uid: fbUser.uid,
        );
        return true;
      }
      // Se não restaurou, considera como não logado (vai para login).
      return false;
    }

    // Caso padrão: tenta firebase também (ex.: migração/primeiro uso).
    final fbUser = await _getFirebaseUserWithWarmup();
    if (fbUser != null) {
      await SessionService.instance.saveLogin(
        loginType: 'firebase',
        uid: fbUser.uid,
      );
      return true;
    }

    return false;
  }

  Future<void> _onLoginOk() async {
    await _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLogged) {
      return LoginUnificadoPage(onLoginOk: _onLoginOk);
    }

    return const _V1Entry();
  }
}

class _V1Entry extends StatelessWidget {
  const _V1Entry();

  @override
  Widget build(BuildContext context) => const VoxFinanceApp();
}
