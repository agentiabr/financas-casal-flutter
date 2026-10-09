import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ParsedVoiceCommand {
  final String text;
  final double? valor;
  final String? descricao;
  final String? categoria;
  final String? formaPagamento;
  final String? tipo;

  ParsedVoiceCommand({
    required this.text,
    this.valor,
    this.descricao,
    this.categoria,
    this.formaPagamento,
    this.tipo,
  });
}

class SpeechService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';

  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (val) {
        _isListening = false;
        notifyListeners();
      },
      onStatus: (val) {
        _isListening = val == 'listening';
        notifyListeners();
      },
    );
    return _isAvailable;
  }

  Future<void> startListening({required Function(String text) onResult}) async {
    if (!_isAvailable) {
      await initialize();
    }
    _lastWords = '';
    _isListening = true;
    notifyListeners();

    await _speech.listen(
      localeId: 'pt_BR',
      onResult: (result) {
        _lastWords = result.recognizedWords;
        onResult(_lastWords);
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    notifyListeners();
  }

  // Motor NLP para processamento em linguagem natural
  ParsedVoiceCommand parseCommand(String text) {
    final lower = text.toLowerCase().trim();
    double? valor;
    String tipo = 'Despesa Variável';
    String categoria = 'Outros';
    String formaPagamento = 'PIX';
    String descricao = text;

    // 1. Extração do Valor
    final regexValor = RegExp(r'(?:r\$|reais|valor de|de)?\s*([0-9]+(?:[.,][0-9]{2})?)\s*(?:reais)?');
    final match = regexValor.firstMatch(lower);
    if (match != null) {
      final strNum = match.group(1)!.replaceAll(',', '.');
      valor = double.tryParse(strNum);
    }

    // 2. Extração da Categoria (incluindo Pet)
    if (lower.contains('pet') || lower.contains('ração') || lower.contains('veterinário') || lower.contains('cachorro') || lower.contains('gato')) {
      categoria = 'Pet';
    } else if (lower.contains('mercado') || lower.contains('supermercado') || lower.contains('feira') || lower.contains('almoço') || lower.contains('jantar') || lower.contains('padaria')) {
      categoria = 'Alimentação';
    } else if (lower.contains('uber') || lower.contains('gasolina') || lower.contains('combustível') || lower.contains('posto')) {
      categoria = 'Transporte';
    } else if (lower.contains('farmácia') || lower.contains('remédio') || lower.contains('médico') || lower.contains('dentista')) {
      categoria = 'Saúde';
    } else if (lower.contains('luz') || lower.contains('água') || lower.contains('aluguel') || lower.contains('condomínio') || lower.contains('internet')) {
      categoria = 'Moradia';
      tipo = 'Despesa Fixa';
    } else if (lower.contains('salário') || lower.contains('recebi') || lower.contains('pagamento recebido')) {
      categoria = 'Salário';
      tipo = 'Receita';
    }

    // 3. Forma de Pagamento
    if (lower.contains('pix')) {
      formaPagamento = 'PIX';
    } else if (lower.contains('crédito') || lower.contains('cartão de crédito')) {
      formaPagamento = 'Cartão de Crédito';
    } else if (lower.contains('débito')) {
      formaPagamento = 'Cartão de Débito';
    } else if (lower.contains('dinheiro')) {
      formaPagamento = 'Dinheiro';
    }

    return ParsedVoiceCommand(
      text: text,
      valor: valor,
      descricao: descricao,
      categoria: categoria,
      formaPagamento: formaPagamento,
      tipo: tipo,
    );
  }
}
