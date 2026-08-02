import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../network/orbi_request_headers.dart';
import '../security/device_fingerprint.dart';
import '../state/app_runtime_cache.dart';

class AppBootstrapService {
  AppBootstrapService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String _fingerprint = DeviceFingerprint.generate();
  final Uuid _uuid = const Uuid();

  Future<Map<String, dynamic>> fetchInitialSnapshot(
    String token, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final graphqlSnapshot = await _fetchGraphqlSnapshot(
        token,
        timeout: timeout,
      );
      AppRuntimeCache.rememberDashboardPayload(graphqlSnapshot);
      return graphqlSnapshot;
    } catch (_) {
      // REST remains as a safe compatibility path for older core deployments.
    }

    final endpoints = [
      Uri.parse('${AppConfig.baseUrl}/v1/dashboard'),
      Uri.parse('${AppConfig.baseUrl}/api/v1/dashboard'),
      Uri.parse('${AppConfig.baseUrl}/api/v1/user/dashboard'),
    ];

    http.Response? response;
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final candidate = await _client
            .get(
              endpoint,
              headers: OrbiRequestHeaders.build(
                token: token,
                fingerprint: _fingerprint,
                trace: _uuid.v4(),
              ),
            )
            .timeout(timeout);
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          break;
        }
        lastError =
            'APP_BOOTSTRAP_FAILED:${candidate.statusCode}:'
            '${candidate.body}';
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null) {
      throw StateError(lastError?.toString() ?? 'APP_BOOTSTRAP_FAILED');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded['data'] ?? decoded
        : decoded;
    if (data is! Map) {
      throw StateError('APP_BOOTSTRAP_PAYLOAD_INVALID');
    }

    final snapshot = Map<String, dynamic>.from(data);
    AppRuntimeCache.rememberDashboardPayload(snapshot);
    return snapshot;
  }

  Future<Map<String, dynamic>> _fetchGraphqlSnapshot(
    String token, {
    required Duration timeout,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${AppConfig.baseUrl}/v1/graphql'),
          headers: {
            ...OrbiRequestHeaders.build(
              token: token,
              fingerprint: _fingerprint,
              trace: _uuid.v4(),
            ),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'query': '''
query MobileBoot(\$transactionLimit: Int!, \$escrowLimit: Int!) {
  mobileSnapshot(transactionLimit: \$transactionLimit, escrowLimit: \$escrowLimit) {
    dashboard
    transactions
    wealthSummary
    paySafeEscrows
  }
}
''',
            'variables': {
              'transactionLimit': 30,
              'escrowLimit': 20,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'APP_BOOTSTRAP_GRAPHQL_FAILED:${response.statusCode}:${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('APP_BOOTSTRAP_GRAPHQL_INVALID');
    final data = decoded['data'];
    if (data is! Map) throw StateError('APP_BOOTSTRAP_GRAPHQL_DATA_INVALID');
    final snapshot = data['mobileSnapshot'];
    if (snapshot is! Map) {
      throw StateError('APP_BOOTSTRAP_GRAPHQL_SNAPSHOT_INVALID');
    }
    return _normalizeGraphqlSnapshot(Map<dynamic, dynamic>.from(snapshot));
  }

  Map<String, dynamic> _normalizeGraphqlSnapshot(Map<dynamic, dynamic> raw) {
    final dashboard = raw['dashboard'];
    final normalized = dashboard is Map
        ? Map<String, dynamic>.from(dashboard)
        : <String, dynamic>{};
    final transactions = _unwrapList(raw['transactions']);
    if (transactions.isNotEmpty) normalized['transactions'] = transactions;
    final wealthSummary = raw['wealthSummary'];
    if (wealthSummary is Map) {
      normalized['wealth_summary'] = Map<String, dynamic>.from(wealthSummary);
      normalized['wealthSummary'] = Map<String, dynamic>.from(wealthSummary);
    }
    final escrows = _unwrapList(raw['paySafeEscrows']);
    if (escrows.isNotEmpty) {
      normalized['paysafe_escrows'] = escrows;
      normalized['paySafeEscrows'] = escrows;
    }
    return normalized;
  }

  List<Map<String, dynamic>> _unwrapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (value is Map) {
      for (final key in const [
        'items',
        'transactions',
        'data',
        'results',
        'rows',
        'history',
      ]) {
        final nested = value[key];
        if (nested is List) return _unwrapList(nested);
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
