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

  // 4. Logout / Desconectar
  Future<void> signOut() async {
    if (SupabaseConfig.isConfigured) {
      await SupabaseConfig.client.auth.signOut();
    }
    _currentUser = null;
    notifyListeners();
  }
}
