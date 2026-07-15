import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

class TransactionGeoContext {
  const TransactionGeoContext._();

  static const Duration maxLocationAge = Duration(minutes: 2);

  static Future<Map<String, dynamic>> requiredMetadata({
    bool allowNetworkFallback = false,
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
      position = await _getFreshPosition();
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

    final publicNetworkGeo = await _fetchPublicNetworkGeo();
    final publicIp = publicNetworkGeo?['publicIp']?.toString();
    final ipGeo = _networkIpMetadata(publicNetworkGeo, capturedAt);

    return {
      'clientTimeContext': buildClientTimeContext(),
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
      ...?ipGeo == null ? null : {'ipGeo': ipGeo},
      'riskContext': {
        'locationConsent': true,
        'locationRequired': true,
        'locationAgeSeconds': age.inSeconds,
        'locationFallback': false,
        ...?publicIp == null
            ? null
            : {
                'networkPublicIp': publicIp,
                'networkIpSource': 'ipapi_co',
              },
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
      'clientTimeContext': geoMetadata['clientTimeContext'] is Map
          ? Map<String, dynamic>.from(geoMetadata['clientTimeContext'] as Map)
          : buildClientTimeContext(),
      if (geoMetadata['geo'] is Map)
        'geo': Map<String, dynamic>.from(geoMetadata['geo'] as Map),
      if (geoMetadata['ipGeo'] is Map)
        'ipGeo': Map<String, dynamic>.from(geoMetadata['ipGeo'] as Map),
      'riskContext': {...currentRiskContext, ...incomingRiskContext},
    };
  }

  static Map<String, dynamic> buildClientTimeContext() {
    final now = DateTime.now();
    final utc = now.toUtc();
    return {
      // Canonical audit instant sent as UTC; backend persists and compares this.
      'request_timestamp_utc': utc.toIso8601String(),
      'timezone_name': now.timeZoneName,
      'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
      'timezone_offset': _formatOffset(now.timeZoneOffset),
    };
  }

  static Map<String, dynamic> buildRegistrationTimeMetadata() {
    return {
      'clientTimeContext': buildClientTimeContext(),
    };
  }

  static double _round(double value, {required int decimals}) {
    final factor = pow(10, decimals).toDouble();
    return (value * factor).roundToDouble() / factor;
  }

  static Map<String, dynamic>? _networkIpMetadata(
    Map<String, dynamic>? networkGeo,
    DateTime capturedAt,
  ) {
    final publicIp = networkGeo?['publicIp']?.toString();
    if (publicIp == null || publicIp.trim().isEmpty) return null;
    return {
      'countryCode': networkGeo?['countryCode'],
      'region': networkGeo?['region'],
      'city': networkGeo?['city'],
      'latitudeRounded': _roundNullable(networkGeo?['latitude']),
      'longitudeRounded': _roundNullable(networkGeo?['longitude']),
      'accuracyMeters': null,
      'source': 'network_ip_device_public',
      'precision': 'coarse',
      'publicIp': publicIp,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  static Future<Position> _getFreshPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    }
  }

  static Future<Map<String, dynamic>> _networkIpFallback({
    required String reason,
    required String userMessage,
  }) async {
    final capturedAt = DateTime.now().toUtc();
    final publicNetworkGeo = await _fetchPublicNetworkGeo();
    final publicIp = publicNetworkGeo?['publicIp']?.toString();
    return {
      'clientTimeContext': buildClientTimeContext(),
      'geo': {
        'countryCode': publicNetworkGeo?['countryCode'],
        'region': publicNetworkGeo?['region'],
        'city': publicNetworkGeo?['city'],
        'latitudeRounded': _roundNullable(publicNetworkGeo?['latitude']),
        'longitudeRounded': _roundNullable(publicNetworkGeo?['longitude']),
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
        ...?publicIp == null
            ? null
            : {
                'networkPublicIp': publicIp,
                'networkIpSource': 'ipapi_co',
              },
      },
    };
  }

  static String _formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$mins';
  }

  static double? _roundNullable(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite) return null;
    return _round(parsed, decimals: 3);
  }

  static Future<Map<String, dynamic>?> _fetchPublicNetworkGeo() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await utf8.decodeStream(response);
        final parsed = jsonDecode(body);
        if (parsed is Map) {
          final ip = parsed['ip']?.toString().trim();
          if (ip != null && ip.isNotEmpty) {
            return {
              'publicIp': ip,
              'countryCode': parsed['country_code']?.toString().trim(),
              'region': parsed['region_code']?.toString().trim().isNotEmpty == true
                  ? parsed['region_code']?.toString().trim()
                  : parsed['region']?.toString().trim(),
              'city': parsed['city']?.toString().trim(),
              'latitude': parsed['latitude'],
              'longitude': parsed['longitude'],
            };
          }
        }
      }
    } catch (_) {
      // Fall through to IP-only lookup below.
    } finally {
      client.close(force: true);
    }

    final publicIp = await _fetchPublicIp();
    if (publicIp == null) return null;
    return {'publicIp': publicIp};
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
