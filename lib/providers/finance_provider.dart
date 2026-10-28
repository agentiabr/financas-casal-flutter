import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../models/credit_card_model.dart';
import '../models/installment_model.dart';
import '../models/piggy_model.dart';
import '../models/cycle_model.dart';
import '../models/initial_data.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  final List<TransactionModel> _trash = [];
  List<CreditCardModel> _cards = [];
  List<InstallmentModel> _installments = [];
  List<PiggyModel> _piggies = [];
  
  String _activeCycle = '05/Out a 04/Nov 2026';
  bool _isPrivacyMode = false;
  double _foodBudgetCap = 1500.00;
  double _bankRealValue = 0.0;
  DateTime? _bankCheckTimestamp;

  FinanceProvider() {
    _initData();
  }

  void _initData() {
    // Inicialização protegida: dados históricos pertencem exclusivamente a Rodrigo Cardoso
    final currentUserEmail = SupabaseConfig.isConfigured
        ? SupabaseConfig.client.auth.currentUser?.email?.toLowerCase().trim()
        : null;
    final isMaster = currentUserEmail == 'rodrigocardosocn@gmail.com';
    if (isMaster) {
      _transactions = List.from(initialTransactionsList);
      _cards = [
        CreditCardModel(id: 1, nome: 'Nubank Rodrigo', titular: 'Rodrigo', final4: '8412', limite: 8000.00, cor: 'purple'),
        CreditCardModel(id: 2, nome: 'XP Márcia', titular: 'Márcia', final4: '1093', limite: 15000.00, cor: 'emerald'),
        CreditCardModel(id: 3, nome: 'Itaú Click', titular: 'Comum', final4: '4521', limite: 6000.00, cor: 'amber'),
      ];
    } else {
      _transactions = [];
      _cards = [];
    }
    _fetchFromSupabase();
    _subscribeRealtime();

    // Compras parceladas
    _installments = [
      InstallmentModel(id: 1, descricao: 'Notebook Dell XPS', valorParcela: 450.00, totalParcelas: 10, parcelaAtual: 4, valorTotal: 4500.00, cartao: 'XP Márcia', cicloInicio: '05/Jul a 04/Ago 2026'),
      InstallmentModel(id: 2, descricao: 'Geladeira Inverter', valorParcela: 320.00, totalParcelas: 12, parcelaAtual: 2, valorTotal: 3840.00, cartao: 'Nubank Rodrigo', cicloInicio: '05/Set a 04/Out 2026'),
    ];

    // Cofrinhos
    _piggies = [
      PiggyModel(id: 1, nome: 'Reserva de Emergência', meta: 30000.00, saldoAtual: 18500.00, cor: 'blue', icone: 'shield-check'),
      PiggyModel(id: 2, nome: 'Viagem Férias 2027', meta: 12000.00, saldoAtual: 4800.00, cor: 'purple', icone: 'plane'),
      PiggyModel(id: 3, nome: 'Reforma / Decoração', meta: 8000.00, saldoAtual: 2300.00, cor: 'amber', icone: 'home'),
    ];
  }

  // Getters
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get currentCycleTransactions =>
      _transactions.where((t) => t.ciclo.contains(_activeCycle.split(' ')[0])).toList();
  List<TransactionModel> get trash => _trash;
  List<CreditCardModel> get cards => _cards;
  List<InstallmentModel> get installments => _installments;
  List<PiggyModel> get piggies => _piggies;
  String get activeCycle => _activeCycle;
  bool get isPrivacyMode => _isPrivacyMode;
  double get foodBudgetCap => _foodBudgetCap;
  double get bankRealValue => _bankRealValue;
  DateTime? get bankCheckTimestamp => _bankCheckTimestamp;

  // Métricas Calculadas Dinâmicas
  double get totalReceitas =>
      currentCycleTransactions.where((t) => t.tipo == 'Receita').fold(0.0, (acc, cur) => acc + cur.valor);

  double get totalDespesasFixas =>
      currentCycleTransactions.where((t) => t.tipo == 'Despesa Fixa').fold(0.0, (acc, cur) => acc + cur.valor);

  double get totalDespesasVariaveis =>
      currentCycleTransactions.where((t) => t.tipo == 'Despesa Variável').fold(0.0, (acc, cur) => acc + cur.valor);

  double get totalGastos => totalDespesasFixas + totalDespesasVariaveis;

  double get saldoDisponivel => totalReceitas - totalGastos;

  int get percentComprometido =>
      totalReceitas > 0 ? ((totalGastos / totalReceitas) * 100).round() : 0;

  int get fixasQuitadasCount =>
      currentCycleTransactions.where((t) => t.tipo == 'Despesa Fixa').length;

  int get totalFixasCount => 18;

  double get totalInstallmentsFutureCompromised =>
      _installments.fold(0.0, (acc, cur) => acc + cur.valorParcela);

  // Orçamento de Alimentação
  double get foodBudgetSpent {
    return currentCycleTransactions
        .where((t) => t.categoria == 'Alimentação' || t.categoria == 'Supermercado')
        .fold(0.0, (acc, cur) => acc + cur.valor);
  }

  double get foodBudgetRemaining => (_foodBudgetCap - foodBudgetSpent).clamp(0.0, double.infinity);
  int get foodBudgetPercent => _foodBudgetCap > 0 ? ((foodBudgetSpent / _foodBudgetCap) * 100).round() : 0;

  // Ações de Estado
  void setActiveCycle(String cycle) {
    _activeCycle = cycle;
    notifyListeners();
  }

  void togglePrivacy() {
    _isPrivacyMode = !_isPrivacyMode;
    notifyListeners();
  }

  void addTransaction(TransactionModel tx) {
    _transactions.insert(0, tx);
    notifyListeners();
    _syncToSupabase(tx);
  }

  void editTransaction(TransactionModel tx) {
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) {
      _transactions[idx] = tx;
      notifyListeners();
      _syncToSupabase(tx);
    }
  }

  void deleteTransaction(int id) {
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final removed = _transactions.removeAt(idx);
      _trash.insert(0, removed);
      notifyListeners();
      _deleteFromSupabase(id);
    }
  }

  void restoreFromTrash(int id) {
    final idx = _trash.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final restored = _trash.removeAt(idx);
      _transactions.insert(0, restored);
      notifyListeners();
      _syncToSupabase(restored);
    }
  }

  // Cofrinhos
  void depositPiggy(int id, double amount) {
    final p = _piggies.firstWhere((p) => p.id == id);
    p.saldoAtual += amount;
    notifyListeners();
  }

  void withdrawPiggy(int id, double amount) {
    final p = _piggies.firstWhere((p) => p.id == id);
    p.saldoAtual = (p.saldoAtual - amount).clamp(0.0, double.infinity);
    notifyListeners();
  }

  // Conferência Bancária
  void updateBankRealCheck(double realVal) {
    _bankRealValue = realVal;
    _bankCheckTimestamp = DateTime.now();
    notifyListeners();
  }

  // Supabase Sync & Realtime Fetch
  Future<void> _fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    final currentUserEmail = SupabaseConfig.client.auth.currentUser?.email?.toLowerCase().trim();
    if (currentUserEmail != 'rodrigocardosocn@gmail.com') return;
    try {
      final data = await SupabaseConfig.client
          .from('transactions')
          .select()
          .order('data', ascending: false);
      if (data is List && data.isNotEmpty) {
        final realRows = data.where((item) {
          if (item is Map<String, dynamic>) {
            return item['id'] != 999999 && item['ciclo'] != '__SYSTEM_BACKUP__' && item['tipo'] != '__CLOUD_SNAPSHOT__';
          }
          return true;
        }).toList();
        if (realRows.isNotEmpty) {
          _transactions = realRows
              .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar transações do Supabase: $e');
    }
  }

  Future<void> _syncToSupabase(TransactionModel tx) async {
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.from('transactions').upsert(tx.toJson());
      } catch (e) {
        debugPrint('Erro ao sincronizar com Supabase: $e');
      }
    }
  }

  Future<void> _deleteFromSupabase(int id) async {
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.from('transactions').delete().eq('id', id);
      } catch (e) {
        debugPrint('Erro ao deletar do Supabase: $e');
      }
    }
  }

  Timer? _realtimeDebounceTimer;
  RealtimeChannel? _realtimeChannel;

  void _subscribeRealtime() {
    if (!SupabaseConfig.isConfigured) return;
    try {
      _realtimeChannel = SupabaseConfig.client
          .channel('public:transactions')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (payload) {
              debugPrint('Supabase Realtime alteração detectada: ${payload.eventType}');
              _realtimeDebounceTimer?.cancel();
              _realtimeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                _fetchFromSupabase();
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Aviso ao registrar Realtime no Supabase: $e');
    }
  }

  @override
  void dispose() {
    _realtimeDebounceTimer?.cancel();
    if (_realtimeChannel != null && SupabaseConfig.isConfigured) {
      try {
        SupabaseConfig.client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      } catch (_) {}
    }
    super.dispose();
  }
}
