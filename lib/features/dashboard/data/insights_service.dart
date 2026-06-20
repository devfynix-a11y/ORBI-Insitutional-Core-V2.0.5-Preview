import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/device_fingerprint.dart';
import 'financial_insights.dart';

class InsightsService {
  final String _baseUrl;
  final String _fingerprint = DeviceFingerprint.generate();

  InsightsService({String? baseUrl}) : _baseUrl = baseUrl ?? AppConfig.baseUrl;

  Future<FinancialInsights> fetch(String token) async {
    final endpoints = [
      Uri.parse('$_baseUrl/api/v1/insights'),
      Uri.parse('$_baseUrl/v1/insights'),
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(endpoint, headers: _headers(token));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;

        final body = jsonDecode(response.body);
        if (body is! Map) continue;

        final success = body['success'];
        if (success is bool && !success) continue;

        final payload = body['data'] is Map ? body['data'] : body;
        if (payload is! Map) continue;

        return FinancialInsights(
          spendingAlerts: _extractStringList(payload['spendingAlerts']),
          budgetSuggestions: _extractStringList(payload['budgetSuggestions']),
          financialAdvice: _extractStringList(payload['financialAdvice']),
        );
      } catch (_) {
        continue;
      }
    }

    return const FinancialInsights.empty();
  }

  Map<String, String> _headers(String token) {
    return OrbiRequestHeaders.build(token: token, fingerprint: _fingerprint);
  }

  List<String> _extractStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
