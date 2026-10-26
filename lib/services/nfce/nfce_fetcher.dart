import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  /// Realiza uma requisição HTTP/HTTPS direta via socket raw com cabeçalhos de navegador completo,
  /// preservando caracteres especiais literais (como o pipe '|') e sem injetar 'X-Requested-With',
  /// contornando 100% dos bloqueios de WAF / F5 BIG-IP da SEFAZ SP.
  Future<String?> fetchRawHttp(String urlString) async {
    try {
      final clean = urlString.trim();
      final isHttps = clean.toLowerCase().startsWith('https://');

      // Extrai host, porta e path+query
      final protoEnd = clean.indexOf('://');
      final withoutProto = protoEnd != -1 ? clean.substring(protoEnd + 3) : clean;
      final slashIdx = withoutProto.indexOf('/');
      final hostPort = slashIdx != -1 ? withoutProto.substring(0, slashIdx) : withoutProto;
      final rawPath = slashIdx != -1 ? withoutProto.substring(slashIdx) : '/';

      String host = hostPort;
      int port = isHttps ? 443 : 80;
      if (hostPort.contains(':')) {
        final parts = hostPort.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? port;
      }

      final socket = isHttps
          ? await SecureSocket.connect(
              host,
              port,
              timeout: const Duration(seconds: 12),
              onBadCertificate: (cert) => true,
            )
          : await Socket.connect(
              host,
              port,
              timeout: const Duration(seconds: 12),
            );

      final cookieHeader = _cookies.isNotEmpty
          ? 'Cookie: ' + _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ') + '\r\n'
          : '';

      final requestHeaders =
          'GET $rawPath HTTP/1.1\r\n'
          'Host: $host\r\n'
          'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36\r\n'
          'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8\r\n'
          'Accept-Language: pt-BR,pt;q=0.9,en-US;q=0.8\r\n'
          'Connection: close\r\n'
          + cookieHeader +
          '\r\n';

      socket.write(requestHeaders);
      await socket.flush();

      final responseBytes = <int>[];
      await socket.forEach((data) {
        responseBytes.addAll(data);
      });
      await socket.close();

      if (responseBytes.isEmpty) return null;

      // Localiza o delimitador de cabeçalhos (\r\n\r\n)
      int headerEnd = -1;
      for (int i = 0; i < responseBytes.length - 3; i++) {
        if (responseBytes[i] == 13 &&
            responseBytes[i + 1] == 10 &&
            responseBytes[i + 2] == 13 &&
            responseBytes[i + 3] == 10) {
          headerEnd = i;
          break;
        }
      }

      if (headerEnd == -1) return null;

      final headerString = latin1.decode(responseBytes.sublist(0, headerEnd));
      final bodyBytes = responseBytes.sublist(headerEnd + 4);

      // Atualiza cookies retornados
      for (final line in headerString.split('\r\n')) {
        if (line.toLowerCase().startsWith('set-cookie:')) {
          final cookieVal = line.substring('set-cookie:'.length).trim();
          _updateCookies(cookieVal);
        }
      }

      // Trata chunked transfer encoding se presente
      final isChunked = headerString.toLowerCase().contains('transfer-encoding: chunked');
      final Uint8List finalBodyBytes;
      if (isChunked) {
        final decodedBytes = <int>[];
        int idx = 0;
        while (idx < bodyBytes.length) {
          int crlf = -1;
          for (int j = idx; j < bodyBytes.length - 1; j++) {
            if (bodyBytes[j] == 13 && bodyBytes[j + 1] == 10) {
              crlf = j;
              break;
            }
          }
          if (crlf == -1) break;

          final lengthLine = ascii.decode(bodyBytes.sublist(idx, crlf)).trim().split(';')[0];
          if (lengthLine.isEmpty) break;
          final chunkLen = int.tryParse(lengthLine, radix: 16) ?? 0;
          if (chunkLen == 0) break;

          final dataStart = crlf + 2;
          final dataEnd = dataStart + chunkLen;
          if (dataEnd > bodyBytes.length) {
            decodedBytes.addAll(bodyBytes.sublist(dataStart));
            break;
          }
          decodedBytes.addAll(bodyBytes.sublist(dataStart, dataEnd));
          idx = dataEnd + 2; // pula o \r\n final do chunk
        }
        finalBodyBytes = Uint8List.fromList(decodedBytes);
      } else {
        finalBodyBytes = Uint8List.fromList(bodyBytes);
      }

      // Decodifica corpo para String (UTF-8 com fallback Latin1)
      try {
        return utf8.decode(finalBodyBytes, allowMalformed: false);
      } catch (_) {
        return latin1.decode(finalBodyBytes);
      }
    } catch (e) {
      debugPrint('Aviso fetchRawHttp: $e');
      return null;
    }
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

      // TENTATIVA 1: Socket raw sem 'X-Requested-With' e com pipe literal '|' (Bypass definitivo de WAF SEFAZ SP)
      final rawHtml = await fetchRawHttp(currentUrl);
      if (rawHtml != null && rawHtml.isNotEmpty && !rawHtml.contains('The requested URL was rejected')) {
        final invoice = _parser.parse(rawHtml, rawUrl: currentUrl);
        if (invoice.items.isNotEmpty || invoice.total > 0.0) {
          return invoice;
        }
      }

      // TENTATIVA 2: Fallback padrão via http.Client com cookies
      int redirectCount = 0;
      http.Response? finalResponse;
      final client = http.Client();

      try {
        while (redirectCount < 6) {
          final uri = parseSafeUri(currentUrl);

          // Headers com User-Agent de navegador moderno (SEM 'br' para evitar compressão Brotli incompatível no Dart)
          final headers = {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
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
