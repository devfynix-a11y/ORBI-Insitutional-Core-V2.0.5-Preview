import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/device_fingerprint.dart';
import '../../../core/utils/user_facing_error.dart';

class EnterpriseService {
  EnterpriseService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? AppConfig.baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Uuid _uuid = const Uuid();
  final String _fingerprint = DeviceFingerprint.generate();

  Map<String, String> _headers(String token) {
    return OrbiRequestHeaders.build(
      token: token,
      fingerprint: _fingerprint,
      trace: _uuid.v4(),
    );
  }

  Future<Map<String, dynamic>> createOrganization(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/organizations');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> listOrganizations(String token) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/organizations');
    return _getJson(uri, token: token);
  }

  Future<Map<String, dynamic>> linkUserToOrganization(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/users/link');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> inviteUser(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/users/invite');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> fetchOrganizationDetails(
    String token,
    String organizationId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/enterprise/organizations/$organizationId',
    );
    return _getJson(uri, token: token);
  }

  Future<Map<String, dynamic>> fetchBudgetAlerts(
    String token,
    String organizationId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/enterprise/budgets/alerts?orgId=$organizationId',
    );
    return _getJson(uri, token: token);
  }

  Future<Map<String, dynamic>> fetchPendingApprovals(
    String token,
    String organizationId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/enterprise/treasury/approvals?orgId=$organizationId',
    );
    return _getJson(uri, token: token);
  }

  Future<Map<String, dynamic>> requestWithdrawal(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/treasury/withdraw/request');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> approveWithdrawal(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/treasury/withdraw/approve');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> configureAutoSweep(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/enterprise/treasury/autosweep');
    return _postJson(uri, token: token, body: payload);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String token,
  }) async {
    final response = await _client.get(uri, headers: _headers(token));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (response.body.trim().isEmpty) {
      return {
        'success': isSuccess,
        'data': <String, dynamic>{},
        'statusCode': response.statusCode,
      };
    }

    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        if (!isSuccess && parsed['success'] != true) {
          throw Exception(
            UserFacingError.from(
              Exception(
                parsed['error']?.toString() ??
                    parsed['message']?.toString() ??
                    'status ${response.statusCode}',
              ),
              fallback: 'Unable to complete this enterprise request right now.',
            ),
          );
        }
        return parsed;
      }
    } catch (e) {
      if (!isSuccess) rethrow;
      if (e is! FormatException) rethrow;
    }

    if (!isSuccess) {
      throw Exception(
        UserFacingError.from(
          Exception('status ${response.statusCode}'),
          fallback: 'Unable to complete this enterprise request right now.',
        ),
      );
    }
    return {
      'success': isSuccess,
      'data': <String, dynamic>{},
      'raw': response.body,
      'statusCode': response.statusCode,
    };
  }
}
