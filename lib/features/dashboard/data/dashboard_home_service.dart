import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/device_fingerprint.dart';

class DashboardHomeService {
  DashboardHomeService({String? baseUrl})
    : _baseUrl = baseUrl ?? AppConfig.baseUrl;

  final String _baseUrl;
  final String _fingerprint = DeviceFingerprint.generate();

  Future<List<Map<String, dynamic>>> fetchSharedPots(String token) {
    return _fetchCollection(
      token,
      endpoints: const ['/api/v1/wealth/shared-pots', '/v1/wealth/shared-pots'],
      keys: const ['pots', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchSharedBudgets(String token) {
    return _fetchCollection(
      token,
      endpoints: const [
        '/api/v1/wealth/shared-budgets',
        '/v1/wealth/shared-budgets',
      ],
      keys: const ['budgets', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchBillReserves(String token) {
    return _fetchCollection(
      token,
      endpoints: const [
        '/api/v1/wealth/bill-reserves',
        '/v1/wealth/bill-reserves',
      ],
      keys: const ['reserves', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecentTransactions(
    String token, {
    int limit = 8,
  }) {
    return _fetchCollection(
      token,
      endpoints: <String>[
        '/api/v1/transactions?limit=$limit',
        '/v1/transactions?limit=$limit',
      ],
      keys: const ['transactions', 'items', 'results', 'rows', 'history'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchUpcomingBills(String token) async {
    return _fetchCollection(
      token,
      endpoints: const [
        '/api/v1/wealth/upcoming-commitments',
        '/v1/wealth/upcoming-commitments',
      ],
      keys: const ['commitments', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchMerchantRecommendations(
    String token,
  ) async {
    return _fetchCollection(
      token,
      endpoints: const [
        '/api/v1/insights/merchant-recommendations',
        '/v1/insights/merchant-recommendations',
      ],
      keys: const ['recommendations', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> fetchNetWorthSummary(String token) async {
    return _fetchMap(
      token,
      endpoints: const ['/api/v1/wealth/net-worth', '/v1/wealth/net-worth'],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCollection(
    String token, {
    required List<String> endpoints,
    required List<String> keys,
  }) async {
    for (final endpoint in endpoints) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl$endpoint'),
          headers: OrbiRequestHeaders.build(
            token: token,
            fingerprint: _fingerprint,
          ),
        ).timeout(const Duration(seconds: 6));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final body = jsonDecode(response.body);
        final list = _extractList(body, keys);
        if (list.isNotEmpty) return list;
      } catch (_) {
        continue;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> _fetchMap(
    String token, {
    required List<String> endpoints,
  }) async {
    for (final endpoint in endpoints) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl$endpoint'),
          headers: OrbiRequestHeaders.build(
            token: token,
            fingerprint: _fingerprint,
          ),
        ).timeout(const Duration(seconds: 6));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final body = jsonDecode(response.body);
        dynamic data = body;
        if (data is Map && data['data'] != null) {
          data = data['data'];
        }
        if (data is Map) {
          return _normalizeMap(Map<dynamic, dynamic>.from(data));
        }
      } catch (_) {
        continue;
      }
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic raw, List<String> keys) {
    dynamic data = raw;
    if (data is Map && data['data'] != null) {
      data = data['data'];
    }
    if (data is List) {
      return data.whereType<Map>().map(_normalizeMap).toList();
    }
    if (data is! Map) return const <Map<String, dynamic>>[];
    final map = _normalizeMap(data);
    for (final key in keys) {
      final value = map[key];
      if (value is List) {
        return value.whereType<Map>().map(_normalizeMap).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}
