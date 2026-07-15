import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/session_currency.dart';
import '../data/wallet_models.dart';
import '../data/wallet_service.dart';
import 'wallet_error_localizer.dart';

class WalletTransactionState {
  const WalletTransactionState({
    this.items = const [],
    this.groupedByLifecycle = const {},
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<WalletTransactionRecord> items;
  final Map<TransactionLifecycle, List<WalletTransactionRecord>>
  groupedByLifecycle;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  WalletTransactionState copyWith({
    List<WalletTransactionRecord>? items,
    Map<TransactionLifecycle, List<WalletTransactionRecord>>?
    groupedByLifecycle,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return WalletTransactionState(
      items: items ?? this.items,
      groupedByLifecycle: groupedByLifecycle ?? this.groupedByLifecycle,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class WalletViewModel extends ChangeNotifier {
  WalletViewModel({
    required WalletService walletService,
    required Map<String, dynamic> session,
  }) : _walletService = walletService,
       _session = Map<String, dynamic>.from(session);

  static const Duration _provisioningRefreshInterval = Duration(seconds: 8);
  static const int _maxProvisioningAutoRefreshAttempts = 8;
  static const int _transactionPageSize = 50;

  final WalletService _walletService;
  final Map<String, dynamic> _session;

  bool _loading = true;
  String _languageCode = 'en';
  String? _error;
  List<WalletRecord> _wallets = const [];
  List<WalletRecord> _filteredWallets = const [];
  WalletFilter _selectedFilter = WalletFilter.all;
  bool _hideBalances = false;
  Timer? _provisioningRefreshTimer;
  int _provisioningRefreshAttempts = 0;
  final Map<String, WalletTransactionState> _transactionStates = {};
  bool _disposed = false;

  bool get isLoading => _loading;
  bool get isInitialLoading => _loading && _wallets.isEmpty && _error == null;
  String? get error => _error;
  bool get hideBalances => _hideBalances;
  WalletFilter get selectedFilter => _selectedFilter;
  List<WalletRecord> get wallets => _wallets;
  List<WalletRecord> get filteredWallets => _filteredWallets;
  int get walletCount => _wallets.length;
  bool get isProvisioningState =>
      !_loading && _error == null && _wallets.isEmpty;
  int get provisioningRefreshAttempts => _provisioningRefreshAttempts;
  int get maxProvisioningAutoRefreshAttempts =>
      _maxProvisioningAutoRefreshAttempts;

  void updateLanguageCode(String? languageCode) {
    final normalized = (languageCode ?? 'en').trim().toLowerCase();
    if (normalized.isEmpty || normalized == _languageCode) return;
    _languageCode = normalized;
  }

  Map<String, dynamic> get _sessionUser {
    final user = _session['user'];
    return user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{};
  }

  String get customerName =>
      (_sessionUser['full_name'] ?? _sessionUser['name'] ?? 'Account Holder')
          .toString()
          .toUpperCase();

  String? get customerId => _firstNonEmptyString([
    _sessionUser['customer_id'],
    _sessionUser['customerId'],
    _sessionUser['customerID'],
    (_sessionUser['user_metadata'] is Map
        ? (_sessionUser['user_metadata'] as Map)['customer_id']
        : null),
    (_sessionUser['user_metadata'] is Map
        ? (_sessionUser['user_metadata'] as Map)['customerId']
        : null),
    _sessionUser['fnx_id'],
    _sessionUser['fnxId'],
    _session['customer_id'],
    _session['customerId'],
  ]);

  String get sessionCurrency => resolveSessionCurrency(_session);

  WalletRecord? get primaryInternalVault {
    for (final wallet in _wallets) {
      if (wallet.isPrimaryOperatingVault) return wallet;
    }
    for (final wallet in _wallets) {
      if (wallet.isInternal && !wallet.isEscrow) return wallet;
    }
    return null;
  }

  Future<void> initialize() => refresh();

  Future<void> refresh({
    bool fromAutoRefresh = false,
    bool forceRefresh = false,
  }) async {
    final hadWalletsBefore = _wallets.isNotEmpty;
    final shouldShowLoading = !fromAutoRefresh || !hadWalletsBefore;

    if (!fromAutoRefresh) {
      _provisioningRefreshAttempts = 0;
    }
    if (shouldShowLoading) {
      _loading = true;
      _error = null;
      _notifyIfAlive();
    }

    try {
      final wallets = await _walletService.getWallets(
        forceRefresh: forceRefresh || fromAutoRefresh,
      );
      if (_disposed) return;
      final nextWallets = wallets.map(WalletRecord.fromJson).toList();
      final walletsChanged = !_walletListsEqual(_wallets, nextWallets);
      final previousError = _error;
      _wallets = nextWallets;
      _recomputeFilteredWallets();
      if (!shouldShowLoading &&
          previousError != null &&
          _error == null &&
          !walletsChanged) {
        _notifyIfAlive();
      } else if (!shouldShowLoading && walletsChanged) {
        _notifyIfAlive();
      }
    } catch (error, stackTrace) {
      if (_disposed) return;
      _error = localizeWalletFetchError(error, languageCode: _languageCode);
      _reportError(error, stackTrace, context: 'wallets_fetch');
      if (!shouldShowLoading) {
        _notifyIfAlive();
      }
    } finally {
      if (!_disposed) {
        _loading = false;
        _syncProvisioningAutoRefresh();
        if (shouldShowLoading) {
          _notifyIfAlive();
        }
      }
    }
  }

  void setFilter(WalletFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _recomputeFilteredWallets();
    _notifyIfAlive();
  }

  void toggleBalances() {
    _hideBalances = !_hideBalances;
    _notifyIfAlive();
  }

  void handleRealtimeEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString().toUpperCase();
    if (type == 'BALANCE_UPDATE') {
      final walletId = (event['wallet_id'] ?? '').toString();
      final balance = _asDoubleOrNull(event['balance']);
      if (walletId.isNotEmpty &&
          balance != null &&
          _applyBalanceUpdate(walletId, balance)) {
        return;
      }
    }
    unawaited(refresh(fromAutoRefresh: true, forceRefresh: true));
  }

  WalletTransactionState transactionsFor(String walletId) {
    return _transactionStates[walletId] ?? const WalletTransactionState();
  }

  Future<void> loadTransactions(
    WalletRecord wallet, {
    bool loadMore = false,
  }) async {
    final current = transactionsFor(wallet.id);
    if (current.isLoading) return;
    if (loadMore && !current.hasMore) return;

    _transactionStates[wallet.id] = current.copyWith(
      isLoading: true,
      error: null,
    );
    _notifyIfAlive();

    try {
      final nextOffset = loadMore ? current.items.length : 0;
      final rawItems = await _walletService.getWalletTransactions(
        wallet.id,
        limit: _transactionPageSize,
        offset: nextOffset,
      );
      if (_disposed) return;
      final fetched = rawItems
          .map(
            (item) => WalletTransactionRecord.fromJson(
              item,
              fallbackCurrency: wallet.currency.isEmpty
                  ? sessionCurrency
                  : wallet.currency,
            ),
          )
          .toList();

      final merged = loadMore
          ? _mergeTransactions(current.items, fetched)
          : fetched;
      _transactionStates[wallet.id] = WalletTransactionState(
        items: merged,
        groupedByLifecycle: _groupTransactions(merged),
        isLoading: false,
        hasMore: fetched.length == _transactionPageSize,
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      _transactionStates[wallet.id] = current.copyWith(
        isLoading: false,
        error: localizeWalletTransactionError(
          error,
          languageCode: _languageCode,
        ),
      );
      _reportError(error, stackTrace, context: 'wallet_transactions');
    }
    _notifyIfAlive();
  }

  bool _applyBalanceUpdate(String walletId, double balance) {
    final index = _wallets.indexWhere(
      (wallet) =>
          wallet.id.trim().toLowerCase() == walletId.trim().toLowerCase(),
    );
    if (index == -1) return false;
    final updated = List<WalletRecord>.from(_wallets);
    updated[index] = updated[index].copyWith(balance: balance);
    _wallets = updated;
    _recomputeFilteredWallets();
    _notifyIfAlive();
    return true;
  }

  bool _walletListsEqual(List<WalletRecord> current, List<WalletRecord> next) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.balance != b.balance ||
          a.currency != b.currency ||
          a.name != b.name ||
          a.status != b.status ||
          a.type != b.type) {
        return false;
      }
    }
    return true;
  }

  void _recomputeFilteredWallets() {
    final source = _wallets
        .where((wallet) => !wallet.isEscrow && !wallet.isPrimaryOperatingVault)
        .toList();
    switch (_selectedFilter) {
      case WalletFilter.all:
        _filteredWallets = source;
        break;
      case WalletFilter.internal:
        _filteredWallets = source.where((wallet) => wallet.isInternal).toList();
        break;
      case WalletFilter.linked:
        _filteredWallets = source.where((wallet) => wallet.isLinked).toList();
        break;
    }
  }

  Map<TransactionLifecycle, List<WalletTransactionRecord>> _groupTransactions(
    List<WalletTransactionRecord> items,
  ) {
    final grouped = <TransactionLifecycle, List<WalletTransactionRecord>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.lifecycle, () => <WalletTransactionRecord>[])
          .add(item);
    }
    return grouped;
  }

  List<WalletTransactionRecord> _mergeTransactions(
    List<WalletTransactionRecord> current,
    List<WalletTransactionRecord> next,
  ) {
    final merged = <WalletTransactionRecord>[...current];
    final seen = current.map((item) => item.id).toSet();
    for (final item in next) {
      if (seen.add(item.id)) merged.add(item);
    }
    return merged;
  }

  void _syncProvisioningAutoRefresh() {
    if (!isProvisioningState) {
      _provisioningRefreshTimer?.cancel();
      _provisioningRefreshTimer = null;
      return;
    }
    if (_provisioningRefreshAttempts >= _maxProvisioningAutoRefreshAttempts) {
      _provisioningRefreshTimer?.cancel();
      _provisioningRefreshTimer = null;
      return;
    }
    if (_provisioningRefreshTimer?.isActive ?? false) {
      return;
    }

    _provisioningRefreshTimer = Timer(_provisioningRefreshInterval, () async {
      if (_disposed) return;
      _provisioningRefreshAttempts += 1;
      await refresh(fromAutoRefresh: true);
    });
  }

  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  void _reportError(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    debugPrint('wallet_error [$context] $error');
    debugPrintStack(stackTrace: stackTrace);
    // Integrate remote error reporting here if the app adds one later.
  }

  double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    _disposed = true;
    _provisioningRefreshTimer?.cancel();
    super.dispose();
  }
}

String? _firstNonEmptyString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
