import 'plans_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/finance_provider.dart';
import '../services/speech_service.dart';
import '../widgets/currency_mask_controller.dart';
import '../widgets/food_budget_card.dart';
import 'transactions_screen.dart';
import 'piggies_screen.dart';
import '../models/transaction_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  final List<Map<String, dynamic>> _accordionItems = [
    {
      'id': 'resumo_contas',
      'title': 'Resumo das Contas do Mês',
      'icon': Icons.bar_chart_outlined,
      'expanded': true,
    },
    {
      'id': 'analise_visual',
      'title': 'Análise Visual & Categorias',
      'icon': Icons.pie_chart_outline_rounded,
      'expanded': true,
    },
    {
      'id': 'cofrinho_casal',
      'title': 'Cofrinho do Casal',
      'icon': Icons.savings_outlined,
      'expanded': false,
    },
    {
      'id': 'orcamento_previsto',
      'title': 'Orçamento Previsto',
      'icon': Icons.shopping_basket_outlined,
      'expanded': false,
    },
    {
      'id': 'carteira_cartoes',
      'title': 'Carteira de Cartões',
      'icon': Icons.credit_card_outlined,
      'expanded': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final isNegative = finance.saldoDisponivel < 0;

    // Se estiver em outra aba
    if (_currentBottomNavIndex == 3) {
      return const TransactionsScreen();
    } else if (_currentBottomNavIndex == 4) {
      return const PiggiesScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(finance),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Status Bar do Ciclo e Alerta de Renda Gasta
              _buildStatusHeader(finance, isNegative),
              const SizedBox(height: 12),

              // 2. Card-Herói Flat com Mascote e Saldo
              _buildHeroCard(finance, isNegative),
              const SizedBox(height: 12),

              // 3. Accordion Estável Reordenável no Meio da Tela
              _buildMiddleReorderableAccordion(finance),
              const SizedBox(height: 12),

              // 4. Card Flat de Compras Parceladas
              _buildInstallmentsHighlightCard(finance),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomDock(),
    );
  }

  PreferredSizeWidget _buildAppBar(FinanceProvider finance) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.wallet, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CtrlPig', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Controle Financeiro Inteligente', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.crown, size: 18, color: Colors.amber),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
          tooltip: 'Ver Planos & Assinatura',
        ),
        IconButton(
          icon: Icon(finance.isPrivacyMode ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
          onPressed: () => finance.togglePrivacy(),
          tooltip: 'Modo Privacidade',
        ),
        CircleAvatar(radius: 12, backgroundColor: Colors.blue.shade700, child: const Text('R', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        const SizedBox(width: 4),
        CircleAvatar(radius: 12, backgroundColor: Colors.pink.shade600, child: const Text('M', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(LucideIcons.creditCard, size: 18),
          onPressed: _openCardsModal,
          tooltip: 'Ver Cartões de Crédito',
        ),
        IconButton(
          icon: const Icon(LucideIcons.logOut, size: 18),
          onPressed: () async {
            final auth = Provider.of<AuthService>(context, listen: false);
            await auth.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            }
          },
          tooltip: 'Desconectar / Sair',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStatusHeader(FinanceProvider finance, bool isNegative) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 14, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(finance.activeCycle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isNegative ? Colors.red.shade100 : Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isNegative ? '🚨 Saldo Negativo' : '⚠️ Renda gasta: ${finance.percentComprometido}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isNegative ? Colors.red.shade800 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(FinanceProvider finance, bool isNegative) {
    final displayBalance = finance.isPrivacyMode
        ? r'R$ •••••'
        : _currencyFormat.format(finance.saldoDisponivel);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNegative
              ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
              : [const Color(0xFF1D4ED8), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isNegative ? Colors.red : Colors.blue).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ciclo Vigente • Mês Ativo', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('Olá, Rodrigo & Márcia 👋', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🤖🐷', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Saldo Livre Disponível:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            displayBalance,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          // 3 Botões de Ação Rápida
          Row(
            children: [
              Expanded(
                child: _buildHeroActionButton(
                  icon: LucideIcons.mic,
                  label: 'Por Voz',
                  onTap: _openVoiceModal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeroActionButton(
                  icon: LucideIcons.camera,
                  label: 'Foto Nota',
                  onTap: _openCameraReceiptModal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openNewTransactionModal,
                  icon: const Icon(LucideIcons.plus, size: 14, color: AppTheme.primaryBlue),
                  label: const Text('Digitar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentsHighlightCard(FinanceProvider finance) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.purpleInstallments,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.layers, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${finance.installments.length} Compras Parceladas Ativas', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95))),
                Text('Comprometido: ${_currencyFormat.format(finance.totalInstallmentsFutureCompromised)} / mês', style: const TextStyle(fontSize: 11, color: Color(0xFF6D28D9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary(FinanceProvider finance) {
    return Row(
      children: [
        _buildMetricTile('Receitas', _currencyFormat.format(finance.totalReceitas), AppTheme.emeraldGreen),
        const SizedBox(width: 8),
        _buildMetricTile('Fixas', _currencyFormat.format(finance.totalDespesasFixas), AppTheme.primaryBlue),
        const SizedBox(width: 8),
        _buildMetricTile('Variáveis', _currencyFormat.format(finance.totalDespesasVariaveis), AppTheme.amberWarning),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return NavigationBar(
      selectedIndex: _currentBottomNavIndex,
      onDestinationSelected: (idx) {
        if (idx == 2) {
          _openNewTransactionModal();
        } else {
          setState(() => _currentBottomNavIndex = idx);
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(LucideIcons.home), label: 'Início'),
        NavigationDestination(icon: Icon(LucideIcons.barChart2), label: 'Métricas'),
        NavigationDestination(icon: Icon(LucideIcons.plusCircle), label: 'Lançar'),
        NavigationDestination(icon: Icon(LucideIcons.receipt), label: 'Tabela'),
        NavigationDestination(icon: Icon(LucideIcons.piggyBank), label: 'Cofrinhos'),
      ],
    );
  }

  void _openVoiceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _buildVoiceModalSheet(),
    );
  }

  Widget _buildVoiceModalSheet() {
    final speech = Provider.of<SpeechService>(context);
    final finance = Provider.of<FinanceProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎙️ Lançamento por Voz Nativo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Fale o que comprou (Ex.: "Almoço 45 reais no débito" ou "Ração do pet 80")', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              if (speech.isListening) {
                await speech.stopListening();
              } else {
                await speech.startListening(onResult: (text) {});
              }
            },
            child: CircleAvatar(
              radius: 36,
              backgroundColor: speech.isListening ? Colors.red : AppTheme.primaryBlue,
              child: Icon(speech.isListening ? LucideIcons.square : LucideIcons.mic, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            speech.lastWords.isNotEmpty ? speech.lastWords : 'Toque no microfone para falar...',
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          if (speech.lastWords.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                final parsed = speech.parseCommand(speech.lastWords);
                if (parsed.valor != null && parsed.valor! > 0) {
                  finance.addTransaction(TransactionModel(
                    id: DateTime.now().millisecondsSinceEpoch,
                    data: DateTime.now(),
                    ciclo: finance.activeCycle,
                    tipo: parsed.tipo ?? 'Despesa Variável',
                    categoria: parsed.categoria ?? 'Outros',
                    descricao: parsed.descricao ?? speech.lastWords,
                    valor: parsed.valor!,
                    responsavel: 'Comum (Casal)',
                    formaPagamento: parsed.formaPagamento ?? 'PIX',
                  ));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lançamento adicionado: R\$ ${parsed.valor} (${parsed.categoria})')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
              child: const Text('Confirmar Reconhecimento'),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _openCameraReceiptModal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📸 Câmera Nativa com Google ML Kit pronta para escanear cupom fiscal!')),
    );
  }

  void _openNewTransactionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _buildNewTxSheet(),
    );
  }

  Widget _buildNewTxSheet() {
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String categoria = '🐾 Pet';
    String responsavel = 'Comum (Casal)';
    String formaPagamento = 'PIX';
    final finance = Provider.of<FinanceProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('➕ Novo Lançamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Descrição / Estabelecimento', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: valorCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: r'Valor (R$)',
              hintText: '0,00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: categoria,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '🐾 Pet', child: Text('🐾 Pet / Veterinário')),
              DropdownMenuItem(value: 'Alimentação', child: Text('🛒 Alimentação / Mercado')),
              DropdownMenuItem(value: 'Transporte', child: Text('🚗 Transporte / Combustível')),
              DropdownMenuItem(value: 'Saúde', child: Text('💊 Saúde / Farmácia')),
              DropdownMenuItem(value: 'Moradia', child: Text('🏠 Moradia / Contas')),
              DropdownMenuItem(value: 'Lazer', child: Text('🎉 Lazer / Restaurante')),
              DropdownMenuItem(value: 'Outros', child: Text('📦 Outros')),
            ],
            onChanged: (v) => categoria = v!,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final val = CurrencyInputFormatter.parse(valorCtrl.text);
              if (val > 0 && descCtrl.text.isNotEmpty) {
                finance.addTransaction(TransactionModel(
                  id: DateTime.now().millisecondsSinceEpoch,
                  data: DateTime.now(),
                  ciclo: finance.activeCycle,
                  tipo: 'Despesa Variável',
                  categoria: categoria,
                  descricao: descCtrl.text,
                  valor: val,
                  responsavel: responsavel,
                  formaPagamento: formaPagamento,
                ));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Salvar Lançamento'),
          )
        ],
      ),
    );
  }

  Widget _buildMiddleReorderableAccordion(FinanceProvider finance) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return Material(
              color: Colors.transparent,
              elevation: 0,
              child: child,
            );
          },
          itemCount: _accordionItems.length,
          onReorder: (int oldIndex, int newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _accordionItems.removeAt(oldIndex);
              _accordionItems.insert(newIndex, item);
            });
          },
          itemBuilder: (BuildContext context, int index) {
            final item = _accordionItems[index];
            final String itemId = item['id'] as String;
            final bool isOpen = item['expanded'] as bool;

            return Padding(
              key: ValueKey<String>(itemId),
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        item['expanded'] = !isOpen;
                      });
                    },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.transparent : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: isOpen
                            ? Border.all(color: Colors.transparent)
                            : Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: isOpen
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_indicator,
                              color: Colors.grey.shade400,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            item['icon'] as IconData,
                            color: Colors.grey.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isOpen ? FontWeight.bold : FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: isOpen ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade600,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    child: SizedBox(
                      width: double.infinity,
                      height: isOpen ? null : 0,
                      child: isOpen
                          ? Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 12.0),
                              child: _buildAccordionBody(itemId, finance),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccordionBody(String itemId, FinanceProvider finance) {
    switch (itemId) {
      case 'resumo_contas':
        return _buildMetricsSummary(finance);
      case 'orcamento_previsto':
        return const FoodBudgetCard();
      case 'cofrinho_casal':
        return const Text('Acesse suas metas e cofrinhos do casal.', style: TextStyle(fontSize: 12));
      case 'carteira_cartoes':
        return Column(
          children: finance.cards
              .map((c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('${c.titular} • final ${c.final4}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(_currencyFormat.format(c.limite), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ))
              .toList(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openCardsModal() {
    final finance = Provider.of<FinanceProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💳 Cartões de Crédito & Limites', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ...finance.cards.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: c.cor == 'purple' ? Colors.purple.shade100 : Colors.green.shade100,
                child: const Icon(LucideIcons.creditCard, size: 18),
              ),
              title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('${c.titular} • final ${c.final4}', style: const TextStyle(fontSize: 11)),
              trailing: Text(_currencyFormat.format(c.limite), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )),
          ],
        ),
      ),
    );
  }
}
