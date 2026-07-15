import 'package:intl/intl.dart';

class MoneyParts {
  final String prefix;
  final String main;
  final String decimals;
  final String suffix;

  const MoneyParts({
    required this.prefix,
    required this.main,
    required this.decimals,
    required this.suffix,
  });
}

const double kCompactMoneyThreshold = 1000;
const double kLargeCardCompactThreshold = 100000000;
const int kExactMoneyDecimalDigits = 2;
const int kCompactMoneyMaxFractionDigits = 1;

String normalizeCurrencyCode(String? code) {
  final normalized = code?.trim().toUpperCase() ?? '';
  return normalized;
}

String resolveCurrencyCode(Iterable<dynamic> values) {
  for (final value in values) {
    final normalized = normalizeCurrencyCode(value?.toString());
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}

String requireCurrencyCode(
  Iterable<dynamic> values, {
  String message = 'Account currency is required.',
}) {
  final resolved = resolveCurrencyCode(values);
  if (resolved.isEmpty) {
    throw StateError(message);
  }
  return resolved;
}

String resolveCurrencyDisplaySymbol(
  String currencyCode, {
  String? backendSymbol,
}) {
  final normalizedCode = normalizeCurrencyCode(currencyCode);
  if (normalizedCode.isEmpty) return '';
  final normalizedSymbol = backendSymbol?.trim() ?? '';
  if (normalizedSymbol.isNotEmpty) {
    return normalizedSymbol.endsWith(' ')
        ? normalizedSymbol
        : '$normalizedSymbol ';
  }
  return '$normalizedCode ';
}

String formatCurrencyAmount(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  int decimalDigits = kExactMoneyDecimalDigits,
  String? currencySymbol,
}) {
  final code = normalizeCurrencyCode(currencyCode);
  if (code.isEmpty) {
    final formatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = decimalDigits
      ..maximumFractionDigits = decimalDigits;
    return formatter.format(value);
  }
  final formatter = NumberFormat.currency(
    name: code,
    symbol: resolveCurrencyDisplaySymbol(code, backendSymbol: currencySymbol),
    decimalDigits: decimalDigits,
    locale: locale,
  );
  return formatter.format(value);
}

String formatAppBalanceAmount(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  int decimalDigits = kExactMoneyDecimalDigits,
}) {
  return formatCurrencyAmount(
    value,
    currencyCode,
    locale: locale,
    decimalDigits: decimalDigits,
  );
}

String formatExactMoney(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  int decimalDigits = kExactMoneyDecimalDigits,
  bool hideBalances = false,
}) {
  if (hideBalances) {
    return '••••••';
  }
  return formatCurrencyAmount(
    value,
    currencyCode,
    locale: locale,
    decimalDigits: decimalDigits,
  );
}

String formatFinancialMoney(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  int decimalDigits = kExactMoneyDecimalDigits,
  bool hideBalances = false,
}) {
  return formatExactMoney(
    value,
    currencyCode,
    locale: locale,
    decimalDigits: decimalDigits,
    hideBalances: hideBalances,
  );
}

String formatDisplayMoney(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  bool hideBalances = false,
}) {
  return formatCompactMoney(
    value,
    currencyCode,
    locale: locale,
    hideBalances: hideBalances,
    compactFrom: kCompactMoneyThreshold,
    maxCompactFractionDigits: kCompactMoneyMaxFractionDigits,
  );
}

String formatLargeCardMoney(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  bool hideBalances = false,
}) {
  return formatCompactMoney(
    value,
    currencyCode,
    locale: locale,
    hideBalances: hideBalances,
    compactFrom: kLargeCardCompactThreshold,
    maxCompactFractionDigits: kCompactMoneyMaxFractionDigits,
  );
}

String formatCompactMoney(
  double value,
  String currencyCode, {
  String locale = 'en_US',
  bool hideBalances = false,
  double compactFrom = kCompactMoneyThreshold,
  int maxCompactFractionDigits = kCompactMoneyMaxFractionDigits,
}) {
  if (hideBalances) {
    return '••••••';
  }

  final absolute = value.abs();
  if (absolute < compactFrom) {
    return formatCurrencyAmount(value, currencyCode, locale: locale);
  }

  final suffix = absolute >= 1000000000000
      ? 'T'
      : absolute >= 1000000000
      ? 'B'
      : absolute >= 1000000
      ? 'M'
      : absolute >= 1000
      ? 'K'
      : '';

  if (suffix.isEmpty) {
    return formatCurrencyAmount(value, currencyCode, locale: locale);
  }

  final scaled = suffix == 'T'
      ? value / 1000000000000
      : suffix == 'B'
      ? value / 1000000000
      : suffix == 'M'
      ? value / 1000000
      : value / 1000;

  final digits = scaled.abs() >= 100 || scaled == scaled.roundToDouble()
      ? 0
      : maxCompactFractionDigits.clamp(0, 6);
  final formatter = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = digits;
  final formattedNumber = formatter.format(scaled);

  final symbol = normalizeCurrencyCode(currencyCode);
  return symbol.isEmpty
      ? '$formattedNumber$suffix'
      : '$formattedNumber$suffix $symbol';
}

MoneyParts splitMoneyParts(String value) {
  final compactMatch = RegExp(
    r'^([^\d-]*)(-?[\d,]+(?:\.\d+)?[KMBT])(\s+.+)?$',
  ).firstMatch(value);
  if (compactMatch != null) {
    return MoneyParts(
      prefix: compactMatch.group(1) ?? '',
      main: compactMatch.group(2) ?? value,
      decimals: '',
      suffix: compactMatch.group(3) ?? '',
    );
  }
  final match = RegExp(
    r'^([^\d-]*)(-?[\d,]+)(\.\d+)?(\s+.+)?$',
  ).firstMatch(value);
  if (match == null) {
    return MoneyParts(prefix: '', main: value, decimals: '', suffix: '');
  }
  return MoneyParts(
    prefix: match.group(1) ?? '',
    main: match.group(2) ?? value,
    decimals: match.group(3) ?? '',
    suffix: match.group(4) ?? '',
  );
}
