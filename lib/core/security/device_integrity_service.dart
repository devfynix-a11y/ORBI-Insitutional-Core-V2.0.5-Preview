import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIntegritySnapshot {
  final String? attestationToken;
  final bool? isCompromised;
  final String? deviceState;

  const DeviceIntegritySnapshot({
    this.attestationToken,
    this.isCompromised,
    this.deviceState,
  });
}

class DeviceIntegrityService {
  static const MethodChannel _channel = MethodChannel('orbi/device_integrity');
  static DeviceIntegritySnapshot _cached = const DeviceIntegritySnapshot();

  static DeviceIntegritySnapshot get snapshot => _cached;
  static String? get attestationToken => _cached.attestationToken;
  static bool? get isCompromised => _cached.isCompromised;
  static String? get deviceState => _cached.deviceState;

  static Future<void> init() async {
    _cached = await _fetchSnapshot();
  }

  static Future<DeviceIntegritySnapshot> refresh() async {
    _cached = await _fetchSnapshot();
    return _cached;
  }

  static Future<DeviceIntegritySnapshot> _fetchSnapshot() async {
    try {
      final Map<dynamic, dynamic>? raw =
          await _channel.invokeMapMethod('getIntegritySnapshot');
      if (raw == null) return const DeviceIntegritySnapshot();
      final mapped = raw.map((key, value) => MapEntry(key.toString(), value));
      return DeviceIntegritySnapshot(
        attestationToken: _asString(mapped['attestationToken']),
        isCompromised: _asBool(mapped['isCompromised']),
        deviceState: _asString(mapped['deviceState']),
      );
    } on MissingPluginException {
      return const DeviceIntegritySnapshot();
    } catch (e) {
      debugPrint('⚠️ device_integrity: failed to fetch snapshot: $e');
      return const DeviceIntegritySnapshot();
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }
}
