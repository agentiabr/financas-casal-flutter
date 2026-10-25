import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de dados consolidado do perfil financeiro
class OnboardingProfileResult {
  final String? objetivoFinanceiro;
  final String? situacaoAtual;
  final String? fonteRenda;
  final String? reservaEmergencia;
  final String? nivelIntimidade;
  final List<String> modulosAtivos;
  final bool pulou;

  const OnboardingProfileResult({
    this.objetivoFinanceiro,
    this.situacaoAtual,
    this.fonteRenda,
    this.reservaEmergencia,
    this.nivelIntimidade,
    this.modulosAtivos = const [],
    this.pulou = false,
  });

  Map<String, dynamic> toJson() => {
        'objetivo_financeiro': objetivoFinanceiro,
        'situacao_atual': situacaoAtual,
        'fonte_renda': fonteRenda,
        'reserva_emergencia': reservaEmergencia,
        'nivel_intimidade': nivelIntimidade,
        'modulos_ativos': modulosAtivos,
        'pulou': pulou,
        'data_preenchimento': DateTime.now().toIso8601String(),
      };
}

/// Tela de Onboarding Interativo com PageView Horizontal de 6 Passos
class OnboardingSurveyScreen extends StatefulWidget {
  final bool canSkip;
  final VoidCallback? onCompleted;

  const OnboardingSurveyScreen({
    super.key,
    this.canSkip = true,
    this.onCompleted,
  });

  @override
  State<OnboardingSurveyScreen> createState() => _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState extends State<OnboardingSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSteps = 6;

  // Estado das respostas
  String? _objetivoFinanceiro;
  String? _situacaoAtual;
  String? _fonteRenda;
  String? _reservaEmergencia;
  String? _nivelIntimidade;
  final Set<String> _modulosAtivos = <String>{};

  // Cores da Paleta Corporativa Clean
  static const Color _brandNavy = Color(0xFF0A192F);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _brandAccentBlue = Color(0xFF2563EB);
  static const Color _brandLightBg = Color(0xFFF8FAFC);
  static const Color _textSlate900 = Color(0xFF0F172A);
  static const Color _textSlate600 = Color(0xFF475569);
  static const Color _borderSlate200 = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onStepSelected(String key, String value) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (_currentPage) {
        case 0:
          _objetivoFinanceiro = value;
          break;
        case 1:
          _situacaoAtual = value;
          break;
        case 2:
          _fonteRenda = value;
          break;
        case 3:
          _reservaEmergencia = value;
          break;
        case 4:
          _nivelIntimidade = value;
          break;
      }
    });

    // Avanço automático e suave para a próxima etapa
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _currentPage < _totalSteps - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _toggleModule(String moduleKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (moduleKey == 'nenhuma') {
        _modulosAtivos.clear();
        _modulosAtivos.add('nenhuma');
      } else {
        _modulosAtivos.remove('nenhuma');
        if (_modulosAtivos.contains(moduleKey)) {
          _modulosAtivos.remove(moduleKey);
        } else {
          _modulosAtivos.add(moduleKey);
        }
      }
    });
  }

  Future<void> _finishOnboarding({bool pulou = false}) async {
    HapticFeedback.mediumImpact();
    final result = OnboardingProfileResult(
      objetivoFinanceiro: _objetivoFinanceiro,
      situacaoAtual: _situacaoAtual,
      fonteRenda: _fonteRenda,
      reservaEmergencia: _reservaEmergencia,
      nivelIntimidade: _nivelIntimidade,
      modulosAtivos: _modulosAtivos.where((m) => m != 'nenhuma').toList(),
      pulou: pulou,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ctrlpig_onboarding_survey_done', true);
      await prefs.setString('ctrlpig_user_financial_profile', jsonEncode(result.toJson()));
      await prefs.setStringList('ctrlpig_active_modules', result.modulosAtivos);
    } catch (_) {}

    if (mounted) {
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: _brandLightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior de Progresso e Botão Pular
            _buildTopNavBar(progress),

            // Conteúdo dos 6 Passos com PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de Navegação Superior: Indicador e Ação "Pular"
  Widget _buildTopNavBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão Voltar (aparece a partir do Passo 2)
              if (_currentPage > 0)
                IconButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textSlate900),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                )
              else
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _brandBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CtrlPig',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),

              // Indicador de Etapa
              Text(
                'Passo ${_currentPage + 1} de $_totalSteps',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textSlate600,
                ),
              ),

              // Botão Pular Discreto
              if (widget.canSkip)
                TextButton(
                  onPressed: () => _finishOnboarding(pulou: true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Pular',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textSlate600,
                    ),
                  ),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 12),

          // Barra Linear de Progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: _borderSlate200,
                valueColor: const AlwaysStoppedAnimation<Color>(_brandAccentBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Passo 1: Objetivo Financeiro
  Widget _buildStep1() {
    return _SurveyStepLayout(
      title: 'Qual é o seu principal objetivo financeiro hoje?',
      subtitle: 'Isso ajudará a calibrar as recomendações e metas do seu painel.',
      options: [
        _SurveyOption(
          label: 'Sair das dívidas e organizar contas em atraso.',
          icon: '🛑',
          isSelected: _objetivoFinanceiro == 'Sair das dívidas e organizar contas em atraso.',
          onTap: () => _onStepSelected('objetivo', 'Sair das dívidas e organizar contas em atraso.'),
        ),
        _SurveyOption(
          label: 'Controlar os gastos do dia a dia.',
          icon: '📊',
          isSelected: _objetivoFinanceiro == 'Controlar os gastos do dia a dia.',
          onTap: () => _onStepSelected('objetivo', 'Controlar os gastos do dia a dia.'),
        ),
        _SurveyOption(
          label: 'Juntar dinheiro para um objetivo específico.',
          icon: '🎯',
          isSelected: _objetivoFinanceiro == 'Juntar dinheiro para um objetivo específico.',
          onTap: () => _onStepSelected('objetivo', 'Juntar dinheiro para um objetivo específico.'),
        ),
        _SurveyOption(
          label: 'Acompanhar e otimizar meus investimentos.',
          icon: '📈',
          isSelected: _objetivoFinanceiro == 'Acompanhar e otimizar meus investimentos.',
          onTap: () => _onStepSelected('objetivo', 'Acompanhar e otimizar meus investimentos.'),
        ),
      ],
    );
  }

  /// Passo 2: Situação Financeira Atual
  Widget _buildStep2() {
    return _SurveyStepLayout(
      title: 'Como você descreveria a sua situação financeira atual?',
      subtitle: 'Seja sincero(a), todas as análises são 100% privadas no seu aparelho.',
      options: [
        _SurveyOption(
          label: 'Gasto mais do que ganho.',
          icon: '⚠️',
          isSelected: _situacaoAtual == 'Gasto mais do que ganho.',
          onTap: () => _onStepSelected('situacao', 'Gasto mais do que ganho.'),
        ),
        _SurveyOption(
          label: 'Empato as contas, não sobra nada no fim do mês.',
          icon: '⚖️',
          isSelected: _situacaoAtual == 'Empato as contas, não sobra nada no fim do mês.',
          onTap: () => _onStepSelected('situacao', 'Empato as contas, não sobra nada no fim do mês.'),
        ),
        _SurveyOption(
          label: 'Consigo poupar um pouco de dinheiro com frequência.',
          icon: '🌱',
          isSelected: _situacaoAtual == 'Consigo poupar um pouco de dinheiro com frequência.',
          onTap: () => _onStepSelected('situacao', 'Consigo poupar um pouco de dinheiro com frequência.'),
        ),
        _SurveyOption(
          label: 'Tenho um controle folgado e invisto regularmente.',
          icon: '🚀',
          isSelected: _situacaoAtual == 'Tenho um controle folgado e invisto regularmente.',
          onTap: () => _onStepSelected('situacao', 'Tenho um controle folgado e invisto regularmente.'),
        ),
      ],
    );
  }

  /// Passo 3: Fonte de Renda
  Widget _buildStep3() {
    return _SurveyStepLayout(
      title: 'Como funciona a sua principal fonte de renda?',
      subtitle: 'Definirá se o app prioriza orçamentos por ciclo fixo ou projeções médias.',
      options: [
        _SurveyOption(
          label: 'Fixa (Salário, funcionário público, aposentadoria).',
          icon: '🏢',
          isSelected: _fonteRenda == 'Fixa (Salário, funcionário público, aposentadoria).',
          onTap: () => _onStepSelected('fonte_renda', 'Fixa (Salário, funcionário público, aposentadoria).'),
        ),
        _SurveyOption(
          label: 'Variável (Autônomo, MEI, PJ, comissões).',
          icon: '💼',
          isSelected: _fonteRenda == 'Variável (Autônomo, MEI, PJ, comissões).',
          onTap: () => _onStepSelected('fonte_renda', 'Variável (Autônomo, MEI, PJ, comissões).'),
        ),
        _SurveyOption(
          label: 'Mista (Renda fixa + trabalhos extras/freelas).',
          icon: '🔄',
          isSelected: _fonteRenda == 'Mista (Renda fixa + trabalhos extras/freelas).',
          onTap: () => _onStepSelected('fonte_renda', 'Mista (Renda fixa + trabalhos extras/freelas).'),
        ),
      ],
    );
  }

  /// Passo 4: Reserva de Emergência
  Widget _buildStep4() {
    return _SurveyStepLayout(
      title: 'Você já possui uma reserva de emergência?',
      subtitle: 'A base da sua segurança financeira em momentos imprevistos.',
      options: [
        _SurveyOption(
          label: 'Ainda não comecei a montar.',
          icon: '⏳',
          isSelected: _reservaEmergencia == 'Ainda não comecei a montar.',
          onTap: () => _onStepSelected('reserva', 'Ainda não comecei a montar.'),
        ),
        _SurveyOption(
          label: 'Sim, cobriria menos de 3 meses dos meus custos.',
          icon: '🛡️',
          isSelected: _reservaEmergencia == 'Sim, cobriria menos de 3 meses dos meus custos.',
          onTap: () => _onStepSelected('reserva', 'Sim, cobriria menos de 3 meses dos meus custos.'),
        ),
        _SurveyOption(
          label: 'Sim, cobriria entre 3 e 6 meses.',
          icon: '🏰',
          isSelected: _reservaEmergencia == 'Sim, cobriria entre 3 e 6 meses.',
          onTap: () => _onStepSelected('reserva', 'Sim, cobriria entre 3 e 6 meses.'),
        ),
        _SurveyOption(
          label: 'Sim, estou protegido (mais de 6 meses).',
          icon: '⭐',
          isSelected: _reservaEmergencia == 'Sim, estou protegido (mais de 6 meses).',
          onTap: () => _onStepSelected('reserva', 'Sim, estou protegido (mais de 6 meses).'),
        ),
      ],
    );
  }

  /// Passo 5: Nível de Intimidade
  Widget _buildStep5() {
    return _SurveyStepLayout(
      title: 'Qual o seu nível de intimidade com finanças e investimentos?',
      subtitle: 'Adaptaremos o vocabulário e a complexidade das análises para você.',
      options: [
        _SurveyOption(
          label: 'Iniciante (preciso de ajuda com o básico).',
          icon: '🐣',
          isSelected: _nivelIntimidade == 'Iniciante (preciso de ajuda com o básico).',
          onTap: () => _onStepSelected('intimidade', 'Iniciante (preciso de ajuda com o básico).'),
        ),
        _SurveyOption(
          label: 'Intermediário (conheço os termos, quero melhorar a prática).',
          icon: '🧭',
          isSelected: _nivelIntimidade == 'Intermediário (conheço os termos, quero melhorar a prática).',
          onTap: () => _onStepSelected('intimidade', 'Intermediário (conheço os termos, quero melhorar a prática).'),
        ),
        _SurveyOption(
          label: 'Avançado (busco apenas automação e análise).',
          icon: '💎',
          isSelected: _nivelIntimidade == 'Avançado (busco apenas automação e análise).',
          onTap: () => _onStepSelected('intimidade', 'Avançado (busco apenas automação e análise).'),
        ),
      ],
    );
  }

  /// Passo 6 (Múltipla Escolha): Personalização dos Módulos do Dashboard
  Widget _buildStep6() {
    final hasSelection = _modulosAtivos.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para personalizar seu painel, quais destas categorias fazem parte das suas despesas?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _textSlate900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione quantas quiser. Você poderá adicionar outras depois pelas configurações.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textSlate600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Grid de Opções de Módulos (2 colunas)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _ModuleGridCard(
                        keyId: 'pet',
                        icon: '🐶',
                        title: 'Pet',
                        subtitle: 'Rações, vacinas e veterinário',
                        isSelected: _modulosAtivos.contains('pet'),
                        onTap: () => _toggleModule('pet'),
                      ),
                      _ModuleGridCard(
                        keyId: 'veiculo',
                        icon: '🚗',
                        title: 'Veículo',
                        subtitle: 'Gasolina, IPVA e oficina',
                        isSelected: _modulosAtivos.contains('veiculo'),
                        onTap: () => _toggleModule('veiculo'),
                      ),
                      _ModuleGridCard(
                        keyId: 'saude',
                        icon: '🏥',
                        title: 'Saúde / Plano',
                        subtitle: 'Consultas e farmácia',
                        isSelected: _modulosAtivos.contains('saude'),
                        onTap: () => _toggleModule('saude'),
                      ),
                      _ModuleGridCard(
                        keyId: 'educacao',
                        icon: '📚',
                        title: 'Educação',
                        subtitle: 'Cursos e mensalidades',
                        isSelected: _modulosAtivos.contains('educacao'),
                        onTap: () => _toggleModule('educacao'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Opção de "Nenhuma dessas categorias"
                  GestureDetector(
                    onTap: () => _toggleModule('nenhuma'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _modulosAtivos.contains('nenhuma')
                            ? _brandAccentBlue.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _modulosAtivos.contains('nenhuma')
                              ? _brandAccentBlue
                              : _borderSlate200,
                          width: _modulosAtivos.contains('nenhuma') ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _modulosAtivos.contains('nenhuma')
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: _modulosAtivos.contains('nenhuma')
                                ? _brandAccentBlue
                                : _textSlate600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nenhuma dessas categorias',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _modulosAtivos.contains('nenhuma')
                                    ? _brandNavy
                                    : _textSlate900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Botão Finalizar Onboarding
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: hasSelection ? () => _finishOnboarding(pulou: false) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  disabledBackgroundColor: _borderSlate200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Finalizar Onboarding',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasSelection ? Colors.white : _textSlate600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: hasSelection ? Colors.white : _textSlate600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout padronizado para cada etapa do onboarding
class _SurveyStepLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> options;

  const _SurveyStepLayout({
    required this.title,
    required this.subtitle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: options,
            ),
          ),
        ],
      ),
    );
  }
}

/// Componente visual do card de resposta individual (Passos 1 a 5)
class _SurveyOption extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SurveyOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1E40AF);
    const borderSlate200 = Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? brandBlue.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? brandBlue : borderSlate200,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? 0.04 : 0.015),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? brandBlue.withOpacity(0.12) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0A192F) : const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: isSelected ? brandBlue : const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Componente visual de Card em Grid para seleção de módulos (Passo 6)
class _ModuleGridCard extends StatelessWidget {
  final String keyId;
  final String icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModuleGridCard({
    required this.keyId,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1E40AF);
    const borderSlate200 = Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? brandBlue.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? brandBlue : borderSlate200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.04 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? brandBlue : const Color(0xFFCBD5E1),
                  size: 22,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF0A192F) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
