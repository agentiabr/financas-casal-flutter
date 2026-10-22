import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/nfce_invoice.dart';
import 'nfce_number_parser.dart';
import 'nfce_parser.dart';

/// Serviço responsável por requisitar a página oficial da SEFAZ no lado Dart (sem restrições de CORS)
/// e orquestrar a extração de dados via [NfceParser].
class NfceFetcher {
  final http.Client _client;
  final NfceParser _parser;

  NfceFetcher({http.Client? client, NfceParser? parser})
      : _client = client ?? http.Client(),
        _parser = parser ?? NfceParser();

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
      final uri = Uri.parse(cleanUrl);

      // Headers com User-Agent de navegador moderno para evitar bloqueios WAF da SEFAZ
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      // Executa a requisição com timeout de 15 segundos
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedHtml = _decodeResponseBody(response);
        final invoice = _parser.parse(decodedHtml, rawUrl: cleanUrl);

        // Se o parser não conseguiu extrair itens ou total, verifica se houve fallback
        if (invoice.items.isEmpty && invoice.total == 0.0) {
          return NfceInvoice.fallback(
            accessKey: accessKey ?? invoice.accessKey,
            rawUrl: cleanUrl,
            errorMessage: 'A página da SEFAZ foi carregada, mas não apresentou itens públicos legíveis.',
          );
        }

        return invoice;
      } else if (response.statusCode >= 300 && response.statusCode < 400) {
        // Redirecionamento HTTP
        final redirectLocation = response.headers['location'];
        if (redirectLocation != null && redirectLocation.isNotEmpty) {
          final nextUri = uri.resolve(redirectLocation).toString();
          return fetchAndParse(nextUri);
        }
        return NfceInvoice.fallback(
          accessKey: accessKey,
          rawUrl: cleanUrl,
          errorMessage: 'Redirecionamento sem destino informado pela SEFAZ (${response.statusCode}).',
        );
      } else {
        return NfceInvoice.fallback(
          accessKey: accessKey,
          rawUrl: cleanUrl,
          errorMessage: 'Servidor da SEFAZ retornou status de erro ${response.statusCode}.',
        );
      }
    } on TimeoutException {
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: cleanUrl,
        errorMessage: 'Tempo limite esgotado ao conectar com a SEFAZ (15s). Chave de acesso preservada.',
      );
    } catch (e) {
      return NfceInvoice.fallback(
        accessKey: accessKey,
        rawUrl: cleanUrl,
        errorMessage: 'Falha de conexão com a SEFAZ: $e',
      );
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
