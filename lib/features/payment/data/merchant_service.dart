import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class MerchantService {
  MerchantService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listMerchants({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(
      AppConfig.endpoints['merchants'] ?? '/merchants',
      queryParameters: queryParameters,
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listMerchantCategories() async {
    final response = await _dio.get(
      AppConfig.endpoints['merchantCategories'] ?? '/merchants/categories',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> createMerchantAccount(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['merchantAccounts'] ?? '/merchants/accounts',
      data: payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listMyMerchantAccounts() async {
    final response = await _dio.get(
      AppConfig.endpoints['merchantAccountsMine'] ?? '/merchants/accounts/my',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> getMerchantAccount(String accountId) async {
    final response = await _dio.get(
      '${AppConfig.endpoints['merchantAccounts'] ?? '/merchants/accounts'}/$accountId',
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> updateMerchantSettlement(
    String accountId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      '${AppConfig.endpoints['merchantAccounts'] ?? '/merchants/accounts'}/$accountId/settlement',
      data: payload,
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
      final items = data['items'] ?? data['results'] ?? data['accounts'];
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
