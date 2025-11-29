// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vox_finance/ui/core/service/local_auth_service.dart';
import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/core/service/backup_service.dart';

import 'package:vox_finance/ui/pages/auth/register_page.dart';
import 'package:vox_finance/ui/pages/home/home_page.dart';
import 'package:vox_finance/ui/widgets/google_sign_in_button.dart';

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

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  Future<void> _saveLoginState(String type) async {
    final prefs = await _prefs();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loginType', type); // 'local' ou 'firebase'
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await _prefs();
    final savedEmail = prefs.getString('email') ?? '';
    final savedPassword = prefs.getString('password') ?? '';
    final savedRemember = prefs.getBool('rememberMe') ?? false;

    if (!mounted) return;
    setState(() {
      _emailController.text = savedEmail;
      _senhaController.text = savedPassword;
      _rememberMe = savedRemember;
    });
  }

  Future<void> _saveOrClearCredentials() async {
    final prefs = await _prefs();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('password', _senhaController.text.trim());
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }
  }

  Future<void> _checkAlreadyLogged() async {
    final prefs = await _prefs();
    final logged = prefs.getBool('isLoggedIn') ?? false;

    if (logged) {
      // já logado → vai direto pra Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      await _loadSavedCredentials();
    }
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

      await _saveOrClearCredentials();
      await _saveLoginState("local");

      _show("Login efetuado com sucesso.");

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
      final user = await FirebaseAuthService.instance.signInWithGoogle();

      if (user == null) {
        _show("Login com Google cancelado.");
        return;
      }

      // opcional: limpar credenciais locais
      await _saveOrClearCredentials();
      await _saveLoginState("firebase");

      await BackupService.instance.restaurarTudo(user.uid);

      _show("Login com Google realizado.");

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
                          'Entre com sua conta local ou Google',
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
                                  'Entre para acessar o VoxFinance',
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
                                    labelText: "E-mail",
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                      size: 22,
                                    ),
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

                                // Senha
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: "Senha",
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

                                // Manter conectado + Esqueceu a senha?
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: _toggleRememberMe,
                                            visualDensity:
                                                VisualDensity.compact,
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
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
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

                                // Botão Entrar (local)
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _loginLocal,
                                    style: ElevatedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      backgroundColor: const Color(0xFF0F7F5A),
                                      elevation: 4,
                                      shadowColor: Colors.black26,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Entrar",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Botão Criar conta (local)
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterPage(),
                                              ),
                                            );
                                          },
                                    style: OutlinedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text("Criar conta"),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Separador "ou"
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('ou'),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Botão Google oficial
                                GoogleSignInButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _loginGoogle,
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
