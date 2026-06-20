import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_mobileapp/core/utils/amount_input_formatter.dart';

void main() {
  group('AmountInputFormatter', () {
    test('adds thousands separators', () {
      expect(AmountInputFormatter.format('1000'), '1,000');
      expect(AmountInputFormatter.format('1234567'), '1,234,567');
    });

    test('preserves and limits decimal digits', () {
      expect(AmountInputFormatter.format('1234567.5'), '1,234,567.5');
      expect(AmountInputFormatter.format('1234.567'), '1,234.56');
    });

    test('parses formatted values for API payloads', () {
      expect(AmountInputFormatter.tryParse('1,250,000.75'), 1250000.75);
      expect(AmountInputFormatter.tryParse(''), isNull);
    });

    test('keeps the caret near the edited digit', () {
      final formatter = AmountInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '100',
          selection: TextSelection.collapsed(offset: 3),
        ),
        const TextEditingValue(
          text: '1000',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(result.text, '1,000');
      expect(result.selection.baseOffset, 5);
    });
  });
}
