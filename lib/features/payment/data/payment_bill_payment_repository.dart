import '../../services/data/service_actor_service.dart';

class PaymentBillPaymentRepository {
  PaymentBillPaymentRepository({ServiceActorService? service})
    : _service = service ?? ServiceActorService();

  final ServiceActorService _service;

  Future<Map<String, dynamic>> previewBillPayment(
    Map<String, dynamic> payload,
  ) {
    return _service.previewBillPayment(payload);
  }

  Future<Map<String, dynamic>> settleBillPayment(
    Map<String, dynamic> payload,
  ) {
    return _service.settleBillPayment(payload);
  }

  Future<Map<String, dynamic>> previewBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) {
    return _service.previewBillPaymentFromReserve(payload);
  }

  Future<Map<String, dynamic>> settleBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) {
    return _service.settleBillPaymentFromReserve(payload);
  }
}
