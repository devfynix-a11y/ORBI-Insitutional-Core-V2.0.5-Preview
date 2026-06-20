import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// BiometricAuthService handles fingerprint and face recognition authentication.
///
/// After initial login, users can opt to use biometrics instead of password
/// for faster re-authentication when the session expires.
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<BiometricAvailability> getAvailability() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final enrolled = await _localAuth.canCheckBiometrics;
      final types = enrolled ? await _localAuth.getAvailableBiometrics() : const <BiometricType>[];
      return BiometricAvailability(
        supported: supported,
        enrolled: enrolled,
        types: types,
      );
    } catch (e) {
      debugPrint('❌ Biometric availability check failed: $e');
      return const BiometricAvailability(
        supported: false,
        enrolled: false,
        types: <BiometricType>[],
      );
    }
  }

  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      // both hardware and enrolled check
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return can && supported;
    } catch (e) {
      debugPrint('❌ Biometric availability check failed: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('❌ Failed to get biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics (fingerprint or face)
  /// Returns true if authentication is successful
  Future<bool> authenticate({
    String reason = 'Authenticate to access your ORBI account',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('⚠️ Biometric not available on this device');
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      debugPrint('🔐 authenticate() returned $isAuthenticated');

      if (isAuthenticated) {
        debugPrint('✅ Biometric authentication successful');
        return true;
      } else {
        debugPrint('❌ Biometric authentication cancelled');
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Biometric auth error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected biometric error: $e');
      return false;
    }
  }

  /// Stop any ongoing authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('⚠️ Failed to stop authentication: $e');
    }
  }
}

class BiometricAvailability {
  final bool supported;
  final bool enrolled;
  final List<BiometricType> types;

  const BiometricAvailability({
    required this.supported,
    required this.enrolled,
    required this.types,
  });
}
