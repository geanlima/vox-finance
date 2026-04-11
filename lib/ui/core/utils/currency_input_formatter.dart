import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove qualquer coisa que não seja número
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericString.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Converte para centavos
    double value = double.parse(numericString) / 100;

    final formatted = _formatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Converte o texto (ex.: `R$ 1.234,56` ou `1234,56`) para reais usando só os dígitos como centavos.
  static double parse(String formattedText) {
    final numeric = formattedText.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return 0;
    return double.parse(numeric) / 100;
  }
}
