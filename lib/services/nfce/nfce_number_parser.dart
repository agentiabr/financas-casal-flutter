/// Utilitário de normalização numérica, de unidades e de chaves para NFC-e brasileira
class NfceNumberParser {
  /// Converte strings numéricas em formato brasileiro ("20,09", "1.234,56", "R$ 0,15") em double
  static double parseCurrency(String? raw) {
    if (raw == null) return 0.0;
    var clean = raw.trim();
    if (clean.isEmpty) return 0.0;

    // Remove R$, espaços sem quebra (\u00A0), tabs e rótulos
    clean = clean
        .replaceAll(r'R$', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'(valor|total|unit|vl\.|pago|subtotal)[:\s]*', caseSensitive: false), '')
        .trim();

    // Se possui ponto e vírgula (ex: 1.250,50), remove o ponto de milhar e troca vírgula por ponto
    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      // Formato comum brasileiro: 20,09 -> 20.09
      clean = clean.replaceAll(',', '.');
    }

    // Extrai apenas a parte numérica válida (dígitos e um único ponto decimal)
    final match = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(clean);
    if (match != null) {
      return double.tryParse(match.group(0) ?? '') ?? 0.0;
    }

    return 0.0;
  }

  /// Converte strings de quantidade ("1,05", "0,570", "Qtd.: 2") em double
  static double parseQuantity(String? raw) {
    if (raw == null) return 1.0;
    var clean = raw.trim();
    if (clean.isEmpty) return 1.0;

    // Remove prefixos como Qtd.:, Qtde:, Qtd
    clean = clean.replaceAll(RegExp(r'qtd[e\.]*[:\s]*', caseSensitive: false), '').trim();

    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }

    final match = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(clean);
    if (match != null) {
      final val = double.tryParse(match.group(0) ?? '') ?? 1.0;
      return val > 0 ? val : 1.0;
    }

    return 1.0;
  }

  /// Normaliza unidades de medida da NFC-e (UN, KG, L, CX, etc.)
  static String normalizeUnit(String? raw) {
    if (raw == null) return 'UN';
    var clean = raw
        .replaceFirst(RegExp(r'^(?:UNIDADE|UNID|UND|UN)\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\wÀ-ÿ]'), '')
        .trim()
        .toUpperCase();

    // Algumas páginas SP concatenam o rótulo "UN:" ao texto da unidade
    // ao extrair o conteúdo do HTML (por exemplo, "UNKG").
    if (clean.startsWith('UN') &&
        const {'KG', 'KGS', 'KILO', 'QUILO', 'L', 'LT', 'LTS'}
            .contains(clean.substring(2))) {
      clean = clean.substring(2);
    }

    if (clean.isEmpty) return 'UN';

    switch (clean) {
      case 'UN':
      case 'UND':
      case 'UNID':
      case 'UNIDADE':
      case 'PC':
      case 'PÇ':
      case 'PECA':
      case 'PEÇA':
        return 'UN';
      case 'KG':
      case 'KGS':
      case 'KILO':
      case 'QUILO':
      case 'QUILOGRAMA':
        return 'KG';
      case 'L':
      case 'LT':
      case 'LTS':
      case 'LITRO':
      case 'LITROS':
        return 'L';
      case 'G':
      case 'GR':
      case 'GRAMA':
      case 'GRAMAS':
        return 'G';
      case 'CX':
      case 'CXA':
      case 'CAIXA':
        return 'CX';
      case 'PCT':
      case 'PACOTE':
        return 'PCT';
      case 'DZ':
      case 'DUZIA':
      case 'DÚZIA':
        return 'DZ';
      case 'M':
      case 'MT':
      case 'METRO':
      case 'METROS':
        return 'M';
      default:
        return clean;
    }
  }

  /// Extrai Chave de Acesso da NFC-e (44 dígitos numéricos)
  static String? extractAccessKey(String? input) {
    if (input == null || input.isEmpty) return null;

    // 1. Tenta extrair do parâmetro de URL (ex: ?p=352610...|2|1|1|... ou ?chNFe=3526...)
    if (input.contains('?p=') || input.contains('&p=')) {
      final uri = Uri.tryParse(input);
      final pParam = uri?.queryParameters['p'];
      if (pParam != null) {
        final keyPart = pParam.split('|').first.replaceAll(RegExp(r'\D'), '');
        if (keyPart.length == 44) return keyPart;
      }
    }
    if (input.contains('chNFe=')) {
      final uri = Uri.tryParse(input);
      final ch = uri?.queryParameters['chNFe']?.replaceAll(RegExp(r'\D'), '');
      if (ch != null && ch.length == 44) return ch;
    }

    // 2. Extrai 44 dígitos contínuos do texto ou com espaços (3526 1003 ...)
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    final match = RegExp(r'\d{44}').firstMatch(digitsOnly);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }

  /// Converte data brasileira (DD/MM/YYYY ou DD/MM/YYYY HH:mm:ss) para formato ISO (YYYY-MM-DD)
  static String parseDateToIso(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateTime.now().toIso8601String().split('T')[0];
    }

    final match = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(raw);
    if (match != null) {
      final day = match.group(1);
      final month = match.group(2);
      final year = match.group(3);
      return '$year-$month-$day';
    }

    // Se já estiver no formato YYYY-MM-DD
    final isoMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (isoMatch != null) {
      return isoMatch.group(0)!;
    }

    return DateTime.now().toIso8601String().split('T')[0];
  }
}
