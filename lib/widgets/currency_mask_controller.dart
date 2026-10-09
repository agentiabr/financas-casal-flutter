import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove todos os caracteres não numéricos
    String cleanDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Converte para centavos (divisão automática por 100)
    double value = double.parse(cleanDigits) / 100.0;
    String formatted = _formatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static double parse(String formatted) {
    if (formatted.isEmpty) return 0.0;
    String clean = formatted.replaceAll(r'R$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
