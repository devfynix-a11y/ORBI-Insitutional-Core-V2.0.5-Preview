import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../security/device_integrity_service.dart';

class OrbiRequestHeaders {
  OrbiRequestHeaders._();

  static final Uuid _uuid = const Uuid();

  static Map<String, String> build({
    String? token,
    String? registryType,
    String? fingerprint,
    String? trace,
    String? idempotencyKey,
    bool includeContentType = true,
    bool includeAccept = false,
  }) {
    final resolvedTrace = trace ?? _uuid.v4();
    final now = DateTime.now();
    final attestation = DeviceIntegrityService.attestationToken;
    final deviceState = DeviceIntegrityService.deviceState;
    final resolvedRegistryType = _resolveRegistryType(
      registryType: registryType,
      token: token,
    );

    return {
      if (includeContentType) 'Content-Type': 'application/json',
      if (includeAccept) 'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': 'Bearer ${token.trim()}',
      ...?switch (resolvedRegistryType) {
        final registryValue? => {'x-orbi-registry-type': registryValue},
        null => null,
      },
      'x-orbi-app-id': AppConfig.appId,
      'x-orbi-app-origin': AppConfig.appOrigin,
      if (AppConfig.shouldSendAndroidApkHash)
        'x-orbi-apk-hash': AppConfig.androidAppHash,
      'x-orbi-trace': resolvedTrace,
      'x-orbi-timezone-name': now.timeZoneName,
      'x-orbi-timezone-offset-minutes': now.timeZoneOffset.inMinutes.toString(),
      'x-orbi-timezone-offset': _formatOffset(now.timeZoneOffset),
      'x-orbi-request-timestamp-utc': now.toUtc().toIso8601String(),
      if (fingerprint != null && fingerprint.trim().isNotEmpty)
        'x-orbi-fingerprint': fingerprint.trim(),
      if (attestation != null && attestation.isNotEmpty)
        'x-orbi-attestation': attestation,
      if (deviceState != null && deviceState.isNotEmpty)
        'x-orbi-device-state': deviceState,
      'x-fynix-app-id': AppConfig.appId,
      'x-fynix-trace': resolvedTrace,
      'x-fynix-timezone-offset-minutes':
          now.timeZoneOffset.inMinutes.toString(),
      if (fingerprint != null && fingerprint.trim().isNotEmpty)
        'x-fynix-fingerprint': fingerprint.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'x-idempotency-key': idempotencyKey.trim(),
    };
  }

  static String _formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$mins';
  }

  static String? _resolveRegistryType({String? registryType, String? token}) {
    final explicitRegistryType = registryType?.trim();
    if (explicitRegistryType != null && explicitRegistryType.isNotEmpty) {
      return explicitRegistryType.toUpperCase();
    }

    final payload = _decodeJwtPayload(token);
    if (payload == null) return null;

    final extractedRegistryType = _firstNonEmptyString([
      payload['registry_type'],
      payload['user_registry_type'],
      payload['app_metadata'] is Map
          ? (payload['app_metadata'] as Map)['registry_type']
          : null,
      payload['user_metadata'] is Map
          ? (payload['user_metadata'] as Map)['registry_type']
          : null,
      payload['user'] is Map
          ? (payload['user'] as Map)['registry_type']
          : null,
    ]);

    if (extractedRegistryType == null) return null;
    return extractedRegistryType.toUpperCase();
  }

  static Map<String, dynamic>? _decodeJwtPayload(String? token) {
    final rawToken = token?.trim();
    if (rawToken == null || rawToken.isEmpty) return null;

    final parts = rawToken.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
