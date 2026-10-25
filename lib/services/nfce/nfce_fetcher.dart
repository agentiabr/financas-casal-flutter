import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/nfce_invoice.dart';
import 'nfce_number_parser.dart';
import 'nfce_parser.dart';

/// Serviço responsável por requisitar a página oficial da SEFAZ no lado Dart (sem restrições de CORS)
/// e orquestrar a extração de dados via [NfceParser].
class NfceFetcher {
  final NfceParser _parser;
  final Map<String, String> _cookies = {};

  NfceFetcher({NfceParser? parser})
      : _parser = parser ?? NfceParser();

  /// Normaliza URLs de consulta pública conhecidas para ir direto à página de itens
  static String normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains('fazenda.sp.gov.br')) {
      if (url.contains('/qrcode?p=')) {
        final pIndex = url.indexOf('/qrcode?p=');
        final query = url.substring(pIndex + '/qrcode?p='.length);
        return 'https://www.nfce.fazenda.sp.gov.br/NFCeConsultaPublica/Paginas/ConsultaQRCode.aspx?p=$query';
      }
      if (url.contains('ConsultaPublica.aspx?p=')) {
        return url.replaceAll('ConsultaPublica.aspx', 'ConsultaQRCode.aspx');
      }
    }
    return url;
  }

  /// Converte strings de URL com caracteres especiais (como pipe '|') em URIs válidos
  static Uri parseSafeUri(String urlString) {
    var clean = urlString.trim();
    final qIndex = clean.indexOf('?');
    if (qIndex != -1) {
      final base = clean.substring(0, qIndex);
      final query = clean.substring(qIndex + 1);
      final safeQuery = query.replaceAll('|', '%7C').replaceAll(' ', '%20');
      clean = '$base?$safeQuery';
    } else {
      clean = clean.replaceAll('|', '%7C').replaceAll(' ', '%20');
    }
    return Uri.parse(clean);
  }

  /// Busca a página HTML da URL fornecida e retorna o modelo [NfceInvoice]
  Future<NfceInvoice> fetchAndParse(String rawUrl) async {
    final cleanUrl = rawUrl.trim();
    final accessKey = NfceNumberParser.extractAccessKey(cleanUrl);

    if (cleanUrl.isEmpty || (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: cleanUrl,
        errorMessage: 'URL do QR Code inválida ou vazia: $cleanUrl',
      );
    }

    try {
      var currentUrl = normalizeUrl(cleanUrl);
      int redirectCount = 0;
      http.Response? finalResponse;
      final client = http.Client();

      try {
        while (redirectCount < 6) {
          final uri = parseSafeUri(currentUrl);

          // Headers com User-Agent de navegador moderno (SEM 'br' para evitar compressão Brotli incompatível no Dart)
          final headers = {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8',
            'Accept-Encoding': 'gzip, deflate',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          };

          if (_cookies.isNotEmpty) {
            headers['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
          }

          final request = http.Request('GET', uri)
            ..followRedirects = false
            ..headers.addAll(headers);

          final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));
          final response = await http.Response.fromStream(streamedResponse);

          // Salva cookies retornados no Set-Cookie
          final rawSetCookie = response.headers['set-cookie'];
          if (rawSetCookie != null && rawSetCookie.isNotEmpty) {
            _updateCookies(rawSetCookie);
          }

          // Se for redirecionamento HTTP (301, 302, 303, 307)
          if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers['location'];
            if (location != null && location.isNotEmpty) {
              currentUrl = uri.resolve(location).toString();
              redirectCount++;
              continue;
            }
          }

          finalResponse = response;
          break;
        }
      } finally {
        client.close();
      }

      if (finalResponse != null && finalResponse.statusCode >= 200 && finalResponse.statusCode < 300) {
        final decodedHtml = _decodeResponseBody(finalResponse);
        final invoice = _parser.parse(decodedHtml, rawUrl: currentUrl);

        // Se o parser não conseguiu extrair itens ou total, verifica se houve fallback
        if (invoice.items.isEmpty && invoice.total == 0.0) {
          return NfceInvoice.fallback(
            accessKey: accessKey ?? invoice.accessKey,
            rawUrl: cleanUrl,
            errorMessage: 'A página da SEFAZ foi carregada, mas não apresentou itens legíveis.',
          );
        }

        return invoice;
      } else {
        final status = finalResponse?.statusCode ?? 0;
        return NfceInvoice.fallback(
          accessKey: accessKey,
          rawUrl: cleanUrl,
          errorMessage: 'Servidor da SEFAZ retornou status $status.',
        );
      }
    } on TimeoutException {
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: cleanUrl,
        errorMessage: 'Tempo limite esgotado ao conectar com a SEFAZ (10s).',
      );
    } catch (e) {
      debugPrint('Aviso NfceFetcher: $e');
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: cleanUrl,
        errorMessage: 'Falha de conexão com a SEFAZ: $e',
      );
    }
  }

  void _updateCookies(String rawSetCookie) {
    for (final cookiePart in rawSetCookie.split(',')) {
      final nameVal = cookiePart.split(';')[0].trim();
      final eqIdx = nameVal.indexOf('=');
      if (eqIdx > 0) {
        final name = nameVal.substring(0, eqIdx).trim();
        final value = nameVal.substring(eqIdx + 1).trim();
        if (name.isNotEmpty &&
            !name.toLowerCase().startsWith('path') &&
            !name.toLowerCase().startsWith('domain') &&
            !name.toLowerCase().startsWith('expires')) {
          _cookies[name] = value;
        }
      }
    }
  }

  /// Trata encodings frequentes das SEFAZ (ISO-8859-1 / Latin1 vs UTF-8)
  String _decodeResponseBody(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    // Se o header declara explicitamente iso-8859-1 ou windows-1252
    if (contentType.contains('iso-8859-1') || contentType.contains('windows-1252') || contentType.contains('latin1')) {
      try {
        return latin1.decode(response.bodyBytes);
      } catch (_) {}
    }

    // Tenta primeiro UTF-8 com allowMalformed para evitar crash de FormatException
    try {
      final utf8Str = utf8.decode(response.bodyBytes, allowMalformed: false);
      return utf8Str;
    } catch (_) {
      // Fallback para Latin1 / ISO-8859-1
      return latin1.decode(response.bodyBytes);
    }
  }
}
