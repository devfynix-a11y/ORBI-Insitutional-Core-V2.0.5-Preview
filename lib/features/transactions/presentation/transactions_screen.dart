import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/theme/orbi_card_styles.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_brand_hero_card.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../auth/state/auth_controller.dart';
import '../../notifications/state/notification_controller.dart';
import '../data/transaction_receipt_service.dart';
import '../../wallet/data/wallet_service.dart';

class TransactionsScreen extends StatefulWidget {
  final String initialMoneyState;

  const TransactionsScreen({
    super.key,
    this.initialMoneyState = _TransactionsScreenState._allMoneyStates,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final WalletService _walletService = WalletService();
  final TransactionReceiptService _receiptService = TransactionReceiptService();
  static const String _allMoneyStates = 'all';
  bool _loading = false;
  bool _isOpeningDetails = false;
  String? _error;
  String _selectedMoneyState = _allMoneyStates;
  List<Map<String, dynamic>> _transactions = const [];
  Uint8List? _logoBytesCache;
  Uint8List? _watermarkBytesCache;
  Timer? _realtimeRefreshDebounce;
  StreamSubscription<Map<String, dynamic>>? _transactionUpdateSubscription;

  bool _canReportTransferIssue(Map<String, dynamic> tx) {
    final composite = [
      tx['type'],
      tx['transaction_type'],
      tx['kind'],
      tx['category'],
      tx['description'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
    return composite.contains('transfer');
  }

  Future<void> _reportIncorrectTransfer(Map<String, dynamic> tx) async {
    final ui = OrbiTheme.uiOf(context);
    final isSwahili =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final txId = _pickString([tx['id'], tx['transaction_id'], tx['reference']]);
    if (txId.isEmpty) return;
    final controller = TextEditingController();
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              isSwahili
                  ? 'Ripoti uhamisho usio sahihi'
                  : 'Report incorrect transfer',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSwahili
                      ? 'Tutaupeleka kwenye ukaguzi.'
                      : 'This transfer will go for review.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isSwahili ? 'Sababu' : 'Reason',
                    hintText: isSwahili
                        ? 'Mfano: nimetuma kwa mpokeaji asiye sahihi'
                        : 'Example: sent to the wrong recipient',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(isSwahili ? 'Ghairi' : 'Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ui.warning),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(isSwahili ? 'Wasilisha' : 'Submit'),
              ),
            ],
          );
        },
      );
      if (approved != true) return;
      final reason = controller.text.trim();
      if (reason.length < 5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSwahili ? 'Weka sababu.' : 'Enter a reason.'),
          ),
        );
        return;
      }
      await _walletService.lockTransaction(txId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSwahili
                ? 'Uhamisho umetumwa kwenye ukaguzi.'
                : 'Transfer sent for review.',
          ),
        ),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingError.from(
              e,
              fallback: isSwahili
                  ? 'Imeshindikana kutuma ombi.'
                  : 'Could not submit request.',
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  PdfPageFormat _receiptPdfPageFormat() {
    return PdfPageFormat.a4.copyWith(
      marginLeft: 24,
      marginRight: 24,
      marginTop: 18,
      marginBottom: 18,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedMoneyState = widget.initialMoneyState;
    _loadTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transactionUpdateSubscription = context
          .read<NotificationController>()
          .balanceUpdates
          .listen(_handleRealtimeEvent);
    });
  }

  @override
  void dispose() {
    _realtimeRefreshDebounce?.cancel();
    _transactionUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (_loading) return;
    final token = await context.read<AuthController>().getValidAccessToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.transactionsSessionExpiredMessage;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final txs = await _walletService.getWalletTransactions(
        '',
        limit: 50,
        offset: 0,
      );
      txs.sort((a, b) {
        final at = _asDate(
          a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? a['date'],
        );
        final bt = _asDate(
          b['created_at'] ?? b['createdAt'] ?? b['timestamp'] ?? b['date'],
        );
        return bt.compareTo(at);
      });
      if (!mounted) return;
      setState(() => _transactions = txs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserFacingError.from(
          e,
          fallback: AppLocalizations.of(
            context,
          )!.transactionsFetchFailedMessage,
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  DateTime _asDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }

  String _pickString(List<dynamic> values) {
    for (final v in values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  bool _looksLikeUuid(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(v);
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _loadTransactions();
    });
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString().toUpperCase();
    if (type == 'TRANSACTION_UPDATE') {
      final newTx = event['raw'] is Map
          ? Map<String, dynamic>.from(event['raw'] as Map)
          : null;
      if (newTx != null && newTx.isNotEmpty) {
        _addOrUpdateTransaction(newTx);
        return;
      }
    }
    _scheduleRealtimeRefresh();
  }

  void _addOrUpdateTransaction(Map<String, dynamic> tx) {
    if (!mounted) return;
    final txId = _pickString([tx['id'], tx['transaction_id'], tx['reference']]);
    if (txId.isEmpty) {
      _scheduleRealtimeRefresh();
      return;
    }

    final updated = List<Map<String, dynamic>>.from(_transactions);
    final existingIndex = updated.indexWhere(
      (t) =>
          _pickString([
            t['id'],
            t['transaction_id'],
            t['reference'],
          ]).trim().toLowerCase() ==
          txId.trim().toLowerCase(),
    );

    if (existingIndex != -1) {
      updated[existingIndex] = tx;
    } else {
      updated.insert(0, tx);
    }

    updated.sort((a, b) {
      final at = _asDate(
        a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? a['date'],
      );
      final bt = _asDate(
        b['created_at'] ?? b['createdAt'] ?? b['timestamp'] ?? b['date'],
      );
      return bt.compareTo(at);
    });

    setState(() => _transactions = updated);
  }

  String _cleanUserFacing(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (_looksLikeUuid(v)) return '';
    return v;
  }

  String _maskCustomerId(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    if (_looksLikeUuid(v)) return '';

    // Expected shape: FN26-5921-2562 -> FN26-****-2562
    final parts = v.split('-');
    if (parts.length >= 3 &&
        parts[0].toUpperCase().startsWith('FN') &&
        parts[1].isNotEmpty) {
      final first = parts[0];
      final last = parts.last;
      return '$first-****-$last';
    }

    if (v.length <= 6) return v;
    return '${v.substring(0, 3)}****${v.substring(v.length - 3)}';
  }

  bool _isCredit(Map<String, dynamic> tx) {
    final direction = _pickString([tx['direction'], tx['flow']]).toLowerCase();
    final type = _pickString([
      tx['type'],
      tx['transaction_type'],
      tx['kind'],
      tx['category'],
    ]).toLowerCase();
    if (direction == 'in' || direction == 'incoming' || direction == 'credit') {
      return true;
    }
    return type.contains('deposit') ||
        type.contains('refund') ||
        type.contains('salary') ||
        type.contains('income');
  }

  String _currency(Map<String, dynamic> tx) {
    final sessionUser = context.read<AuthController>().session['user'];
    final user = sessionUser is Map
        ? Map<String, dynamic>.from(sessionUser)
        : <String, dynamic>{};
    return resolveCurrencyCode([
      tx['currency'],
      tx['currency_code'],
      user['currency'],
      user['currency_code'],
      user['preferred_currency'],
    ]);
  }

  String get _localeTag {
    final locale = Localizations.localeOf(context);
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }

  String _amountText(Map<String, dynamic> tx) {
    final amount = _asDouble(
      tx['amount'] ??
          tx['value'] ??
          tx['total'] ??
          tx['total_amount'] ??
          tx['net_amount'],
    );
    final isCredit = _isCredit(tx);
    final prefix = isCredit ? '+' : '-';
    final currency = _currency(tx);
    return '$prefix${formatCompactMoney(amount.abs(), currency, locale: _localeTag, compactFrom: kCompactMoneyThreshold)}';
  }

  String _money(Map<String, dynamic> tx, double value) {
    return formatCompactMoney(
      value,
      _currency(tx),
      locale: _localeTag,
      compactFrom: kCompactMoneyThreshold,
    );
  }

  double _baseAmount(Map<String, dynamic> tx) {
    return _asDouble(
      tx['amount'] ??
          tx['value'] ??
          tx['total'] ??
          tx['total_amount'] ??
          tx['net_amount'],
    ).abs();
  }

  double _taxAmount(Map<String, dynamic> tx) {
    final breakdown = tx['breakdown'] is Map
        ? Map<String, dynamic>.from(tx['breakdown'] as Map)
        : <String, dynamic>{};
    return _asDouble(
      tx['tax'] ??
          tx['tax_amount'] ??
          tx['vat'] ??
          tx['levy'] ??
          breakdown['tax'],
    ).abs();
  }

  double _feeAmount(Map<String, dynamic> tx) {
    final breakdown = tx['breakdown'] is Map
        ? Map<String, dynamic>.from(tx['breakdown'] as Map)
        : <String, dynamic>{};
    return _asDouble(
      tx['fee'] ??
          tx['service_fee'] ??
          tx['charge'] ??
          tx['charges'] ??
          breakdown['fee'],
    ).abs();
  }

  String _title(Map<String, dynamic> tx) {
    final l10n = AppLocalizations.of(context)!;
    final name = _pickString([
      tx['counterparty_name'],
      tx['recipient_name'],
      tx['beneficiary_name'],
      tx['sender_name'],
      tx['merchant_name'],
    ]);
    final isCredit = _isCredit(tx);
    if (name.isNotEmpty) {
      return isCredit
          ? l10n.transactionsReceivedFrom(name)
          : l10n.transactionsSentTo(name);
    }

    final fallback = _pickString([
      tx['description'],
      tx['type'],
      tx['transaction_type'],
    ]);
    return fallback.isEmpty ? l10n.transactionsGenericTitle : fallback;
  }

  String _subtitle(Map<String, dynamic> tx) {
    final ref = _pickString([
      tx['reference'],
      tx['transaction_reference'],
      tx['ref'],
      tx['id'],
    ]);
    final status = _pickString([tx['status'], tx['state'], 'completed']);
    final when = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(_asDate(tx['created_at'] ?? tx['createdAt'] ?? tx['timestamp']));
    return '$status • $when • ${ref.isEmpty ? '-' : ref}';
  }

  String _friendlyType(Map<String, dynamic> tx) {
    final l10n = AppLocalizations.of(context)!;
    final raw = _pickString([
      tx['type'],
      tx['transaction_type'],
      tx['kind'],
      tx['category'],
    ]);
    if (raw.isEmpty) return l10n.transactionsGenericTitle;
    return raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  dynamic _lookupTransactionValue(Map<String, dynamic> tx, List<String> keys) {
    final metadata = tx['metadata'] is Map
        ? Map<String, dynamic>.from(tx['metadata'] as Map)
        : <String, dynamic>{};
    final breakdown = tx['breakdown'] is Map
        ? Map<String, dynamic>.from(tx['breakdown'] as Map)
        : <String, dynamic>{};
    for (final key in keys) {
      final direct = tx[key];
      if (direct != null) return direct;
      final nestedMeta = metadata[key];
      if (nestedMeta != null) return nestedMeta;
      final nestedBreakdown = breakdown[key];
      if (nestedBreakdown != null) return nestedBreakdown;
    }
    return null;
  }

  Color? _parseBackendColor(dynamic rawColor) {
    final value = (rawColor ?? '').toString().trim();
    if (value.isEmpty) return null;
    var hex = value;
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  Color _transactionAccent(Map<String, dynamic> tx, OrbiUiTokens ui) {
    final isCredit = _isCredit(tx);
    final direction = _pickString([
      tx['direction'],
      tx['flow'],
      tx['entry_type'],
      tx['entryType'],
    ]).toLowerCase();
    final backend = _parseBackendColor(
      _lookupTransactionValue(tx, [
        'color',
        'accent_color',
        'accentColor',
        'category_color',
        'categoryColor',
      ]),
    );

    final raw = _pickString([
      tx['icon'],
      tx['transaction_type'],
      tx['type'],
      tx['kind'],
      tx['category'],
      tx['description'],
    ]).toLowerCase();
    final looksIncoming =
        isCredit ||
        direction == 'in' ||
        direction == 'incoming' ||
        direction == 'credit' ||
        raw.contains('deposit') ||
        raw.contains('salary') ||
        raw.contains('refund') ||
        raw.contains('received') ||
        raw.contains('incoming');
    final looksOutgoing =
        (!isCredit &&
            (direction == 'out' ||
                direction == 'outgoing' ||
                direction == 'debit')) ||
        raw.contains('withdraw') ||
        raw.contains('send') ||
        raw.contains('sent') ||
        raw.contains('transfer out') ||
        raw.contains('payment');

    if (looksIncoming) return ui.success;
    if (looksOutgoing) return ui.danger;
    if (backend != null) return backend;

    if (raw.contains('deposit') ||
        raw.contains('salary') ||
        raw.contains('refund')) {
      return ui.success;
    }
    if (raw.contains('bill') || raw.contains('utility')) {
      return ui.warning;
    }
    if (raw.contains('escrow') || raw.contains('secure')) {
      return ui.accent;
    }
    if (raw.contains('merchant') || raw.contains('shop')) {
      return const Color(0xFFC76B29);
    }
    if (raw.contains('fx') || raw.contains('swap')) {
      return const Color(0xFF356AE6);
    }
    if (raw.contains('goal') || raw.contains('saving')) {
      return const Color(0xFF6F9A37);
    }
    if (raw.contains('transfer') || raw.contains('send')) {
      return ui.danger;
    }
    final seed = _pickString([
      tx['id'],
      tx['reference'],
      tx['type'],
      tx['category'],
    ]);
    const palette = [
      Color(0xFF2E7D8F),
      Color(0xFF7A5AF8),
      Color(0xFFC76B29),
      Color(0xFF6F9A37),
      Color(0xFF356AE6),
      Color(0xFFB54749),
    ];
    final hash = seed.runes.fold<int>(0, (value, rune) => value * 31 + rune);
    return palette[hash.abs() % palette.length];
  }

  IconData _transactionIcon(Map<String, dynamic> tx, {required bool isCredit}) {
    final raw = _pickString([
      _lookupTransactionValue(tx, ['icon', 'icon_name', 'iconName']),
      tx['transaction_type'],
      tx['type'],
      tx['kind'],
      tx['category'],
      tx['description'],
    ]).toLowerCase();
    if (raw.contains('deposit') || raw.contains('topup')) {
      return Icons.south_west_rounded;
    }
    if (raw.contains('withdraw')) return Icons.north_east_rounded;
    if (raw.contains('bill') || raw.contains('utility')) {
      return Icons.receipt_long_rounded;
    }
    if (raw.contains('merchant') || raw.contains('shop')) {
      return Icons.storefront_outlined;
    }
    if (raw.contains('card')) return Icons.credit_card_rounded;
    if (raw.contains('escrow') || raw.contains('secure')) {
      return Icons.shield_outlined;
    }
    if (raw.contains('goal') || raw.contains('saving')) {
      return Icons.savings_outlined;
    }
    if (raw.contains('refund')) return Icons.undo_rounded;
    if (raw.contains('fx') || raw.contains('swap')) {
      return Icons.currency_exchange_rounded;
    }
    return isCredit ? Icons.call_received_rounded : Icons.call_made_rounded;
  }

  Future<Uint8List?> _loadLogoBytes() async {
    if (_logoBytesCache != null) return _logoBytesCache;
    try {
      final data = await rootBundle.load(
        'assets/images/brand/orbi-logo-v2-dark-blue.png',
      );
      _logoBytesCache = data.buffer.asUint8List();
      return _logoBytesCache;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadWatermarkBytes() async {
    if (_watermarkBytesCache != null) return _watermarkBytesCache;
    try {
      final data = await rootBundle.load(
        'assets/images/brand/orbi-logo-v2-dark-blue.png',
      );
      _watermarkBytesCache = data.buffer.asUint8List();
      return _watermarkBytesCache;
    } catch (_) {
      return null;
    }
  }

  List<MapEntry<String, String>> _receiptRows(Map<String, dynamic> tx) {
    final l10n = AppLocalizations.of(context)!;
    final senderMap = tx['sender'] is Map
        ? Map<String, dynamic>.from(tx['sender'] as Map)
        : <String, dynamic>{};
    final receiverMap = tx['receiver'] is Map
        ? Map<String, dynamic>.from(tx['receiver'] as Map)
        : <String, dynamic>{};
    final counterpartyMap = tx['counterparty'] is Map
        ? Map<String, dynamic>.from(tx['counterparty'] as Map)
        : <String, dynamic>{};

    final date = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(_asDate(tx['created_at'] ?? tx['createdAt'] ?? tx['timestamp']));
    final direction = _isCredit(tx)
        ? l10n.transactionsCredit
        : l10n.transactionsDebit;
    final senderName = _cleanUserFacing(
      _pickString([
        senderMap['name'],
        tx['sender_name'],
        tx['source_name'],
        tx['from_name'],
        tx['counterparty_name'],
        tx['sender'],
      ]),
    );
    final recipientName = _cleanUserFacing(
      _pickString([
        receiverMap['name'],
        counterpartyMap['name'],
        tx['recipient_name'],
        tx['beneficiary_name'],
        tx['target_name'],
        tx['to_name'],
        tx['counterparty_name'],
        tx['recipient'],
      ]),
    );
    final senderCustomerId = _pickString([
      senderMap['customerId'],
      senderMap['customer_id'],
      senderMap['id'],
      tx['source_customer_id'],
      tx['sender_customer_id'],
      tx['customer_id'],
    ]);
    final recipientCustomerId = _pickString([
      receiverMap['customerId'],
      receiverMap['customer_id'],
      counterpartyMap['id'],
      receiverMap['id'],
      tx['recipient_customer_id'],
      tx['beneficiary_customer_id'],
      tx['recipient_reference'],
      tx['target_customer_id'],
      tx['to_customer_id'],
    ]);
    final senderMaskedId = _maskCustomerId(senderCustomerId);
    final recipientMaskedId = _maskCustomerId(recipientCustomerId);
    final sourceDisplay = _pickString([
      if (senderName.isNotEmpty && senderMaskedId.isNotEmpty)
        '$senderName ($senderMaskedId)',
      senderName,
      senderMaskedId,
      l10n.transactionsNotAvailable,
    ]);
    final destinationDisplay = _pickString([
      if (recipientName.isNotEmpty && recipientMaskedId.isNotEmpty)
        '$recipientName ($recipientMaskedId)',
      recipientName,
      recipientMaskedId,
      l10n.transactionsNotAvailable,
    ]);
    final baseAmount = _baseAmount(tx);
    final taxAmount = _taxAmount(tx);
    final feeAmount = _feeAmount(tx);
    final totalAmount = baseAmount + taxAmount + feeAmount;
    final ordered = <MapEntry<String, String>>[
      MapEntry(
        l10n.transactionsReceiptReferenceId,
        _pickString([
          tx['reference'],
          tx['transaction_reference'],
          tx['ref'],
          tx['id'],
          tx['transaction_id'],
        ]),
      ),
      MapEntry(l10n.transactionsReceiptType, _friendlyType(tx)),
      MapEntry(
        l10n.transactionsReceiptStatus,
        _pickString([
          tx['status'],
          tx['state'],
          l10n.transactionsStatusCompleted,
        ]),
      ),
      MapEntry(l10n.transactionsReceiptAmount, _amountText(tx)),
      MapEntry(l10n.transactionsReceiptBaseAmount, _money(tx, baseAmount)),
      MapEntry(l10n.transactionsReceiptTax, _money(tx, taxAmount)),
      MapEntry(l10n.transactionsReceiptServiceFee, _money(tx, feeAmount)),
      MapEntry(l10n.transactionsReceiptTotalCharged, _money(tx, totalAmount)),
      MapEntry(l10n.transactionsReceiptDirection, direction),
      MapEntry(l10n.transactionsReceiptMoneyState, _lifecycleState(tx)),
      MapEntry(l10n.transactionsReceiptDate, date),
      MapEntry(l10n.transactionsReceiptFrom, sourceDisplay),
      MapEntry(l10n.transactionsReceiptTo, destinationDisplay),
    ];
    return ordered.where((e) => e.value.trim().isNotEmpty).toList();
  }

  String _lifecycleState(Map<String, dynamic> tx) {
    final l10n = AppLocalizations.of(context)!;
    switch (_lifecycleStateKey(tx)) {
      case 'available':
        return l10n.moneyStateAvailable;
      case 'budgeted':
        return l10n.moneyStateBudgeted;
      case 'saved':
        return l10n.moneyStateSaved;
      case 'locked':
        return l10n.moneyStateLocked;
      case 'spent':
        return l10n.moneyStateSpent;
      default:
        return l10n.moneyStateAllocated;
    }
  }

  String _lifecycleStateKey(Map<String, dynamic> tx) {
    final raw = _pickString([
      tx['transaction_type'],
      tx['type'],
      tx['kind'],
      tx['category'],
      tx['description'],
    ]).toLowerCase();
    if (raw.contains('goal') || raw.contains('saving')) {
      if (raw.contains('withdraw')) return 'available';
      if (raw.contains('lock')) return 'locked';
      return 'saved';
    }
    if (raw.contains('budget') || raw.contains('category')) return 'budgeted';
    if (raw.contains('bill') ||
        raw.contains('payment') ||
        raw.contains('transfer') ||
        raw.contains('withdraw') ||
        raw.contains('expense') ||
        raw.contains('merchant') ||
        raw.contains('shop')) {
      return 'spent';
    }
    if (_isCredit(tx)) return 'available';
    return 'allocated';
  }

  List<Map<String, dynamic>> _filteredTransactions() {
    if (_selectedMoneyState == _allMoneyStates) return _transactions;
    return _transactions
        .where((tx) => _lifecycleStateKey(tx) == _selectedMoneyState)
        .toList();
  }

  List<_MoneyStateFilter> _moneyStateFilters(AppLocalizations l10n) {
    return [
      _MoneyStateFilter(_allMoneyStates, l10n.transactionsFilterAll),
      _MoneyStateFilter('available', l10n.moneyStateAvailable),
      _MoneyStateFilter('allocated', l10n.moneyStateAllocated),
      _MoneyStateFilter('budgeted', l10n.moneyStateBudgeted),
      _MoneyStateFilter('saved', l10n.moneyStateSaved),
      _MoneyStateFilter('locked', l10n.moneyStateLocked),
      _MoneyStateFilter('spent', l10n.moneyStateSpent),
    ];
  }

  Widget _buildMoneyStateFilters(
    BuildContext context,
    AppLocalizations l10n,
    OrbiUiTokens ui,
  ) {
    final filters = _moneyStateFilters(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transactionsFilterByMoneyState,
          style: TextStyle(
            color: ui.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final selected = _selectedMoneyState == filter.key;
            return ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedMoneyState = filter.key);
              },
              labelStyle: TextStyle(
                color: selected ? ui.textPrimary : ui.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: ui.iconMuted.withValues(alpha: 0.14),
              backgroundColor: ui.cardMuted,
              side: BorderSide(
                color: selected
                    ? ui.iconMuted.withValues(alpha: 0.32)
                    : ui.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    Map<String, dynamic> tx,
    OrbiUiTokens ui,
  ) {
    final amount = _amountText(tx);
    final isCredit = _isCredit(tx);
    final accent = _transactionAccent(tx, ui);
    final icon = _transactionIcon(tx, isCredit: isCredit);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: OrbiCardStyles.elevatedCardDecoration(
        context,
        radius: 16,
        accent: accent,
        branded: true,
        elevated: true,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTransactionDetails(tx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: OrbiCardStyles.iconBadgeDecoration(
                            context,
                            accent: accent,
                            radius: 14,
                          ),
                          child: Icon(icon, color: accent, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title(tx),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_subtitle(tx)} • ${_lifecycleState(tx)}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MoneyText(
                        value: amount,
                        mainFontSize: 18,
                        sideFontSize: 10,
                        textAlign: TextAlign.end,
                        mainColor: accent,
                        sideColor: accent,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: OrbiCardStyles.iconBadgeDecoration(
                      context,
                      accent: accent,
                      radius: 14,
                    ),
                    child: Icon(icon, color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(tx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_subtitle(tx)} • ${_lifecycleState(tx)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ui.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: MoneyText(
                        value: amount,
                        mainFontSize: 18,
                        sideFontSize: 10,
                        textAlign: TextAlign.end,
                        mainColor: accent,
                        sideColor: accent,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<int> _barcodeWidths(String raw) {
    final input = raw.trim().isEmpty ? 'ORBI' : raw.trim();
    final widths = <int>[];
    for (final rune in input.runes) {
      final seed = rune % 9;
      widths.add(1 + (seed % 3));
      widths.add(1 + ((seed + 1) % 3));
      widths.add(1 + ((seed + 2) % 3));
      widths.add(1 + ((seed + 3) % 2));
    }
    return widths;
  }

  Widget _barcodeStrip(String value, {required OrbiUiTokens ui}) {
    final widths = _barcodeWidths(value);
    final totalWidth = widths.fold<int>(0, (sum, width) => sum + width);
    var dark = true;
    final bars = widths.map((w) {
      final bar = Container(
        width: w.toDouble(),
        color: dark ? ui.textPrimary : ui.card,
      );
      dark = !dark;
      return bar;
    }).toList();
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.borderStrong),
      ),
      child: ClipRect(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: totalWidth.toDouble(),
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bars,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildReceiptPdf(
    List<MapEntry<String, String>> rows, {
    required String heading,
    Uint8List? logoBytes,
    Uint8List? watermarkBytes,
    required String barcodeValue,
  }) async {
    final doc = pw.Document();
    final brandFont = await PdfGoogleFonts.michromaRegular();
    final receiptInk = PdfColor.fromHex('#163126');
    final receiptMutedInk = PdfColor.fromHex('#5E7268');
    final receiptBorder = PdfColor.fromHex('#2E8B57');
    final receiptSoft = PdfColor.fromHex('#E7F5EC');
    final now = DateTime.now();
    final printedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final tzName = now.timeZoneName.trim();
    final offset = now.timeZoneOffset;
    final offsetSign = offset.isNegative ? '-' : '+';
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(
      2,
      '0',
    );
    final offsetLabel = 'UTC$offsetSign$offsetHours:$offsetMinutes';
    final printedAtLabel = tzName.isNotEmpty && tzName.toUpperCase() != 'UTC'
        ? '$printedAt $tzName ($offsetLabel)'
        : printedAt;
    final receiptPageFormat = _receiptPdfPageFormat();
    doc.addPage(
      pw.MultiPage(
        pageFormat: receiptPageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          final bars = _barcodeWidths(barcodeValue);
          var dark = true;
          final pdfBars = bars.map((w) {
            final bar = pw.Container(
              width: w.toDouble(),
              color: dark ? receiptInk : PdfColor.fromHex('#FFFFFF'),
            );
            dark = !dark;
            return bar;
          }).toList();
          final receiptBody = pw.CustomPaint(
            foregroundPainter: (canvas, size) {
              const zigZagHeight = 4.0;
              const zigZagWidth = 10.0;
              final width = size.x;
              final height = size.y;
              canvas
                ..setStrokeColor(receiptBorder)
                ..setLineWidth(0.8);
              var x = 0.0;
              canvas.moveTo(0, height - zigZagHeight);
              while (x < width) {
                canvas
                  ..lineTo(x + zigZagWidth / 2, height)
                  ..lineTo(x + zigZagWidth, height - zigZagHeight);
                x += zigZagWidth;
              }
              canvas.strokePath();
              x = width;
              canvas.moveTo(width, zigZagHeight);
              while (x > 0) {
                canvas
                  ..lineTo(x - zigZagWidth / 2, 0)
                  ..lineTo(x - zigZagWidth, zigZagHeight);
                x -= zigZagWidth;
              }
              canvas.strokePath();
            },
            child: pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.DefaultTextStyle(
                style: pw.TextStyle(color: receiptInk),
                child: pw.Stack(
                  children: [
                    if (watermarkBytes != null)
                      pw.Positioned.fill(
                        child: pw.Align(
                          alignment: const pw.Alignment(0, 0.2),
                          child: pw.Opacity(
                            opacity: 0.08,
                            child: pw.Image(
                              pw.MemoryImage(watermarkBytes),
                              width: 220,
                              height: 220,
                            ),
                          ),
                        ),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Header(
                          level: 0,
                          margin: pw.EdgeInsets.zero,
                          child: pw.Center(
                            child: pw.Column(
                              children: [
                                if (logoBytes != null) ...[
                                  pw.Image(
                                    pw.MemoryImage(logoBytes),
                                    width: 34,
                                    height: 34,
                                  ),
                                  pw.SizedBox(height: 6),
                                ],
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: receiptSoft,
                                    border: pw.Border.all(color: receiptBorder),
                                    borderRadius: pw.BorderRadius.circular(999),
                                  ),
                                  child: pw.Text(
                                    'ORBI',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: receiptBorder,
                                      font: brandFont,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  heading,
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'Orbi Financial Technologies\n'
                                  'P.O. BOX 02, Dar es Salaam, Tanzania\n'
                                  'Main Branch Kariakoo Alikoma-Magila Street, Block No 123 Second Floor\n'
                                  'Tel +255764258114',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: receiptMutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Table(
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2.2),
                            1: const pw.FixedColumnWidth(14),
                            2: const pw.FlexColumnWidth(3.8),
                          },
                          defaultVerticalAlignment:
                              pw.TableCellVerticalAlignment.top,
                          children: rows
                              .map(
                                (row) => pw.TableRow(
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(
                                        bottom: 7,
                                      ),
                                      child: pw.Text(
                                        row.key.toUpperCase(),
                                        style: pw.TextStyle(
                                          fontSize: 8.6,
                                          color: receiptMutedInk,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(
                                        bottom: 7,
                                      ),
                                      child: pw.Text(
                                        ':',
                                        textAlign: pw.TextAlign.center,
                                        style: const pw.TextStyle(fontSize: 9),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(
                                        bottom: 7,
                                      ),
                                      child: pw.Text(
                                        row.value,
                                        softWrap: true,
                                        style: pw.TextStyle(
                                          fontSize: 9.2,
                                          fontWeight:
                                              row.key == 'Amount' ||
                                                  row.key == 'Base Amount' ||
                                                  row.key == 'Tax' ||
                                                  row.key == 'Service Fee' ||
                                                  row.key == 'Total Charged'
                                              ? pw.FontWeight.bold
                                              : pw.FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          width: double.infinity,
                          height: 56,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: pw.BoxDecoration(
                            color: receiptSoft,
                            border: pw.Border.all(color: receiptBorder),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Center(
                            child: pw.SizedBox(
                              width: bars.fold<double>(
                                0,
                                (sum, width) => sum + width.toDouble(),
                              ),
                              height: 40,
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: pdfBars,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Center(
                          child: pw.Text(
                            barcodeValue,
                            style: pw.TextStyle(
                              fontSize: 8.3,
                              color: receiptMutedInk,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Center(
                          child: pw.Text(
                            'Thank you for choosing ORBI. We value your trust.',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              color: receiptBorder,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Center(
                          child: pw.Text(
                            'Printed: $printedAtLabel',
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              color: receiptMutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          return [
            pw.Center(
              child: pw.Container(
                width: receiptPageFormat.availableWidth,
                height: receiptPageFormat.availableHeight,
                alignment: pw.Alignment.center,
                child: receiptBody,
              ),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  Widget _receiptPreviewCard({
    required List<MapEntry<String, String>> rows,
    required String heading,
    required Uint8List? logoBytes,
    required Uint8List? watermarkBytes,
    required String barcodeValue,
    required OrbiUiTokens ui,
  }) {
    const receiptPaper = Color(0xFFFFFFFF);
    const receiptInk = Color(0xFF163126);
    const receiptMutedInk = Color(0xFF5E7268);
    const receiptBorder = Color(0xFF2E8B57);
    const receiptSoft = Color(0xFFE7F5EC);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipPath(
          clipper: const _ReceiptZigZagClipper(),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: receiptPaper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: receiptBorder, width: 1.1),
            ),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Stack(
              children: [
                if (watermarkBytes != null)
                  Positioned.fill(
                    child: Align(
                      alignment: const Alignment(0, 0.2),
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.memory(
                          watermarkBytes,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          if (logoBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Image.memory(
                                logoBytes,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: receiptSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: receiptBorder),
                            ),
                            child: Text(
                              'ORBI',
                              style: GoogleFonts.michroma(
                                color: receiptBorder,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            heading,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: receiptInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Orbi Financial Technologies\n'
                            'P.O. BOX 02, Dar es Salaam, Tanzania\n'
                            'Main Branch, Block No 123, Second Floor\n'
                            'Tel +255764258114',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: receiptMutedInk,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: receiptBorder, height: 1),
                    const SizedBox(height: 9),
                    ...rows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 122,
                              child: Text(
                                row.key.toUpperCase(),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: receiptMutedInk,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  color: receiptInk,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.value,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: receiptInk,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: _barcodeStrip(
                          barcodeValue,
                          ui: ui.copyWith(
                            card: receiptPaper,
                            borderStrong: receiptBorder,
                            textPrimary: receiptInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        barcodeValue,
                        style: const TextStyle(
                          color: receiptMutedInk,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Thank you for choosing ORBI. We value your trust.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: receiptBorder,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTransactionDetails(Map<String, dynamic> tx) async {
    final ui = OrbiTheme.uiOf(context);
    if (_isOpeningDetails) return;
    _isOpeningDetails = true;
    try {
      final txId = _pickString([
        tx['id'],
        tx['transaction_id'],
        tx['reference'],
      ]);
      Map<String, dynamic> receiptPayload = Map<String, dynamic>.from(tx);
      if (txId.isNotEmpty) {
        try {
          final serverReceipt = await _receiptService.fetchReceipt(txId);
          if (serverReceipt.isNotEmpty) {
            receiptPayload = {...receiptPayload, ...serverReceipt};
          }
        } catch (_) {
          // Fall back to local receipt composition when server receipt is absent.
        }
      }
      final rows = _receiptRows(receiptPayload);
      final logoBytes = await _loadLogoBytes();
      final watermarkBytes = await _loadWatermarkBytes();
      const heading = 'TRANSACTION RECEIPT';
      final barcodeValue = txId.isEmpty
          ? 'ORBI-${DateTime.now().millisecondsSinceEpoch}'
          : txId;
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ui.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.86,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Text(
                          'TRANSACTION RECEIPT',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close, color: ui.iconMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _receiptPreviewCard(
                          rows: rows,
                          heading: heading,
                          logoBytes: logoBytes,
                          watermarkBytes: watermarkBytes,
                          barcodeValue: barcodeValue,
                          ui: ui,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        if (_canReportTransferIssue(tx)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _reportIncorrectTransfer(tx);
                              },
                              icon: const Icon(
                                Icons.report_problem_outlined,
                                size: 18,
                              ),
                              label: Text(
                                Localizations.localeOf(
                                          context,
                                        ).languageCode.toLowerCase() ==
                                        'sw'
                                    ? 'Ripoti uhamisho usio sahihi'
                                    : 'Report incorrect transfer',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final pdf = await _buildReceiptPdf(
                                rows,
                                heading: heading,
                                logoBytes: logoBytes,
                                watermarkBytes: watermarkBytes,
                                barcodeValue: barcodeValue,
                              );
                              await Printing.layoutPdf(
                                onLayout: (_) async => pdf,
                              );
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.actionDownloadPrint,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final pdf = await _buildReceiptPdf(
                                rows,
                                heading: heading,
                                logoBytes: logoBytes,
                                watermarkBytes: watermarkBytes,
                                barcodeValue: barcodeValue,
                              );
                              await Printing.sharePdf(
                                bytes: pdf,
                                filename:
                                    'obi_receipt_${txId.isEmpty ? DateTime.now().millisecondsSinceEpoch : txId}.pdf',
                              );
                            },
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.actionShareReceipt,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _isOpeningDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final filteredTransactions = _filteredTransactions();
    if (_loading) {
      return OrbiBackground(
        padding: EdgeInsets.zero,
        child: Center(child: CircularProgressIndicator(color: ui.success)),
      );
    }
    if (_error != null) {
      return OrbiBackground(
        padding: EdgeInsets.zero,
        child: Center(
          child: OrbiResponsiveContent(
            padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 16),
            child: OrbiStateCard(
              icon: Icons.receipt_long_outlined,
              title: l10n.transactionsLoadFailedTitle,
              message: _error!,
              accentColor: ui.danger,
              accentBackground: ui.dangerSoft,
              action: FilledButton(
                onPressed: _loadTransactions,
                child: Text(AppLocalizations.of(context)!.actionRetry),
              ),
            ),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return OrbiBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              OrbiResponsiveContent(
                padding: OrbiResponsive.pagePadding(
                  context,
                  top: 16,
                  bottom: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _transactionsHero(context, l10n, ui, const []),
                    const SizedBox(height: 16),
                    Text(
                      l10n.transactionsHistoryTitle,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMoneyStateFilters(context, l10n, ui),
                    const SizedBox(height: 16),
                    OrbiStateCard(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.transactionsEmptyTitle,
                      message: l10n.transactionsEmptyMessage,
                      accentColor: ui.iconMuted,
                      accentBackground: ui.cardStrong,
                      padding: const EdgeInsets.all(20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return OrbiBackground(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _loadTransactions,
        color: ui.success,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            OrbiResponsiveContent(
              padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _transactionsHero(context, l10n, ui, filteredTransactions),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.transactionsHistoryTitle,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.transactionsItemsCount(
                            filteredTransactions.length,
                          ),
                          style: TextStyle(color: ui.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildMoneyStateFilters(context, l10n, ui),
                  const SizedBox(height: 12),
                  if (filteredTransactions.isEmpty)
                    OrbiStateCard(
                      icon: Icons.filter_alt_off_outlined,
                      title: l10n.transactionsNoFilteredMatchesTitle,
                      message: l10n.transactionsNoFilteredMatchesMessage,
                      accentColor: ui.iconMuted,
                      accentBackground: ui.cardStrong,
                      padding: const EdgeInsets.all(18),
                    )
                  else
                    ...filteredTransactions.map(
                      (tx) => _buildTransactionTile(context, tx, ui),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsHero(
    BuildContext context,
    AppLocalizations l10n,
    OrbiUiTokens ui,
    List<Map<String, dynamic>> transactions,
  ) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final credits = transactions.where(_isCredit).length;
    final debits = transactions.isEmpty ? 0 : transactions.length - credits;
    return OrbiBrandHeroCard(
      title: l10n.transactionsHistoryTitle,
      subtitle: sw
          ? 'Chuja, hakiki, na fungua risiti unapohitaji.'
          : 'Filter, verify, and open receipts when needed.',
      icon: Icons.receipt_long_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OrbiHeroMetricChip(
            icon: Icons.receipt_long_outlined,
            label: sw ? 'Zinazoonekana' : 'Visible',
            value: '${transactions.length}',
          ),
          OrbiHeroMetricChip(
            icon: Icons.south_west_rounded,
            label: sw ? 'Zinazoingia' : 'Credits',
            value: '$credits',
          ),
          OrbiHeroMetricChip(
            icon: Icons.north_east_rounded,
            label: sw ? 'Zinazotoka' : 'Debits',
            value: '$debits',
          ),
          OrbiHeroMetricChip(
            icon: Icons.filter_alt_outlined,
            label: sw ? 'Muonekano' : 'View',
            value: _selectedMoneyState.toUpperCase(),
          ),
        ],
      ),
    );
  }
}

class _MoneyStateFilter {
  final String key;
  final String label;

  const _MoneyStateFilter(this.key, this.label);
}

class _ReceiptZigZagClipper extends CustomClipper<Path> {
  const _ReceiptZigZagClipper();

  @override
  Path getClip(Size size) {
    const zigZagHeight = 6.0;
    const zigZagWidth = 12.0;
    final path = Path();
    final height = size.height;
    final width = size.width;

    path.moveTo(0, zigZagHeight);
    var x = 0.0;
    while (x < width) {
      path.lineTo(x + zigZagWidth / 2, 0);
      path.lineTo(x + zigZagWidth, zigZagHeight);
      x += zigZagWidth;
    }

    path.lineTo(width, height - zigZagHeight);
    x = width;
    while (x > 0) {
      path.lineTo(x - zigZagWidth / 2, height);
      path.lineTo(x - zigZagWidth, height - zigZagHeight);
      x -= zigZagWidth;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
