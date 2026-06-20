import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class EscrowService {
  EscrowService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

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
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['escrowCreate'] ?? '/escrow/create',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> releaseEscrow(
    String referenceId,
  ) async {
    final response = await _dio.post(
      '/escrow/release',
      data: {'referenceId': referenceId},
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> disputeEscrow(
    String referenceId, {
    required String reason,
  }) async {
    final response = await _dio.post(
      '/escrow/dispute',
      data: {
        'referenceId': referenceId,
        'reason': reason,
      },
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> acceptEscrow(String referenceId) async {
    final response = await _dio.post(
      '/escrow/accept',
      data: {'referenceId': referenceId},
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> refundEscrow(String referenceId) async {
    final response = await _dio.post(
      '/escrow/refund',
      data: {'referenceId': referenceId},
    );
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
