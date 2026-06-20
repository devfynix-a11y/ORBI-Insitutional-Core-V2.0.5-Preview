import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.maxDecimalDigits = 2});

  final int maxDecimalDigits;

  static final NumberFormat _wholeFormatter = NumberFormat('#,##0', 'en_US');

  static String format(String raw, {int maxDecimalDigits = 2}) {
    final sanitized = sanitize(raw);
    if (sanitized.isEmpty) return '';

    final parts = sanitized.split('.');
    final wholePart = parts.first.isEmpty ? '0' : parts.first;
    final formattedWhole = _wholeFormatter.format(int.tryParse(wholePart) ?? 0);

    if (parts.length == 1) {
      return formattedWhole;
    }

    final decimalPart = parts[1];
    if (decimalPart.isEmpty) {
      return '$formattedWhole.';
    }

    final limitedDecimal = decimalPart.substring(
      0,
      decimalPart.length > maxDecimalDigits
          ? maxDecimalDigits
          : decimalPart.length,
    );
    return '$formattedWhole.$limitedDecimal';
  }

  static String sanitize(String raw) {
    final trimmed = raw.replaceAll(',', '').trim();
    final buffer = StringBuffer();
    var hasDot = false;

    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      final isDigit = rune >= 48 && rune <= 57;
      if (isDigit) {
        buffer.write(char);
        continue;
      }
      if (char == '.' && !hasDot) {
        hasDot = true;
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static double? tryParse(String raw) {
    final sanitized = sanitize(raw);
    if (sanitized.isEmpty || sanitized == '.') return null;
    return double.tryParse(sanitized);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = sanitize(
      newValue.text.substring(0, cursor),
    ).length;
    final sanitized = sanitize(newValue.text);
    if (sanitized.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final parts = sanitized.split('.');
    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > maxDecimalDigits) {
      return oldValue;
    }

    final formatted = format(sanitized, maxDecimalDigits: maxDecimalDigits);
    var formattedCursor = 0;
    var sanitizedCount = 0;
    while (formattedCursor < formatted.length &&
        sanitizedCount < digitsBeforeCursor) {
      final char = formatted[formattedCursor];
      if (char != ',') sanitizedCount++;
      formattedCursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formattedCursor.clamp(0, formatted.length),
      ),
    );
  }
}
