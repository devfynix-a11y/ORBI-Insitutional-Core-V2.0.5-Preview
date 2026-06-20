import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';

class DepositService {
  DepositService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;
  static const Uuid _uuid = Uuid();

  Future<Map<String, dynamic>> createDepositIntent({
    required String targetWalletId,
    required String providerId,
    required String rail,
    required double amount,
    required String currency,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final idempotencyKey = 'deposit-intent-${_uuid.v4()}';
    final response = await _dio.post(
      '/external-funds/deposit-intents',
      options: Options(
        headers: {
          'Idempotency-Key': idempotencyKey,
          'x-idempotency-key': idempotencyKey,
        },
      ),
      data: {
        'targetWalletId': targetWalletId,
        'providerId': providerId,
        'paymentRailCapabilityCode': providerId,
        'rail': rail,
        'amount': amount,
        'currency': currency,
        'description': description?.trim().isEmpty == true ? null : description,
        'feeAmount': 0,
        'taxAmount': 0,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      }..removeWhere((key, value) => value == null),
    );
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listDepositMovements({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/external-funds/movements',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final raw = response.data;
    dynamic data = raw;
    if (raw is Map<String, dynamic>) {
      data = raw['data'] ?? raw;
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                (item['direction'] ?? '').toString().toUpperCase() ==
                'EXTERNAL_TO_INTERNAL',
          )
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final nested =
          data['items'] ?? data['results'] ?? data['movements'] ?? data['rows'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (item) =>
                  (item['direction'] ?? '').toString().toUpperCase() ==
                  'EXTERNAL_TO_INTERNAL',
            )
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
