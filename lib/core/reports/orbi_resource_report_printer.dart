import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'report_models.dart';
import 'report_pdf_builder.dart';
import 'report_sheet.dart';
import 'report_utils.dart';

typedef OrbiReportLoader = Future<Map<String, dynamic>> Function(String range);

/// Modern entry point for resource reports – exposes the sheet and sharing.
class OrbiResourceReportPrinter {
  const OrbiResourceReportPrinter._();

  static Future<void> openReportSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String filePrefix,
    required OrbiReportLoader loadReport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReportSheet(
        title: title,
        subtitle: subtitle,
        filePrefix: filePrefix,
        loadReport: (range) => loadReport(range.key),
      ),
    );
  }

  static Future<void> shareReport(
    Map<String, dynamic> report, {
    required String title,
    required String filePrefix,
    bool sw = false,
  }) async {
    final bytes = await ReportPdfBuilder.build(report, title: title, sw: sw);
    final range = ReportUtils.stringAt(report, [
      'range',
      'key',
    ], fallback: 'report');
    final safeRange = range.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${filePrefix}_$safeRange.pdf',
    );
  }
}
