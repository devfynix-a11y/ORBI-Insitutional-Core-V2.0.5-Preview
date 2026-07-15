import 'package:flutter/material.dart';

/// Report range selection
enum ReportRange { week, month, year }

extension ReportRangeExtension on ReportRange {
  String get key {
    switch (this) {
      case ReportRange.week:
        return 'week';
      case ReportRange.month:
        return 'month';
      case ReportRange.year:
        return 'year';
    }
  }

  String get labelEn {
    switch (this) {
      case ReportRange.week:
        return 'Week';
      case ReportRange.month:
        return 'Month';
      case ReportRange.year:
        return 'Year';
    }
  }

  String get labelSw {
    switch (this) {
      case ReportRange.week:
        return 'Wiki';
      case ReportRange.month:
        return 'Mwezi';
      case ReportRange.year:
        return 'Mwaka';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportRange.week:
        return Icons.date_range_rounded;
      case ReportRange.month:
        return Icons.calendar_month_rounded;
      case ReportRange.year:
        return Icons.event_available_rounded;
    }
  }
}

/// Resource metadata
class ReportResource {
  const ReportResource({
    required this.label,
    required this.name,
    required this.currency,
  });

  final String label;
  final String name;
  final String currency;
}
