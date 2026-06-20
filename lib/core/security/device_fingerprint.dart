import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprint {
  static const String _storageKey = 'device_fingerprint_raw';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final Uuid _uuid = const Uuid();
  static String? _rawId;

  /// Initialize the device fingerprint cache.
  /// Call once during app startup to ensure stable IDs.
  static Future<void> init() async {
    if (_rawId != null) return;
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      _rawId = existing;
      return;
    }
    final generated = _uuid.v4();
    _rawId = generated;
    await _storage.write(key: _storageKey, value: generated);
  }

  /// Returns a stable SHA-256 fingerprint string.
  static String generate() {
    final raw = _rawId ?? _fallbackRaw();
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String _fallbackRaw() {
    return '${Platform.operatingSystem}-${Platform.version}';
  }
}
