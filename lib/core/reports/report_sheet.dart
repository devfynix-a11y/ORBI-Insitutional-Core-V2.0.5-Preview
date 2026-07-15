import 'dart:typed_data';
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';

import '../theme/orbi_theme.dart';
import '../widgets/orbi_logo.dart';
import 'report_image_pdf_builder.dart';
import 'report_models.dart';
import 'report_utils.dart';

class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.filePrefix,
    required this.loadReport,
  });

  final String title;
  final String subtitle;
  final String filePrefix;
  final Future<Map<String, dynamic>> Function(ReportRange range) loadReport;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  static const double _printPreviewWidth = 1080;
  final GlobalKey _previewKey = GlobalKey();
  ReportRange _selectedRange = ReportRange.month;
  Map<String, dynamic>? _report;
  bool _busy = false;
  bool _printBusy = false;
  bool _shareBusy = false;
  String? _error;

  bool get _sw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _sw ? sw : en;

  Future<void> _loadReport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.loadReport(_selectedRange);
      if (!mounted) return;
      final txs = ReportUtils.asList(report['transactions']);
      if (txs.isNotEmpty) {
        debugPrint(
          'ReportSheet.destination.debug keys=${txs.first.keys.toList()}',
        );
      }
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _buildPdfFromPreview() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Report preview is not ready for capture.');
    }
    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(
      format: dart_ui.ImageByteFormat.png,
    );
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not capture report preview.');
    }
    return OrbiReportImagePdfBuilder.build(
      reportPngBytes: byteData.buffer.asUint8List(),
    );
  }

  Future<void> _runPdfAction({required bool share}) async {
    if (_report == null || _printBusy || _shareBusy) return;
    setState(() {
      _error = null;
      if (share) {
        _shareBusy = true;
      } else {
        _printBusy = true;
      }
    });
    try {
      final pdf = await _buildPdfFromPreview();
      final range = ReportUtils.stringAt(_report!, [
        'range',
        'key',
      ], fallback: _selectedRange.key);
      final safeRange = range.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = '${widget.filePrefix}_$safeRange.pdf';
      if (share) {
        await Printing.sharePdf(bytes: pdf, filename: filename);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => pdf);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _printBusy = false;
          _shareBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ui.sheet,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ui.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(ui),
            const SizedBox(height: 16),
            _buildPicker(ui),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 14),
            if (_report == null)
              _buildIntro(ui)
            else
              Flexible(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: RepaintBoundary(
                      key: _previewKey,
                      child: SizedBox(
                        width: _printPreviewWidth,
                        child: _ReportPreviewCard(
                          report: _report!,
                          title: widget.title,
                          sw: _sw,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _buildActions(ui),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OrbiUiTokens ui) {
    return Row(
      children: [
        const OrbiLogoV2(width: 92),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: ui.iconMuted),
        ),
      ],
    );
  }

  Widget _buildPicker(OrbiUiTokens ui) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: ui.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          style: TextStyle(
            color: ui.textMuted,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<ReportRange>(
          segments: ReportRange.values.map((range) {
            return ButtonSegment<ReportRange>(
              value: range,
              label: Text(_t(range.labelEn, range.labelSw)),
              icon: Icon(range.icon, size: 18),
            );
          }).toList(),
          selected: {_selectedRange},
          onSelectionChanged: _busy || _printBusy || _shareBusy
              ? null
              : (Set<ReportRange> selection) {
                  setState(() {
                    _selectedRange = selection.first;
                    _report = null;
                  });
                },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return ui.successSoft;
              }
              return ui.card;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return ui.success;
              return ui.textMuted;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? ui.success
                    : ui.border,
                width: 1.4,
              );
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntro(OrbiUiTokens ui) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.border),
      ),
      child: Text(
        _t(
          'Choose a period, then preview the report before printing or sharing.',
          'Chagua kipindi, kisha kagua ripoti kabla ya kuchapisha au kushiriki.',
        ),
        style: TextStyle(
          color: ui.textMuted,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActions(OrbiUiTokens ui) {
    if (_report == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _loadReport,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.preview_rounded),
          label: Text(
            _busy ? _t('Preparing...', 'Inaandaa...') : _t('Preview', 'Kagua'),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _printBusy || _shareBusy
                ? null
                : () => _runPdfAction(share: false),
            icon: _printBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: Text(
              _printBusy
                  ? _t('Preparing...', 'Inaandaa...')
                  : _t('Print', 'Chapisha'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _printBusy || _shareBusy
                ? null
                : () => _runPdfAction(share: true),
            icon: _shareBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(
              _shareBusy
                  ? _t('Preparing...', 'Inaandaa...')
                  : _t('Share', 'Shiriki'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportPreviewCard extends StatelessWidget {
  const _ReportPreviewCard({
    required this.report,
    required this.title,
    required this.sw,
  });

  final Map<String, dynamic> report;
  final String title;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final transactions = ReportUtils.asList(report['transactions']);
    final generatedAt = ReportUtils.formatDateTime(report['generatedAt']);
    final rangeStart = ReportUtils.formatDateTime(
      report.valueAt(['range', 'start']),
    );
    final rangeEnd = ReportUtils.formatDateTime(
      report.valueAt(['range', 'end']),
    );
    final currency = ReportUtils.firstText([
      ReportUtils.from(report['summary'])['currency'],
      'TZS',
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OrbiLogoV2(width: 128, color: Colors.black),
              const Spacer(),
              _pill(sw ? 'Ripoti' : 'Report'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A2332),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sw
                ? 'Kipindi: $rangeStart - $rangeEnd'
                : 'Period: $rangeStart - $rangeEnd',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sw ? 'Imetengenezwa: $generatedAt' : 'Generated: $generatedAt',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 18),
          _summaryStrip(currency),
          const SizedBox(height: 18),
          Text(
            sw ? 'Historia ya miamala' : 'Transaction history',
            style: const TextStyle(
              color: Color(0xFF1A2332),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _transactionTable(transactions, currency),
        ],
      ),
    );
  }

  Widget _summaryStrip(String currency) {
    final summary = ReportUtils.from(report['summary']);
    final items = <MapEntry<String, String>>[
      MapEntry(
        sw ? 'Miamala' : 'Transactions',
        ReportUtils.displayValue(
          summary['transaction_count'] ?? summary['count'] ?? 0,
        ),
      ),
      MapEntry(
        sw ? 'Pesa zilizoingia' : 'Money in',
        ReportUtils.displayMoney(summary['total_in'], currency: currency),
      ),
      MapEntry(
        sw ? 'Pesa zilizotoka' : 'Money out',
        ReportUtils.displayMoney(summary['total_out'], currency: currency),
      ),
    ];
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF1A2332),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _transactionTable(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    final rows = transactions.take(30).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.15),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.35),
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(1.05),
          5: FlexColumnWidth(1.0),
        },
        children: [
          _row([
            sw ? 'Tarehe' : 'Date',
            sw ? 'Kutoka' : 'From',
            sw ? 'Kwenda' : 'To',
            sw ? 'Kitendo' : 'Activity',
            sw ? 'Kiasi' : 'Amount',
            sw ? 'Hali' : 'Status',
          ], header: true),
          ...rows.map((tx) {
            return _row([
              ReportUtils.formatDateTime(tx['created_at'] ?? tx['date']),
              _cleanName(
                tx['source_wallet_name'] ??
                    tx['from_name'] ??
                    tx['sender_name'] ??
                    'Orbi',
              ),
              _destinationName(tx),
              _activity(tx),
              ReportUtils.displayMoney(
                tx['amount'],
                currency: tx['currency'] ?? currency,
              ),
              _status(tx['status']),
            ]);
          }),
        ],
      ),
    );
  }

  TableRow _row(List<String> cells, {bool header = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: header ? const Color(0xFFEAF7F8) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.7),
        ),
      ),
      children: cells.indexed
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Text(
                entry.$2,
                textAlign: header ? TextAlign.center : TextAlign.left,
                maxLines: header || entry.$1 != 3 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                softWrap: !header && entry.$1 == 3,
                style: TextStyle(
                  color: header
                      ? const Color(0xFF0F7C86)
                      : const Color(0xFF1A2332),
                  fontSize: header ? 12 : 11,
                  fontWeight: header ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFECEE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0F7C86),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  String _activity(Map<String, dynamic> tx) {
    return ReportUtils.firstText([
      tx['activity_label'],
      tx['description'],
      tx['note'],
      sw ? 'Muamala' : 'Transaction',
    ]);
  }

  String _destinationName(Map<String, dynamic> tx) {
    final receiver = ReportUtils.from(tx['receiver'] ?? tx['recipient']);
    final counterparty = ReportUtils.from(tx['counterparty']);
    final beneficiary = ReportUtils.from(tx['beneficiary']);
    final metadata = ReportUtils.from(tx['metadata']);
    final ledger = ReportUtils.from(tx['ledger']);
    final movement = ReportUtils.from(tx['movement']);
    final destinationWallet = ReportUtils.from(
      tx['destination_wallet'] ??
          tx['destinationWallet'] ??
          tx['target_wallet'] ??
          tx['targetWallet'] ??
          tx['to_wallet'] ??
          tx['toWallet'],
    );
    final destination = _cleanName(
      tx['destination_display_name'] ??
          tx['destinationDisplayName'] ??
          tx['destination_name'] ??
          tx['destinationName'] ??
          tx['counterparty_display_name'] ??
          tx['counterpartyDisplayName'] ??
          tx['recipient_display_name'] ??
          tx['recipientDisplayName'] ??
          tx['receiver_display_name'] ??
          tx['receiverDisplayName'] ??
          tx['destination_wallet_name'] ??
          tx['destinationWalletName'] ??
          tx['target_wallet_name'] ??
          tx['targetWalletName'] ??
          tx['to_wallet_name'] ??
          tx['toWalletName'] ??
          tx['wallet_name'] ??
          destinationWallet['wallet_name'] ??
          destinationWallet['name'] ??
          destinationWallet['display_name'] ??
          tx['to_name'] ??
          tx['recipient_name'] ??
          tx['receiver_name'] ??
          tx['beneficiary_name'] ??
          tx['target_name'] ??
          tx['counterparty_name'] ??
          tx['merchant_name'] ??
          receiver['full_name'] ??
          receiver['display_name'] ??
          receiver['name'] ??
          counterparty['full_name'] ??
          counterparty['display_name'] ??
          counterparty['name'] ??
          beneficiary['full_name'] ??
          beneficiary['display_name'] ??
          beneficiary['name'] ??
          metadata['destination_display_name'] ??
          metadata['destination_name'] ??
          metadata['recipient_name'] ??
          metadata['receiver_name'] ??
          metadata['counterparty_name'] ??
          metadata['merchant_name'] ??
          metadata['to_name'] ??
          ledger['destination_wallet_name'] ??
          ledger['counterparty_name'] ??
          ledger['to_name'] ??
          movement['destination_name'] ??
          movement['counterparty_name'] ??
          movement['merchant_name'],
    );
    if (destination != '-') return destination;

    final raw = [
      tx['allocation_source'],
      tx['money_state'],
      tx['moneyState'],
      tx['wallet_type'],
      tx['walletType'],
      tx['transaction_type'],
      tx['type'],
      tx['category'],
      tx['description'],
      tx['note'],
      tx['reference'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');

    if (raw.contains('escrow') || raw.contains('safe')) {
      return 'PaySafe Escrow Wallet';
    }
    if (raw.contains('shared_pot') || raw.contains('pot')) {
      return 'Fungu Wallet';
    }
    if (raw.contains('shared_budget') || raw.contains('budget')) {
      return 'Mezani Wallet';
    }
    if (raw.contains('goal') || raw.contains('saving')) {
      return 'Goal Wallet';
    }
    if (raw.contains('lock') || raw.contains('allocated')) {
      return 'Allocated Wallet';
    }
    if (raw.contains('deposit') || raw.contains('credit')) {
      return 'Operating Wallet';
    }
    return sw ? 'Akaunti ya ORBI' : 'ORBI Wallet';
  }

  String _status(dynamic value) {
    final raw = value?.toString().toLowerCase() ?? '';
    if (raw.contains('fail')) return sw ? 'Imeshindikana' : 'Failed';
    if (raw.contains('pending')) return sw ? 'Inasubiri' : 'Pending';
    if (raw.contains('cancel')) return sw ? 'Imeghairiwa' : 'Cancelled';
    return sw ? 'Imekamilika' : 'Completed';
  }

  String _cleanName(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';
    if (RegExp(r'^[0-9a-fA-F-]{20,}$').hasMatch(text)) return '-';
    return text;
  }
}
