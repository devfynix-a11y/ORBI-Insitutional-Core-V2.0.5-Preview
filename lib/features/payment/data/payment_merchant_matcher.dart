import 'scan_pay_service.dart';
import 'payment_routing_catalog_service.dart';
import 'payment_provider_normalizer.dart';

class PaymentMerchantMatch {
  const PaymentMerchantMatch({
    required this.reference,
    required this.displayName,
  });

  final String reference;
  final String displayName;
}

class PaymentMerchantMatcher {
  const PaymentMerchantMatcher();

  PaymentMerchantMatch? matchIntent(
    ScanPayIntent intent, {
    List<PaymentMerchantDirectoryEntry> directory = const <PaymentMerchantDirectoryEntry>[],
  }) {
    final direct = _firstNonEmpty([
      intent.recipientInput,
      intent.merchantId,
      intent.reference,
    ]);
    final matchedEntry = _matchDirectory(
      directory,
      candidates: [
        intent.merchantId,
        intent.recipientInput,
        intent.merchantName,
        intent.reference,
      ],
    );
    final reference = matchedEntry?.reference ?? direct;
    if (reference == null) return null;
    final displayName = matchedEntry?.displayName ??
        _firstNonEmpty([
          intent.merchantName,
          intent.provider,
          intent.recipientInput,
          intent.merchantId,
        ]) ??
        reference;
    return PaymentMerchantMatch(
      reference: reference,
      displayName: displayName,
    );
  }

  PaymentMerchantMatch? matchManualInput(String raw) {
    final reference = raw.trim();
    if (reference.isEmpty) return null;
    return PaymentMerchantMatch(
      reference: reference,
      displayName: reference,
    );
  }

  PaymentMerchantDirectoryEntry? _matchDirectory(
    List<PaymentMerchantDirectoryEntry> directory, {
    required List<String?> candidates,
  }) {
    for (final candidate in candidates) {
      final normalized = candidate == null
          ? null
          : PaymentProviderNormalizer.normalize(candidate);
      if (normalized == null || normalized.isEmpty) continue;
      for (final entry in directory) {
        if (PaymentProviderNormalizer.normalize(entry.reference) == normalized ||
            PaymentProviderNormalizer.normalize(entry.displayName) == normalized ||
            entry.aliases.any(
              (alias) => PaymentProviderNormalizer.normalize(alias) == normalized,
            )) {
          return entry;
        }
      }
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
