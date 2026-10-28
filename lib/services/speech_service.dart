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
  bool _manualSessionActive = false;
  String _accumulatedWords = '';
  String _currentSegmentWords = '';
  Function(String text)? _activeOnResult;

  bool get isListening => _isListening || _manualSessionActive;
  String get lastWords {
    if (_accumulatedWords.isEmpty) return _currentSegmentWords;
    if (_currentSegmentWords.isEmpty) return _accumulatedWords;
    return '$_accumulatedWords $_currentSegmentWords'.trim();
  }

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (val) {
        _isListening = false;
        if (_manualSessionActive) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (_manualSessionActive) {
              _listenInternal();
            }
          });
        }
        notifyListeners();
      },
      onStatus: (val) {
        _isListening = val == 'listening';
        if ((val == 'done' || val == 'notListening') && _manualSessionActive) {
          if (_currentSegmentWords.trim().isNotEmpty) {
            _accumulatedWords = _accumulatedWords.isEmpty
                ? _currentSegmentWords.trim()
                : '$_accumulatedWords ${_currentSegmentWords.trim()}';
            _currentSegmentWords = '';
          }
          Future.delayed(const Duration(milliseconds: 250), () {
            if (_manualSessionActive) {
              _listenInternal();
            }
          });
        }
        notifyListeners();
      },
    );
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    bool finalOnly = false,
  }) async {
    if (!_isAvailable) {
      await initialize();
    }
    _accumulatedWords = '';
    _currentSegmentWords = '';
    _manualSessionActive = true;
    _activeOnResult = onResult;
    _isListening = true;
    notifyListeners();

    await _listenInternal();
  }

  Future<void> _listenInternal() async {
    if (!_manualSessionActive) return;
    try {
      await _speech.listen(
        localeId: 'pt_BR',
        pauseFor: const Duration(seconds: 30),
        listenFor: const Duration(seconds: 120),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
        onResult: (result) {
          if (!_manualSessionActive) return;
          _currentSegmentWords = result.recognizedWords.trim();
          final combined = lastWords;
          if (result.finalResult && _currentSegmentWords.isNotEmpty) {
            _accumulatedWords = _accumulatedWords.isEmpty
                ? _currentSegmentWords
                : '$_accumulatedWords $_currentSegmentWords';
            _currentSegmentWords = '';
          }
          if (_activeOnResult != null && combined.isNotEmpty) {
            _activeOnResult!(combined);
          }
          notifyListeners();
        },
      );
    } catch (_) {}
  }

  Future<void> stopListening() async {
    _manualSessionActive = false;
    _isListening = false;
    _activeOnResult = null;
    try {
      await _speech.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> cancelListening() async {
    _manualSessionActive = false;
    _isListening = false;
    _accumulatedWords = '';
    _currentSegmentWords = '';
    _activeOnResult = null;
    try {
      await _speech.cancel();
    } catch (_) {}
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

  @override
  void dispose() {
    _manualSessionActive = false;
    _isListening = false;
    _activeOnResult = null;
    try {
      _speech.cancel();
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }
}
