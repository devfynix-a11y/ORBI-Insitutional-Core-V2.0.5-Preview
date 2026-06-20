import '../../services/data/service_actor_service.dart';

class PaymentOrbiPayRepository {
  PaymentOrbiPayRepository({ServiceActorService? service})
    : _service = service ?? ServiceActorService();

  final ServiceActorService _service;

  Future<Map<String, dynamic>> previewOrbiPay(Map<String, dynamic> payload) {
    return _service.previewOrbiPay(payload);
  }

  Future<Map<String, dynamic>> settleOrbiPay(Map<String, dynamic> payload) {
    return _service.settleOrbiPay(payload);
  }
}
