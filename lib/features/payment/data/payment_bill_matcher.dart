import 'scan_pay_service.dart';
import 'payment_provider_normalizer.dart';

class PaymentBillMatch {
  const PaymentBillMatch({
    required this.categoryIndex,
    required this.providerIndex,
  });

  final int categoryIndex;
  final int providerIndex;
}

class PaymentBillMatcher {
  const PaymentBillMatcher();

  static const Map<String, int> _billProviderCategoryAliases = {
    'tanesco': 0,
    'zesco': 0,
    'luku': 0,
    'electricity': 0,
    'power': 0,
    'water': 1,
    'water bills': 1,
    'dawasa': 1,
    'ruwasa': 1,
    'maji ya mkoa': 1,
    'gas': 2,
    'oryx gas': 2,
    'taifa gas': 2,
    'lake gas': 2,
    'bundles': 3,
    'bundle': 3,
    'bando': 3,
    'vodacom': 3,
    'airtel': 3,
    'tigo': 3,
    'mix by yas': 3,
    'halotel': 3,
    'internet': 4,
    'ttcl': 4,
    'zuku': 4,
    'simbanet': 4,
    'liquid telecom': 4,
    'school fees': 5,
    'school': 5,
    'ada ya shule': 5,
    'ada ya chuo': 5,
    'hosteli': 5,
    'government': 6,
    'government bills': 6,
    'tra': 6,
    'egovernment': 6,
    'nida': 6,
    'local government': 6,
    'insurance': 7,
    'bima': 7,
    'nhif': 7,
    'jubilee': 7,
    'nic': 7,
    'alliance life': 7,
    'telephone': 8,
    'ttcl voice': 8,
    'office line': 8,
    'business tel': 8,
    'entertainment': 9,
    'dstv': 9,
    'azam tv': 9,
    'startimes': 9,
    'netflix': 9,
    'other bills': 10,
    'service invoice': 10,
    'membership fee': 10,
    'custom provider': 10,
  };

  PaymentBillMatch? match(
    ScanPayIntent intent,
    List<List<String>> providersByCategory, {
    Map<String, int> additionalAliases = const {},
  }) {
    final categoryIndex = _resolveBillCategoryIndex(
      intent,
      additionalAliases: additionalAliases,
    );
    if (categoryIndex == null || categoryIndex >= providersByCategory.length) {
      return null;
    }
    final providerIndex = _resolveBillProviderIndex(
      providersByCategory[categoryIndex],
      intent,
    );
    return PaymentBillMatch(
      categoryIndex: categoryIndex,
      providerIndex: providerIndex,
    );
  }

  int? _resolveBillCategoryIndex(
    ScanPayIntent intent, {
    Map<String, int> additionalAliases = const {},
  }) {
    final aliasMap = <String, int>{
      ..._billProviderCategoryAliases,
      ...additionalAliases.map(
        (key, value) => MapEntry(key.trim().toLowerCase(), value),
      ),
    };
    final candidates = [intent.billCategory, intent.provider, intent.merchantName];
    for (final candidate in candidates) {
      final normalized = candidate == null
          ? null
          : PaymentProviderNormalizer.normalize(candidate);
      if (normalized == null || normalized.isEmpty) continue;
      for (final entry in aliasMap.entries) {
        if (normalized == entry.key || normalized.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  int _resolveBillProviderIndex(
    List<String> providers,
    ScanPayIntent intent,
  ) {
    final candidates = [intent.provider, intent.merchantName, intent.recipientInput];
    for (final candidate in candidates) {
      final normalized = candidate == null
          ? null
          : PaymentProviderNormalizer.normalize(candidate);
      if (normalized == null || normalized.isEmpty) continue;
      final index = providers.indexWhere(
        (provider) {
          final providerKey = PaymentProviderNormalizer.normalize(provider);
          return providerKey == normalized ||
              providerKey.contains(normalized) ||
              normalized.contains(providerKey);
        },
      );
      if (index >= 0) return index;
    }
    return 0;
  }
}
