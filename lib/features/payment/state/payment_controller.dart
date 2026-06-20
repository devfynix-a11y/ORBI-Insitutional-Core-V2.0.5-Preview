import 'package:flutter/foundation.dart';

import '../../../core/utils/user_facing_error.dart';
import '../data/models/bill_provider_catalog.dart';
import '../data/payment_bill_catalog_repository.dart';
import '../data/payment_bill_payment_repository.dart';
import '../data/payment_orbi_pay_repository.dart';

class PaymentController extends ChangeNotifier {
  PaymentController({
    PaymentBillCatalogRepository? billCatalogRepository,
    PaymentBillPaymentRepository? billPaymentRepository,
    PaymentOrbiPayRepository? orbiPayRepository,
  })
    : _billCatalogRepository =
          billCatalogRepository ?? PaymentBillCatalogRepository(),
      _billPaymentRepository =
          billPaymentRepository ?? PaymentBillPaymentRepository(),
      _orbiPayRepository = orbiPayRepository ?? PaymentOrbiPayRepository();

  final PaymentBillCatalogRepository _billCatalogRepository;
  final PaymentBillPaymentRepository _billPaymentRepository;
  final PaymentOrbiPayRepository _orbiPayRepository;

  List<BillProviderCategory> _billCategories = const [];
  bool _isBillCatalogLoading = false;
  String? _billCatalogError;

  List<BillProviderCategory> get billCategories => _billCategories;
  bool get isBillCatalogLoading => _isBillCatalogLoading;
  String? get billCatalogError => _billCatalogError;

  Future<void> loadBillCatalog({bool notify = true}) async {
    _isBillCatalogLoading = true;
    _billCatalogError = null;
    if (notify) notifyListeners();

    try {
      _billCategories = await _billCatalogRepository.fetchBillCategories();
    } catch (error) {
      _billCatalogError = UserFacingError.from(
        error,
        fallback: 'Unable to load bill providers right now.',
      );
      _billCategories = const [];
    } finally {
      _isBillCatalogLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<Map<String, dynamic>> previewBillPayment(
    Map<String, dynamic> payload,
  ) {
    return _billPaymentRepository.previewBillPayment(payload);
  }

  Future<Map<String, dynamic>> settleBillPayment(
    Map<String, dynamic> payload,
  ) {
    return _billPaymentRepository.settleBillPayment(payload);
  }

  Future<Map<String, dynamic>> previewBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) {
    return _billPaymentRepository.previewBillPaymentFromReserve(payload);
  }

  Future<Map<String, dynamic>> settleBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) {
    return _billPaymentRepository.settleBillPaymentFromReserve(payload);
  }

  Future<Map<String, dynamic>> previewOrbiPay(Map<String, dynamic> payload) {
    return _orbiPayRepository.previewOrbiPay(payload);
  }

  Future<Map<String, dynamic>> settleOrbiPay(Map<String, dynamic> payload) {
    return _orbiPayRepository.settleOrbiPay(payload);
  }
}
