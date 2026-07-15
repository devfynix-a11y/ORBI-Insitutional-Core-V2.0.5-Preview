import 'package:intl/intl.dart';

/// Static helpers and extension methods for report data.
class ReportUtils {
  const ReportUtils._();

  static Map<String, dynamic> from(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static List<Map<String, dynamic>> asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '-';
  }

  static dynamic firstNonNull(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  static String displayValue(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return NumberFormat('#,##0.##').format(value);
    }
    return value.toString();
  }

  static String displayMoney(dynamic value, {String? currency}) {
    if (value == null) return '-';
    final amount = value is num
        ? value
        : num.tryParse(value.toString().replaceAll(',', ''));
    if (amount == null) return displayValue(value);
    final formatted = NumberFormat('#,##0.##').format(amount);
    return currency != null && currency.isNotEmpty
        ? '$currency $formatted'
        : formatted;
  }

  static String formatDateTime(dynamic value) {
    if (value == null) return '-';
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }

  static String stringAt(
    Map<String, dynamic> source,
    List<String> path, {
    required String fallback,
  }) {
    final value = _valueAt(source, path);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static dynamic _valueAt(Map<String, dynamic> source, List<String> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }
}

/// Extension for Maps to access nested values.
extension ReportMapExtension on Map<String, dynamic> {
  dynamic valueAt(List<String> path) => ReportUtils._valueAt(this, path);
}
