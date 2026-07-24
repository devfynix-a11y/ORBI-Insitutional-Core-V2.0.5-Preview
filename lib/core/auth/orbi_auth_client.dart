import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:orbi_mobileapp/core/config/app_config.dart';
import 'package:orbi_mobileapp/core/auth/passkey_response_parser.dart';
import 'package:orbi_mobileapp/core/device/device_info_service.dart';
import 'package:orbi_mobileapp/core/security/transaction_geo_context.dart';
import 'package:orbi_mobileapp/core/network/orbi_request_headers.dart';
import 'package:orbi_mobileapp/core/security/device_fingerprint.dart';

enum PreflightIssue {
  none,
  dnsFailure,
  timeout,
  noInternet,
  backendUnavailable,
  unknown,
}

class PreflightHealthResult {
  final bool isHealthy;
  final PreflightIssue issue;

  const PreflightHealthResult({required this.isHealthy, required this.issue});
}

class AuthApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  const AuthApiException(
    this.message, {
    this.code = 'AUTH_ERROR',
    this.statusCode,
    this.payload,
  });

  bool get requiresAccountActivation =>
      code == 'ACCOUNT_NOT_ACTIVATED' ||
      code == 'ACCOUNT_NOT_ACTIVE' ||
      code == 'ACCOUNT_UNCONFIRMED' ||
      code == 'UNCONFIRMED_ACCOUNT' ||
      message.toUpperCase().contains('ACCOUNT_NOT_ACTIVATED') ||
      message.toUpperCase().contains('ACCOUNT_NOT_ACTIVE') ||
      message.toUpperCase().contains('ACCOUNT_UNCONFIRMED') ||
      message.toUpperCase().contains('UNCONFIRMED_ACCOUNT') ||
      message.toUpperCase().contains('UNCONFIRMED') ||
      message.toUpperCase().contains('NOT CONFIRMED') ||
      message.toUpperCase().contains('CONFIRM YOUR ACCOUNT') ||
      message.toUpperCase().contains('ACTIVATE YOUR ACCOUNT');

  @override
  String toString() => message;
}

/// ORBI AUTHENTICATION CLIENT
/// ---------------------------
/// A production-ready client for interacting with the Orbi Sovereign Backend.
/// Handles Login, Signup, Token Management, and Authenticated Requests.
class OrbiAuthClient {
  static const Duration _authRequestTimeout = Duration(seconds: 15);

  /// Build device info payload for authentication requests
  static Future<Map<String, dynamic>> buildDevicePayload() {
    return DeviceInfoService.buildPayload();
  }

  final String baseUrl; // Should be AppConfig.apiUrl
  final Uuid _uuid = const Uuid();
  final String _fingerprint = DeviceFingerprint.generate();
  final http.Client _httpClient = http.Client();
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userProfile;
  String? _lastRegisteredCredentialId;

  OrbiAuthClient({required this.baseUrl});

  static bool _didLogApkHashHeader = false;
  static bool _didLogAppOriginHeader = false;

  void _logBiometricDebug(String label, Object? payload) {
    if (!kDebugMode) return;
    final keysOrType = payload is Map
        ? payload.keys.toList()
        : payload.runtimeType;
    debugPrint('🔐 [PASSKEY][DEBUG] $label keys/type: $keysOrType');
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Generate mandatory headers required by Sentinel WAF
  Map<String, String> _getMandatoryHeaders({String? token}) {
    if (kDebugMode && !_didLogApkHashHeader) {
      _didLogApkHashHeader = true;
      debugPrint(
        '🛡️ [GATEKEEPER] x-orbi-apk-hash=${AppConfig.androidAppHash}',
      );
    }
    if (kDebugMode && !_didLogAppOriginHeader) {
      _didLogAppOriginHeader = true;
      debugPrint('🛡️ [GATEKEEPER] x-orbi-app-origin=${AppConfig.appOrigin}');
    }
    final registryType =
        (_userProfile?['registry_type'] ?? _userProfile?['registryType'])
            ?.toString();
    return OrbiRequestHeaders.build(
      token: token,
      registryType: registryType,
      fingerprint: _fingerprint,
      trace: _uuid.v4(),
    );
  }

  /// Lightweight preflight to verify DNS/network reachability.
  Future<bool> preflightHealth() async {
    final result = await preflightHealthDetailed();
    return result.isHealthy;
  }

  /// Detailed preflight with explicit failure reason for better UX messaging.
  Future<PreflightHealthResult> preflightHealthDetailed() async {
    PreflightHealthResult? lastResult;
    for (final base in AppConfig.baseUrls) {
      final url = Uri.parse('$base/health');
      final result = await _preflightHealthUrl(url);
      if (result.isHealthy) return result;
      lastResult = result;
    }
    return lastResult ??
        const PreflightHealthResult(
          isHealthy: false,
          issue: PreflightIssue.backendUnavailable,
        );
  }

  Future<PreflightHealthResult> _preflightHealthUrl(Uri url) async {
    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 5));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return PreflightHealthResult(
        isHealthy: ok,
        issue: ok ? PreflightIssue.none : PreflightIssue.backendUnavailable,
      );
    } on SocketException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('failed host lookup') ||
          message.contains('no address associated with hostname') ||
          message.contains('name or service not known')) {
        return const PreflightHealthResult(
          isHealthy: false,
          issue: PreflightIssue.dnsFailure,
        );
      }

      if (message.contains('network is unreachable') ||
          message.contains('no route to host') ||
          message.contains('connection refused') ||
          message.contains('software caused connection abort') ||
          message.contains('connection reset')) {
        return const PreflightHealthResult(
          isHealthy: false,
          issue: PreflightIssue.noInternet,
        );
      }

      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.noInternet,
      );
    } on HttpException {
      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.backendUnavailable,
      );
    } on FormatException {
      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.backendUnavailable,
      );
    } on HandshakeException {
      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.backendUnavailable,
      );
    } on TimeoutException {
      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.timeout,
      );
    } catch (_) {
      return const PreflightHealthResult(
        isHealthy: false,
        issue: PreflightIssue.unknown,
      );
    }
  }

  /// 1. LOGIN
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? deviceId,
    String? ip,
    Map<String, dynamic>? device,
  }) async {
    final path = AppConfig.endpoints['login'] ?? '/auth/login';
    try {
      debugPrint('📤 [LOGIN] POST $path');
      debugPrint('📋 Payload: {e: $email, p: ***}');

      final payload = <String, dynamic>{
        // Official Core contract.
        'email': email,
        'password': password,
        // Legacy compatibility for older self-hosted Core builds.
        'e': email,
        'p': password,
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        payload['device_id'] = deviceId;
      }
      if (device != null && device.isNotEmpty) {
        payload['device'] = device;
      }
      // Add metadata for device registration
      final fingerprint = deviceId ?? _fingerprint;
      if (fingerprint.isNotEmpty || (ip != null && ip.isNotEmpty)) {
        payload['metadata'] = {
          'app_origin': AppConfig.appOrigin,
          if (device == null || device.isEmpty) 'fingerprint': fingerprint,
          if (ip != null && ip.isNotEmpty) 'ip': ip,
          'userAgent': Platform.operatingSystem,
        };
      }

      final response = await _postWithFallback(
        path,
        headers: _getMandatoryHeaders(),
        body: jsonEncode(payload),
        logContext: 'LOGIN',
      );

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Login response received');

      final body = _tryDecodeJsonMap(response.body);
      if (body == null) {
        throw Exception(
          _buildNonJsonResponseError(response, context: 'Login failed'),
        );
      }

      if (response.statusCode == 200) {
        if (body['success'] == true) {
          final data = body['data'];
          _accessToken =
              data['access_token'] ?? data['session']?['access_token'];
          _refreshToken = data['session']?['refresh_token'];
          _userProfile = data['user'];
          debugPrint('✅ Login successful');
          return data;
        } else {
          throw Exception(body['error'] ?? 'Login failed');
        }
      } else {
        debugPrint('❌ Server Error: ${response.statusCode}');
        debugPrint('❌ Error: ${body['error']}');
        final code = _extractErrorCode(body);
        final err =
            _extractErrorMessage(body['error'] ?? body['message']) ??
            'Login failed';
        throw AuthApiException(
          err,
          code: code,
          statusCode: response.statusCode,
          payload: body,
        );
      }
    } catch (e) {
      debugPrint('❌ Login Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> pinLogin(
    String email,
    String pin, {
    String? deviceId,
    String? ip,
    Map<String, dynamic>? device,
  }) async {
    final path = AppConfig.endpoints['pinLogin'] ?? '/auth/pin-login';
    final url = Uri.parse('$baseUrl$path');
    try {
      debugPrint('📤 [PIN_LOGIN] POST $url');
      debugPrint('📋 Payload: {e: $email, pin: ***}');

      final payload = <String, dynamic>{'e': email, 'pin': pin};
      if ((device == null || device.isEmpty) &&
          deviceId != null &&
          deviceId.isNotEmpty) {
        payload['device_id'] = deviceId;
      }
      if (device != null && device.isNotEmpty) {
        payload['device'] = device;
      }
      final fingerprint = deviceId ?? _fingerprint;
      if (fingerprint.isNotEmpty || (ip != null && ip.isNotEmpty)) {
        payload['metadata'] = {
          'app_origin': AppConfig.appOrigin,
          if (device == null || device.isEmpty) 'fingerprint': fingerprint,
          if (ip != null && ip.isNotEmpty) 'ip': ip,
          'userAgent': Platform.operatingSystem,
        };
      }

      final response = await _postWithFallback(
        path,
        headers: _getMandatoryHeaders(),
        body: jsonEncode(payload),
        logContext: 'PIN_LOGIN',
      );

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 PIN login response received');

      final body = _tryDecodeJsonMap(response.body);
      if (body == null) {
        throw Exception(
          _buildNonJsonResponseError(response, context: 'PIN login failed'),
        );
      }

      if (response.statusCode == 200) {
        if (body['success'] == true) {
          final data = body['data'];
          _accessToken =
              data['access_token'] ?? data['session']?['access_token'];
          _refreshToken = data['session']?['refresh_token'];
          _userProfile = data['user'];
          debugPrint('✅ PIN login successful');
          return data;
        } else {
          throw Exception(body['error'] ?? 'PIN login failed');
        }
      } else {
        debugPrint('❌ Server Error: ${response.statusCode}');
        debugPrint('❌ Error: ${body['error']}');
        final code = _extractErrorCode(body);
        final err =
            _extractErrorMessage(body['error'] ?? body['message']) ??
            'PIN login failed';
        throw AuthApiException(
          err,
          code: code,
          statusCode: response.statusCode,
          payload: body,
        );
      }
    } catch (e) {
      debugPrint('❌ PIN Login Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> pinEnroll({
    required String pin,
    String? deviceId,
    Map<String, dynamic>? device,
    String? token,
    String? ip,
  }) async {
    final path = AppConfig.endpoints['pinEnroll'] ?? '/auth/pin/enroll';
    final url = Uri.parse('$baseUrl$path');
    final payload = <String, dynamic>{
      'pin': pin,
      if ((device == null || device.isEmpty) &&
          deviceId != null &&
          deviceId.isNotEmpty)
        'device_id': deviceId,
      if (device != null && device.isNotEmpty) 'device': device,
      'metadata': {
        'app_origin': AppConfig.appOrigin,
        if ((device == null || device.isEmpty) &&
            deviceId != null &&
            deviceId.isNotEmpty)
          'fingerprint': deviceId,
        if (ip != null && ip.isNotEmpty) 'ip': ip,
        'userAgent': Platform.operatingSystem,
      },
    };
    final response = await http.post(
      url,
      headers: _getMandatoryHeaders(token: token ?? _accessToken),
      body: jsonEncode(payload),
    );
    return _decodeAuthResponse(response, defaultError: 'PIN enroll failed');
  }

  Future<Map<String, dynamic>> pinUpdate({
    required String pin,
    String? deviceId,
    Map<String, dynamic>? device,
    String? token,
    String? ip,
  }) async {
    final path = AppConfig.endpoints['pinUpdate'] ?? '/auth/pin/update';
    final url = Uri.parse('$baseUrl$path');
    final payload = <String, dynamic>{
      'new_pin': pin,
      if ((device == null || device.isEmpty) &&
          deviceId != null &&
          deviceId.isNotEmpty)
        'device_id': deviceId,
      if (device != null && device.isNotEmpty) 'device': device,
      'metadata': {
        'app_origin': AppConfig.appOrigin,
        if ((device == null || device.isEmpty) &&
            deviceId != null &&
            deviceId.isNotEmpty)
          'fingerprint': deviceId,
        if (ip != null && ip.isNotEmpty) 'ip': ip,
        'userAgent': Platform.operatingSystem,
      },
    };
    final response = await http.post(
      url,
      headers: _getMandatoryHeaders(token: token ?? _accessToken),
      body: jsonEncode(payload),
    );
    return _decodeAuthResponse(response, defaultError: 'PIN update failed');
  }

  /// 2. SIGNUP (with optional fields)
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String currency,
    String? nationality,
    String? address,
    String? languageCode,
    String? countryCode,
    String? countryName,
    String? dialCode,
    String? fcmToken,
  }) async {
    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedCurrency.isEmpty) {
      throw Exception('Account currency is required for signup.');
    }
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['signup']}');
    debugPrint('📤 [SIGNUP] POST $url');
    final registrationTimeMetadata =
        TransactionGeoContext.buildRegistrationTimeMetadata();
    final payload = {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      ...?(nationality == null ? null : {'nationality': nationality}),
      ...?(address == null ? null : {'address': address}),
      'currency': normalizedCurrency,
      'preferred_currency': normalizedCurrency,
      ...?(countryCode == null ? null : {'country_code': countryCode}),
      ...?(countryName == null ? null : {'country_name': countryName}),
      ...?(dialCode == null ? null : {'dial_code': dialCode}),
      ...?(languageCode == null ? null : {'language': languageCode}),
      ...?(fcmToken == null ? null : {'fcm_token': fcmToken}),
      'app_origin': AppConfig.appOrigin,
      'registry_type': 'CONSUMER',
      'metadata': {
        ...registrationTimeMetadata,
        'app_origin': AppConfig.appOrigin,
        'registry_type': 'CONSUMER',
        'preferred_currency': normalizedCurrency,
        ...?(countryCode == null ? null : {'country_code': countryCode}),
        ...?(countryName == null ? null : {'country_name': countryName}),
        ...?(dialCode == null ? null : {'dial_code': dialCode}),
        ...?(languageCode == null ? null : {'language': languageCode}),
      },
    };
    try {
      final response = await http.post(
        url,
        headers: _getMandatoryHeaders(),
        body: jsonEncode(payload),
      );
      debugPrint('📥 [SIGNUP] status=${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          if (data['session'] != null) {
            _accessToken = data['session']['access_token'];
            _userProfile = data['user'];
          }
          return data;
        } else {
          throw Exception(body['error'] ?? 'Signup failed');
        }
      } else {
        // try decode but guard against non-json
        try {
          final body = jsonDecode(response.body);
          final bodyMap = body is Map<String, dynamic>
              ? body
              : (body is Map ? Map<String, dynamic>.from(body) : null);
          if (bodyMap == null) {
            throw Exception('Server Error: ${response.statusCode}');
          }
          final code = _extractErrorCode(bodyMap);
          final err =
              _extractErrorMessage(bodyMap['error'] ?? bodyMap['message']) ??
              'Signup failed';
          throw AuthApiException(
            err,
            code: code,
            statusCode: response.statusCode,
            payload: bodyMap,
          );
        } catch (_) {
          throw Exception(
            'Server Error: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 3. GET PROFILE
  Future<Map<String, dynamic>> getUserProfile() async {
    if (_accessToken == null) throw Exception('Not authenticated');
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['profile']}');
    try {
      final response = await http.get(
        url,
        headers: _getMandatoryHeaders(token: _accessToken),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Failed to fetch profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchKycStatus(String accessToken) async {
    final path = AppConfig.endpoints['kycStatus'] ?? '/user/kyc/status';
    final url = Uri.parse('$baseUrl$path');
    final response = await http.get(
      url,
      headers: _getMandatoryHeaders(token: accessToken),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final data = body is Map<String, dynamic> ? body['data'] ?? body : body;
      if (data is Map<String, dynamic>) return data;
      return {};
    }
    throw Exception('Failed to fetch KYC status (${response.statusCode})');
  }

  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['refresh']}');
    try {
      final response = await http.post(
        url,
        headers: _getMandatoryHeaders(token: _accessToken),
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          _accessToken =
              data['access_token'] ?? data['session']?['access_token'];
          _refreshToken =
              data['refresh_token'] ?? data['session']?['refresh_token'];
          if (data['user'] is Map<String, dynamic>) {
            _userProfile = data['user'] as Map<String, dynamic>;
          }
          return data;
        }
        throw Exception(body['error'] ?? 'Refresh failed');
      }

      throw Exception('Refresh failed: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout(String refreshToken) async {
    final logoutPath = AppConfig.endpoints['logout'];
    if (logoutPath == null) {
      logoutLocal();
      return;
    }

    try {
      final url = Uri.parse('$baseUrl$logoutPath');
      await http.post(
        url,
        headers: _getMandatoryHeaders(token: _accessToken),
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } catch (_) {
      // Local logout must still happen even if backend request fails.
    } finally {
      logoutLocal();
    }
  }

  Future<Map<String, dynamic>> initiatePasswordReset(String identifier) async {
    final path = AppConfig.endpoints['passwordResetInitiate'];
    if (path == null) {
      throw Exception('Password reset initiate endpoint not configured');
    }
    final response = await _postWithFallback(
      path,
      headers: _getMandatoryHeaders(),
      body: jsonEncode({'identifier': identifier}),
      logContext: 'PASSWORD reset/initiate',
      allowRootFallbacks: false,
    );
    return _decodeOptionalDataResponse(
      response,
      defaultError: 'Failed to initiate password reset',
    );
  }

  Future<Map<String, dynamic>> completePasswordReset(
    String password, {
    String? accessToken,
    String? identifier,
    String? requestId,
    String? code,
  }) async {
    final path = AppConfig.endpoints['passwordResetComplete'];
    if (path == null) {
      throw Exception('Password reset complete endpoint not configured');
    }
    final normalizedPassword = password.trim();
    final payload = <String, dynamic>{
      // Official Core contract.
      'password': normalizedPassword,
      // Compatibility for older gateway/Core builds and reset forms.
      'newPassword': normalizedPassword,
      'new_password': normalizedPassword,
      'p': normalizedPassword,
    };
    if (identifier != null) payload['identifier'] = identifier;
    if (requestId != null) payload['requestId'] = requestId;
    if (code != null) payload['code'] = code;
    final response = await _postWithFallback(
      path,
      headers: _getMandatoryHeaders(token: accessToken),
      body: jsonEncode(payload),
      logContext: 'PASSWORD reset/complete',
      allowRootFallbacks: false,
    );
    return _decodeOptionalDataResponse(
      response,
      defaultError: 'Failed to complete password reset',
    );
  }

  Future<Map<String, dynamic>> initiateAccountConfirmation(
    String identifier, {
    String? replacementContact,
  }) async {
    final path = AppConfig.endpoints['accountConfirmationInitiate'];
    if (path == null) {
      throw Exception('Account confirmation endpoint not configured');
    }
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _getMandatoryHeaders(),
      body: jsonEncode({
        'identifier': identifier,
        if (replacementContact != null && replacementContact.trim().isNotEmpty)
          'replacementContact': replacementContact.trim(),
      }),
    );
    return _decodeOptionalDataResponse(
      response,
      defaultError: 'Failed to request account activation code',
    );
  }

  Future<Map<String, dynamic>> completeAccountConfirmation({
    required String identifier,
    required String requestId,
    required String code,
  }) async {
    final path = AppConfig.endpoints['accountConfirmationComplete'];
    if (path == null) {
      throw Exception('Account confirmation endpoint not configured');
    }
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _getMandatoryHeaders(),
      body: jsonEncode({
        'identifier': identifier,
        'requestId': requestId,
        'code': code,
      }),
    );
    return _decodeOptionalDataResponse(
      response,
      defaultError: 'Failed to activate account',
    );
  }

  Future<Map<String, dynamic>> bootstrapProvisioning() async {
    final path = AppConfig.endpoints['bootstrap'] ?? '/sys/bootstrap';
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final url = Uri.parse('$baseUrl$path');
    final headers = {..._getMandatoryHeaders(token: token)};

    Exception? lastError;
    final methods = ['POST', 'GET'];
    for (final method in methods) {
      try {
        final response = method == 'POST'
            ? await http.post(url, headers: headers, body: '{}')
            : await http.get(url, headers: headers);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = _tryDecodeJsonMap(response.body);
          if (body == null) return <String, dynamic>{};
          final data = body['data'] ?? body;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
          return Map<String, dynamic>.from(body);
        }

        final body = _tryDecodeJsonMap(response.body);
        final err =
            _extractErrorMessage(body?['error'] ?? body?['message']) ??
            'status ${response.statusCode}';
        lastError = Exception(
          'Bootstrap provisioning failed on $method $path: $err',
        );
      } catch (e) {
        lastError = Exception(
          'Bootstrap provisioning failed on $method $path: $e',
        );
      }
    }

    throw lastError ?? Exception('Bootstrap provisioning failed');
  }

  Future<Map<String, dynamic>> biometricRegisterStart({
    String? email,
    String? userId,
    String? otpCode,
    String? otpRequestId,
  }) async {
    final path = AppConfig.endpoints['biometricRegisterStart'];
    if (path == null) {
      throw Exception('Biometric register start endpoint not configured');
    }

    final payload = <String, dynamic>{};
    if (userId != null && userId.isNotEmpty) payload['userId'] = userId;
    if (email != null && email.isNotEmpty) payload['email'] = email;
    if (otpCode != null && otpCode.isNotEmpty) {
      payload['otpCode'] = otpCode;
    }
    if (otpRequestId != null && otpRequestId.isNotEmpty) {
      payload['otpRequestId'] = otpRequestId;
    }

    debugPrint(
      '📋 [PASSKEY] register/start payload keys: ${payload.keys.toList()}',
    );
    _logBiometricDebug('register/start payload', payload);
    final headers = {..._getMandatoryHeaders(token: _accessToken)};
    final response = await _postWithFallback(
      path,
      headers: headers,
      body: jsonEncode(payload),
      logContext: 'PASSKEY register/start',
    );
    _logBiometricDebug('register/start response', {
      'status': response.statusCode,
    });

    final body = _tryDecodeJsonMap(response.body);
    if (body == null) {
      throw Exception(
        _buildNonJsonResponseError(
          response,
          context: 'Biometric register start failed',
        ),
      );
    }

    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : null;
    final success = body['success'] == true;
    final options = _extractPasskeyOptions(
      data ?? Map<String, dynamic>.from(body),
    );
    final looksLikeOptions = options != null;

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (success || looksLikeOptions)) {
      return data ?? Map<String, dynamic>.from(body);
    }

    if (_looksLikeOtpChallenge(body) ||
        (data != null && _looksLikeOtpChallenge(data))) {
      final payloadMap = data ?? Map<String, dynamic>.from(body);
      payloadMap['status'] ??= 'CHALLENGE_REQUIRED';
      return payloadMap;
    }

    final err =
        _extractErrorMessage(body['error'] ?? body['message']) ??
        'Biometric register start failed';
    throw Exception('Server Error: ${response.statusCode} - $err');
  }

  Future<Map<String, dynamic>> biometricRegisterFinish(
    Map<String, dynamic> credentialPayload,
  ) async {
    final path = AppConfig.endpoints['biometricRegisterFinish'];
    if (path == null) {
      throw Exception('Biometric register finish endpoint not configured');
    }

    final normalizedPayload = _normalizePasskeyFinishPayload(credentialPayload);

    debugPrint(
      '📋 [PASSKEY] register/finish payload keys: ${normalizedPayload.keys.toList()}',
    );
    _logBiometricDebug('register/finish payload', normalizedPayload);
    final registeredId = normalizedPayload['id'] ?? normalizedPayload['rawId'];
    if (registeredId is String && registeredId.isNotEmpty) {
      _lastRegisteredCredentialId = registeredId;
    }
    final headers = {..._getMandatoryHeaders(token: _accessToken)};
    final response = await _postWithFallback(
      path,
      headers: headers,
      body: jsonEncode(normalizedPayload),
      logContext: 'PASSKEY register/finish',
    );
    _logBiometricDebug('register/finish response', {
      'status': response.statusCode,
    });
    return _decodeAuthResponse(
      response,
      defaultError: 'Biometric register finish failed',
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String requestId,
    required String code,
  }) async {
    final path = AppConfig.endpoints['authVerify'] ?? '/auth/verify';
    final url = Uri.parse('$baseUrl$path');
    final payloads = [
      {'requestId': requestId, 'code': code},
      {'request_id': requestId, 'code': code},
      {'requestId': requestId, 'otp': code},
      {'request_id': requestId, 'otp': code},
    ];

    http.Response? lastFailure;
    for (final payload in payloads) {
      debugPrint('📤 [PASSKEY] auth/verify POST $url');
      debugPrint(
        '📋 [PASSKEY] auth/verify payload keys: ${payload.keys.toList()}',
      );
      final response = await http.post(
        url,
        headers: _getMandatoryHeaders(),
        body: jsonEncode(payload),
      );
      debugPrint('📥 [PASSKEY] auth/verify status: ${response.statusCode}');
      debugPrint('📥 [PASSKEY] auth/verify response received');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decodeAuthResponse(
          response,
          defaultError: 'OTP verification failed',
        );
      }
      lastFailure = response;
    }

    if (lastFailure == null) {
      throw Exception('OTP verification failed');
    }
    final body = _tryDecodeJsonMap(lastFailure.body);
    final err =
        _extractErrorMessage(body?['error'] ?? body?['message']) ??
        'OTP verification failed';
    throw Exception('Server Error: ${lastFailure.statusCode} - $err');
  }

  Future<Map<String, dynamic>> initiateSensitiveAction({
    required String userId,
    required String contact,
    required String action,
    required String type,
    String? token,
    Map<String, dynamic>? device,
    String? deviceName,
    String? name,
  }) async {
    final path = AppConfig.endpoints['sensitiveActionInitiate'];
    if (path == null) {
      throw Exception('Sensitive action initiate endpoint not configured');
    }

    final url = Uri.parse('$baseUrl$path');
    final payload = {
      'userId': userId,
      'contact': contact,
      'action': action,
      'type': type,
      if (device != null && device.isNotEmpty) 'device': device,
      if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
      if (name != null && name.isNotEmpty) 'name': name,
    };

    final response = await http.post(
      url,
      headers: _getMandatoryHeaders(token: token),
      body: jsonEncode(payload),
    );
    return _decodeAuthResponse(
      response,
      defaultError: 'Sensitive action initiate failed',
    );
  }

  Future<Map<String, dynamic>> verifySensitiveAction({
    required String requestId,
    required String code,
    String? token,
    bool refreshSession = false,
    Map<String, dynamic>? device,
  }) async {
    final path = AppConfig.endpoints['sensitiveActionVerify'];
    if (path == null) {
      throw Exception('Sensitive action verify endpoint not configured');
    }

    final url = Uri.parse('$baseUrl$path');
    final payload = {
      'requestId': requestId,
      'code': code,
      if (refreshSession) 'refreshSession': true,
      ...?device == null ? null : {'device': device},
    };

    final headers = {..._getMandatoryHeaders(token: token)};
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    return _decodeAuthResponse(
      response,
      defaultError: 'Sensitive action verify failed',
    );
  }

  Future<Map<String, dynamic>> biometricLoginStart({
    String? email,
    String? identifier,
    String? userId,
    String? fullName,
  }) async {
    final path = AppConfig.endpoints['biometricLoginStart'];
    if (path == null) {
      throw Exception('Biometric login start endpoint not configured');
    }

    final payload = <String, dynamic>{};
    if (userId != null && userId.isNotEmpty) {
      payload['userId'] = userId;
    }
    final resolvedIdentifier = (identifier != null && identifier.isNotEmpty)
        ? identifier
        : email;
    if (resolvedIdentifier != null && resolvedIdentifier.isNotEmpty) {
      payload['identifier'] = resolvedIdentifier;
    }
    if (fullName != null && fullName.isNotEmpty) {
      payload['full_name'] = fullName;
    }

    debugPrint('📋 [PASSKEY] login/start payload: $payload');
    final response = await _postWithFallback(
      path,
      headers: _getMandatoryHeaders(),
      body: jsonEncode(payload),
      logContext: 'PASSKEY login/start',
    );
    final data = _decodeAuthResponse(
      response,
      defaultError: 'Biometric login start failed',
    );
    _logBiometricAllowCredentialsMismatch(data);
    return data;
  }

  Future<Map<String, dynamic>> biometricLoginFinish(
    Map<String, dynamic> assertionPayload,
  ) async {
    final path = AppConfig.endpoints['biometricLoginFinish'];
    if (path == null) {
      throw Exception('Biometric login finish endpoint not configured');
    }

    final normalizedPayload = _normalizePasskeyFinishPayload(assertionPayload);
    debugPrint(
      '📋 [PASSKEY] login/finish payload keys: ${normalizedPayload.keys.toList()}',
    );
    final response = await _postWithFallback(
      path,
      headers: _getMandatoryHeaders(),
      body: jsonEncode(normalizedPayload),
      logContext: 'PASSKEY login/finish',
    );
    return _decodeAuthResponse(
      response,
      defaultError: 'Biometric login finish failed',
    );
  }

  Iterable<String> _candidatePaths(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final paths = <String>[normalized];

    if (normalized.contains('/auth/passkey/')) {
      paths.add(normalized.replaceFirst('/auth/passkey/', '/auth/biometric/'));
    } else if (normalized.contains('/auth/biometric/')) {
      paths.add(normalized.replaceFirst('/auth/biometric/', '/auth/passkey/'));
    }

    return paths.toSet();
  }

  Iterable<Uri> _candidateUris(String path, {bool allowRootFallbacks = true}) {
    String normalize(String input) {
      if (input.endsWith('/')) {
        return input.substring(0, input.length - 1);
      }
      return input;
    }

    String stripVersion(String input) {
      if (input.endsWith('/v1')) {
        return input.substring(0, input.length - 3);
      }
      if (input.endsWith('/api/v1')) {
        return input.substring(0, input.length - 7);
      }
      return input;
    }

    final normalizedBases = <String>{
      normalize(baseUrl),
      ...AppConfig.apiUrls.map(normalize),
    }.toList(growable: false);
    final seen = <String>{};
    final candidates = <Uri>[];

    void add(String base, String suffix) {
      final uri = Uri.parse('$base$suffix');
      if (seen.add(uri.toString())) {
        candidates.add(uri);
      }
    }

    for (final candidatePath in _candidatePaths(path)) {
      for (final normalizedBase in normalizedBases) {
        final root = stripVersion(normalizedBase);
        add(normalizedBase, candidatePath);
        if (allowRootFallbacks) {
          add(root, candidatePath);
          add(root, '/v1$candidatePath');
          add(root, '/api/v1$candidatePath');
        }
      }
    }

    return candidates;
  }

  Future<http.Response> _postWithFallback(
    String path, {
    required Map<String, String> headers,
    required Object body,
    required String logContext,
    bool allowRootFallbacks = true,
  }) async {
    http.Response? lastResponse;
    TimeoutException? lastTimeout;
    for (final url in _candidateUris(
      path,
      allowRootFallbacks: allowRootFallbacks,
    )) {
      debugPrint('📤 [$logContext] POST $url');
      late final http.Response response;
      try {
        response = await http
            .post(url, headers: headers, body: body)
            .timeout(_authRequestTimeout);
      } on TimeoutException catch (error) {
        lastTimeout = error;
        debugPrint('⏱️ [$logContext] timeout via $url: $error');
        continue;
      } on SocketException catch (error) {
        debugPrint('🌐 [$logContext] network failure via $url: $error');
        continue;
      } on HttpException catch (error) {
        debugPrint('🌐 [$logContext] http failure via $url: $error');
        continue;
      } on HandshakeException catch (error) {
        debugPrint('🔐 [$logContext] TLS failure via $url: $error');
        continue;
      }
      debugPrint('📥 [$logContext] status: ${response.statusCode}');
      debugPrint('📥 [$logContext] response received');

      final bodyMap = _tryDecodeJsonMap(response.body);
      final notFound =
          response.statusCode == 404 ||
          (bodyMap?['error']?.toString().toUpperCase() == 'NOT_FOUND');
      if (notFound) {
        lastResponse = response;
        continue;
      }
      return response;
    }
    if (lastTimeout != null && lastResponse == null) {
      throw TimeoutException(
        '$logContext request timed out. Please try again in a moment.',
        _authRequestTimeout,
      );
    }
    return lastResponse ??
        await http
            .post(Uri.parse('$baseUrl$path'), headers: headers, body: body)
            .timeout(_authRequestTimeout);
  }

  Map<String, dynamic> _normalizeAssertionPayload(
    Map<String, dynamic> payload,
  ) {
    final normalized = Map<String, dynamic>.from(payload);
    normalized.remove('origin');
    normalized.remove('app_origin');
    normalized.remove('appOrigin');

    final idValue =
        normalized['id'] ??
        normalized['credentialId'] ??
        normalized['credential_id'] ??
        normalized['rawId'];

    if (idValue is String && idValue.isNotEmpty) {
      normalized['id'] = idValue;
    } else if (idValue is num) {
      normalized['id'] = idValue.toString();
    }

    final response = normalized['response'];
    if (response is Map) {
      final responseMap = Map<String, dynamic>.from(response);
      responseMap.remove('origin');
      responseMap.remove('app_origin');
      responseMap.remove('appOrigin');
      normalized['response'] = responseMap;
    }

    return normalized;
  }

  Map<String, dynamic> _normalizePasskeyFinishPayload(
    Map<String, dynamic> payload,
  ) {
    final normalized = _normalizeAssertionPayload(payload);

    final resolvedUserId = _stringify([
      normalized['userId'],
      normalized['user_id'],
      normalized['uid'],
    ]);
    if (resolvedUserId.isNotEmpty) {
      normalized['userId'] = resolvedUserId;
    }

    final resolvedChallenge = _extractChallengeValue(normalized['challenge']);
    if (resolvedChallenge.isNotEmpty) {
      normalized['challenge'] = resolvedChallenge;
    }

    final resolvedPlatform = _stringify([
      normalized['platform'],
      normalized['devicePlatform'],
      normalized['device_platform'],
    ]);
    if (resolvedPlatform.isNotEmpty) {
      normalized['platform'] = resolvedPlatform.toLowerCase();
    }

    final resolvedIdentifier = _stringify([
      normalized['identifier'],
      normalized['email'],
      normalized['username'],
    ]);
    if (resolvedIdentifier.isNotEmpty) {
      normalized['identifier'] = resolvedIdentifier;
    }

    return normalized;
  }

  String _extractChallengeValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Map) {
      return _stringify([
        value['challenge'],
        value['value'],
        value['id'],
        value['requestId'],
        value['request_id'],
      ]);
    }
    return '';
  }

  String _stringify(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return '';
  }

  dynamic _extractPasskeyOptions(Map<String, dynamic> payload) {
    return PasskeyResponseParser.extractOptions(payload);
  }

  Map<String, dynamic> _decodeAuthResponse(
    http.Response response, {
    required String defaultError,
  }) {
    final body = _tryDecodeJsonMap(response.body);
    if (body == null) {
      throw Exception(
        _buildNonJsonResponseError(response, context: defaultError),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == true) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        final normalizedBody = Map<String, dynamic>.from(body);
        normalizedBody.remove('success');
        return normalizedBody;
      }

      final data = body['data'];
      if (data is Map<String, dynamic> && _looksLikePasskeyPayload(data)) {
        return data;
      }
      if (_looksLikePasskeyPayload(body)) {
        return Map<String, dynamic>.from(body);
      }
    }

    final err =
        _extractErrorMessage(body['error'] ?? body['message']) ?? defaultError;
    throw Exception('Server Error: ${response.statusCode} - $err');
  }

  bool _looksLikePasskeyPayload(Map<String, dynamic> payload) {
    return payload.containsKey('challenge') ||
        payload.containsKey('publicKey') ||
        payload.containsKey('allowCredentials') ||
        payload.containsKey('rpId') ||
        payload.containsKey('rp') ||
        payload.containsKey('pubKeyCredParams') ||
        payload.containsKey('status') ||
        payload.containsKey('token');
  }

  void _logBiometricAllowCredentialsMismatch(Map<String, dynamic> payload) {
    if (!kDebugMode) return;
    final registeredId = _lastRegisteredCredentialId?.trim();
    if (registeredId == null || registeredId.isEmpty) return;

    final allowCredentials = payload['allowCredentials'];
    if (allowCredentials is! List) return;

    final ids = <String>[];
    for (final entry in allowCredentials) {
      if (entry is Map) {
        final value = entry['id'];
        if (value is String && value.isNotEmpty) {
          ids.add(value);
        }
      }
    }
    if (ids.isEmpty) return;

    final matches = ids.where((id) => id == registeredId).toList();
    if (matches.isEmpty) {
      debugPrint(
        '⚠️ [PASSKEY][DEBUG] allowCredentials mismatch: '
        'registeredId=$registeredId allowIdsCount=${ids.length}',
      );
    } else {
      debugPrint(
        '✅ [PASSKEY][DEBUG] allowCredentials matched registeredId=$registeredId',
      );
    }
  }

  bool _looksLikeOtpChallenge(Map<String, dynamic> payload) {
    return PasskeyResponseParser.requiresOtpChallenge(payload);
  }

  String? _extractErrorMessage(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final candidates = <dynamic>[
        value['message'],
        value['error'],
        value['detail'],
      ];
      for (final candidate in candidates) {
        if (candidate is String && candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }

  String _extractErrorCode(Map<String, dynamic> body) {
    final raw = body['error'];
    if (raw is String && raw.trim().isNotEmpty) {
      final value = raw.trim();
      return value.contains(':') ? value.split(':').first.trim() : value;
    }
    if (raw is Map) {
      final code = raw['code'] ?? raw['error'];
      if (code is String && code.trim().isNotEmpty) return code.trim();
    }
    final message = body['message'];
    if (message is String && message.contains(':')) {
      return message.split(':').first.trim();
    }
    return 'AUTH_ERROR';
  }

  Map<String, dynamic> _decodeOptionalDataResponse(
    http.Response response, {
    required String defaultError,
  }) {
    final body = _tryDecodeJsonMap(response.body);
    if (body == null) {
      throw Exception(
        _buildNonJsonResponseError(response, context: defaultError),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == false) {
        final err =
            _extractErrorMessage(body['error'] ?? body['message']) ??
            defaultError;
        throw Exception('Server Error: ${response.statusCode} - $err');
      }

      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return body;
    }

    final err =
        _extractErrorMessage(body['error'] ?? body['message']) ?? defaultError;
    throw Exception('Server Error: ${response.statusCode} - $err');
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _buildNonJsonResponseError(
    http.Response response, {
    required String context,
  }) {
    final sample = response.body.length > 120
        ? '${response.body.substring(0, 120)}...'
        : response.body;
    return '$context: backend returned non-JSON response '
        '(status ${response.statusCode}). '
        'This usually means wrong base URL/route (often an HTML error page). '
        'Response sample: $sample';
  }

  /// 4. CREATE WALLET (example)
  Future<Map<String, dynamic>> createWallet(
    String name,
    String currency,
  ) async {
    if (_accessToken == null) throw Exception('Not authenticated');
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['wallets']}');
    try {
      final response = await http.post(
        url,
        headers: _getMandatoryHeaders(token: _accessToken),
        body: jsonEncode({
          'name': name,
          'currency': currency,
          'type': 'standard',
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Failed to create wallet');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ---------- GETTERS (to use stored values) ----------
  bool get isAuthenticated => _accessToken != null;

  /// Access the stored refresh token (if any)
  String? get refreshToken => _refreshToken;

  /// Access the stored user profile (if any)
  Map<String, dynamic>? get userProfile => _userProfile;

  /// Clear all tokens (logout)
  void logoutLocal() {
    _accessToken = null;
    _refreshToken = null;
    _userProfile = null;
  }
}

/// USAGE EXAMPLE (remove or comment out in production)
/*
void main() async {
  final client = OrbiAuthClient(baseUrl: AppConfig.apiUrl);
  try {
    debugPrint('Connecting to: ${client.baseUrl}');
    // Login
    await client.login('user@example.com', 'SecurePass123!');
    debugPrint('Access token: ${client.isAuthenticated}');
    // Get profile
    final profile = await client.getUserProfile();
    debugPrint('Profile: $profile');
    // Create wallet
    final wallet = await client.createWallet('My Savings', 'TZS');
    debugPrint('Wallet: $wallet');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
*/
