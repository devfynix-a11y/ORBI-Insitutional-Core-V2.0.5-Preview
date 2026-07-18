import '../utils/money_format.dart';

class AppRuntimeCache {
  AppRuntimeCache._();

  static Map<String, dynamic>? _profile;
  static Map<String, dynamic>? _dashboardPayload;
  static List<Map<String, dynamic>>? _wallets;
  static List<Map<String, dynamic>>? _recentTransactions;
  static List<Map<String, dynamic>>? _goals;
  static List<Map<String, dynamic>>? _categories;
  static List<Map<String, dynamic>>? _tasks;
  static String _currency = '';
  static DateTime? _dashboardCachedAt;
  static DateTime? _walletsCachedAt;
  static DateTime? _transactionsCachedAt;

  static const Duration dashboardTtl = Duration(seconds: 30);
  static const Duration walletsTtl = Duration(minutes: 2);
  static const Duration transactionsTtl = Duration(seconds: 45);

  static Map<String, dynamic>? get profile =>
      _profile == null ? null : Map<String, dynamic>.from(_profile!);

  static Map<String, dynamic>? get freshDashboardPayload {
    final cached = _dashboardPayload;
    final cachedAt = _dashboardCachedAt;
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > dashboardTtl) return null;
    return Map<String, dynamic>.from(cached);
  }

  static List<Map<String, dynamic>>? get freshWallets {
    final cached = _wallets;
    final cachedAt = _walletsCachedAt;
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > walletsTtl) return null;
    return cached.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static List<Map<String, dynamic>>? get freshRecentTransactions {
    final cached = _recentTransactions;
    final cachedAt = _transactionsCachedAt;
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > transactionsTtl) return null;
    return cached.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static List<Map<String, dynamic>>? get goals {
    if (freshDashboardPayload == null) return null;
    return _goals?.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static List<Map<String, dynamic>>? get categories {
    if (freshDashboardPayload == null) return null;
    return _categories?.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static List<Map<String, dynamic>>? get tasks {
    if (freshDashboardPayload == null) return null;
    return _tasks?.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static String get currency => _currency;

  static void rememberProfile(Map<String, dynamic> profile) {
    _profile = Map<String, dynamic>.from(profile);
    _rememberCurrencyFrom(_profile!);
  }

  static void rememberDashboardPayload(Map<String, dynamic> payload) {
    _dashboardPayload = Map<String, dynamic>.from(payload);
    _dashboardCachedAt = DateTime.now();
    _rememberCurrencyFrom(_dashboardPayload!);

    final profile = _firstMap([
      payload['profile'],
      payload['user'],
      payload['account'],
    ]);
    if (profile != null) rememberProfile(profile);

    final wallets = _firstListOfMaps([
      payload['wallets'],
      payload['accounts'],
      payload['walletAccounts'],
      payload['wallet_accounts'],
    ]);
    if (wallets.isNotEmpty) rememberWallets(wallets);

    final transactions = _firstListOfMaps([
      payload['transactions'],
      payload['recentTransactions'],
      payload['recent_transactions'],
      payload['history'],
    ]);
    if (transactions.isNotEmpty) rememberRecentTransactions(transactions);

    final goals = _firstListOfMaps([
      payload['goals'],
      payload['savingGoals'],
      payload['saving_goals'],
    ]);
    if (goals.isNotEmpty) _goals = goals;

    final categories = _firstListOfMaps([
      payload['categories'],
      payload['budgets'],
      payload['budgetCategories'],
      payload['budget_categories'],
    ]);
    if (categories.isNotEmpty) _categories = categories;

    final tasks = _firstListOfMaps([
      payload['tasks'],
      payload['upcomingBills'],
      payload['upcoming_bills'],
      payload['billReserves'],
      payload['bill_reserves'],
    ]);
    if (tasks.isNotEmpty) _tasks = tasks;
  }

  static void rememberSession(Map<String, dynamic> session) {
    _rememberCurrency(_resolveCurrencyFrom(session));
    final user = session['user'];
    if (user is Map) {
      rememberProfile(Map<String, dynamic>.from(user));
    }
  }

  static void rememberWallets(List<Map<String, dynamic>> wallets) {
    _wallets = wallets.map((item) => Map<String, dynamic>.from(item)).toList();
    _walletsCachedAt = DateTime.now();
    for (final wallet in wallets) {
      _rememberCurrencyFrom(wallet);
      if (_currency.isNotEmpty) break;
    }
  }

  static void rememberRecentTransactions(List<Map<String, dynamic>> items) {
    _recentTransactions = items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _transactionsCachedAt = DateTime.now();
    for (final item in items) {
      _rememberCurrencyFrom(item);
      if (_currency.isNotEmpty) break;
    }
  }

  static void clearWallets() {
    _wallets = null;
    _walletsCachedAt = null;
  }

  static void clearTransactions() {
    _recentTransactions = null;
    _transactionsCachedAt = null;
  }

  static void clear() {
    _profile = null;
    _dashboardPayload = null;
    _wallets = null;
    _recentTransactions = null;
    _goals = null;
    _categories = null;
    _tasks = null;
    _currency = '';
    _dashboardCachedAt = null;
    _walletsCachedAt = null;
    _transactionsCachedAt = null;
  }

  static Map<String, dynamic>? _firstMap(List<dynamic> values) {
    for (final value in values) {
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<Map<String, dynamic>> _firstListOfMaps(List<dynamic> values) {
    for (final value in values) {
      if (value is List) {
        final items = value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        if (items.isNotEmpty) return items;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static void _rememberCurrencyFrom(Map<String, dynamic> source) {
    _rememberCurrency(_resolveCurrencyFrom(source));
  }

  static void _rememberCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    if (normalized.isNotEmpty) {
      _currency = normalized;
    }
  }

  static String _resolveCurrencyFrom(Map<dynamic, dynamic> source) {
    return resolveCurrencyCode(_currencyCandidatesFromMap(source));
  }

  static List<dynamic> _currencyCandidatesFromMap(
    Map<dynamic, dynamic> source,
  ) {
    final values = <dynamic>[
      source['currency'],
      source['currency_code'],
      source['currencyCode'],
      source['preferred_currency'],
      source['preferredCurrency'],
      source['account_currency'],
      source['accountCurrency'],
      source['asset_currency'],
      source['assetCurrency'],
      source['default_currency'],
      source['defaultCurrency'],
    ];

    void addFrom(dynamic value) {
      if (value is Map) {
        values.addAll(_currencyCandidatesFromMap(value));
      } else if (value is List) {
        for (final item in value) {
          addFrom(item);
        }
      }
    }

    for (final key in const [
      'user',
      'profile',
      'account',
      'primary_account',
      'primaryAccount',
      'wallet',
      'primary_wallet',
      'primaryWallet',
      'metadata',
    ]) {
      addFrom(source[key]);
    }

    for (final key in const [
      'accounts',
      'wallets',
      'walletAccounts',
      'wallet_accounts',
      'balances',
      'vaults',
      'platformVaults',
      'platform_vaults',
    ]) {
      addFrom(source[key]);
    }

    return values;
  }
}
