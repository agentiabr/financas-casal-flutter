import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  String? lastErrorMessage;

  // Verifica se o dispositivo possui hardware biométrico disponível
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Erro ao verificar suporte biométrico: $e');
      return false;
    }
  }

  // Lista os tipos de biometria cadastrados (Impressão Digital, Face ID, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Erro ao obter biometrias disponíveis: $e');
      return <BiometricType>[];
    }
  }

  // Autenticação com Face ID, Impressão Digital ou Senha do Aparelho
  Future<bool> authenticate({
    String reason = 'Confirme sua identidade para acessar as Finanças de Rodrigo & Márcia',
  }) async {
    lastErrorMessage = null;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final available = await _auth.getAvailableBiometrics();

      debugPrint('Biometrics status: canCheck=$canCheck, isSupported=$isSupported, available=$available');

      if (!canCheck && !isSupported && available.isEmpty) {
        lastErrorMessage = 'Dispositivo sem suporte ou biometria cadastrada.';
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite fallback para PIN/Padrão/Senha do aparelho
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (!authenticated) {
        lastErrorMessage = 'Autenticação cancelada ou não concluída.';
      }
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('PlatformException na biometria: ${e.code} - ${e.message}');
      if (e.code == 'NotEnrolled') {
        lastErrorMessage = 'Nenhuma biometria cadastrada no aparelho. Configure sua digital nas Configurações do celular ou use a senha.';
      } else if (e.code == 'PasscodeNotSet') {
        lastErrorMessage = 'O aparelho não possui bloqueio de tela configurado.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        lastErrorMessage = 'Biometria temporariamente bloqueada. Desbloqueie o celular com sua senha.';
      } else {
        lastErrorMessage = 'Falha na autenticação: ${e.message ?? e.code}';
      }
      return false;
    } catch (e) {
      debugPrint('Erro geral durante a autenticação biométrica: $e');
      lastErrorMessage = 'Erro ao processar biometria: $e';
      return false;
    }
  }
}
