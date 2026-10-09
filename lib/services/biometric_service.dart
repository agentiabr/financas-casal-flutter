import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // Verifica se o dispositivo possui hardware biométrico disponível
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      debugPrint('Erro ao verificar suporte biométrico: $e');
      return false;
    }
  }

  // Lista os tipos de biometria cadastrados (Impressão Digital, Face ID, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Erro ao obter biometrias disponíveis: $e');
      return <BiometricType>[];
    }
  }

  // Autenticação com Face ID, Impressão Digital ou Senha do Aparelho
  Future<bool> authenticate({String reason = 'Confirme sua identidade para acessar as Finanças de Rodrigo & Márcia'}) async {
    try {
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) {
        // Se o dispositivo não tiver biometria (ex: emulador), libera para não travar o usuário
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite fallback para PIN/Senha do aparelho
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Erro durante a autenticação biométrica: $e');
      return false;
    }
  }
}
