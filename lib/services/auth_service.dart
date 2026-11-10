import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  AuthService() {
    _initAuthListener();
  }

  User? get currentUser => _currentUser ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client.auth.currentUser : null);
  bool get isAuthenticated => currentUser != null;
  bool get isLoading => _isLoading;

  StreamSubscription<AuthState>? _authSubscription;

  void _initAuthListener() {
    if (SupabaseConfig.isConfigured) {
      _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
        _currentUser = data.session?.user;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  // 1. Login com E-mail e Senha
  Future<String?> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (SupabaseConfig.isConfigured) {
        final res = await SupabaseConfig.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        _currentUser = res.user;
        _isLoading = false;
        notifyListeners();
        return null; // Sucesso
      } else {
        // Modo offline / teste local de desenvolvimento
        await Future.delayed(const Duration(milliseconds: 600));
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro inesperado ao realizar login: $e';
    }
  }

  // 2. Cadastro de Novo Usuário (Individual, Casal ou Família com Suporte a Código Vitalício)
  Future<String?> signUp({
    required String email,
    required String password,
    required String nome,
    String accountType = 'casal',
    String? activationCode,
    bool isLifetime = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (SupabaseConfig.isConfigured) {
        final res = await SupabaseConfig.client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'nome': nome,
            'account_type': accountType,
            'activation_code': activationCode ?? '',
            'is_lifetime': isLifetime,
          },
        );
        _currentUser = res.user;

        // Registra o workspace/household isolado se possível
        if (res.user != null) {
          try {
            final householdTitle = accountType == 'individual'
                ? 'Espaço de $nome'
                : (accountType == 'casal' ? 'Casal $nome' : 'Família $nome');
            final maxMembros = accountType == 'individual' ? 1 : (accountType == 'casal' ? 2 : 6);

            await SupabaseConfig.client.from('households').insert({
              'nome_familia': householdTitle,
              'plano': accountType,
              'max_membros': maxMembros,
            });
          } catch (e) {
            debugPrint('Aviso ao registrar household no Supabase: $e');
          }
        }

        _isLoading = false;
        notifyListeners();
        return null; // Sucesso
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro ao cadastrar: $e';
    }
  }

  // 3. Recuperação de Senha por E-mail
  Future<String?> resetPassword(String email) async {
    try {
      if (SupabaseConfig.isConfigured) {
        await SupabaseConfig.client.auth.resetPasswordForEmail(email.trim());
        return null;
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erro ao enviar e-mail de recuperação: $e';
    }
  }

  // 5. Exclusão definitiva da conta na nuvem (LGPD art. 18, VI)
  // Chama a função RPC `delete_my_account` (ver supabase/migrations/20261109120000_security_compliance.sql).
  Future<String?> deleteAccount() async {
    try {
      if (SupabaseConfig.isConfigured && SupabaseConfig.client.auth.currentUser != null) {
        await SupabaseConfig.client.rpc('delete_my_account');
        await SupabaseConfig.client.auth.signOut();
      }
      _currentUser = null;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Não foi possível excluir a conta na nuvem: $e';
    }
  }

  // 6. Sincronização de trilha de auditoria append-only na nuvem (public.audit_logs)
  Future<void> logAuditEvent(String event, Map<String, dynamic> meta) async {
    try {
      final user = currentUser;
      if (SupabaseConfig.isConfigured && user != null && event.isNotEmpty) {
        final safeEvent = event.length > 60 ? event.substring(0, 60) : event;
        await SupabaseConfig.client.from('audit_logs').insert({
          'user_id': user.id,
          'event': safeEvent,
          'meta': meta,
        });
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar audit_logs no Supabase: $e');
    }
  }

  // 7. Sincronização de comprovante de consentimento LGPD na nuvem (public.legal_consents)
  Future<void> logLegalConsent({
    required String kind,
    required String version,
    required bool granted,
  }) async {
    try {
      final user = currentUser;
      if (SupabaseConfig.isConfigured &&
          user != null &&
          const {'terms', 'privacy', 'kids', 'health', 'ai'}.contains(kind)) {
        await SupabaseConfig.client.from('legal_consents').insert({
          'user_id': user.id,
          'kind': kind,
          'version': version,
          'granted': granted,
        });
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar legal_consents no Supabase: $e');
    }
  }

  // 4. Logout / Desconectar
  Future<void> signOut() async {
    if (SupabaseConfig.isConfigured) {
      await SupabaseConfig.client.auth.signOut();
    }
    _currentUser = null;
    notifyListeners();
  }
}
