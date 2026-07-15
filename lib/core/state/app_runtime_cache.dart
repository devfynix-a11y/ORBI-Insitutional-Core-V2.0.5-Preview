import '../utils/money_format.dart';

class AppRuntimeCache {
  AppRuntimeCache._();

  static Map<String, dynamic>? _profile;
  static List<Map<String, dynamic>>? _wallets;
  static List<Map<String, dynamic>>? _recentTransactions;
  static String _currency = '';
  static DateTime? _walletsCachedAt;
  static DateTime? _transactionsCachedAt;

  static const Duration walletsTtl = Duration(minutes: 2);
  static const Duration transactionsTtl = Duration(seconds: 45);

  static Map<String, dynamic>? get profile =>
      _profile == null ? null : Map<String, dynamic>.from(_profile!);

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

  static String get currency => _currency;

  static void rememberProfile(Map<String, dynamic> profile) {
    _profile = Map<String, dynamic>.from(profile);
    _rememberCurrencyFrom(_profile!);
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
    _wallets = null;
    _recentTransactions = null;
    _currency = '';
    _walletsCachedAt = null;
    _transactionsCachedAt = null;
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
