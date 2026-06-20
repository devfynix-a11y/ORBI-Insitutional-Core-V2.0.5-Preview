import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

class TransactionGeoContext {
  const TransactionGeoContext._();

  static const Duration maxLocationAge = Duration(minutes: 2);

  static Future<Map<String, dynamic>> requiredMetadata({
    bool allowNetworkFallback = true,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!allowNetworkFallback) {
        throw const TransactionGeoException(
          'Turn on Location Services to complete this transaction securely.',
        );
      }
      return _networkIpFallback(
        reason: 'device_location_service_disabled',
        userMessage:
            'Device location is off. ORBI will use network location for this transaction review.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!allowNetworkFallback) {
        throw const TransactionGeoException(
          'Allow Location permission to complete this transaction securely.',
        );
      }
      return _networkIpFallback(
        reason: permission == LocationPermission.deniedForever
            ? 'device_location_permission_denied_forever'
            : 'device_location_permission_denied',
        userMessage:
            'Location permission is off. ORBI will use network location for this transaction review.',
      );
    }

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      if (!allowNetworkFallback) {
        throw const TransactionGeoException(
          'Precise location is required to complete this transaction securely.',
        );
      }
      return _networkIpFallback(
        reason: 'device_gps_unavailable',
        userMessage:
            'Precise location is unavailable. ORBI will use network location for this transaction review.',
      );
    }
    final capturedAt = DateTime.now().toUtc();
    final age = capturedAt.difference(position.timestamp.toUtc()).abs();
    if (age > maxLocationAge) {
      if (!allowNetworkFallback) {
        throw const TransactionGeoException(
          'Fresh location is required to complete this transaction securely.',
        );
      }
      return _networkIpFallback(
        reason: 'device_gps_stale',
        userMessage:
            'Precise location is stale. ORBI will use network location for this transaction review.',
      );
    }

    return {
      'geo': {
        'countryCode': null,
        'region': null,
        'city': null,
        'latitudeRounded': _round(position.latitude, decimals: 3),
        'longitudeRounded': _round(position.longitude, decimals: 3),
        'accuracyMeters': _round(position.accuracy, decimals: 1),
        'source': 'device_gps',
        'precision': 'high',
        'consented': true,
        'capturedAt': capturedAt.toIso8601String(),
      },
      'riskContext': {
        'locationConsent': true,
        'locationRequired': true,
        'locationAgeSeconds': age.inSeconds,
        'locationFallback': false,
      },
    };
  }

  static Map<String, dynamic> mergeInto(
    Map<String, dynamic> metadata,
    Map<String, dynamic> geoMetadata,
  ) {
    final currentRiskContext = metadata['riskContext'] is Map
        ? Map<String, dynamic>.from(metadata['riskContext'] as Map)
        : <String, dynamic>{};
    final incomingRiskContext = geoMetadata['riskContext'] is Map
        ? Map<String, dynamic>.from(geoMetadata['riskContext'] as Map)
        : <String, dynamic>{};

    return {
      ...metadata,
      if (geoMetadata['geo'] is Map)
        'geo': Map<String, dynamic>.from(geoMetadata['geo'] as Map),
      'riskContext': {...currentRiskContext, ...incomingRiskContext},
    };
  }

  static double _round(double value, {required int decimals}) {
    final factor = pow(10, decimals).toDouble();
    return (value * factor).roundToDouble() / factor;
  }

  static Future<Map<String, dynamic>> _networkIpFallback({
    required String reason,
    required String userMessage,
  }) async {
    final capturedAt = DateTime.now().toUtc();
    final publicIp = await _fetchPublicIp();
    return {
      'geo': {
        'countryCode': null,
        'region': null,
        'city': null,
        'latitudeRounded': null,
        'longitudeRounded': null,
        'accuracyMeters': null,
        'source': publicIp == null
            ? 'network_ip_from_request'
            : 'network_ip_device_public',
        'precision': 'coarse',
        'publicIp': publicIp,
        'consented': false,
        'capturedAt': capturedAt.toIso8601String(),
        'fallbackReason': reason,
      },
      'riskContext': {
        'locationConsent': false,
        'locationRequired': true,
        'locationFallback': true,
        'locationFallbackReason': reason,
        'locationFallbackMessage': userMessage,
        'locationAgeSeconds': 0,
      },
    };
  }

  static Future<String?> _fetchPublicIp() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await utf8.decodeStream(response);
      final parsed = jsonDecode(body);
      if (parsed is Map && parsed['ip'] != null) {
        final ip = parsed['ip'].toString().trim();
        return ip.isEmpty ? null : ip;
      }
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
    return null;
  }
}

class TransactionGeoException implements Exception {
  const TransactionGeoException(this.message);

  final String message;

  @override
  String toString() => message;
}
