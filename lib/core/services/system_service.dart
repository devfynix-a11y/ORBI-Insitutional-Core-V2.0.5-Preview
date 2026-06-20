import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';

class SystemService {
  SystemService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<Map<String, dynamic>> fetchBootstrap() async {
    final response = await _dio.get(
      AppConfig.endpoints['bootstrap'] ?? '/sys/bootstrap',
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> fetchMetrics() async {
    final response = await _dio.get(
      AppConfig.endpoints['metrics'] ?? '/sys/metrics',
    );
    return _extractMap(response.data);
  }

  Map<String, dynamic> _extractMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }
}
