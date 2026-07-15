import 'dart:async';
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/receipts/orbi_receipt_image_pdf_builder.dart';
import '../../../core/reports/orbi_resource_report_printer.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/session_currency.dart';
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

  Future<void> _loadTransactions({bool forceRefresh = false}) async {
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
        forceRefresh: forceRefresh,
      );
      txs.sort((a, b) {
        final at = _asDate(
          a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? a['date'],
        );
        final bt = _asDate(
          b['created_at'] ?? b['createdAt'] ?? b['timestamp'] ?? b['date'],
        );
        return at.compareTo(bt);
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
      _loadTransactions(forceRefresh: true);
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
      updated.add(tx);
    }

    updated.sort((a, b) {
      final at = _asDate(
        a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? a['date'],
      );
      final bt = _asDate(
        b['created_at'] ?? b['createdAt'] ?? b['timestamp'] ?? b['date'],
      );
      return at.compareTo(bt);
    });

    setState(() => _transactions = updated);
  }

  String _cleanUserFacing(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (_looksLikeUuid(v)) return '';
    return v;
  }

  String _personNameFrom(
    Map<String, dynamic> map,
    List<dynamic> fallbackValues,
  ) {
    final profile = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'] as Map)
        : map['users'] is Map
        ? Map<String, dynamic>.from(map['users'] as Map)
        : <String, dynamic>{};
    return _cleanUserFacing(
      _pickString([
        map['full_name'],
        map['display_name'],
        map['name'],
        map['username'],
        profile['full_name'],
        profile['display_name'],
        profile['name'],
        profile['username'],
        ...fallbackValues,
        map['phone'],
        map['email'],
        profile['phone'],
        profile['email'],
        map['orbi_id'],
        profile['orbi_id'],
      ]),
    );
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
    final ledger = tx['ledger'] is Map
        ? Map<String, dynamic>.from(tx['ledger'] as Map)
        : <String, dynamic>{};
    final direction = _pickString([
      tx['entry_side'],
      tx['entry_type'],
      ledger['entry_side'],
      ledger['entry_type'],
      tx['direction'],
      tx['flow'],
    ]).toLowerCase();
    final type = _pickString([
      tx['type'],
      tx['transaction_type'],
      tx['kind'],
      tx['category'],
    ]).toLowerCase();
    if (direction.contains('credit') ||
        direction == 'in' ||
        direction == 'incoming') {
      return true;
    }
    if (direction.contains('debit') ||
        direction == 'out' ||
        direction == 'outgoing') {
      return false;
    }
    return type.contains('deposit') ||
        type.contains('refund') ||
        type.contains('salary') ||
        type.contains('income');
  }

  String _currency(Map<String, dynamic> tx) {
    final session = context.read<AuthController>().session;
    return resolveCurrencyCode([
      tx['currency'],
      tx['currency_code'],
      tx['currencyCode'],
      resolveSessionCurrency(session),
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
    return '$prefix${formatFinancialMoney(amount.abs(), currency, locale: _localeTag)}';
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
        'assets/images/brand/orbi-logo-v2-black.png',
      );
      _logoBytesCache = data.buffer.asUint8List();
      return _logoBytesCache;
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
    final senderName = _personNameFrom(senderMap, [
      tx['source_wallet_name'],
      tx['sourceWalletName'],
      tx['from_wallet_name'],
      tx['fromWalletName'],
      tx['sender_name'],
      tx['source_name'],
      tx['from_name'],
      tx['counterparty_name'],
      tx['sender'],
    ]);
    final recipientName = _personNameFrom(receiverMap, [
      tx['destination_wallet_name'],
      tx['destinationWalletName'],
      tx['target_wallet_name'],
      tx['targetWalletName'],
      tx['to_wallet_name'],
      tx['toWalletName'],
      tx['wallet_name'],
      counterpartyMap['full_name'],
      counterpartyMap['display_name'],
      counterpartyMap['name'],
      tx['recipient_name'],
      tx['beneficiary_name'],
      tx['target_name'],
      tx['to_name'],
      tx['counterparty_name'],
      tx['recipient'],
      tx['recipient_phone'],
      tx['beneficiary_phone'],
      tx['target_phone'],
      tx['to_phone'],
      tx['recipient_email'],
      tx['beneficiary_email'],
      tx['target_email'],
      tx['to_email'],
      tx['recipient_orbi_id'],
      tx['target_orbi_id'],
    ]);
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
    final normalizedSource = _friendlyMovementLabel(
      tx,
      sourceDisplay,
      toSide: false,
    );
    final destinationDisplay = _pickString([
      if (recipientName.isNotEmpty && recipientMaskedId.isNotEmpty)
        '$recipientName ($recipientMaskedId)',
      recipientName,
      recipientMaskedId,
      l10n.transactionsNotAvailable,
    ]);
    final normalizedDestination = _friendlyMovementLabel(
      tx,
      destinationDisplay,
      toSide: true,
    );
    final ordered = <MapEntry<String, String>>[
      MapEntry(l10n.transactionsReceiptAmount, _amountText(tx)),
      MapEntry(
        l10n.transactionsReceiptStatus,
        _pickString([
          tx['status'],
          tx['state'],
          l10n.transactionsStatusCompleted,
        ]),
      ),
      MapEntry(l10n.transactionsReceiptDate, date),
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
      MapEntry(l10n.transactionsReceiptFrom, normalizedSource),
      MapEntry(
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw'
            ? 'Kwenda'
            : 'To',
        normalizedDestination,
      ),
    ];
    return ordered.where((e) => e.value.trim().isNotEmpty).toList();
  }

  String _friendlyMovementLabel(
    Map<String, dynamic> tx,
    String current, {
    required bool toSide,
  }) {
    final normalized = current.trim().toLowerCase();
    final shouldReplace =
        normalized.isEmpty ||
        normalized.contains('external recipient') ||
        normalized.contains('not available') ||
        normalized.contains('haipatikani') ||
        normalized == 'external' ||
        normalized == 'n/a';
    if (!shouldReplace) return current;

    final raw = _pickString([
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
    ]).toLowerCase();

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
    final status = _transactionStatusMeta(tx, ui);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTransactionDetails(tx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _transactionIconBadge(icon, accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _title(tx),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _subtitle(tx),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 50),
                        Expanded(child: _transactionStatusChip(status)),
                        SizedBox(
                          width: 126,
                          child: MoneyText(
                            value: amount,
                            mainFontSize: 16,
                            sideFontSize: 9,
                            textAlign: TextAlign.end,
                            mainColor: accent,
                            sideColor: accent,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: ui.iconMuted.withValues(alpha: 0.72),
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _transactionIconBadge(icon, accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title(tx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(tx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 142,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoneyText(
                          value: amount,
                          mainFontSize: 17,
                          sideFontSize: 9,
                          textAlign: TextAlign.end,
                          mainColor: accent,
                          sideColor: accent,
                        ),
                        const SizedBox(height: 6),
                        _transactionStatusChip(status),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: ui.iconMuted.withValues(alpha: 0.64),
                    size: 20,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _transactionIconBadge(IconData icon, Color accent) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }

  Widget _transactionStatusChip(_TransactionStatusMeta status) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: status.color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TransactionStatusMeta _transactionStatusMeta(
    Map<String, dynamic> tx,
    OrbiUiTokens ui,
  ) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final raw = _pickString([
      tx['status'],
      tx['state'],
      tx['transaction_status'],
      tx['transactionStatus'],
      tx['payment_status'],
      tx['paymentStatus'],
      tx['lifecycle_status'],
      tx['lifecycleStatus'],
      'completed',
    ]).toLowerCase();

    if (raw.contains('fail') ||
        raw.contains('reject') ||
        raw.contains('declin') ||
        raw.contains('error')) {
      return _TransactionStatusMeta(
        label: sw ? 'Imeshindikana' : 'Failed',
        icon: Icons.cancel_rounded,
        color: ui.danger,
      );
    }
    if (raw.contains('cancel') || raw.contains('void')) {
      return _TransactionStatusMeta(
        label: sw ? 'Imeghairiwa' : 'Cancelled',
        icon: Icons.block_rounded,
        color: ui.textMuted,
      );
    }
    if (raw.contains('pend') ||
        raw.contains('process') ||
        raw.contains('progress') ||
        raw.contains('review') ||
        raw.contains('hold')) {
      return _TransactionStatusMeta(
        label: sw ? 'Inaendelea' : 'In progress',
        icon: Icons.sync_rounded,
        color: ui.warning,
      );
    }
    if (raw.contains('lock') || raw.contains('escrow')) {
      return _TransactionStatusMeta(
        label: sw ? 'Imehifadhiwa' : 'Secured',
        icon: Icons.verified_user_rounded,
        color: ui.accent,
      );
    }
    return _TransactionStatusMeta(
      label: sw ? 'Imekamilika' : 'Completed',
      icon: Icons.check_circle_rounded,
      color: ui.success,
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

  String _receiptStatusLabel(List<MapEntry<String, String>> detailRows) {
    return detailRows.isNotEmpty && detailRows.first.value.trim().isNotEmpty
        ? detailRows.first.value.trim()
        : 'Completed';
  }

  String _receiptStatusKey(String status) {
    final raw = status.toLowerCase();
    if (raw.contains('fail') ||
        raw.contains('reject') ||
        raw.contains('declin') ||
        raw.contains('error') ||
        raw.contains('shindik')) {
      return 'failed';
    }
    if (raw.contains('cancel') ||
        raw.contains('void') ||
        raw.contains('ghair')) {
      return 'cancelled';
    }
    if (raw.contains('pend') ||
        raw.contains('process') ||
        raw.contains('progress') ||
        raw.contains('review') ||
        raw.contains('hold') ||
        raw.contains('endelea')) {
      return 'pending';
    }
    if (raw.contains('lock') ||
        raw.contains('escrow') ||
        raw.contains('secure') ||
        raw.contains('hifadhi')) {
      return 'secured';
    }
    return 'completed';
  }

  Color _receiptStatusColor(String status) {
    switch (_receiptStatusKey(status)) {
      case 'failed':
        return const Color(0xFFDC2626);
      case 'cancelled':
        return const Color(0xFF64748B);
      case 'pending':
        return const Color(0xFFD97706);
      case 'secured':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF16A34A);
    }
  }

  Color _receiptStatusSoftColor(String status) {
    switch (_receiptStatusKey(status)) {
      case 'failed':
        return const Color(0xFFFEF2F2);
      case 'cancelled':
        return const Color(0xFFF1F5F9);
      case 'pending':
        return const Color(0xFFFFFBEB);
      case 'secured':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFF0FDF4);
    }
  }

  IconData _receiptStatusIcon(String status) {
    switch (_receiptStatusKey(status)) {
      case 'failed':
        return Icons.cancel_rounded;
      case 'cancelled':
        return Icons.block_rounded;
      case 'pending':
        return Icons.sync_rounded;
      case 'secured':
        return Icons.verified_user_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Future<Uint8List> _buildReceiptPdfFromPreview(GlobalKey previewKey) async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Receipt preview is not ready for capture.');
    }
    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(
      format: dart_ui.ImageByteFormat.png,
    );
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not capture receipt preview.');
    }
    return OrbiReceiptImagePdfBuilder.build(
      receiptPngBytes: byteData.buffer.asUint8List(),
    );
  }

  Widget _receiptPreviewCard({
    required List<MapEntry<String, String>> rows,
    required String heading,
    required Uint8List? logoBytes,
    required String barcodeValue,
    required OrbiUiTokens ui,
  }) {
    const receiptPaper = Color(0xFFFFFFFF);
    const receiptInk = Color(0xFF1A2332);
    const receiptMutedInk = Color(0xFF64748B);
    const receiptBorder = Color(0xFF2563EB);
    const receiptSoft = Color(0xFFEFF6FF);
    final primaryRow = rows.isNotEmpty
        ? rows.first
        : const MapEntry<String, String>('Amount', '-');
    final detailRows = rows.length > 1
        ? rows.skip(1).toList()
        : <MapEntry<String, String>>[];
    final statusLabel = _receiptStatusLabel(detailRows);
    final statusColor = _receiptStatusColor(statusLabel);
    final statusSoft = _receiptStatusSoftColor(statusLabel);
    final statusIcon = _receiptStatusIcon(statusLabel);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: receiptPaper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141A2332),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (logoBytes != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.035,
                        child: Image.memory(
                          logoBytes,
                          width: 270,
                          height: 270,
                          fit: BoxFit.contain,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: logoBytes != null
                        ? Image.memory(
                            logoBytes,
                            width: 96,
                            height: 38,
                            fit: BoxFit.contain,
                            color: Colors.black,
                          )
                        : const Text(
                            'Orbi',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'SECURE PAYMENT RECEIPT',
                      style: TextStyle(
                        color: receiptMutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 15, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          primaryRow.key.toUpperCase(),
                          style: const TextStyle(
                            color: receiptMutedInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            primaryRow.value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: receiptInk,
                              fontSize: 42,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: receiptBorder),
                          ),
                          child: Text(
                            heading,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: receiptBorder,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRANSACTION DETAILS',
                          style: TextStyle(
                            color: receiptMutedInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...detailRows.skip(1).toList().asMap().entries.map((
                          entry,
                        ) {
                          final row = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 13),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _receiptDetailIcon(entry.key),
                                  color: receiptMutedInk,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    row.key,
                                    style: const TextStyle(
                                      color: receiptMutedInk,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    row.value,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: receiptInk,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: receiptSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: receiptBorder,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                barcodeValue,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: receiptInk,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _barcodeStrip(
                          barcodeValue,
                          ui: ui.copyWith(
                            card: receiptSoft,
                            borderStrong: receiptBorder,
                            textPrimary: receiptInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Thank you for choosing ORBI. We value your trust.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: receiptBorder,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
  }

  IconData _receiptDetailIcon(int index) {
    switch (index) {
      case 0:
        return Icons.calendar_month_rounded;
      case 1:
        return Icons.confirmation_number_rounded;
      case 2:
        return Icons.arrow_outward_rounded;
      case 3:
        return Icons.south_west_rounded;
      default:
        return Icons.sell_rounded;
    }
  }

  Future<void> _showReceiptLoadingOverlay() async {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: ui.sheet,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ui.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: ui.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    sw ? 'Tunaandaa risiti...' : 'Preparing receipt...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sw ? 'Tafadhali subiri kidogo.' : 'Please wait a moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _closeReceiptLoadingOverlay() {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _openTransactionDetails(Map<String, dynamic> tx) async {
    final ui = OrbiTheme.uiOf(context);
    if (_isOpeningDetails) return;
    _isOpeningDetails = true;
    var loadingOverlayOpen = false;
    try {
      unawaited(_showReceiptLoadingOverlay());
      loadingOverlayOpen = true;
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
      const heading = 'TRANSACTION RECEIPT';
      final barcodeValue = txId.isEmpty
          ? 'ORBI-${DateTime.now().millisecondsSinceEpoch}'
          : txId;
      if (!mounted) return;
      if (loadingOverlayOpen) {
        _closeReceiptLoadingOverlay();
        loadingOverlayOpen = false;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ui.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          final receiptPreviewKey = GlobalKey();
          var printBusy = false;
          var shareBusy = false;
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> runReceiptAction({
                required bool share,
                required Future<void> Function(Uint8List pdf) action,
              }) async {
                if (printBusy || shareBusy) return;
                setSheetState(() {
                  if (share) {
                    shareBusy = true;
                  } else {
                    printBusy = true;
                  }
                });
                try {
                  final pdf = await _buildReceiptPdfFromPreview(
                    receiptPreviewKey,
                  );
                  try {
                    debugPrint(
                      'TransactionsScreen.receipt.image.v1: generated receipt PDF size=${pdf.length} bytes',
                    );
                  } catch (_) {}
                  await action(pdf);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        UserFacingError.from(
                          e,
                          fallback:
                              Localizations.localeOf(
                                    context,
                                  ).languageCode.toLowerCase() ==
                                  'sw'
                              ? 'Imeshindikana kuandaa risiti.'
                              : 'Could not prepare the receipt.',
                        ),
                      ),
                    ),
                  );
                } finally {
                  if (mounted) {
                    setSheetState(() {
                      if (share) {
                        shareBusy = false;
                      } else {
                        printBusy = false;
                      }
                    });
                  }
                }
              }

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
                              onPressed: printBusy || shareBusy
                                  ? null
                                  : () => Navigator.pop(ctx),
                              icon: Icon(Icons.close, color: ui.iconMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: RepaintBoundary(
                              key: receiptPreviewKey,
                              child: _receiptPreviewCard(
                                rows: rows,
                                heading: heading,
                                logoBytes: logoBytes,
                                barcodeValue: barcodeValue,
                                ui: ui,
                              ),
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
                                  onPressed: printBusy || shareBusy
                                      ? null
                                      : () async {
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
                                onPressed: printBusy || shareBusy
                                    ? null
                                    : () => runReceiptAction(
                                        share: false,
                                        action: (pdf) => Printing.layoutPdf(
                                          onLayout: (_) async => pdf,
                                        ),
                                      ),
                                icon: printBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.download_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  printBusy
                                      ? (Localizations.localeOf(
                                                  context,
                                                ).languageCode.toLowerCase() ==
                                                'sw'
                                            ? 'Inaandaa...'
                                            : 'Preparing...')
                                      : AppLocalizations.of(
                                          context,
                                        )!.actionDownloadPrint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: printBusy || shareBusy
                                    ? null
                                    : () => runReceiptAction(
                                        share: true,
                                        action: (pdf) => Printing.sharePdf(
                                          bytes: pdf,
                                          filename:
                                              'obi_receipt_${txId.isEmpty ? DateTime.now().millisecondsSinceEpoch : txId}.pdf',
                                        ),
                                      ),
                                icon: shareBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.share_rounded, size: 18),
                                label: Text(
                                  shareBusy
                                      ? (Localizations.localeOf(
                                                  context,
                                                ).languageCode.toLowerCase() ==
                                                'sw'
                                            ? 'Inaandaa...'
                                            : 'Preparing...')
                                      : AppLocalizations.of(
                                          context,
                                        )!.actionShareReceipt,
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
        },
      );
    } finally {
      if (mounted && loadingOverlayOpen) {
        _closeReceiptLoadingOverlay();
      }
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
                onPressed: () => _loadTransactions(forceRefresh: true),
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
          onRefresh: () => _loadTransactions(forceRefresh: true),
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
        onRefresh: () => _loadTransactions(forceRefresh: true),
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
    return OrbiBrandHeroCard(
      title: l10n.transactionsHistoryTitle,
      subtitle: sw
          ? 'Chuja, hakiki, na fungua risiti unapohitaji.'
          : 'Filter, verify, and open receipts when needed.',
      icon: Icons.receipt_long_outlined,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.summarize_outlined, size: 18),
          label: Text(sw ? 'Ripoti' : 'Report'),
          onPressed: _showTransactionReportSheet,
        ),
      ),
    );
  }

  Future<void> _showTransactionReportSheet() async {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    await OrbiResourceReportPrinter.openReportSheet(
      context,
      title: sw ? 'Ripoti ya Miamala' : 'Transaction report',
      subtitle: sw
          ? 'Audit ya miamala yako kwa kipindi ulichochagua.'
          : 'Audit of your transactions for the selected period.',
      filePrefix: 'orbi_transaction_report',
      loadReport: (range) => _receiptService.fetchReport(range: range),
    );
  }
}

class _MoneyStateFilter {
  final String key;
  final String label;

  const _MoneyStateFilter(this.key, this.label);
}

class _TransactionStatusMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _TransactionStatusMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
}
