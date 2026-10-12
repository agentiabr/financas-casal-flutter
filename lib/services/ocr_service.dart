import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptItem {
  final String produto;
  final double qtd;
  final double preco; // Preço Unitário
  final double total;
  final String unidade;

  ReceiptItem({
    required this.produto,
    required this.qtd,
    required this.preco,
    required this.total,
    this.unidade = 'un',
  });

  Map<String, dynamic> toJson() => {
    'produto': produto,
    'qtd': qtd,
    'preco': preco,
    'total': total,
    'unidade': unidade,
  };
}

class ReceiptOcrResult {
  final String? storeName;
  final double? totalAmount;
  final DateTime? date;
  final List<ReceiptItem> items;
  final List<String> lines;
  final String rawText;

  ReceiptOcrResult({
    this.storeName,
    this.totalAmount,
    this.date,
    required this.items,
    required this.lines,
    required this.rawText,
  });

  Map<String, dynamic> toJson() {
    String dateStr = '';
    if (date != null) {
      dateStr = '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
    }
    return {
      'estabelecimento': storeName ?? 'Supermercado',
      'data': dateStr,
      'valor_total': totalAmount ?? 0.0,
      'itens': items.map((e) => e.toJson()).toList(),
      'linhas': lines,
      'raw_text': rawText,
    };
  }
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptOcrResult> processReceiptImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) {
          lines.add(t);
        }
      }
    }

    // 1. Detectar Data da Compra
    DateTime? detectedDate;
    final dateRegex = RegExp(
      r'(?:EMISS[ÃA]O|DATA|EMITIDO|DT|CUPOM)?[\s:\.]*([0-3]?\d)[\/\.\-]([0-1]?\d)[\/\.\-](20\d\d|\d\d)',
      caseSensitive: false,
    );
    final dateMatch = dateRegex.firstMatch(rawText);
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1) ?? '');
      final m = int.tryParse(dateMatch.group(2) ?? '');
      var yStr = dateMatch.group(3) ?? '';
      if (yStr.length == 2) yStr = '20$yStr';
      final y = int.tryParse(yStr);
      if (d != null && m != null && y != null && d >= 1 && d <= 31 && m >= 1 && m <= 12) {
        detectedDate = DateTime(y, m, d);
      }
    }
    detectedDate ??= DateTime.now();

    // 2. Detectar Valor Total da NF
    double? detectedTotal;
    final totalRegex = RegExp(
      r'(?:VALOR\s+TOTAL(?:\s+DA\s+NOTA|\s+A\s+PAGAR|\s+PAGO|\s+L[ÍI]QUIDO)?|TOTAL\s+A\s+PAGAR|TOTAL\s+L[ÍI]QUIDO|TOTAL\s+PAGO|VALOR\s+A\s+PAGAR|VLR\s+TOTAL|TOTAL)\s*(?:R\$)?[\s:]*([0-9]{1,4}(?:\.[0-9]{3})*(?:,[0-9]{2})|[0-9]+[.,][0-9]{2})',
      caseSensitive: false,
    );
    for (int i = lines.length - 1; i >= 0; i--) {
      final match = totalRegex.firstMatch(lines[i]);
      if (match != null) {
        detectedTotal = _parseMoney(match.group(1)!);
        if (detectedTotal != null && detectedTotal > 0) break;
      }
    }
    if (detectedTotal == null || detectedTotal <= 0) {
      final match = totalRegex.firstMatch(rawText);
      if (match != null) {
        detectedTotal = _parseMoney(match.group(1)!);
      }
    }

    // 3. Detectar Estabelecimento (primeiras linhas não fiscais)
    String? detectedStore;
    final fiscalKeywords = [
      'cnpj', 'ie:', 'im:', 'danfe', 'cupom', 'emissao', 'extrato', 'sat', 'nfc-e', 'nfe',
      'av ', 'rua ', 'alameda', 'rodovia', 'travessa', 'bairro', 'cep', 'tel', 'fone',
      '---', '===', 'documento auxiliar', 'consumidor eletronica'
    ];
    for (int i = 0; i < lines.length && i < 10; i++) {
      final l = lines[i];
      final lower = l.toLowerCase();
      if (fiscalKeywords.any((k) => lower.contains(k))) continue;
      if (l.length >= 3 && RegExp(r'[a-zA-ZÀ-ÿ]{3,}').hasMatch(l)) {
        detectedStore = l.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '').trim();
        break;
      }
    }

    // 4. Detectar Itens Comprados (com quantidade e preço unitário)
    final items = <ReceiptItem>[];
    final twoLineQty = RegExp(
      r'^(?:QTD[\s:]*)?(\d+(?:[.,]\d+)?)\s*(UN|KG|LT|L|PC|CX|G|PCT|UND|PÇ)?\s*[Xx*]\s*([0-9]+[.,][0-9]{2})(?:\s+([0-9]+[.,][0-9]{2}))?',
      caseSensitive: false,
    );
    final singleLineQty = RegExp(
      r'^(?:[0-9]{1,4}\s+)?(?:[0-9]{8,14}\s+)?(.+?)\s+(?:QTD[\s:]*)?(\d+(?:[.,]\d+)?)\s*(UN|KG|LT|L|PC|CX|G|PCT|UND|PÇ)?\s*[Xx*]\s*([0-9]+[.,][0-9]{2})(?:\s+([0-9]+[.,][0-9]{2}))?',
      caseSensitive: false,
    );
    final trailingPrice = RegExp(
      r'^(?:[0-9]{1,4}\s+)?(?:[0-9]{8,14}\s+)?([a-zA-ZÀ-ÿ0-9\s\.\-\/\%]{3,40})\s+([0-9]{1,3}[.,][0-9]{2})$',
    );

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // A) Linha única com Qtd x Preço
      final mSingle = singleLineQty.firstMatch(line);
      if (mSingle != null) {
        final pName = _cleanItemName(mSingle.group(1)!);
        final qty = _parseMoney(mSingle.group(2)!) ?? 1.0;
        final unit = (mSingle.group(3) ?? 'un').toLowerCase();
        final price = _parseMoney(mSingle.group(4)!) ?? 0.0;
        final totGroup = mSingle.group(5);
        final tot = totGroup != null ? (_parseMoney(totGroup) ?? (qty * price)) : (qty * price);

        if (_isValidItemName(pName) && price > 0) {
          items.add(ReceiptItem(produto: pName, qtd: qty, preco: price, total: tot, unidade: unit));
          i++;
          continue;
        }
      }

      // B) Duas linhas: Linha atual = Nome, Linha seguinte = Qtd x Preço
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        final mQty = twoLineQty.firstMatch(nextLine);
        if (mQty != null) {
          final pName = _cleanItemName(line);
          final qty = _parseMoney(mQty.group(1)!) ?? 1.0;
          final unit = (mQty.group(2) ?? 'un').toLowerCase();
          final price = _parseMoney(mQty.group(3)!) ?? 0.0;
          final totGroup = mQty.group(4);
          final tot = totGroup != null ? (_parseMoney(totGroup) ?? (qty * price)) : (qty * price);

          if (_isValidItemName(pName) && price > 0) {
            items.add(ReceiptItem(produto: pName, qtd: qty, preco: price, total: tot, unidade: unit));
            i += 2;
            continue;
          }
        }
      }

      // C) Linha com Preço no final (Qtd default 1)
      final mTrail = trailingPrice.firstMatch(line);
      if (mTrail != null) {
        final rawName = mTrail.group(1)!.trim();
        final pName = _cleanItemName(rawName);
        final price = _parseMoney(mTrail.group(2)!) ?? 0.0;
        if (_isValidItemName(pName) && price > 0) {
          items.add(ReceiptItem(produto: pName, qtd: 1.0, preco: price, total: price, unidade: 'un'));
        }
      }

      i++;
    }

    // Se o total não foi detectado mas encontramos itens, calcula o total da soma dos itens
    if ((detectedTotal == null || detectedTotal <= 0) && items.isNotEmpty) {
      detectedTotal = items.fold(0.0, (acc, item) => acc + item.total);
    }

    return ReceiptOcrResult(
      storeName: detectedStore,
      totalAmount: detectedTotal,
      date: detectedDate,
      items: items,
      lines: lines,
      rawText: rawText,
    );
  }

  static double? _parseMoney(String valStr) {
    try {
      var s = valStr.trim();
      if (s.contains(',') && s.contains('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else if (s.contains(',')) {
        s = s.replaceAll(',', '.');
      }
      return double.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  static String _cleanItemName(String raw) {
    return raw
        .replaceAll(RegExp(r'^(?:[0-9]{1,4}\s+)?(?:[0-9]{8,14}\s+)?'), '')
        .replaceAll(RegExp(r'^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$'), '')
        .trim();
  }

  static bool _isValidItemName(String name) {
    if (name.length < 3) return false;
    final lower = name.toLowerCase();
    const blacklist = [
      'total', 'subtotal', 'troco', 'cartao', 'cartão', 'dinheiro', 'imposto', 'tributos',
      'cnpj', 'valor', 'forma pagto', 'debito', 'débito', 'credito', 'crédito', 'procon',
      'chave de acesso', 'protocolo', 'danfe', 'sat', 'nfc-e', 'cupom'
    ];
    return !blacklist.any((k) => lower.contains(k));
  }

  void dispose() {
    _textRecognizer.close();
  }
}
