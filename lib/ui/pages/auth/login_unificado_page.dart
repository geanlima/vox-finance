// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/service/local_auth_service.dart';
import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/core/service/backup_service.dart';
import 'package:vox_finance/ui/core/service/session_service.dart';

import 'package:vox_finance/ui/pages/auth/register_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/widgets/google_signin_button.dart';

class LoginUnificadoPage extends StatefulWidget {
  const LoginUnificadoPage({super.key});

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

  // ============================================================
  // AUXILIARES
  // ============================================================

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _checkAlreadyLogged() async {
    // ✅ Fonte de verdade do Firebase
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      // garante sessão coerente
      await SessionService.instance.saveLogin(
        loginType: 'firebase',
        uid: fbUser.uid,
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      return;
    }

    // ✅ Fallback: login local persistido (se você marcou "Manter conectado")
    final logged = await SessionService.instance.isLoggedIn();
    final loginType = await SessionService.instance.getLoginType();

    if (logged && loginType == 'local') {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      return;
    }

    // não está logado -> fica na tela
  }

  void _toggleRememberMe(bool? value) {
    setState(() {
      _rememberMe = value ?? false;
    });
  }

  // ============================================================
  // LOGIN LOCAL
  // ============================================================

  Future<void> _loginLocal() async {
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

      // ✅ se marcou "Manter conectado", salva sessão. Se não marcou, limpa.
      if (_rememberMe) {
        await SessionService.instance.saveLogin(loginType: 'local');
      } else {
        await SessionService.instance.clearLogin();
      }

      _show("Login efetuado com sucesso.");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (_) {
      _show("Erro ao entrar.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // LOGIN GOOGLE
  // ============================================================

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);

    try {
      // ✅ dica: para sempre permitir escolher conta, faça signOut antes
      await FirebaseAuthService.instance.signOut();

      final user = await FirebaseAuthService.instance.signInWithGoogle();

      if (user == null) {
        _show("Login com Google cancelado.");
        return;
      }

      // ✅ salva sessão do firebase com UID (essencial pro backup por usuário)
      await SessionService.instance.saveLogin(
        loginType: 'firebase',
        uid: user.uid,
      );

      // ☁️ restaura o banco do usuário
      await BackupService.instance.restaurarTudo(user.uid);

      _show("Login com Google realizado.");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (_) {
      _show("Erro ao entrar com Google.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // CICLO DE VIDA
  // ============================================================

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

  // ============================================================
  // UI
  // ============================================================

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
                    Column(
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
                      ],
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
                            mainAxisSize: MainAxisSize.min,
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
                                  if (v.length < 4) {
                                    return "Mínimo 4 caracteres";
                                  }
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
                                          onChanged: _toggleRememberMe,
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
                                    onPressed: () {
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
