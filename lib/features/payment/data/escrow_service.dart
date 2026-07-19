import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class EscrowService {
  EscrowService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;
  final Uuid _uuid = const Uuid();

  String createIdempotencyKey([String prefix = 'paysafe']) {
    final safePrefix = prefix.trim().isEmpty ? 'paysafe' : prefix.trim();
    return '$safePrefix-${_uuid.v4()}';
  }

  Future<List<Map<String, dynamic>>> listEscrows({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(
      AppConfig.endpoints['escrow'] ?? '/escrow',
      queryParameters: queryParameters,
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> getEscrow(String escrowId) async {
    final response = await _dio.get(
      '${AppConfig.endpoints['escrow'] ?? '/escrow'}/$escrowId',
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> createEscrow(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final response = await _postWithIdempotency(
      AppConfig.endpoints['escrowCreate'] ?? '/escrow/create',
      payload,
      idempotencyKey: idempotencyKey,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> releaseEscrow(
    String referenceId, {
    String? idempotencyKey,
  }) async {
    final response = await _postWithIdempotency('/escrow/release', {
      'referenceId': referenceId,
    }, idempotencyKey: idempotencyKey);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> disputeEscrow(
    String referenceId, {
    required String reason,
    String? idempotencyKey,
  }) async {
    final response = await _postWithIdempotency('/escrow/dispute', {
      'referenceId': referenceId,
      'reason': reason,
    }, idempotencyKey: idempotencyKey);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> acceptEscrow(
    String referenceId, {
    String? idempotencyKey,
  }) async {
    final response = await _postWithIdempotency('/escrow/accept', {
      'referenceId': referenceId,
    }, idempotencyKey: idempotencyKey);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> refundEscrow(
    String referenceId, {
    String? idempotencyKey,
  }) async {
    final response = await _postWithIdempotency('/escrow/refund', {
      'referenceId': referenceId,
    }, idempotencyKey: idempotencyKey);
    return _extractItem(response.data);
  }

  Future<Response<dynamic>> _postWithIdempotency(
    String path,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) {
    final resolvedIdempotencyKey = (idempotencyKey?.trim().isNotEmpty ?? false)
        ? idempotencyKey!.trim()
        : createIdempotencyKey();
    final enrichedPayload = Map<String, dynamic>.from(payload)
      ..putIfAbsent('idempotencyKey', () => resolvedIdempotencyKey)
      ..putIfAbsent('idempotency_key', () => resolvedIdempotencyKey);
    return _dio.post(
      path,
      data: enrichedPayload,
      options: Options(
        headers: {
          'Idempotency-Key': resolvedIdempotencyKey,
          'x-idempotency-key': resolvedIdempotencyKey,
        },
      ),
    );
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
      final items = data['items'] ?? data['results'] ?? data['escrows'];
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
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return const <String, dynamic>{};
  }

  dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['data'] ?? raw;
    }
    return raw;
  }
}
