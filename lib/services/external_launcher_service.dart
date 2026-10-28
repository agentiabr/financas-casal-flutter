import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviços utilitários para abertura de URLs externas e integração direta com WhatsApp
class ExternalLauncherService {
  /// Abre uma URL externa ou direciona para o WhatsApp se for um link de mensagem
  static Future<void> openExternalUrl(String url) async {
    try {
      final parsedUri = Uri.tryParse(url);
      if (parsedUri != null &&
          (parsedUri.host.contains('wa.me') ||
           parsedUri.host.contains('whatsapp.com') ||
           parsedUri.scheme == 'whatsapp')) {
        String text = parsedUri.queryParameters['text'] ?? '';
        String phone = parsedUri.queryParameters['phone'] ?? '';
        if (phone.isEmpty && parsedUri.pathSegments.isNotEmpty) {
          final first = parsedUri.pathSegments.first;
          if (RegExp(r'^\d+$').hasMatch(first)) {
            phone = first;
          }
        }
        await shareWhatsAppText(text, phone: phone);
        return;
      }

      final uri = Uri.parse(url);
      bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok) {
        debugPrint('Não foi possível abrir externamente: $url');
      }
    } catch (e) {
      debugPrint('Erro ao abrir link externo: $e');
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
  }

  /// Compartilha texto e número no WhatsApp via URI nativa com fallback para API Web
  static Future<void> shareWhatsAppText(String text, {String? phone}) async {
    try {
      String cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('55') && cleanPhone.length >= 10 && cleanPhone.length <= 11) {
        cleanPhone = '55$cleanPhone';
      }

      final Map<String, String> queryParams = {'text': text};
      if (cleanPhone.isNotEmpty) {
        queryParams['phone'] = cleanPhone;
      }

      // Constrói URI nativa whatsapp://send diretamente com UTF-8 limpo
      final Uri waUri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: queryParams,
      );

      bool ok = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      if (!ok) {
        final Uri webUri = Uri.https(
          'api.whatsapp.com',
          '/send',
          queryParams,
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Erro ao compartilhar no WhatsApp: $e");
    }
  }
}
