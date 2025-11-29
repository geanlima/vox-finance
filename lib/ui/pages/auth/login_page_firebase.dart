// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/core/service/backup_service.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/widgets/google_signin_button.dart';

class LoginPageFirebase extends StatefulWidget {
  const LoginPageFirebase({super.key});

  @override
  State<LoginPageFirebase> createState() => _LoginPageFirebaseState();
}

class _LoginPageFirebaseState extends State<LoginPageFirebase> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ============================================================
  //  A U X I L I A R E S
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _setLoggedIn(bool value, {String? loginType}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
    if (loginType != null) {
      await prefs.setString('loginType', loginType); // 'firebase' ou 'local'
    }
  }

  // ============================================================
  //  L O G I N   C O M   G O O G L E
  // ============================================================
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final user = await FirebaseAuthService.instance.signInWithGoogle();

      if (user == null) {
        _showMessage('Login com Google cancelado.');
        return;
      }

      await _setLoggedIn(true);

      // Restaura backup da nuvem para o SQLite
      await BackupService.instance.restaurarTudo(user.uid);

      _showMessage('Login com Google realizado. Dados sincronizados.');

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      _showMessage('Erro ao entrar com Google.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  //  L O G I N   F I R E B A S E  +  B A C K U P
  // ============================================================

  Future<void> _loginFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();

      // 🔐 Login no Firebase
      final user = await FirebaseAuthService.instance.loginWithEmailPassword(
        email,
        senha,
      );

      if (user == null) {
        _showMessage('Erro ao autenticar no Firebase.');
        return;
      }

      await _setLoggedIn(true);

      // ☁️ Restaurar backup da nuvem para o SQLite
      await BackupService.instance.restaurarTudo(user.uid);

      _showMessage('Login online efetuado. Dados sincronizados com a nuvem.');

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro ao fazer login online (Firebase).';

      if (e.code == 'user-not-found') {
        msg = 'Usuário não encontrado no Firebase.';
      } else if (e.code == 'wrong-password') {
        msg = 'Senha inválida.';
      } else if (e.code == 'invalid-credential') {
        msg = 'Credenciais inválidas.';
      }

      _showMessage(msg);
    } catch (_) {
      _showMessage('Erro inesperado ao fazer login online (Firebase).');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // ============================================================
  //  U I
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
                    // TOPO
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
                          'Sincronize seus dados com a nuvem',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // CARD
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 40, end: 0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Opacity(
                            opacity: (40 - value) / 40,
                            child: child,
                          ),
                        );
                      },
                      child: Card(
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
                                  'Entre para sincronizar com a nuvem',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // E-mail
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'E-mail',
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                      size: 22,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Informe o e-mail';
                                    }
                                    if (!value.contains('@')) {
                                      return 'E-mail inválido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Senha
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 22,
                                    ),
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
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Informe a senha';
                                    }
                                    if (value.trim().length < 6) {
                                      return 'Mínimo 6 caracteres';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Botão "Entrar e sincronizar" (e-mail/senha Firebase)
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _loginFirebase,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.cloud_sync_outlined),
                                    label: const Text(
                                      'Entrar e sincronizar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Separador "OU"
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text('ou'),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Botão oficial "Entrar com Google"
                                GoogleSignInButton(
                                  onPressed:
                                      _isLoading ? null : _loginWithGoogle,
                                ),
                              ],
                            ),
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
