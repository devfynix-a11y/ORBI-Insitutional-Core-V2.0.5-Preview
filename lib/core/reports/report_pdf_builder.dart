import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_models.dart';
import 'report_utils.dart';

class ReportPdfBuilder {
  ReportPdfBuilder._();

  static const String _logoAsset = 'assets/images/brand/orbi-logo-v2-black.png';

  // Modern Orbi/slate palette. Keep report pages light and avoid full-page
  // color layers because some Android PDF previews render them as solid blocks.
  static const PdfColor _darkSlate = PdfColor.fromInt(0xFF1A2332);
  static const PdfColor _slate = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _brandAccent = PdfColor.fromInt(0xFF1A2332);
  static const PdfColor _brandSoft = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _paper = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _slatePage = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _slateLine = PdfColor.fromInt(0xFFE2E8F0);
  // ────────────────────────────────────────────────────────────────

  static Uint8List? _logoBytesCache;
  static pw.ThemeData? _themeCache;

  static Future<Uint8List> build(
    Map<String, dynamic> report, {
    required String title,
    required bool sw,
  }) async {
    debugPrint('ReportPdfBuilder.v5.white-background: building $title report');
    final doc = pw.Document();
    final pdfTheme = await _pdfTheme();
    final logoBytes = await _loadLogoBytes();
    final generatedAt = ReportUtils.formatDateTime(report['generatedAt']);
    final rangeStart = ReportUtils.formatDateTime(
      report.valueAt(['range', 'start']),
    );
    final rangeEnd = ReportUtils.formatDateTime(
      report.valueAt(['range', 'end']),
    );
    final summary = ReportUtils.from(report['summary']);
    final members = ReportUtils.asList(report['members']);
    final transactions = ReportUtils.asList(report['transactions']);
    final reportType = _friendlyReportType(report['report_type'], sw: sw);
    final resource = _extractResource(report, fallbackTitle: title, sw: sw);
    final summaryRows = _buildSummaryRows(report, summary, sw: sw);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          theme: pdfTheme,
          buildBackground: (_) => _buildWhitePageBackground(),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _slateLine, width: 0.7),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                sw
                    ? 'ORBI ripoti ya ukaguzi • Imetengenezwa $generatedAt'
                    : 'ORBI audit datasheet • Generated $generatedAt',
                style: pw.TextStyle(fontSize: 8, color: _slate),
              ),
              pw.Text(
                sw
                    ? 'Ukurasa ${context.pageNumber} / ${context.pagesCount}'
                    : 'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: _slate),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildHeader(
            title: title,
            reportType: reportType,
            resourceLabel: resource.label,
            resourceName: resource.name,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            generatedAt: generatedAt,
            logoBytes: logoBytes,
            sw: sw,
          ),
          pw.SizedBox(height: 18),
          _buildSummaryCards(summaryRows),
          pw.SizedBox(height: 18),
          _buildSectionTitle(sw ? 'Muhtasari' : 'Summary details'),
          _buildKeyValueTable(
            summaryRows,
            headers: [sw ? 'Kipengele' : 'Metric', sw ? 'Thamani' : 'Value'],
          ),
          if (members.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle(sw ? 'Wanachama' : 'Members'),
            _buildTable(
              headers: [
                sw ? 'Mwanachama' : 'Member',
                sw ? 'Wajibu' : 'Role',
                sw ? 'Kipindi hiki' : 'This period',
                sw ? 'Jumla sasa' : 'Current total',
              ],
              rows: members.map((member) {
                final user = ReportUtils.from(member['users']);
                return [
                  ReportUtils.firstText([
                    user['full_name'],
                    user['email'],
                    user['phone'],
                    member['user_id'],
                  ]),
                  _friendlyRole(member['role'], sw: sw),
                  ReportUtils.displayMoney(
                    member['period_spent_amount'] ??
                        member['period_contributed_amount'] ??
                        member['period_net_amount'] ??
                        0,
                    currency: resource.currency,
                  ),
                  ReportUtils.displayMoney(
                    member['spent_amount'] ??
                        member['contributed_amount'] ??
                        member['member_limit'] ??
                        member['contribution_target'] ??
                        0,
                  ),
                ];
              }).toList(),
            ),
          ],
          if (transactions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildSectionTitle(
              sw ? 'Historia ya miamala' : 'Transaction history',
            ),
            _buildTable(
              headers: [
                sw ? 'Tarehe' : 'Date',
                sw ? 'Kutoka' : 'From',
                sw ? 'Kwenda' : 'To',
                sw ? 'Kitendo' : 'Activity',
                sw ? 'Kiasi' : 'Amount',
                sw ? 'Salio baada' : 'Balance after',
                sw ? 'Hali' : 'Status',
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(1.15),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.0),
                5: const pw.FlexColumnWidth(1.1),
                6: const pw.FlexColumnWidth(0.9),
              },
              rows: transactions.take(80).map((transaction) {
                return [
                  ReportUtils.formatDateTime(
                    transaction['created_at'] ?? transaction['date'],
                  ),
                  _senderLabel(transaction),
                  _recipientLabel(transaction),
                  _friendlyActivity(transaction, sw: sw),
                  ReportUtils.displayMoney(
                    transaction['amount'],
                    currency: transaction['currency'] ?? resource.currency,
                  ),
                  _balanceAfter(transaction, currency: resource.currency),
                  _friendlyStatus(transaction['status'], sw: sw),
                ];
              }).toList(),
            ),
            if (transactions.length > 80)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  sw
                      ? 'Inaonyesha miamala 80 ya kwanza kati ya ${transactions.length}.'
                      : 'Showing first 80 of ${transactions.length} transactions.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ─── Private builders ──────────────────────────────────────────────

  static pw.Widget _buildWhitePageBackground() {
    return pw.FullPage(ignoreMargins: true, child: pw.Container(color: _paper));
  }

  static Future<pw.ThemeData> _pdfTheme() async {
    if (_themeCache != null) return _themeCache!;
    try {
      final regular = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _themeCache = pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (error) {
      debugPrint('ReportPdfBuilder: bundled font load failed: $error');
      _themeCache = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
    return _themeCache!;
  }

  static Future<Uint8List?> _loadLogoBytes() async {
    if (_logoBytesCache != null) return _logoBytesCache;
    try {
      final data = await rootBundle.load(_logoAsset);
      final raw = data.buffer.asUint8List();
      final sanitized = await _sanitizeImage(raw);
      _logoBytesCache = sanitized;
      if (_logoBytesCache == null) {
        debugPrint(
          'ReportPdfBuilder: logo image failed sanitize, omitting image',
        );
      }
      return _logoBytesCache;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _sanitizeImage(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    if (kIsWeb) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return null;
      return bd.buffer.asUint8List();
    } catch (e, st) {
      debugPrint('ReportPdfBuilder: image sanitize failed: $e\n$st');
      return null;
    }
  }

  static pw.Widget _buildHeader({
    required String title,
    required String reportType,
    required String resourceLabel,
    required String resourceName,
    required String rangeStart,
    required String rangeEnd,
    required String generatedAt,
    required Uint8List? logoBytes,
    required bool sw,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _slateLine, width: 0.9),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 145,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _slatePage,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: _slateLine, width: 0.7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoBytes != null)
                  pw.Image(
                    pw.MemoryImage(logoBytes),
                    width: 105,
                    height: 36,
                    fit: pw.BoxFit.contain,
                  )
                else
                  pw.Text(
                    'Orbi',
                    style: pw.TextStyle(
                      color: _darkSlate,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.SizedBox(height: 7),
                pw.Text(
                  sw ? 'RIPOTI SALAMA' : 'SECURE REPORT',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _slate,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _brandSoft,
                    borderRadius: pw.BorderRadius.circular(999),
                    border: pw.Border.all(color: _brandAccent, width: 0.7),
                  ),
                  child: pw.Text(
                    reportType,
                    style: pw.TextStyle(
                      color: _brandAccent,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  title,
                  maxLines: 2,
                  style: pw.TextStyle(
                    color: _darkSlate,
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  sw
                      ? 'Historia ya miamala na shughuli muhimu kwa ukaguzi wa uwazi.'
                      : 'Transaction history and key activity for transparent audit.',
                  maxLines: 2,
                  style: pw.TextStyle(
                    color: _slate,
                    fontSize: 9.5,
                    lineSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: _miniMeta(resourceLabel, resourceName)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: _miniMeta(
                        sw ? 'Kipindi' : 'Period',
                        '$rangeStart\n$rangeEnd',
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: _miniMeta(
                        sw ? 'Imetengenezwa' : 'Generated',
                        generatedAt,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniMeta(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.all(7),
    decoration: pw.BoxDecoration(
      color: _slatePage,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: _slateLine, width: 0.7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          maxLines: 1,
          style: pw.TextStyle(
            color: _brandAccent,
            fontSize: 6.3,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.65,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          maxLines: 2,
          style: pw.TextStyle(
            color: _darkSlate,
            fontSize: 7.8,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 1.2,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _buildSummaryCards(List<List<String>> rows) {
    final cards = rows.take(6).toList();
    if (cards.isEmpty) return pw.SizedBox.shrink();
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cards.map((row) {
        return pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _paper,
            borderRadius: pw.BorderRadius.circular(16),
            border: pw.Border.all(color: _slateLine),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 26,
                height: 3,
                decoration: pw.BoxDecoration(
                  color: _brandAccent,
                  borderRadius: pw.BorderRadius.circular(999),
                ),
              ),
              pw.SizedBox(height: 9),
              pw.Text(
                row.first,
                style: pw.TextStyle(color: _slate, fontSize: 8),
                maxLines: 1,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                row.length > 1 ? row[1] : '-',
                style: pw.TextStyle(
                  color: _darkSlate,
                  fontSize: 14.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 1,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildSectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 9),
    child: pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: pw.BoxDecoration(
            color: _brandAccent,
            borderRadius: pw.BorderRadius.circular(999),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          text,
          style: pw.TextStyle(
            color: _darkSlate,
            fontSize: 14.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _buildKeyValueTable(
    List<List<String>> rows, {
    required List<String> headers,
  }) => _buildTable(
    headers: headers,
    rows: rows.isEmpty
        ? const [
            ['-', '-'],
          ]
        : rows,
  );

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _slateLine, width: 0.8),
      ),
      child: pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        columnWidths: columnWidths,
        headerStyle: pw.TextStyle(
          color: _brandAccent,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        cellStyle: pw.TextStyle(color: _darkSlate, fontSize: 8.2),
        cellAlignments: const {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerLeft,
        },
        headerDecoration: pw.BoxDecoration(
          color: _brandSoft,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        oddRowDecoration: pw.BoxDecoration(color: _slatePage),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _slateLine, width: 0.5),
          bottom: pw.BorderSide(color: _slateLine, width: 0.7),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  static ReportResource _extractResource(
    Map<String, dynamic> report, {
    required String fallbackTitle,
    required bool sw,
  }) {
    final pot = ReportUtils.from(report['pot']);
    if (pot.isNotEmpty) {
      return ReportResource(
        label: sw ? 'Fungu' : 'Fungu',
        name: ReportUtils.firstText([pot['name'], fallbackTitle]),
        currency: ReportUtils.firstText([pot['currency'], 'TZS']),
      );
    }
    final budget = ReportUtils.from(report['budget']);
    if (budget.isNotEmpty) {
      return ReportResource(
        label: sw ? 'Mezani' : 'Mezani',
        name: ReportUtils.firstText([budget['name'], fallbackTitle]),
        currency: ReportUtils.firstText([budget['currency'], 'TZS']),
      );
    }
    return ReportResource(
      label: sw ? 'Akaunti' : 'Account',
      name: fallbackTitle,
      currency: ReportUtils.firstText([
        ReportUtils.from(report['summary'])['currency'],
        'TZS',
      ]),
    );
  }

  static String _friendlyReportType(dynamic value, {required bool sw}) {
    final raw = value?.toString().toUpperCase() ?? '';
    if (raw.contains('SHARED_POT')) {
      return sw ? 'Ripoti ya Fungu' : 'Fungu report';
    }
    if (raw.contains('SHARED_BUDGET')) {
      return sw ? 'Ripoti ya Mezani' : 'Mezani report';
    }
    if (raw.contains('TRANSACTION')) {
      return sw ? 'Ripoti ya miamala' : 'Transaction report';
    }
    return sw ? 'Ripoti' : 'Report';
  }

  static List<List<String>> _buildSummaryRows(
    Map<String, dynamic> report,
    Map<String, dynamic> summary, {
    required bool sw,
  }) {
    final resource = _extractResource(report, fallbackTitle: 'ORBI', sw: sw);
    final type = report['report_type']?.toString().toUpperCase() ?? '';
    final entries = <List<String>>[];

    void add(String key, String en, String swText, {bool money = false}) {
      if (!summary.containsKey(key)) return;
      entries.add([
        sw ? swText : en,
        money
            ? ReportUtils.displayMoney(
                summary[key],
                currency: resource.currency,
              )
            : ReportUtils.displayValue(summary[key]),
      ]);
    }

    if (type.contains('SHARED_POT')) {
      add(
        'current_amount',
        'Current Fungu balance',
        'Salio la Fungu',
        money: true,
      );
      add(
        'total_contributed',
        'Contributed this period',
        'Michango kipindi hiki',
        money: true,
      );
      add(
        'total_withdrawn',
        'Withdrawn this period',
        'Iliyotolewa kipindi hiki',
        money: true,
      );
      add('net_movement', 'Net movement', 'Mabadiliko halisi', money: true);
      add('transaction_count', 'Transactions', 'Miamala');
      add('member_count', 'Members', 'Wanachama');
      add('target_amount', 'Target amount', 'Lengo la kiasi', money: true);
      add('audit_entry_count', 'Audit entries', 'Kumbukumbu za ukaguzi');
      return entries;
    }

    if (type.contains('SHARED_BUDGET')) {
      add('budget_limit', 'Budget limit', 'Kikomo cha bajeti', money: true);
      add('remaining_amount', 'Remaining amount', 'Kilichobaki', money: true);
      add(
        'total_spent',
        'Spent this period',
        'Matumizi kipindi hiki',
        money: true,
      );
      add('transaction_count', 'Transactions', 'Miamala');
      add('member_count', 'Members', 'Wanachama');
      return entries;
    }

    add('total_in', 'Money in', 'Pesa zilizoingia', money: true);
    add('total_out', 'Money out', 'Pesa zilizotoka', money: true);
    add('net', 'Net movement', 'Mabadiliko halisi', money: true);
    add('transaction_count', 'Transactions', 'Miamala');
    return entries.isEmpty
        ? summary.entries
              .where((entry) => entry.value is! Map && entry.value is! List)
              .map(
                (entry) => [
                  _fallbackLabel(entry.key, sw: sw),
                  ReportUtils.displayValue(entry.value),
                ],
              )
              .toList()
        : entries;
  }

  static String _friendlyActivity(
    Map<String, dynamic> transaction, {
    required bool sw,
  }) {
    final label = transaction['activity_label']?.toString().trim();
    if (label != null && label.isNotEmpty) {
      if (label.toLowerCase().contains('withdraw')) {
        return sw ? 'Utoaji kutoka Fungu' : 'Withdrawal from Fungu';
      }
      if (label.toLowerCase().contains('contribution')) {
        return sw ? 'Mchango kwenye Fungu' : 'Contribution to Fungu';
      }
      return label;
    }
    final raw = [
      transaction['allocation_source'],
      transaction['description'],
      transaction['type'],
      transaction['note'],
      transaction['merchant_name'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
    if (raw.contains('shared_pot') || raw.contains('pot')) {
      if (raw.contains('withdraw')) {
        return sw ? 'Utoaji kutoka Fungu' : 'Withdrawal from Fungu';
      }
      return sw ? 'Mchango kwenye Fungu' : 'Contribution to Fungu';
    }
    if (raw.contains('shared_budget') || raw.contains('budget')) {
      return sw ? 'Matumizi ya Mezani' : 'Mezani spend';
    }
    if (raw.contains('deposit') || raw.contains('credit')) {
      return sw ? 'Pesa zimeingia' : 'Money received';
    }
    if (raw.contains('withdraw') || raw.contains('debit')) {
      return sw ? 'Pesa zimetoka' : 'Money sent';
    }
    return ReportUtils.firstText([
      transaction['description'],
      transaction['note'],
      transaction['merchant_name'],
      sw ? 'Muamala' : 'Transaction',
    ]);
  }

  static String _recipientLabel(Map<String, dynamic> transaction) {
    final receiver = ReportUtils.from(
      transaction['receiver'] ?? transaction['recipient'],
    );
    final counterparty = ReportUtils.from(transaction['counterparty']);
    final beneficiary = ReportUtils.from(transaction['beneficiary']);
    final user = ReportUtils.from(transaction['users'] ?? transaction['user']);
    final destinationWallet = ReportUtils.from(
      transaction['destination_wallet'] ??
          transaction['destinationWallet'] ??
          transaction['target_wallet'] ??
          transaction['targetWallet'] ??
          transaction['to_wallet'] ??
          transaction['toWallet'] ??
          transaction['wallet'],
    );
    final label = ReportUtils.firstText([
      destinationWallet['wallet_name'],
      destinationWallet['name'],
      destinationWallet['display_name'],
      transaction['destination_wallet_name'],
      transaction['destinationWalletName'],
      transaction['target_wallet_name'],
      transaction['targetWalletName'],
      transaction['to_wallet_name'],
      transaction['toWalletName'],
      transaction['wallet_name'],
      receiver['full_name'],
      receiver['display_name'],
      receiver['name'],
      counterparty['full_name'],
      counterparty['display_name'],
      counterparty['name'],
      beneficiary['full_name'],
      beneficiary['display_name'],
      beneficiary['name'],
      transaction['recipient_name'],
      transaction['receiver_name'],
      transaction['beneficiary_name'],
      transaction['target_name'],
      transaction['to_name'],
      transaction['counterparty_name'],
      transaction['recipient_phone'],
      transaction['receiver_phone'],
      transaction['beneficiary_phone'],
      transaction['recipient_email'],
      transaction['receiver_email'],
      transaction['beneficiary_email'],
      transaction['recipient_orbi_id'],
      transaction['receiver_orbi_id'],
      transaction['target_orbi_id'],
      user['full_name'],
      user['display_name'],
      user['name'],
      user['email'],
      user['phone'],
      transaction['recipient_customer_id'],
      transaction['receiver_customer_id'],
      transaction['target_customer_id'],
      transaction['member_user_id'],
      transaction['user_id'],
    ]);
    return _friendlyMovementLabel(
      transaction,
      _hideRawUuid(label),
      toSide: true,
    );
  }

  static String _senderLabel(Map<String, dynamic> transaction) {
    final sender = ReportUtils.from(
      transaction['sender'] ?? transaction['source'],
    );
    final account = ReportUtils.from(transaction['source_account']);
    final user = ReportUtils.from(transaction['users'] ?? transaction['user']);
    final sourceWallet = ReportUtils.from(
      transaction['source_wallet'] ??
          transaction['sourceWallet'] ??
          transaction['from_wallet'] ??
          transaction['fromWallet'],
    );
    final label = ReportUtils.firstText([
      sourceWallet['wallet_name'],
      sourceWallet['name'],
      sourceWallet['display_name'],
      transaction['source_wallet_name'],
      transaction['sourceWalletName'],
      transaction['from_wallet_name'],
      transaction['fromWalletName'],
      sender['full_name'],
      sender['display_name'],
      sender['name'],
      account['name'],
      account['display_name'],
      transaction['sender_name'],
      transaction['source_name'],
      transaction['from_name'],
      transaction['payer_name'],
      transaction['sender_phone'],
      transaction['source_phone'],
      transaction['from_phone'],
      transaction['sender_email'],
      transaction['source_email'],
      transaction['sender_orbi_id'],
      transaction['source_orbi_id'],
      user['full_name'],
      user['display_name'],
      user['name'],
      user['email'],
      user['phone'],
      transaction['sender_customer_id'],
      transaction['source_customer_id'],
      transaction['from_customer_id'],
      transaction['user_id'],
    ]);
    return _friendlyMovementLabel(
      transaction,
      _hideRawUuid(label),
      toSide: false,
    );
  }

  static String _friendlyMovementLabel(
    Map<String, dynamic> transaction,
    String current, {
    required bool toSide,
  }) {
    final normalized = current.trim().toLowerCase();
    final shouldReplace =
        current == '-' ||
        normalized.contains('external recipient') ||
        normalized == 'external' ||
        normalized == 'n/a';
    if (!shouldReplace) return current;

    final raw = [
      transaction['allocation_source'],
      transaction['money_state'],
      transaction['moneyState'],
      transaction['wallet_type'],
      transaction['walletType'],
      transaction['transaction_type'],
      transaction['type'],
      transaction['category'],
      transaction['description'],
      transaction['note'],
      transaction['reference'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');

    if (raw.contains('escrow') || raw.contains('safe')) {
      return toSide ? 'PaySafe Escrow Wallet' : 'Operating Wallet';
    }
    if (raw.contains('shared_pot') || raw.contains('pot')) {
      return toSide ? 'Fungu Wallet' : 'Operating Wallet';
    }
    if (raw.contains('shared_budget') || raw.contains('budget')) {
      return toSide ? 'Mezani Wallet' : 'Operating Wallet';
    }
    if (raw.contains('goal') || raw.contains('saving')) {
      return toSide ? 'Goal Wallet' : 'Operating Wallet';
    }
    if (raw.contains('lock') || raw.contains('allocated')) {
      return toSide ? 'Allocated Wallet' : 'Operating Wallet';
    }
    return current;
  }

  static String _balanceAfter(
    Map<String, dynamic> transaction, {
    required String currency,
  }) {
    final balance = ReportUtils.firstNonNull([
      transaction['balance_after'],
      transaction['balanceAfter'],
      transaction['running_balance'],
      transaction['runningBalance'],
      transaction['post_balance'],
      transaction['postBalance'],
      transaction['available_balance_after'],
      transaction['availableBalanceAfter'],
      transaction.valueAt(['metadata', 'balance_after']),
      transaction.valueAt(['metadata', 'balanceAfter']),
      transaction.valueAt(['ledger', 'balance_after']),
      transaction.valueAt(['ledger', 'post_balance']),
    ]);
    if (balance == null) return '-';
    return ReportUtils.displayMoney(balance, currency: currency);
  }

  static String _hideRawUuid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    final looksLikeUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(trimmed);
    return looksLikeUuid ? '-' : trimmed;
  }

  static String _friendlyRole(dynamic value, {required bool sw}) {
    switch (value?.toString().toUpperCase()) {
      case 'OWNER':
        return sw ? 'Mmiliki' : 'Owner';
      case 'MANAGER':
        return sw ? 'Msimamizi' : 'Manager';
      case 'VIEWER':
        return sw ? 'Mtazamaji' : 'Viewer';
      case 'SPENDER':
        return sw ? 'Mtumiaji' : 'Spender';
      case 'CONTRIBUTOR':
        return sw ? 'Mchangiaji' : 'Contributor';
      default:
        return sw ? 'Mwanachama' : 'Member';
    }
  }

  static String _friendlyStatus(dynamic value, {required bool sw}) {
    switch (value?.toString().toUpperCase()) {
      case 'COMPLETED':
      case 'SETTLED':
        return sw ? 'Imekamilika' : 'Completed';
      case 'PENDING':
      case 'PROCESSING':
        return sw ? 'Inasubiri' : 'Pending';
      case 'FAILED':
        return sw ? 'Imeshindikana' : 'Failed';
      case 'CANCELLED':
        return sw ? 'Imeghairiwa' : 'Cancelled';
      case 'REVERSED':
      case 'REFUNDED':
        return sw ? 'Imerejeshwa' : 'Reversed';
      default:
        return ReportUtils.displayValue(value);
    }
  }

  static String _fallbackLabel(String key, {required bool sw}) {
    final spaced = key.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return '-';
    if (sw) return spaced;
    return spaced
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
