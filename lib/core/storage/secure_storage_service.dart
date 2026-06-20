import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';
  static const String _rememberedUserProfileKey = 'remembered_user_profile';
  static const String _biometricIdentityKey = 'biometric_identity';
  static const String _biometricSetupRequiredKey = 'biometric_setup_required';
  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';
  static const String _reauthLockRequiredKey = 'reauth_lock_required';
  static const String _reauthLockStartedAtKey = 'reauth_lock_started_at';
  static const String _appBackgroundedAtKey = 'app_backgrounded_at';
  static final Uuid _uuid = const Uuid();

  /// Safely write to secure storage, ensuring value is ALWAYS a String
  Future<void> _safeWrite(String key, dynamic value) async {
    String stringValue;

    if (value is String) {
      stringValue = value;
    } else if (value is Map || value is List) {
      // Safety: Auto-encode any Map/List to JSON
      debugPrint(
        '⚠️ _safeWrite: Received non-String (${value.runtimeType}), auto-encoding to JSON',
      );
      stringValue = jsonEncode(value);
    } else {
      throw Exception(
        '_safeWrite: Value must be a String, Map, or List. Got ${value.runtimeType}',
      );
    }

    debugPrint('💾 _safeWrite($key): Writing ${stringValue.length} chars');
    await _storage.write(key: key, value: stringValue);
    debugPrint('✅ _safeWrite($key): Completed');
  }

  Future<void> saveToken(String token) async {
    try {
      debugPrint(
        '💾 Saving token (type: ${token.runtimeType}, length: ${token.length})',
      );
      await _safeWrite(_accessTokenKey, token);
      debugPrint('✅ Token saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
      rethrow;
    }
  }

  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      debugPrint(
        '💾 Saving user profile (type: ${profile.runtimeType}, ${profile.keys.length} keys)',
      );
      final sanitized = _sanitizeUserProfile(profile);
      await _safeWrite(_userProfileKey, sanitized);
      await saveRememberedUserProfile(sanitized);
      debugPrint('✅ User profile saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
      debugPrint('📋 Attempted to save profile: $profile');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final json = await _storage.read(key: _userProfileKey);
    if (json == null) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint(
        '⚠️ secure_storage_service: failed to decode user_profile: $e',
      );
      return null;
    }
  }

  Future<void> saveRememberedUserProfile(Map<String, dynamic> profile) async {
    final remembered = _extractRememberedProfile(profile);
    if (remembered.isEmpty) return;
    await _safeWrite(_rememberedUserProfileKey, remembered);
  }

  Future<Map<String, dynamic>?> getRememberedUserProfile() async {
    final json = await _storage.read(key: _rememberedUserProfileKey);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint(
        '⚠️ secure_storage_service: failed to decode remembered_user_profile: $e',
      );
      return null;
    }
  }

  Map<String, dynamic> _extractRememberedProfile(Map<String, dynamic> profile) {
    final src = Map<String, dynamic>.from(profile);
    final remembered = <String, dynamic>{};

    void pick(String from, [String? to]) {
      final value = src[from];
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      remembered[to ?? from] = value;
    }

    pick('id');
    pick('user_id');
    pick('userId');
    pick('email');
    pick('mail');
    pick('full_name');
    pick('fullName');
    pick('name');
    pick('first_name');
    pick('last_name');
    pick('avatar_url');
    pick('avatarUrl');
    pick('profile_photo_url');
    pick('photo_url');
    pick('phone');
    pick('currency');
    pick('language');
    pick('language_code');

    return remembered;
  }

  Map<String, dynamic> _sanitizeUserProfile(Map<String, dynamic> profile) {
    final sanitized = Map<String, dynamic>.from(profile);
    sanitized.remove('wallets');
    sanitized.remove('balances');
    sanitized.remove('transactions');
    sanitized.remove('financial_ledger');
    sanitized.remove('ledger');
    sanitized.remove('session');
    sanitized.remove('access_token');
    sanitized.remove('refresh_token');

    sanitized.updateAll((key, value) {
      if (value is Map) {
        return _sanitizeUserProfile(Map<String, dynamic>.from(value));
      }
      if (value is List) {
        return value
            .map(
              (item) => item is Map
                  ? _sanitizeUserProfile(Map<String, dynamic>.from(item))
                  : item,
            )
            .toList();
      }
      return value;
    });

    sanitized.removeWhere((key, value) {
      final lower = key.toLowerCase();
      if (lower.contains('balance') ||
          lower.contains('wallet') ||
          lower.contains('ledger') ||
          lower.contains('transaction')) {
        return true;
      }
      return false;
    });

    return sanitized;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _safeWrite(_refreshTokenKey, refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> clearSessionOnly() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userProfileKey);
    await clearReauthLockRequired();
  }

  /// Clear only access token + profile metadata.
  /// Keep refresh token for silent re-authentication after inactivity timeout.
  Future<void> clearAccessTokenAndProfile() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  Future<void> setReauthLockRequired(bool required) async {
    if (!required) {
      await clearReauthLockRequired();
      return;
    }
    await _safeWrite(_reauthLockRequiredKey, 'true');
    await _safeWrite(
      _reauthLockStartedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<bool> isReauthLockRequired() async {
    final value = await _storage.read(key: _reauthLockRequiredKey);
    return value == 'true';
  }

  Future<DateTime?> getReauthLockStartedAt() async {
    final value = await _storage.read(key: _reauthLockStartedAtKey);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> clearReauthLockRequired() async {
    await _storage.delete(key: _reauthLockRequiredKey);
    await _storage.delete(key: _reauthLockStartedAtKey);
  }

  Future<void> markAppBackgrounded() async {
    await _safeWrite(
      _appBackgroundedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getAppBackgroundedAt() async {
    final value = await _storage.read(key: _appBackgroundedAtKey);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> clearAppBackgroundedAt() async {
    await _storage.delete(key: _appBackgroundedAtKey);
  }

  // Mandatory biometric setup flag
  Future<void> setBiometricSetupRequired(bool required) async {
    if (!required) {
      await _storage.delete(key: _biometricSetupRequiredKey);
      return;
    }
    await _safeWrite(_biometricSetupRequiredKey, 'true');
  }

  Future<bool> isBiometricSetupRequired() async {
    final val = await _storage.read(key: _biometricSetupRequiredKey);
    return val == 'true';
  }

  Future<void> clearBiometricSetupRequired() async {
    await _storage.delete(key: _biometricSetupRequiredKey);
  }

  // Biometric preference helpers
  Future<void> setBiometricEnabled(bool enabled) async {
    await _safeWrite('biometric_enabled', enabled.toString());
    debugPrint('💾 Biometric enabled set to $enabled');
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: 'biometric_enabled');
    // default to false if not present or unparsable
    return val == 'true';
  }

  Future<void> saveBiometricIdentity(Map<String, dynamic> identity) async {
    await _safeWrite(_biometricIdentityKey, identity);
  }

  Future<Map<String, dynamic>?> getBiometricIdentity() async {
    final json = await _storage.read(key: _biometricIdentityKey);
    if (json == null) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint(
        '⚠️ secure_storage_service: failed to decode biometric_identity: $e',
      );
      return null;
    }
  }

  Future<void> clearBiometricIdentity() async {
    await _storage.delete(key: _biometricIdentityKey);
  }

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    return (hash ?? '').isNotEmpty && (salt ?? '').isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final trimmed = pin.trim();
    if (trimmed.length != 4) {
      throw Exception('PIN must be exactly 4 digits.');
    }
    final salt = _uuid.v4();
    final hash = _hashPin(trimmed, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final hash = await _storage.read(key: _pinHashKey);
    if (salt == null || hash == null) return false;
    final attempt = _hashPin(pin.trim(), salt);
    return attempt == hash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinHashKey);
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  // Failed biometric attempts tracking
  Future<void> incrementBiometricFailedAttempts() async {
    final current = await getBiometricFailedAttempts();
    await _safeWrite('biometric_failed_attempts', (current + 1).toString());
  }

  Future<int> getBiometricFailedAttempts() async {
    final val = await _storage.read(key: 'biometric_failed_attempts');
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> resetBiometricFailedAttempts() async {
    await _storage.delete(key: 'biometric_failed_attempts');
  }

  /// Disable biometric after too many failed attempts
  Future<void> disableBiometricTemporarily() async {
    await setBiometricEnabled(false);
    await _safeWrite('biometric_temporarily_disabled', 'true');
    debugPrint('🔒 Biometric temporarily disabled due to failed attempts');
  }

  Future<bool> isBiometricTemporarilyDisabled() async {
    final val = await _storage.read(key: 'biometric_temporarily_disabled');
    return val == 'true';
  }

  Future<void> resetBiometricTemporaryDisable() async {
    await _storage.delete(key: 'biometric_temporarily_disabled');
  }
}
