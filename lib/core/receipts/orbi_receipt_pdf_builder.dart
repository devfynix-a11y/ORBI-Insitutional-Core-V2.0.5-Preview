import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum OrbiReceiptPrimaryRowMode { first, lastMoney }

class OrbiReceiptPdfBuilder {
  const OrbiReceiptPdfBuilder._();

  static const _fontRegular = 'assets/fonts/NotoSans-Regular.ttf';
  static const _fontBold = 'assets/fonts/NotoSans-Bold.ttf';
  static const _defaultLogoAsset = 'assets/images/brand/orbi-logo-v2-black.png';

  static pw.ThemeData? _cachedTheme;
  static Uint8List? _defaultLogoBytes;

  static Future<Uint8List> build({
    required List<MapEntry<String, String>> rows,
    required String heading,
    required String barcodeValue,
    Uint8List? logoBytes,
    OrbiReceiptPrimaryRowMode primaryRowMode = OrbiReceiptPrimaryRowMode.first,
    String detailsTitle = 'TRANSACTION DETAILS',
    String footerMessage = 'Thank you for choosing ORBI. We value your trust.',
  }) async {
    final doc = pw.Document();
    final theme = await _pdfTheme();
    final effectiveLogoBytes = await _sanitizeLogoBytes(
      logoBytes ?? await _loadDefaultLogoBytes(),
    );
    final primaryRow = _primaryRow(rows, primaryRowMode);
    final detailRows = _detailRows(rows, primaryRow, primaryRowMode);
    final statusLabel = _statusLabel(rows);
    final statusColor = PdfColor.fromHex(_statusHex(statusLabel));
    final statusSoft = PdfColor.fromHex(_statusSoftHex(statusLabel));
    final safeBarcode = _barcodeData(barcodeValue);

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          theme: theme,
        ),
        build: (context) => pw.Center(
          child: pw.Container(
            width: 500,
            padding: const pw.EdgeInsets.fromLTRB(26, 24, 26, 20),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(24),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _logoHeader(effectiveLogoBytes),
                pw.SizedBox(height: 12),
                pw.Text(
                  'SECURE PAYMENT RECEIPT',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#64748B'),
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.SizedBox(height: 12),
                _statusPill(statusLabel, statusColor, statusSoft),
                pw.SizedBox(height: 20),
                _amountCard(primaryRow: primaryRow, heading: heading),
                pw.SizedBox(height: 16),
                _detailsCard(title: detailsTitle, rows: detailRows),
                pw.SizedBox(height: 14),
                _barcodeCard(safeBarcode),
                pw.SizedBox(height: 13),
                pw.Text(
                  footerMessage,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#2563EB'),
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Printed: ${_printedAtLabel()}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#64748B'),
                    fontSize: 8.5,
                  ),
                ),
                pw.SizedBox(height: 9),
                _declarationFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bytes = await doc.save();
      debugPrint(
        'OrbiReceiptPdfBuilder.v3.clean: generated PDF size=${bytes.length} bytes',
      );
      return bytes;
    } catch (error, stackTrace) {
      debugPrint('OrbiReceiptPdfBuilder.build failed: $error\n$stackTrace');
      rethrow;
    }
  }

  static Future<pw.ThemeData> _pdfTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    try {
      final regular = await rootBundle.load(_fontRegular);
      final bold = await rootBundle.load(_fontBold);
      _cachedTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (error) {
      debugPrint('OrbiReceiptPdfBuilder: bundled font load failed: $error');
      _cachedTheme = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
    return _cachedTheme!;
  }

  static Future<Uint8List?> _loadDefaultLogoBytes() async {
    if (_defaultLogoBytes != null) return _defaultLogoBytes;
    try {
      final data = await rootBundle.load(_defaultLogoAsset);
      _defaultLogoBytes = data.buffer.asUint8List();
      return _defaultLogoBytes;
    } catch (error) {
      debugPrint('OrbiReceiptPdfBuilder: logo asset load failed: $error');
      return null;
    }
  }

  static Future<Uint8List?> _sanitizeLogoBytes(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    if (kIsWeb) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final size = ui.Size(source.width.toDouble(), source.height.toDouble());
      canvas.drawRect(
        ui.Offset.zero & size,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawImage(source, ui.Offset.zero, ui.Paint());
      final picture = recorder.endRecording();
      final flattened = await picture.toImage(source.width, source.height);
      final data = await flattened.toByteData(format: ui.ImageByteFormat.png);
      source.dispose();
      flattened.dispose();
      picture.dispose();
      if (data == null) return null;
      return data.buffer.asUint8List();
    } catch (error, stackTrace) {
      debugPrint(
        'OrbiReceiptPdfBuilder: logo sanitize failed: $error\n$stackTrace',
      );
      return null;
    }
  }

  static pw.Widget _logoHeader(Uint8List? logoBytes) {
    if (logoBytes != null && logoBytes.isNotEmpty) {
      return pw.SizedBox(
        width: 128,
        height: 48,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      );
    }
    return pw.Text(
      'Orbi',
      style: pw.TextStyle(
        color: PdfColor.fromHex('#111827'),
        fontSize: 27,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _statusPill(String label, PdfColor color, PdfColor soft) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: color, width: 0.9),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _amountCard({
    required MapEntry<String, String> primaryRow,
    required String heading,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EFF6FF'),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            primaryRow.key.toUpperCase(),
            style: pw.TextStyle(
              color: PdfColor.fromHex('#64748B'),
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 9),
          pw.Text(
            primaryRow.value,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#1A2332'),
              fontSize: 39,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 11),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(999),
              border: pw.Border.all(color: PdfColor.fromHex('#2563EB')),
            ),
            child: pw.Text(
              heading.toUpperCase(),
              style: pw.TextStyle(
                color: PdfColor.fromHex('#2563EB'),
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _detailsCard({
    required String title,
    required List<MapEntry<String, String>> rows,
  }) {
    final displayRows = rows.isEmpty
        ? [const MapEntry('Details', 'No additional details')]
        : rows.take(7).toList();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(20, 17, 20, 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#64748B'),
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 13),
          ...displayRows.map(_detailRow),
        ],
      ),
    );
  }

  static pw.Widget _detailRow(MapEntry<String, String> row) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 128,
            child: pw.Text(
              row.key,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#64748B'),
                fontSize: 10.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              row.value,
              softWrap: true,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#1A2332'),
                fontSize: 10.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _barcodeCard(String data) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(16, 13, 16, 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EFF6FF'),
        borderRadius: pw.BorderRadius.circular(13),
        border: pw.Border.all(color: PdfColor.fromHex('#93C5FD')),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: 390,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(7),
              border: pw.Border.all(color: PdfColor.fromHex('#DBEAFE')),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: data,
              width: 360,
              height: 54,
              drawText: false,
              color: PdfColor.fromHex('#111827'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            data,
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#64748B'),
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static MapEntry<String, String> _primaryRow(
    List<MapEntry<String, String>> rows,
    OrbiReceiptPrimaryRowMode mode,
  ) {
    if (rows.isEmpty) return const MapEntry<String, String>('Amount', '-');
    if (mode == OrbiReceiptPrimaryRowMode.lastMoney) {
      return rows.lastWhere(_isMoneyRow, orElse: () => rows.first);
    }
    return rows.first;
  }

  static List<MapEntry<String, String>> _detailRows(
    List<MapEntry<String, String>> rows,
    MapEntry<String, String> primaryRow,
    OrbiReceiptPrimaryRowMode mode,
  ) {
    final details = rows.where((row) => row != primaryRow).toList();
    if (mode == OrbiReceiptPrimaryRowMode.lastMoney) {
      return details.where((row) => !_isMoneyRow(row)).toList();
    }
    return details.skip(1).toList();
  }

  static bool _isMoneyRow(MapEntry<String, String> row) {
    final key = row.key.toLowerCase();
    return key.contains('amount') ||
        key.contains('kiasi') ||
        key.contains('total') ||
        key.contains('jumla');
  }

  static String _statusLabel(List<MapEntry<String, String>> rows) {
    for (final row in rows) {
      final key = row.key.toLowerCase();
      if (key.contains('status') || key.contains('hali')) {
        final value = row.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return 'Completed';
  }

  static String _statusHex(String status) {
    final key = status.toLowerCase();
    if (key.contains('fail') ||
        key.contains('reject') ||
        key.contains('error') ||
        key.contains('shindik')) {
      return '#DC2626';
    }
    if (key.contains('pend') ||
        key.contains('process') ||
        key.contains('subir')) {
      return '#D97706';
    }
    if (key.contains('cancel') || key.contains('ghair')) return '#64748B';
    if (key.contains('refund') ||
        key.contains('reverse') ||
        key.contains('rejesh')) {
      return '#2563EB';
    }
    return '#16A34A';
  }

  static String _statusSoftHex(String status) {
    final key = status.toLowerCase();
    if (key.contains('fail') ||
        key.contains('reject') ||
        key.contains('error') ||
        key.contains('shindik')) {
      return '#FEF2F2';
    }
    if (key.contains('pend') ||
        key.contains('process') ||
        key.contains('subir')) {
      return '#FFFBEB';
    }
    if (key.contains('cancel') || key.contains('ghair')) return '#F8FAFC';
    if (key.contains('refund') ||
        key.contains('reverse') ||
        key.contains('rejesh')) {
      return '#EFF6FF';
    }
    return '#F0FDF4';
  }

  static String _barcodeData(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '-')
        .replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) {
      return 'ORBI-${DateTime.now().millisecondsSinceEpoch}';
    }
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  static String _printedAtLabel() {
    final now = DateTime.now();
    final printedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$printedAt UTC$sign$hours:$minutes';
  }

  static pw.Widget _declarationFooter() {
    final year = DateTime.now().year;
    return pw.SizedBox(
      width: double.infinity,
      child: pw.Text(
        'If these transactions do not match your records or you are not satisfied, please contact us via +255764258114 or support@orbifinancial.com.\n© $year Orbi Financial. All rights reserved.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#64748B'),
          fontSize: 8.5,
          lineSpacing: 1.4,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
