import 'package:flutter/material.dart';

import '../theme/orbi_theme.dart';
import 'money_format.dart';

InputDecoration withCurrencyPrefix(
  BuildContext context,
  InputDecoration decoration, {
  required String currencyCode,
  String fallbackCurrencyCode = 'TZS',
}) {
  final ui = OrbiTheme.uiOf(context);
  final normalized = normalizeCurrencyCode(currencyCode);
  final resolvedCode = normalized.isEmpty ? fallbackCurrencyCode : normalized;
  return decoration.copyWith(
    prefixText: resolveCurrencyDisplaySymbol(resolvedCode),
    prefixStyle: TextStyle(
      color: ui.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
  );
}
