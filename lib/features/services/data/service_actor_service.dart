import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class ServiceActorService {
  ServiceActorService([ApiClient? client])
    : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listMerchantWallets() async {
    final response = await _dio.get(
      AppConfig.endpoints['merchantWallets'] ?? '/merchant/wallets',
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listMerchantTransactions() async {
    final response = await _dio.get(
      AppConfig.endpoints['merchantTransactions'] ?? '/merchant/transactions',
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listMerchantCustomers() async {
    final response = await _dio.get(
      AppConfig.endpoints['merchantCustomers'] ?? '/merchant/customers',
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listAgentWallets() async {
    final response = await _dio.get(
      AppConfig.endpoints['agentWallets'] ?? '/agent/wallets',
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listAgentTransactions() async {
    final response = await _dio.get(
      AppConfig.endpoints['agentTransactions'] ?? '/agent/transactions',
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listAgentCustomers() async {
    final response = await _dio.get(
      AppConfig.endpoints['agentCustomers'] ?? '/agent/customers',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> lookupAgentByCode(String query) async {
    final response = await _dio.get(
      AppConfig.endpoints['agentLookup'] ?? '/agent/lookup',
      queryParameters: {'q': query},
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listAgentCommissions() async {
    final response = await _dio.get(
      AppConfig.endpoints['agentCommissions'] ?? '/agent/commissions',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> previewMerchantPayment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['merchantPaymentPreview'] ??
          '/merchant/payments/preview',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleMerchantPayment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['merchantPaymentSettle'] ??
          '/merchant/payments/settle',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> previewOrbiPay(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['orbiPayPreview'] ?? '/payments/orbi-pay/preview',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleOrbiPay(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['orbiPaySettle'] ?? '/payments/orbi-pay/settle',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listBillPaymentProviders() async {
    final response = await _dio.get(
      AppConfig.endpoints['billPayProviders'] ?? '/payments/bills/providers',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> previewBillPayment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['billPayPreview'] ?? '/payments/bills/preview',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleBillPayment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['billPaySettle'] ?? '/payments/bills/settle',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> previewBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['billPayReservePreview'] ??
          '/payments/bills/preview-from-reserve',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleBillPaymentFromReserve(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['billPayReserveSettle'] ??
          '/payments/bills/settle-from-reserve',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> previewAgentDeposit(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['agentDepositPreview'] ??
          '/agent/cash/deposit/preview',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleAgentDeposit(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['agentDepositSettle'] ?? '/agent/cash/deposit/settle',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> previewAgentWithdrawal(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['agentWithdrawPreview'] ??
          '/agent/cash/withdraw/preview',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleAgentWithdrawal(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['agentWithdrawSettle'] ??
          '/agent/cash/withdraw/settle',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> registerCustomerForActor({
    required String actorRole,
    required Map<String, dynamic> payload,
  }) async {
    final normalizedRole = actorRole.trim().toUpperCase();
    final endpoint = normalizedRole == 'AGENT'
        ? (AppConfig.endpoints['agentCustomerRegister'] ??
              '/agent/customers/register')
        : (AppConfig.endpoints['merchantCustomerRegister'] ??
              '/merchant/customers/register');
    final response = await _dio.post(endpoint, data: payload);
    return _extractItem(response.data);
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    final data = _unwrap(raw);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final items =
          data['items'] ??
          data['results'] ??
          data['categories'] ??
          data['providers'] ??
          data['transactions'] ??
          data['wallets'] ??
          data['customers'] ??
          data['commissions'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractItem(dynamic raw) {
    final data = _unwrap(raw);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['data'] ?? raw;
    }
    return raw;
  }
}
