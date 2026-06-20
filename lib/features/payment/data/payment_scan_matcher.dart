import 'scan_pay_service.dart';

enum PaymentScanKind { merchant, bill, universal }

class PaymentScanMatcher {
  const PaymentScanMatcher();

  PaymentScanKind classify(ScanPayIntent intent) {
    if ((intent.billCategory ?? '').trim().isNotEmpty ||
        (intent.provider ?? '').trim().isNotEmpty) {
      return PaymentScanKind.bill;
    }
    if ((intent.merchantId ?? '').trim().isNotEmpty ||
        (intent.merchantName ?? '').trim().isNotEmpty) {
      return PaymentScanKind.merchant;
    }
    return PaymentScanKind.universal;
  }
}
