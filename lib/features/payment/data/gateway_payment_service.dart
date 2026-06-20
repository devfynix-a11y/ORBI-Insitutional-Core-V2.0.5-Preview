import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'gateway_payment_models.dart';
import 'payment_rail_capability.dart';

class GatewayPaymentService {
  GatewayPaymentService([ApiClient? client])
    : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<List<GatewayProvider>> listProviders({
    String? countryCode,
    String? currency,
    String? rail,
    String? operation,
    double? amount,
  }) async {
    try {
      final response = await _dio.get(
        AppConfig.endpoints['paymentMethods'] ?? '/payment-methods',
        queryParameters: {
          if ((countryCode ?? '').trim().isNotEmpty)
            'countryCode': countryCode!.trim().toUpperCase(),
          if ((currency ?? '').trim().isNotEmpty)
            'currency': currency!.trim().toUpperCase(),
          if ((rail ?? '').trim().isNotEmpty)
            'rail': rail!.trim().toUpperCase(),
          if ((operation ?? '').trim().isNotEmpty)
            'operation': operation!.trim().toUpperCase(),
          if (amount != null && amount.isFinite) 'amount': amount,
        },
      );
      final data = _unwrap(response.data);
      final capabilities = _extractList(data, [
        'paymentMethods',
        'capabilities',
        'providers',
        'items',
        'results',
      ]);
      return capabilities
          .map(PaymentRailCapability.fromJson)
          .map(_capabilityToProvider)
          .toList();
    } on DioException {
      final response = await _dio.get(
        AppConfig.endpoints['gatewayProviders'] ?? '/gateway/providers',
      );
      final data = _unwrap(response.data);
      final providers = _extractList(data, ['providers']);
      return providers.map(GatewayProvider.fromJson).toList();
    }
  }

  Future<GatewayPaymentInitiationResult> initiatePayment({
    required String providerId,
    required String paymentMethodId,
    required double amount,
    required String currency,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post(
      AppConfig.endpoints['gatewayPaymentInitiate'] ??
          '/gateway/payment/initiate',
      data: {
        'providerId': providerId,
        'paymentMethodId': paymentMethodId,
        'amount': amount,
        'currency': currency,
        if ((description ?? '').trim().isNotEmpty) 'description': description,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
    return GatewayPaymentInitiationResult.fromJson(_extractMap(response.data));
  }

  Future<GatewaySettlementRecord> settlePayment({
    required String orderId,
    required String providerId,
    required String targetWalletId,
    int? autoSettleMinutes,
  }) async {
    final response = await _dio.post(
      _resolveTemplate(
        AppConfig.endpoints['gatewayPaymentSettleTemplate'] ??
            '/gateway/payment/{orderId}/settle',
        'orderId',
        orderId,
      ),
      data: {
        'providerId': providerId,
        'targetWalletId': targetWalletId,
        'autoSettleMinutes': ?autoSettleMinutes,
      },
    );
    return GatewaySettlementRecord.fromJson(_extractMap(response.data));
  }

  Future<GatewaySettlementActionResult> refundPayment({
    required String orderId,
    required String providerId,
    String? reason,
  }) async {
    final response = await _dio.post(
      _resolveTemplate(
        AppConfig.endpoints['gatewayPaymentRefundTemplate'] ??
            '/gateway/payment/{orderId}/refund',
        'orderId',
        orderId,
      ),
      data: {
        'providerId': providerId,
        if ((reason ?? '').trim().isNotEmpty) 'reason': reason,
      },
    );
    return GatewaySettlementActionResult.fromJson(_extractMap(response.data));
  }

  Future<List<GatewayOrder>> listOrders() async {
    final response = await _dio.get(
      AppConfig.endpoints['gatewayPaymentOrders'] ?? '/gateway/orders',
    );
    final data = _unwrap(response.data);
    final orders = _extractList(data, ['orders']);
    return orders.map(GatewayOrder.fromJson).toList();
  }

  Future<GatewayOrder> getOrder(String orderId) async {
    final response = await _dio.get(
      _resolveTemplate(
        AppConfig.endpoints['gatewayPaymentOrderTemplate'] ??
            '/gateway/order/{orderId}',
        'orderId',
        orderId,
      ),
    );
    final data = _unwrap(response.data);
    final order = _extractNestedMap(data, ['order']);
    return GatewayOrder.fromJson(order);
  }

  Future<GatewaySettlementStatus> getSettlementStatus(
    String settlementId,
  ) async {
    final response = await _dio.get(
      _resolveTemplate(
        AppConfig.endpoints['gatewaySettlementStatusTemplate'] ??
            '/gateway/settlement/{settlementId}/status',
        'settlementId',
        settlementId,
      ),
    );
    return GatewaySettlementStatus.fromJson(_extractMap(response.data));
  }

  Future<GatewaySettlementActionResult> confirmSettlement(
    String settlementId,
  ) async {
    final response = await _dio.post(
      _resolveTemplate(
        AppConfig.endpoints['gatewaySettlementConfirmTemplate'] ??
            '/gateway/settlement/{settlementId}/confirm',
        'settlementId',
        settlementId,
      ),
    );
    return GatewaySettlementActionResult.fromJson(_extractMap(response.data));
  }

  Future<GatewaySettlementActionResult> disputeSettlement({
    required String settlementId,
    required String reason,
  }) async {
    final response = await _dio.post(
      _resolveTemplate(
        AppConfig.endpoints['gatewaySettlementDisputeTemplate'] ??
            '/gateway/settlement/{settlementId}/dispute',
        'settlementId',
        settlementId,
      ),
      data: {'reason': reason},
    );
    return GatewaySettlementActionResult.fromJson(_extractMap(response.data));
  }

  Future<List<GatewaySettlementSummary>> listSettlements({
    String? phase,
  }) async {
    final response = await _dio.get(
      AppConfig.endpoints['gatewaySettlements'] ?? '/gateway/settlements',
      queryParameters: {if ((phase ?? '').trim().isNotEmpty) 'phase': phase},
    );
    final data = _unwrap(response.data);
    final settlements = _extractList(data, ['settlements']);
    return settlements.map(GatewaySettlementSummary.fromJson).toList();
  }

  Map<String, dynamic> _extractMap(dynamic raw) {
    final data = _unwrap(raw);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _extractNestedMap(dynamic raw, List<String> keys) {
    final data = _extractMap(raw);
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return data;
  }

  List<Map<String, dynamic>> _extractList(dynamic raw, List<String> keys) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    final data = _extractMap(raw);
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['data'] ?? raw;
    }
    return raw;
  }

  String _resolveTemplate(String template, String key, String value) {
    return template.replaceAll('{$key}', value);
  }

  GatewayProvider _capabilityToProvider(PaymentRailCapability capability) {
    final metadata = Map<String, dynamic>.from(capability.metadata);
    metadata['payment_rail_capability'] = Map<String, dynamic>.from(
      capability.raw,
    );
    return GatewayProvider.fromJson({
      ...capability.raw,
      'id': capability.capabilityCode,
      'name': capability.brandLabel,
      'brandName': capability.brandLabel,
      'type': capability.rail,
      'group': capability.groupLabel,
      'supportedCurrencies': [capability.currency],
      'channels': [_channelFromRail(capability.rail)],
      'metadata': metadata,
    });
  }

  String _channelFromRail(String rail) {
    switch (rail.trim().toUpperCase()) {
      case 'MOBILE_MONEY':
        return 'mobile_money';
      case 'BANK':
        return 'bank_transfer';
      case 'CARD_GATEWAY':
        return 'card';
      case 'CRYPTO':
        return 'crypto';
      case 'WALLET':
        return 'wallet';
      default:
        return rail.toLowerCase();
    }
  }
}
