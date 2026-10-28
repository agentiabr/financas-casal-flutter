import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centraliza a comunicação com a camada nativa Android (MainActivity / MethodChannel)
class NativeChannelService {
  static const MethodChannel _channel = MethodChannel('com.antigravity.ctrlpig/launcher_icon');

  /// Verifica se há fones de ouvido conectados
  static Future<bool> isHeadphonesConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isHeadphonesConnected') ?? false;
    } catch (e) {
      debugPrint('Aviso ao checar fones conectados: $e');
      return false;
    }
  }

  /// Verifica se o áudio dos alarmes de remédio está ativado
  static Future<bool> getMedAudioEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('getMedAudioEnabled') ?? true;
    } catch (e) {
      debugPrint('Aviso ao consultar áudio de remédios: $e');
      return true;
    }
  }

  /// Define se o áudio dos remédios está ativado
  static Future<void> setMedAudioEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setMedAudioEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Aviso ao sincronizar áudio de remédios: $e');
    }
  }

  /// Define o estilo do alarme (ex: 'female', 'vibrate')
  static Future<void> setAlarmStyle(String style) async {
    try {
      await _channel.invokeMethod('setAlarmStyle', {'style': style});
    } catch (e) {
      debugPrint('Aviso ao definir estilo de alarme: $e');
    }
  }

  /// Define se a fala do nome do remédio deve ser desativada
  static Future<void> setMedSpeakNameDisabled(bool disabled) async {
    try {
      await _channel.invokeMethod('setMedSpeakNameDisabled', {'disabled': disabled});
    } catch (e) {
      debugPrint('Aviso ao definir bloqueio de fala de nome: $e');
    }
  }

  /// Dispara a fala nativa do alarme
  static Future<void> speakAlarmNative(String text) async {
    try {
      await _channel.invokeMethod('speakAlarmNative', {'text': text});
    } catch (e) {
      debugPrint('Aviso ao disparar fala nativa de alarme: $e');
    }
  }

  /// Interrompe o alarme nativo em execução
  static Future<void> stopNativeAlarm() async {
    try {
      await _channel.invokeMethod('stopNativeAlarm');
    } catch (e) {
      debugPrint('Aviso ao parar alarme nativo: $e');
    }
  }

  /// Exibe notificação simples padrão
  static Future<void> showStandardNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    try {
      await _channel.invokeMethod('showStandardNotification', {
        'title': title,
        'body': body,
        'id': id,
      });
    } catch (e) {
      debugPrint('Aviso ao disparar notificação padrão: $e');
    }
  }

  /// Exibe notificação com fala ou slot específico
  static Future<void> showNotification({
    required String title,
    required String body,
    String? speech,
    String? slot,
    String? type,
    required int id,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'speech': speech ?? '',
        'slot': slot ?? '',
        'type': type ?? '',
        'id': id,
      });
    } catch (e) {
      debugPrint('Aviso ao disparar notificação: $e');
    }
  }

  /// Exibe notificação de lista de compras compartilhada
  static Future<void> showShoppingNotification({
    required String title,
    required String body,
    String? sender,
    String? partner,
    required int id,
  }) async {
    try {
      await _channel.invokeMethod('showShoppingNotification', {
        'title': title,
        'body': body,
        'sender': sender ?? '',
        'partner': partner ?? '',
        'id': id,
      });
    } catch (e) {
      debugPrint('Aviso ao disparar notificação de compras: $e');
    }
  }

  /// Agenda alarmes de medicamentos no AlarmManager nativo
  static Future<void> scheduleMedAlarms(List<Map<String, dynamic>> alarms) async {
    try {
      await _channel.invokeMethod('scheduleMedAlarms', {'alarms': alarms});
    } catch (e) {
      debugPrint('Aviso ao agendar alarmes de medicamentos: $e');
    }
  }

  /// Agenda alarmes de cuidados com pet no AlarmManager nativo
  static Future<void> schedulePetAlarms(List<Map<String, dynamic>> alarms) async {
    try {
      await _channel.invokeMethod('schedulePetAlarms', {'alarms': alarms});
    } catch (e) {
      debugPrint('Aviso ao agendar alarmes de pet: $e');
    }
  }

  /// Atualiza o ícone dinâmico do aplicativo no launcher
  static Future<void> setLauncherIcon(bool isPositive) async {
    try {
      await _channel.invokeMethod('setLauncherIcon', {'isPositive': isPositive});
    } catch (e) {
      debugPrint('Aviso ao alterar ícone do launcher: $e');
    }
  }

  /// Salva imagem em Base64 na galeria/armazenamento do celular
  static Future<bool> saveImage({
    required String base64Data,
    required String filename,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('saveImage', {
            'base64Data': base64Data,
            'filename': filename,
          }) ??
          false;
    } catch (e) {
      debugPrint('Aviso ao salvar imagem nativa: $e');
      return false;
    }
  }

  /// Abre o seletor nativo de contatos da agenda do Android
  static Future<Map<String, dynamic>?> pickContact() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('pickContact');
    } catch (e) {
      debugPrint('Aviso ao selecionar contato nativo: $e');
      return null;
    }
  }

  /// Consome confirmação pendente de remédio tomado disparada via notificação nativa
  static Future<dynamic> consumePendingMedTaken() async {
    try {
      return await _channel.invokeMethod('consumePendingMedTaken');
    } catch (e) {
      debugPrint('Aviso ao consumir remédio pendente nativo: $e');
      return null;
    }
  }

  /// Consome aceite de lista de compras disparado via notificação nativa
  static Future<dynamic> consumePendingShoppingAcceptance() async {
    try {
      return await _channel.invokeMethod('consumePendingShoppingAcceptance');
    } catch (e) {
      debugPrint('Aviso ao consumir aceite de compras nativo: $e');
      return null;
    }
  }
}
