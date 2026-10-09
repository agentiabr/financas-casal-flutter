import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/plan_model.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  PlanType _selectedPlan = PlanType.casal;
  int _extraFamilyMembers = 1; // De 1 a 5 membros no plano família
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R$');

  @override
  Widget build(BuildContext context) {
    final plans = SubscriptionPlanModel.defaultPlans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha seu Plano', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho de Venda
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(child: Text('🤖🐷', style: TextStyle(fontSize: 32))),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Planos Transparentes e Sem Surpresas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                '100% Seguro • Sem conexões bancárias arriscadas • Sincronização em tempo real',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),

              // Lista dos 3 Planos
              ...plans.map((plan) => _buildPlanCard(plan)),

              const SizedBox(height: 20),

              // Botão de Assinar
              ElevatedButton(
                onPressed: () {
                  final plan = plans.firstWhere((p) => p.type == _selectedPlan);
                  final total = plan.calculateTotalPrice(_extraFamilyMembers);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Plano ${plan.title} selecionado: ${_currencyFormat.format(total)}/mês!'),
                      backgroundColor: AppTheme.emeraldGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: Text(
                  'Assinar Plano ${_getPlanName(_selectedPlan)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Cancele a qualquer momento nas configurações da App Store / Google Play.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getPlanName(PlanType type) {
    switch (type) {
      case PlanType.solteiro: return 'Solteiro (R\$ 19,90/mês)';
      case PlanType.casal: return 'Casal (R\$ 29,90/mês)';
      case PlanType.familia:
        final total = 29.90 + (_extraFamilyMembers * 10.00);
        return 'Família (${_currencyFormat.format(total)}/mês)';
    }
  }

  Widget _buildPlanCard(SubscriptionPlanModel plan) {
    final isSelected = _selectedPlan == plan.type;
    double displayPrice = plan.basePrice;
    if (plan.type == PlanType.familia) {
      displayPrice = plan.calculateTotalPrice(_extraFamilyMembers);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan.type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Radio<PlanType>(
                      value: plan.type,
                      groupValue: _selectedPlan,
                      onChanged: (val) => setState(() => _selectedPlan = val!),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (plan.isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('MAIS ESCOLHIDO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(plan.subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${_currencyFormat.format(displayPrice)}/mês',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textMain,
                  ),
                ),
              ],
            ),

            // Se for plano Família, mostrar seletor interativo de membros adicionais (máx 5)
            if (plan.type == PlanType.familia && isSelected) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Membros adicionais (+ R\$ 10/cada):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95)),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.minusCircle, size: 20, color: Color(0xFF6D28D9)),
                              onPressed: _extraFamilyMembers > 1
                                  ? () => setState(() => _extraFamilyMembers--)
                                  : null,
                            ),
                            Text(
                              '$_extraFamilyMembers membro(s)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4C1D95)),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.plusCircle, size: 20, color: Color(0xFF6D28D9)),
                              onPressed: _extraFamilyMembers < 5
                                  ? () => setState(() => _extraFamilyMembers++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'Total de ${2 + _extraFamilyMembers} pessoas com acesso simultâneo na nuvem.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6D28D9)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Lista de Benefícios
            ...plan.features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  const Icon(LucideIcons.check, size: 14, color: AppTheme.emeraldGreen),
                  const SizedBox(width: 8),
                  Text(f, style: const TextStyle(fontSize: 12, color: AppTheme.textMain)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
