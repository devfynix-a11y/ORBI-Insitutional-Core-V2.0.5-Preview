import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../../../core/config/app_config.dart';
import '../device/device_info_service.dart';
import '../security/device_fingerprint.dart';
import '../network/orbi_request_headers.dart';
import '../session/session_manager.dart';
import '../security/tls_pinning.dart';
import '../network/orbi_security_interceptor.dart';

class ApiClient {
  final Dio _dio = Dio();
  final SessionManager _session = SessionManager();
  final String _fingerprint = DeviceFingerprint.generate();
  static bool _didLogApkHashHeader = false;

  ApiClient() {
    _configure();
  }

  Dio get client => _dio;

  void _configure() {
    _dio.options = BaseOptions(
      // ✅ Use versioned API base URL with /v1/
      baseUrl: AppConfig.apiUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
    );

    if (TlsPinning.enabled) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            TlsPinningHttpOverrides().createHttpClient(null),
      );
    }

    _dio.interceptors.add(OrbiSecurityInterceptor(_dio));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final authHeader = options.headers['Authorization'];
          String? resolvedToken;
          if (authHeader == null || authHeader.toString().trim().isEmpty) {
            final token = await _session.getStoredToken();
            if (token != null && token.trim().isNotEmpty) {
              resolvedToken = token.trim();
              options.headers['Authorization'] = 'Bearer $resolvedToken';
            }
          } else {
            final rawHeader = authHeader.toString().trim();
            if (rawHeader.toLowerCase().startsWith('bearer ')) {
              resolvedToken = rawHeader.substring(7).trim();
            }
          }

          final storedProfile = await _session.getStoredProfile();
          final registryType = storedProfile == null
              ? null
              : (storedProfile['registry_type'] ??
                        storedProfile['registryType'])
                    ?.toString();

          final trace =
              options.headers['x-orbi-trace']?.toString().trim().isNotEmpty ==
                  true
              ? options.headers['x-orbi-trace'].toString().trim()
              : null;
          final sharedHeaders = OrbiRequestHeaders.build(
            token: resolvedToken,
            registryType: registryType,
            fingerprint: _fingerprint,
            trace: trace,
            includeAccept: true,
          );
          for (final entry in sharedHeaders.entries) {
            options.headers.putIfAbsent(entry.key, () => entry.value);
          }

          final deviceInfo = await DeviceInfoService.buildPayload();
          final deviceId = deviceInfo['device_id']?.toString().trim();
          if (deviceId != null &&
              deviceId.isNotEmpty &&
              options.headers['x-orbi-device-id'] == null) {
            options.headers['x-orbi-device-id'] = deviceId;
          }

          if (kDebugMode && !_didLogApkHashHeader) {
            _didLogApkHashHeader = true;
            debugPrint(
              '🛡️ [API_CLIENT] x-orbi-apk-hash=${AppConfig.androidAppHash}',
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          try {
            debugPrint(
              '📥 [${response.requestOptions.method}] ${_requestUrl(response.requestOptions)} -> ${response.statusCode}',
            );
            debugPrint('📋 Response body: ${response.data}');
          } catch (e) {
            debugPrint('⚠️ api_client: failed to log response: $e');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final fallbackBaseUrl = _fallbackBaseUrlFor(error.requestOptions);
          if (fallbackBaseUrl != null && _shouldRetryOnFallback(error)) {
            try {
              final retryOptions = error.requestOptions;
              retryOptions.baseUrl = fallbackBaseUrl;
              retryOptions.headers['x-orbi-fallback-attempt'] = 'google-vm';
              debugPrint(
                '🌐 [API_CLIENT] Primary API unavailable; retrying via $fallbackBaseUrl',
              );
              final response = await _dio.fetch<dynamic>(retryOptions);
              return handler.resolve(response);
            } catch (retryError) {
              debugPrint('⚠️ [API_CLIENT] Fallback retry failed: $retryError');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // Removed unused methods _refreshToken and _retry to fix build errors.

  String _requestUrl(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${options.baseUrl}$path';
  }

  String? _fallbackBaseUrlFor(RequestOptions options) {
    if (options.headers['x-orbi-fallback-attempt'] != null) return null;
    if (options.path.startsWith('http://') || options.path.startsWith('https://')) {
      return null;
    }
    return AppConfig.fallbackForBaseUrl(options.baseUrl);
  }

  bool _shouldRetryOnFallback(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final method = error.requestOptions.method.toUpperCase();
        return method == 'GET' &&
            (statusCode == 502 || statusCode == 503 || statusCode == 504);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
