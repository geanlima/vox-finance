// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/service/session_service.dart';
import 'package:vox_finance/ui/pages/auth/login_unificado_page.dart';
import 'package:vox_finance/main_v1.dart' show VoxFinanceApp;

import 'package:vox_finance/v2/app/di/injector.dart' as v2;
import 'package:vox_finance/v2/app/vox_finance_v2_app.dart';
import 'package:vox_finance/v2/presentation/pages/gate/escolher_versao_page.dart';
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
    final version =
        logged ? await AppVersionService.getSelectedVersion() : null;

    if (!mounted) return;
    setState(() {
      _isLogged = logged;
      _version = version; // null => vai escolher
      _loading = false;
    });
  }

  Future<bool> _checkLogged() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      await SessionService.instance.saveLogin(
        loginType: 'firebase',
        uid: fbUser.uid,
      );
      return true;
    }

    final logged = await SessionService.instance.isLoggedIn();
    final loginType = await SessionService.instance.getLoginType();
    return logged && loginType == 'local';
  }

  Future<void> _onLoginOk() async {
    await _boot();
  }

  Future<void> _onEscolheuVersao(String v) async {
    await AppVersionService.setSelectedVersion(v);
    if (!mounted) return;
    setState(() => _version = v);
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

    // 2) logado e sem versão => escolher
    if (_version == null) {
      return EscolherVersaoPage(onEscolheu: _onEscolheuVersao);
    }

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
