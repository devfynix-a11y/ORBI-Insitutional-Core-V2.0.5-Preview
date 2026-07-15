import '../state/app_runtime_cache.dart';
import 'money_format.dart';

String resolveSessionCurrency(Map<String, dynamic> session) {
  return resolveCurrencyCode([
    ..._currencyCandidatesFromMap(session),
    AppRuntimeCache.currency,
  ]);
}

String resolveProfileCurrency(Map<String, dynamic> profile) {
  return resolveCurrencyCode([
    ..._currencyCandidatesFromMap(profile),
    AppRuntimeCache.currency,
  ]);
}

List<dynamic> _currencyCandidatesFromMap(Map<dynamic, dynamic> source) {
  final values = <dynamic>[
    source['currency'],
    source['currency_code'],
    source['currencyCode'],
    source['preferred_currency'],
    source['preferredCurrency'],
    source['account_currency'],
    source['accountCurrency'],
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
