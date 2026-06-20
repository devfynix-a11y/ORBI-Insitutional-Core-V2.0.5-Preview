import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';

class TransactionRepository {
  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  TransactionRepository(this._apiClient);

  Future<Response> settleTransaction(Map<String, dynamic> data) async {
    // Generate a unique idempotency key for this operation
    final idempotencyKey = _uuid.v4();

    try {
      // Pass the key via options.extra
      final response = await _apiClient.client.post(
        '/transactions/settle',
        data: data,
        options: Options(extra: {'idempotencyKey': idempotencyKey}),
      );
      return response;
    } on DioException catch (e) {
      // If the error is retryable (timeout, network), you can retry with the SAME key
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        // Retry logic with the same idempotencyKey
        // You may want to add a retry counter to avoid infinite loops
        return _retrySettle(data, idempotencyKey);
      }
      rethrow;
    }
  }

  Future<Response> _retrySettle(
    Map<String, dynamic> data,
    String idempotencyKey,
  ) async {
    // Wait a bit, then retry with the same key
    await Future.delayed(const Duration(seconds: 2));
    return _apiClient.client.post(
      '/transactions/settle',
      data: data,
      options: Options(extra: {'idempotencyKey': idempotencyKey}),
    );
  }
}
