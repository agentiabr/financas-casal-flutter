import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'biometric_lock_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mascote 3D
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🤖🐷', style: TextStyle(fontSize: 38)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Finanças Casal',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rodrigo & Márcia • Acesso por E-mail e Senha',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 28),

                  // Chips Rápidos de Seleção de Usuário (Rodrigo / Márcia)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const CircleAvatar(backgroundColor: Colors.blue, child: Text('R', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        label: const Text('Rodrigo', style: TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: Colors.white.withOpacity(0.12),
                        onPressed: () => setState(() => _emailCtrl.text = 'rodrigo@financas.casal'),
                      ),
                      const SizedBox(width: 10),
                      ActionChip(
                        avatar: const CircleAvatar(backgroundColor: Colors.pink, child: Text('M', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        label: const Text('Márcia', style: TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: Colors.white.withOpacity(0.12),
                        onPressed: () => setState(() => _emailCtrl.text = 'marcia@financas.casal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Mensagem de Erro
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Campo E-mail
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(LucideIcons.mail, color: Colors.white70, size: 18),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo Senha
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(LucideIcons.lock, color: Colors.white70, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.white70, size: 18),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Esqueci Minha Senha
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text('Esqueceu a senha?', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Botão Entrar
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Entrar no Aplicativo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),

                  // Atalho para Biometria / Face ID
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BiometricLockScreen()));
                    },
                    icon: const Icon(LucideIcons.scanFace, size: 18, color: Colors.white),
                    label: const Text('Acessar com Face ID / Biometria', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Link Criar Conta
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Primeiro acesso?', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        },
                        child: const Text('Cadastre-se', style: TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Preencha o e-mail e a senha.');
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signIn(email: email, password: pass);

    if (mounted) {
      if (error == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }

  void _handleForgotPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu e-mail no campo acima para recuperar a senha.')),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    auth.resetPassword(email);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se o e-mail $email existir, o link de recuperação foi enviado!')),
    );
  }
}
