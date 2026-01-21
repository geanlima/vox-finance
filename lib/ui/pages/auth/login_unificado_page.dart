// ignore_for_file: use_build_context_synchronously, deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vox_finance/ui/core/service/local_auth_service.dart';
import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/core/service/backup_service.dart';
import 'package:vox_finance/ui/core/service/session_service.dart';

import 'package:vox_finance/ui/pages/auth/register_page.dart';
import 'package:vox_finance/ui/widgets/google_signin_button.dart';

class LoginUnificadoPage extends StatefulWidget {
  /// ✅ Gate usa isso para seguir o fluxo depois do login
  final Future<void> Function()? onLoginOk;

  const LoginUnificadoPage({super.key, this.onLoginOk});

  @override
  State<LoginUnificadoPage> createState() => _LoginUnificadoPageState();
}

class _LoginUnificadoPageState extends State<LoginUnificadoPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _goNextAfterLogin() async {
    if (widget.onLoginOk != null) {
      await widget.onLoginOk!(); // Gate decide a próxima tela
    }
  }

  Future<void> _checkAlreadyLogged() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        await SessionService.instance.saveLogin(
          loginType: 'firebase',
          uid: fbUser.uid,
        );
        await _goNextAfterLogin();
        return;
      }
    } catch (e) {
      debugPrint('checkAlreadyLogged(firebase) error: $e');
      // se Firebase ainda não estiver pronto, ignora e segue
    }

    final logged = await SessionService.instance.isLoggedIn();
    final loginType = await SessionService.instance.getLoginType();

    if (logged && loginType == 'local') {
      await _goNextAfterLogin();
    }
  }

  void _toggleRememberMe(bool? value) {
    setState(() => _rememberMe = value ?? false);
  }

  Future<void> _loginLocal() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();

      final usuario = await LocalAuthService.instance.loginLocal(email, senha);
      if (usuario == null) {
        _show("Usuário ou senha inválidos.");
        return;
      }

      if (_rememberMe) {
        await SessionService.instance.saveLogin(loginType: 'local');
      } else {
        await SessionService.instance.clearLogin();
      }

      _show("Login efetuado com sucesso.");
      await _goNextAfterLogin();
    } catch (e) {
      debugPrint('loginLocal error: $e');
      _show("Erro ao entrar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _humanFirebaseAuthError(FirebaseAuthException e) {
    // pode ir melhorando conforme aparecerem novos códigos
    switch (e.code) {
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'account-exists-with-different-credential':
        return 'Este e-mail já existe com outro método de login.';
      case 'popup-closed-by-user':
        return 'Login cancelado.';
      default:
        return '${e.code} - ${e.message ?? "Erro de autenticação"}';
    }
  }

  Future<void> _loginGoogle() async {
    if (_isLoading) return;

    // ✅ Feedback claro no Desktop (normal dar problema)
    // Se você quiser permitir no Windows depois, me diga e eu te passo o fluxo certo.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _show(
        "Login com Google no desktop pode não funcionar nesse modelo.\n"
        "Teste no Android (emulador/celular) ou use login local.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // dica: garantir seletor de conta
      await FirebaseAuthService.instance.signOut();

      final user = await FirebaseAuthService.instance.signInWithGoogle();

      if (user == null) {
        _show("Login com Google cancelado.");
        return;
      }

      await SessionService.instance.saveLogin(
        loginType: 'firebase',
        uid: user.uid,
      );

      await BackupService.instance.restaurarTudo(user.uid);

      _show("Login com Google realizado.");
      await _goNextAfterLogin();
    } on FirebaseAuthException catch (e) {
      debugPrint('loginGoogle FirebaseAuthException: ${e.code} ${e.message}');
      _show("Erro Google/Firebase: ${_humanFirebaseAuthError(e)}");
    } on PlatformException catch (e) {
      debugPrint('loginGoogle PlatformException: ${e.code} ${e.message}');
      _show("Erro plataforma: ${e.code} - ${e.message}");
    } catch (e) {
      debugPrint('loginGoogle error: $e');
      _show("Erro ao entrar com Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAlreadyLogged();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F3D2E),
              const Color(0xFF0F3D2E).withOpacity(0.9),
              const Color(0xFFEFF7F3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VoxFinance',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre com sua conta local ou Google',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Entre para acessar o VoxFinance',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 24),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: "E-mail",
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Informe o e-mail";
                                  }
                                  if (!v.contains('@')) {
                                    return "E-mail inválido";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _senhaController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: "Senha",
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return "Informe a senha";
                                  }
                                  if (v.length < 4)
                                    return "Mínimo 4 caracteres";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged:
                                              _isLoading
                                                  ? null
                                                  : _toggleRememberMe,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Flexible(
                                          child: Text(
                                            'Manter conectado',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color
                                                      ?.withOpacity(0.85),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : () {
                                              _show(
                                                'Recuperação de senha será implementada depois.',
                                              );
                                            },
                                    child: Text(
                                      'Esqueceu a senha?',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginLocal,
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text("Entrar"),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const RegisterPage(),
                                              ),
                                            );
                                          },
                                  child: const Text("Criar conta"),
                                ),
                              ),

                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text('ou'),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              GoogleSignInButton(
                                onPressed: _isLoading ? null : _loginGoogle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
