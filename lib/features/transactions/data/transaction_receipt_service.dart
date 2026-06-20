import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class TransactionReceiptService {
  TransactionReceiptService([ApiClient? client])
    : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<Map<String, dynamic>> fetchReceipt(String transactionId) async {
    final template =
        AppConfig.endpoints['transactionReceiptTemplate'] ??
        '/transactions/{id}/receipt';
    final path = template.replaceFirst('{id}', Uri.encodeComponent(transactionId));
    final response = await _dio.get(path);
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }
}
