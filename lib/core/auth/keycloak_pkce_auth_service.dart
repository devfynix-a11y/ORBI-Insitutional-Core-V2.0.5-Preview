import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:orbi_mobileapp/core/config/app_config.dart';
import 'package:orbi_mobileapp/core/network/orbi_request_headers.dart';
import 'package:orbi_mobileapp/core/storage/secure_storage_service.dart';

/// Native OAuth 2.0 Authorization Code + PKCE flow for ORBI Keycloak.
///
/// Keep disabled until the Android/iOS deep-link callback has been tested on
/// signed builds. The existing ORBI API login remains the compatibility path.
class KeycloakPkceAuthService {
  KeycloakPkceAuthService({
    FlutterAppAuth? appAuth,
    SecureStorageService? storage,
    http.Client? httpClient,
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _storage = storage ?? SecureStorageService(),
       _httpClient = httpClient ?? http.Client();

  final FlutterAppAuth _appAuth;
  final SecureStorageService _storage;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> signIn() async {
    if (!AppConfig.keycloakPkceEnabled) {
      throw StateError('KEYCLOAK_PKCE_DISABLED');
    }

    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        AppConfig.keycloakMobileClientId,
        AppConfig.keycloakRedirectUrl,
        discoveryUrl: AppConfig.keycloakDiscoveryUrl,
        scopes: const ['openid', 'profile', 'email'],
        promptValues: const ['login'],
      ),
    );
    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('KEYCLOAK_ACCESS_TOKEN_MISSING');
    }

    await _storage.saveToken(accessToken);
    final refreshToken = result.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    }

    final profile = await _loadOrbiSession(accessToken);
    final user = profile['user'];
    if (user is Map) {
      await _storage.saveUserProfile(Map<String, dynamic>.from(user));
    }
    return profile;
  }

  Future<Map<String, dynamic>> _loadOrbiSession(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('${AppConfig.apiUrl}/auth/session'),
      headers: OrbiRequestHeaders.build(token: accessToken),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('ORBI_SESSION_EXCHANGE_FAILED:${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw StateError('ORBI_SESSION_RESPONSE_INVALID');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
