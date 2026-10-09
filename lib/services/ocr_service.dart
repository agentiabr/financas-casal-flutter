import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  final String? storeName;
  final double? totalAmount;
  final DateTime? date;
  final List<String> lines;

  ReceiptOcrResult({
    this.storeName,
    this.totalAmount,
    this.date,
    required this.lines,
  });
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptOcrResult> processReceiptImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        lines.add(line.text.trim());
      }
    }

    String? detectedStore;
    double? detectedTotal;

    // 1. Detectar Valor Total via Regex (Ex: TOTAL 84,20 ou VALOR A PAGAR 150.00)
    final totalRegex = RegExp(r'(?:TOTAL|VALOR A PAGAR|A PAGAR|VALOR TOTAL)[^0-9]*([0-9]+[.,][0-9]{2})', caseSensitive: false);
    for (final l in lines) {
      final match = totalRegex.firstMatch(l);
      if (match != null) {
        final valStr = match.group(1)!.replaceAll(',', '.');
        detectedTotal = double.tryParse(valStr);
        break;
      }
    }

    // 2. Detectar Nome do Estabelecimento (primeiras linhas não fiscais)
    for (final l in lines) {
      final lower = l.toLowerCase();
      if (l.length >= 4 &&
          !lower.contains('danfe') &&
          !lower.contains('cupom') &&
          !lower.contains('cnpj') &&
          !lower.contains('extrato') &&
          !RegExp(r'^[0-9\W]+$').hasMatch(l)) {
        detectedStore = l;
        break;
      }
    }

    return ReceiptOcrResult(
      storeName: detectedStore,
      totalAmount: detectedTotal,
      date: DateTime.now(),
      lines: lines,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
