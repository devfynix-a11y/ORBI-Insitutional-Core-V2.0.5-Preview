import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class ServicePaymentChallengeService {
  ServicePaymentChallengeService([ApiClient? client])
    : _dio = (client ?? ApiClient()).client;

  final Dio _dio;
  static const Uuid _uuid = Uuid();

  String createIdempotencyKey([String prefix = 'service-challenge']) {
    final safePrefix = prefix.trim().isEmpty
        ? 'service-challenge'
        : prefix.trim();
    return '$safePrefix-${_uuid.v4()}';
  }

  Future<Map<String, dynamic>> respond({
    required String challengeId,
    required String decision,
    String? idempotencyKey,
    String? otcRequestId,
    String? otcCode,
  }) async {
    final normalizedChallengeId = challengeId.trim();
    if (normalizedChallengeId.isEmpty) {
      throw const ServicePaymentChallengeException('Challenge ID is missing.');
    }

    final resolvedIdempotencyKey = (idempotencyKey?.trim().isNotEmpty ?? false)
        ? idempotencyKey!.trim()
        : createIdempotencyKey();
    final template =
        AppConfig.endpoints['servicePaymentChallengeRespondTemplate'] ??
        '/payments/service-challenges/{challengeId}/respond';
    final path = template.replaceAll(
      '{challengeId}',
      Uri.encodeComponent(normalizedChallengeId),
    );

    try {
      final response = await _dio.post(
        path,
        data: {
          'decision': decision,
          'idempotencyKey': resolvedIdempotencyKey,
          'idempotency_key': resolvedIdempotencyKey,
          if (otcRequestId?.trim().isNotEmpty ?? false)
            'otc_request_id': otcRequestId!.trim(),
          if (otcCode?.trim().isNotEmpty ?? false) 'otc_code': otcCode!.trim(),
        },
        options: Options(
          headers: {
            'Idempotency-Key': resolvedIdempotencyKey,
            'x-idempotency-key': resolvedIdempotencyKey,
          },
        ),
      );
      return _extractItem(response.data);
    } on DioException catch (error) {
      throw ServicePaymentChallengeException(_extractDioMessage(error));
    }
  }

  Map<String, dynamic> _extractItem(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return const <String, dynamic>{};
  }

  String _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['code'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    return error.message ?? 'Unable to respond to this payment request.';
  }
}

class ServicePaymentChallengeException implements Exception {
  final String message;

  const ServicePaymentChallengeException(this.message);

  @override
  String toString() => message;
}
