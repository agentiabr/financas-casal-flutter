import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

enum AccountPlanType { individual, casal, familia }

class LicenseValidationResult {
  final bool isValid;
  final bool isLifetime;
  final AccountPlanType planType;
  final String message;
  final String? inviteHouseholdId;

  LicenseValidationResult({
    required this.isValid,
    required this.isLifetime,
    required this.planType,
    required this.message,
    this.inviteHouseholdId,
  });
}

class LicenseService {
  static const String _prefPlanKey = 'ctrlpig_license_plan';
  static const String _prefIsLifetimeKey = 'ctrlpig_license_is_lifetime';
  static const String _prefCodeKey = 'ctrlpig_license_code';
  static const String _prefActivatedAtKey = 'ctrlpig_license_activated_at';

  // Códigos Mestres de Acesso Vitalício Predefinidos
  static final Map<String, AccountPlanType> _masterCodes = {
    // Casal VIP
    'VITALICIO-CASAL': AccountPlanType.casal,
    'CASAL-VIP': AccountPlanType.casal,
    'CASALVIP': AccountPlanType.casal,
    'PIG-CASAL': AccountPlanType.casal,
    'CONTROLPIG-CASAL': AccountPlanType.casal,
    'CASAL2026': AccountPlanType.casal,

    // Família VIP
    'VITALICIO-FAMILIA': AccountPlanType.familia,
    'FAMILIA-VIP': AccountPlanType.familia,
    'FAMILIAVIP': AccountPlanType.familia,
    'PIG-FAMILIA': AccountPlanType.familia,
    'CONTROLPIG-VIP': AccountPlanType.familia,
    'FAMILIA2026': AccountPlanType.familia,

    // Individual VIP
    'VITALICIO-INDIVIDUAL': AccountPlanType.individual,
    'INDIVIDUAL-VIP': AccountPlanType.individual,
    'PIG-INDIVIDUAL': AccountPlanType.individual,
    'PRO-INDIVIDUAL': AccountPlanType.individual,
  };

  // Códigos Globais (aplicam Vitalício ao plano que o usuário escolheu)
  static final Set<String> _globalMasterCodes = {
    'VITALICIO',
    'CONTROLPIGVIP',
    'PIGVIP',
    'PRO-VITALICIO',
    'ADMIN-VIP',
    'VIP2026',
    'ACESSO-TOTAL',
  };

  /// Valida um código digitado pelo usuário
  static LicenseValidationResult validateCode(String rawCode, AccountPlanType selectedPlan) {
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '-');
    if (code.isEmpty) {
      return LicenseValidationResult(
        isValid: false,
        isLifetime: false,
        planType: selectedPlan,
        message: 'Nenhum código informado.',
      );
    }

    // 1. Verifica se é Código Mestre Específico por Plano
    if (_masterCodes.containsKey(code)) {
      final plan = _masterCodes[code]!;
      final planName = plan == AccountPlanType.casal ? 'Casal' : (plan == AccountPlanType.familia ? 'Família' : 'Individual');
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: plan,
        message: '✨ Acesso Vitalício $planName Liberado com Sucesso!',
      );
    }

    // 2. Verifica se é Código Global Master
    if (_globalMasterCodes.contains(code)) {
      final planName = selectedPlan == AccountPlanType.casal ? 'Casal' : (selectedPlan == AccountPlanType.familia ? 'Família' : 'Individual');
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: selectedPlan,
        message: '✨ Código VIP Global Ativado! Plano $planName Vitalício.',
      );
    }

    // 3. Padrão Dinâmico de Códigos Gerados (ex: VIP-CASAL-XXXX ou LIFETIME-XXXX)
    if (code.startsWith('VIP-CASAL') || code.startsWith('CASAL-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: AccountPlanType.casal,
        message: '✨ Código Vitalício Casal Válido!',
      );
    }
    if (code.startsWith('VIP-FAMILIA') || code.startsWith('FAMILIA-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: AccountPlanType.familia,
        message: '✨ Código Vitalício Família Válido!',
      );
    }
    if (code.startsWith('VIP-INDIVIDUAL') || code.startsWith('IND-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: AccountPlanType.individual,
        message: '✨ Código Vitalício Individual Válido!',
      );
    }
    if (code.startsWith('VIP-') || code.startsWith('CPIG-') || code.startsWith('LIFETIME-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: selectedPlan,
        message: '✨ Código Promocional Vitalício Válido!',
      );
    }

    // 4. Código de Convite de Parceiro / Família (ex: PAIR-123456 ou FAM-123456)
    if (code.startsWith('PAIR-') || code.startsWith('CASAL-JOIN-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: AccountPlanType.casal,
        message: '👫 Convite de Casal reconhecido! Você entrará na conta do parceiro(a).',
        inviteHouseholdId: code.replaceFirst('PAIR-', ''),
      );
    }
    if (code.startsWith('FAM-') || code.startsWith('JOIN-')) {
      return LicenseValidationResult(
        isValid: true,
        isLifetime: true,
        planType: AccountPlanType.familia,
        message: '👨‍👩‍👧‍👦 Convite de Família reconhecido! Você entrará no grupo familiar.',
        inviteHouseholdId: code.replaceFirst('FAM-', ''),
      );
    }

    return LicenseValidationResult(
      isValid: false,
      isLifetime: false,
      planType: selectedPlan,
      message: 'Código inválido ou expirado. Verifique a digitação.',
    );
  }

  /// Salva as informações da licença localmente
  static Future<void> saveLicense({
    required AccountPlanType plan,
    required bool isLifetime,
    String? code,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPlanKey, plan.name);
      await prefs.setBool(_prefIsLifetimeKey, isLifetime);
      if (code != null && code.isNotEmpty) {
        await prefs.setString(_prefCodeKey, code);
      }
      await prefs.setString(_prefActivatedAtKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Aviso ao salvar licença: $e');
    }
  }

  /// Recupera as informações atuais de licença
  static Future<Map<String, dynamic>> getLicenseInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planStr = prefs.getString(_prefPlanKey) ?? 'casal';
      final isLifetime = prefs.getBool(_prefIsLifetimeKey) ?? false;
      final code = prefs.getString(_prefCodeKey);
      final activatedAtStr = prefs.getString(_prefActivatedAtKey);

      AccountPlanType plan;
      switch (planStr) {
        case 'individual':
          plan = AccountPlanType.individual;
          break;
        case 'familia':
          plan = AccountPlanType.familia;
          break;
        default:
          plan = AccountPlanType.casal;
      }

      int daysRemaining = 30;
      if (activatedAtStr != null && !isLifetime) {
        final activatedAt = DateTime.tryParse(activatedAtStr);
        if (activatedAt != null) {
          final elapsed = DateTime.now().difference(activatedAt).inDays;
          daysRemaining = (30 - elapsed).clamp(0, 30);
        }
      }

      return {
        'plan': plan,
        'planName': plan == AccountPlanType.casal ? 'Casal' : (plan == AccountPlanType.familia ? 'Família' : 'Individual'),
        'isLifetime': isLifetime,
        'statusText': isLifetime ? 'VIP Vitalício' : '$daysRemaining dias de teste',
        'code': code,
      };
    } catch (_) {
      return {
        'plan': AccountPlanType.casal,
        'planName': 'Casal',
        'isLifetime': false,
        'statusText': '30 dias de teste',
        'code': null,
      };
    }
  }

  /// Gera um código de convite amigável para enviar ao cônjuge ou familiar
  static String generateInviteCode(AccountPlanType plan, {String? prefix}) {
    final rand = Random().nextInt(900000) + 100000; // 6 dígitos
    final tag = plan == AccountPlanType.casal ? 'PAIR' : 'FAM';
    return '$tag-$rand';
  }
}
