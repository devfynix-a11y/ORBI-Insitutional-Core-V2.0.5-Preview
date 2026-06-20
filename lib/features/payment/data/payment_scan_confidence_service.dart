import 'payment_scan_matcher.dart';
import 'scan_pay_service.dart';

enum PaymentScanConfidenceLevel { high, medium, low, invalid }

class PaymentScanConfidence {
  const PaymentScanConfidence({
    required this.level,
    required this.score,
  });

  final PaymentScanConfidenceLevel level;
  final double score;
}

class PaymentScanConfidenceService {
  const PaymentScanConfidenceService();

  PaymentScanConfidence evaluate(
    ScanPayIntent? intent,
    PaymentScanKind kind,
  ) {
    if (intent == null || intent.rawValue.trim().isEmpty) {
      return const PaymentScanConfidence(
        level: PaymentScanConfidenceLevel.invalid,
        score: 0,
      );
    }

    var score = 0.0;
    if ((intent.recipientInput ?? '').trim().isNotEmpty) score += 0.34;
    if ((intent.amount ?? '').trim().isNotEmpty) score += 0.18;
    if ((intent.reference ?? '').trim().isNotEmpty) score += 0.12;
    if ((intent.note ?? '').trim().isNotEmpty) score += 0.06;
    if (intent.isOrbiSchema) score += 0.20;

    switch (kind) {
      case PaymentScanKind.bill:
        if ((intent.provider ?? '').trim().isNotEmpty) score += 0.06;
        if ((intent.billCategory ?? '').trim().isNotEmpty) score += 0.10;
        break;
      case PaymentScanKind.merchant:
        if ((intent.merchantId ?? '').trim().isNotEmpty) score += 0.08;
        if ((intent.merchantName ?? '').trim().isNotEmpty) score += 0.10;
        break;
      case PaymentScanKind.universal:
        break;
    }

    final normalized = score.clamp(0.0, 1.0);
    if (normalized < 0.18) {
      return PaymentScanConfidence(
        level: PaymentScanConfidenceLevel.invalid,
        score: normalized,
      );
    }
    if (normalized < 0.5) {
      return PaymentScanConfidence(
        level: PaymentScanConfidenceLevel.low,
        score: normalized,
      );
    }
    if (normalized < 0.8) {
      return PaymentScanConfidence(
        level: PaymentScanConfidenceLevel.medium,
        score: normalized,
      );
    }
    return PaymentScanConfidence(
      level: PaymentScanConfidenceLevel.high,
      score: normalized,
    );
  }
}
