import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/license_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  AccountPlanType _selectedPlan = AccountPlanType.casal;
  bool _obscurePassword = true;
  String? _errorMessage;
  LicenseValidationResult? _codeValidation;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onCodeChanged);
    _codeCtrl.dispose();
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    final code = _codeCtrl.text.trim();
    if (code.isNotEmpty) {
      final res = LicenseService.validateCode(code, _selectedPlan);
      setState(() {
        _codeValidation = res;
        if (res.isValid) {
          _selectedPlan = res.planType;
        }
      });
    } else {
      setState(() {
        _codeValidation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Criar Nova Conta • ControlPig', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mascote e Boas-Vindas
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Center(child: Text('🤖🐷', style: TextStyle(fontSize: 32))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Comece a Cuidar do seu Dinheiro',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecione o formato ideal para as suas finanças:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 18),

                  // 1. SELETOR DE PLANO (Individual, Casal, Família)
                  Row(
                    children: [
                      _buildPlanOption(
                        type: AccountPlanType.individual,
                        icon: LucideIcons.user,
                        title: 'Individual',
                        subtitle: '1 pessoa',
                      ),
                      const SizedBox(width: 8),
                      _buildPlanOption(
                        type: AccountPlanType.casal,
                        icon: LucideIcons.heart,
                        title: 'Casal',
                        subtitle: '2 pessoas',
                        badge: 'Recomendado',
                      ),
                      const SizedBox(width: 8),
                      _buildPlanOption(
                        type: AccountPlanType.familia,
                        icon: LucideIcons.users,
                        title: 'Família',
                        subtitle: 'Até 6 membros',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),

                  // Nome Completo
                  TextField(
                    controller: _nomeCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome Completo',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(LucideIcons.user, color: Colors.white70, size: 18),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // E-mail
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
                  const SizedBox(height: 12),

                  // Senha
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Criar Senha',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(LucideIcons.lock, color: Colors.white70, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white60, size: 18),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Confirmar Senha
                  TextField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(LucideIcons.checkCheck, color: Colors.white70, size: 18),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. CAMPO DE CÓDIGO VITALÍCIO OU CONVITE (Opcional)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _codeValidation?.isValid == true ? const Color(0xFF10B981) : Colors.white12,
                        width: _codeValidation?.isValid == true ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _codeValidation?.isValid == true ? LucideIcons.badgeCheck : LucideIcons.keyRound,
                              color: _codeValidation?.isValid == true ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Código de Acesso Vitalício ou Convite (Opcional)',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          decoration: InputDecoration(
                            hintText: 'Ex: CASAL-VIP ou código de convite',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.25),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            suffixIcon: _codeValidation?.isValid == true
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                                : null,
                          ),
                        ),
                        if (_codeValidation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _codeValidation!.message,
                            style: TextStyle(
                              color: _codeValidation!.isValid ? const Color(0xFF10B981) : const Color(0xFFF87171),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Sem código? Você começará com 30 dias de teste grátis.',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botão Criar Conta
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _codeValidation?.isLifetime == true ? const Color(0xFF10B981) : AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_codeValidation?.isLifetime == true)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(LucideIcons.sparkles, size: 16),
                                ),
                              Text(
                                _codeValidation?.isLifetime == true ? 'Ativar Conta VIP Vitalícia' : 'Criar Conta e Acessar',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanOption({
    required AccountPlanType type,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
  }) {
    final isSelected = _selectedPlan == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPlan = type;
            if (_codeCtrl.text.isNotEmpty) {
              _onCodeChanged();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.18) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : Colors.white12,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ),
              Icon(icon, color: isSelected ? const Color(0xFF10B981) : Colors.white70, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white38,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final nome = _nomeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmPassCtrl.text;
    final code = _codeCtrl.text.trim();

    if (nome.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Preencha todos os campos.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'As senhas não coincidem.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'A senha deve conter no mínimo 6 caracteres.');
      return;
    }

    final isLifetime = _codeValidation?.isLifetime ?? false;
    final planType = _selectedPlan;

    // Salva a licença no SharedPreferences
    await LicenseService.saveLicense(
      plan: planType,
      isLifetime: isLifetime,
      code: code.isNotEmpty ? code : null,
    );

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signUp(
      email: email,
      password: pass,
      nome: nome,
      accountType: planType.name,
      activationCode: code.isNotEmpty ? code : null,
      isLifetime: isLifetime,
    );

    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLifetime
                  ? '🎉 Conta Criada com Sucesso! Acesso Vitalício VIP Ativado.'
                  : '🎉 Bem-vindo ao ControlPig! Seus 30 dias de teste foram iniciados.',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }
}
