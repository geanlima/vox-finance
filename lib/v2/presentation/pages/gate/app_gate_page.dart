// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/service/session_service.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'package:vox_finance/main_v1.dart' show VoxFinanceApp;

import 'package:vox_finance/v2/app/di/injector.dart' as v2;
import 'package:vox_finance/v2/app/vox_finance_v2_app.dart';
import 'package:vox_finance/ui/core/service/app_version_service.dart';

class AppGatePage extends StatefulWidget {
  const AppGatePage({super.key});

  @override
  State<AppGatePage> createState() => _AppGatePageState();
}

class _AppGatePageState extends State<AppGatePage> {
  bool _loading = true;
  bool _isLogged = false;
  String? _version; // v1 | v2 | null
  bool _bootedOnce = false;

  Future<User?> _getFirebaseUserWithWarmup({
    // Em alguns aparelhos, a restauração de sessão do Firebase no cold start
    // leva alguns segundos a mais. Se o timeout for curto, o app cai no login
    // mesmo com sessão válida.
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final auth = FirebaseAuth.instance;
    final cur = auth.currentUser;
    if (cur != null) return cur;

    try {
      // Em cold start, o Firebase pode demorar um pouco para restaurar a sessão.
      return await auth.authStateChanges().first.timeout(timeout);
    } catch (_) {
      return auth.currentUser;
    }
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ garante que ao voltar para /gate (após trocar versão) ele recarrega tudo
    if (_bootedOnce) {
      _boot();
    }
    _bootedOnce = true;
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final logged = await _checkLogged();
    var version = logged ? await AppVersionService.getSelectedVersion() : null;

    // ✅ padrão: entra direto na V1 (Home) sem pedir escolha
    if (logged && version == null) {
      version = 'v1';
      await AppVersionService.setSelectedVersion('v1');
    }

    if (!mounted) return;
    setState(() {
      _isLogged = logged;
      _version = version; // null => vai escolher
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

    // 1) não está logado => login
    if (!_isLogged) {
      return LoginUnificadoPage(onLoginOk: _onLoginOk);
    }

    // 2) logado e sem versão => por segurança, entra na V1
    if (_version == null) return const _V1Entry();

    // 3) abre app escolhido
    if (_version == 'v2') return const _V2Entry();
    return const _V1Entry();
  }
}

class _V1Entry extends StatelessWidget {
  const _V1Entry();

  @override
  Widget build(BuildContext context) => const VoxFinanceApp();
}

class _V2Entry extends StatelessWidget {
  const _V2Entry();

  static final Future<void> _initFuture = v2.InjectorV2.init();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Erro init V2: ${snap.error}')),
          );
        }
        return const VoxFinanceV2App();
      },
    );
  }
}
