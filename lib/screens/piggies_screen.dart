import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../config/app_theme.dart';
import '../models/piggy_model.dart';
import '../widgets/currency_mask_controller.dart';

class PiggiesScreen extends StatelessWidget {
  const PiggiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cofrinhos & Metas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: finance.piggies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) {
          final p = finance.piggies[idx];
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
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(LucideIcons.piggyBank, color: AppTheme.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Meta: ${fmt.format(p.meta)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      fmt.format(p.saldoAtual),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progresso
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p.percentual,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(height: 12),

                // Botões de Depositar e Resgatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showAmountDialog(context, p, isDeposit: false),
                      child: const Text('Resgatar', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showAmountDialog(context, p, isDeposit: true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                      child: const Text('Depositar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAmountDialog(BuildContext context, PiggyModel piggy, {required bool isDeposit}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Depositar no Cofrinho' : 'Resgatar do Cofrinho'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          decoration: const InputDecoration(labelText: r'Valor (R$)', hintText: '0,00'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = CurrencyInputFormatter.parse(ctrl.text);
              if (val > 0) {
                final prov = Provider.of<FinanceProvider>(context, listen: false);
                if (isDeposit) {
                  prov.depositPiggy(piggy.id, val);
                } else {
                  prov.withdrawPiggy(piggy.id, val);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
