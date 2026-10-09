import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction_model.dart';
import '../config/app_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = '';
  String _selectedTipoFilter = 'Todos';
  String _selectedCategoryFilter = 'Todas';
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);
    final txs = finance.transactions.where((t) {
      final matchesSearch = t.descricao.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.categoria.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTipo = _selectedTipoFilter == 'Todos' || t.tipo == _selectedTipoFilter;
      final matchesCat = _selectedCategoryFilter == 'Todas' || t.categoria == _selectedCategoryFilter;
      return matchesSearch && matchesTipo && matchesCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato & Lançamentos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(finance.isPrivacyMode ? LucideIcons.eyeOff : LucideIcons.eye),
            onPressed: () => finance.togglePrivacy(),
            tooltip: 'Modo Privacidade',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa e Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Pesquisar lançamento ou categoria...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
              ),
            ),
          ),

          // Chips de Filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                _buildFilterChip('Receita'),
                _buildFilterChip('Despesa Fixa'),
                _buildFilterChip('Despesa Variável'),
                _buildCatChip('🐾 Pet'),
                _buildCatChip('Alimentação'),
                _buildCatChip('Moradia'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Lista de Transações
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final tx = txs[idx];
                return _buildTransactionCard(tx, finance);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedTipoFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedTipoFilter = label),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
      ),
    );
  }

  Widget _buildCatChip(String cat) {
    final isSelected = _selectedCategoryFilter == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedCategoryFilter = isSelected ? 'Todas' : cat),
        backgroundColor: Colors.white,
        selectedColor: Colors.purple.shade100,
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx, FinanceProvider finance) {
    final isReceita = tx.tipo == 'Receita';
    final valorFormatado = finance.isPrivacyMode ? r'R$ •••••' : _currencyFormat.format(tx.valor);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isReceita ? AppTheme.emeraldGreen.withOpacity(0.15) : Colors.grey.shade100,
            child: Icon(
              isReceita ? LucideIcons.arrowDownLeft : (tx.categoria.contains('Pet') ? LucideIcons.heart : LucideIcons.shoppingBag),
              size: 16,
              color: isReceita ? AppTheme.emeraldGreen : AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.descricao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(tx.categoria, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const Text(' • ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(tx.responsavel, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (isReceita ? '+ ' : '- ') + valorFormatado,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isReceita ? AppTheme.emeraldGreen : (tx.tipo == 'Despesa Fixa' ? AppTheme.primaryBlue : AppTheme.textMain),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM').format(tx.data),
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16, color: AppTheme.textMuted),
            onPressed: () {
              finance.deleteTransaction(tx.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Lançamento movido para a lixeira'),
                  action: SnackBarAction(
                    label: 'Desfazer',
                    onPressed: () => finance.restoreFromTrash(tx.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
