import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../network/orbi_request_headers.dart';
import '../security/device_fingerprint.dart';
import '../state/app_runtime_cache.dart';

class AppBootstrapService {
  AppBootstrapService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _fingerprint = DeviceFingerprint.generate();
  final Uuid _uuid = const Uuid();

  Future<Map<String, dynamic>> fetchInitialSnapshot(
    String token, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endpoints = [
      Uri.parse('${AppConfig.apiUrl}/dashboard'),
      Uri.parse('${AppConfig.baseUrl}/api/v1/dashboard'),
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
        lastError = 'APP_BOOTSTRAP_FAILED:${candidate.statusCode}:'
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
}
