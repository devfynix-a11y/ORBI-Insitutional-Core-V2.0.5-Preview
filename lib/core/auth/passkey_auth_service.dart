import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// PasskeyAuthService bridges Flutter to native passkey APIs.
/// Native handlers should be registered on channel: `orbi/passkeys`.
class PasskeyAuthService {
  static const MethodChannel _channel = MethodChannel('orbi/passkeys');
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> options,
  ) async {
    return _invokeMapMethod(
      'createCredential',
      <String, dynamic>{'options': options},
      fallbackError: 'Biometric registration is not available on this build.',
    );
  }

  Future<Map<String, dynamic>> getAssertion(
    Map<String, dynamic> options,
  ) async {
    return _invokeMapMethod(
      'getAssertion',
      <String, dynamic>{'options': options},
      fallbackError: 'Biometric login is not available on this build.',
    );
  }

  Future<Map<String, dynamic>> _invokeMapMethod(
    String method,
    Map<String, dynamic> payload, {
    required String fallbackError,
  }) async {
    try {
      debugPrint(
        '🔐 [PASSKEY] invoke $method with payload keys: ${payload.keys.join(", ")}',
      );
      final result = await _channel
          .invokeMethod(method, payload)
          .timeout(_requestTimeout);
      if (result is Map) {
        debugPrint(
          '✅ [PASSKEY] $method success; response keys: ${result.keys.join(", ")}',
        );
        return Map<String, dynamic>.from(result);
      }
      throw Exception('$fallbackError Empty payload returned.');
    } on TimeoutException {
      throw Exception(
        '$fallbackError The request timed out. Please retry or use another sign-in method.',
      );
    } on MissingPluginException {
      throw Exception(fallbackError);
    } on PlatformException catch (e) {
      debugPrint(
        '❌ [PASSKEY] $method PlatformException code=${e.code} message=${e.message} details=${e.details}',
      );
      throw Exception(
        e.message ??
            '$fallbackError (platform code: ${e.code}, details: ${e.details})',
      );
    }
  }
}
