import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../config/app_theme.dart';

class FoodBudgetCard extends StatelessWidget {
  const FoodBudgetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R$');
    final percent = (finance.foodBudgetSpent / finance.foodBudgetCap).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.shoppingCart, color: AppTheme.amberWarning, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Orçamento de Mercado / Alimentação', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Meta mensal programada', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: percent > 0.85 ? Colors.red.shade100 : Colors.emeraldGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(percent * 100).round()}% consumido',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: percent > 0.85 ? Colors.red.shade900 : AppTheme.emeraldGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Régua Graduada de 10% a 100%
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Colors.slate.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.85 ? Colors.red : (percent > 0.60 ? AppTheme.amberWarning : AppTheme.emeraldGreen),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Checkpoints Visuais (20%, 40%, 60%, 80%, 100%)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('25%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('50%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('75%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('100%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          // Valores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gasto: ${fmt.format(finance.foodBudgetSpent)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Limite: ${fmt.format(finance.foodBudgetCap)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Text('Resta: ${fmt.format(finance.foodBudgetRemaining)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
            ],
          ),
        ],
      ),
    );
  }
}
