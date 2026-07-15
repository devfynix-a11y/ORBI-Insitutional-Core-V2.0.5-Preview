import 'package:flutter/material.dart';
import 'dart:async';
import '../storage/secure_storage_service.dart';

/// SessionManager stores session state and manual lock callbacks.
///
/// Key Features:
/// - Persists token/profile
/// - Exposes manual auto-lock callback
/// - Retains user profile metadata for biometric fallback
class SessionManager {
  static const Duration _sessionTimeout = Duration(minutes: 3);
  static const Duration _warningLeadTime = Duration(seconds: 60);
  final SecureStorageService _storage = SecureStorageService();
  VoidCallback? _onSessionExpired;
  ValueChanged<int>? _onInactivityWarning;
  VoidCallback? _onInactivityWarningCleared;
  bool _isSessionActive = false;
  DateTime _lastInteraction = DateTime.now();
  Timer? _inactivityTimer;
  int _remainingSeconds = _sessionTimeout.inSeconds;
  bool _warningVisible = false;

  bool get isSessionActive => _isSessionActive;
  int get remainingSeconds => _remainingSeconds;
  Duration get sessionTimeout => _sessionTimeout;
  Duration get warningLeadTime => _warningLeadTime;
  bool get hasTimedOut =>
      _isSessionActive &&
      DateTime.now().difference(_lastInteraction) >= _sessionTimeout;

  /// Save session after successful login
  Future<void> saveSession(Map<String, dynamic> session) async {
    try {
      debugPrint('🔐 [STRT] saveSession starting...');
      final token = session['access_token'];
      debugPrint('🔐 [CHK1] token retrieved: ${token == null ? "NULL" : "OK"}');

      // Ensure token is a string
      if (token == null) {
        throw Exception('No access_token in session');
      }

      debugPrint('🔍 saveSession: token type = ${token.runtimeType}');

      if (token is! String) {
        throw Exception(
          'Invalid access_token type: ${token.runtimeType}. Expected String but got ${token.runtimeType}',
        );
      }

      debugPrint('💾 saveSession: saving token (${token.length} chars)');
      debugPrint('🔐 [CHK2] About to call _storage.saveToken()...');
      await _storage.saveToken(token);
      debugPrint('🔐 [CHK3] _storage.saveToken() completed');
      debugPrint('✅ saveSession: token saved to storage');

      debugPrint('🔐 [CHK4] About to process user profile...');
      // Persist user profile if provided (encode Map -> JSON string)
      final user = session['user'];
      debugPrint(
        '🔐 [CHK5] user retrieved: ${user == null ? "NULL" : "OK (${user.runtimeType})"}',
      );

      if (user != null) {
        debugPrint('🔍 saveSession: user type = ${user.runtimeType}');
        if (user is Map<String, dynamic>) {
          debugPrint(
            '💾 saveSession: saving user profile (${user.keys.length} keys)',
          );
          try {
            debugPrint('🔐 [CHK6] About to call _storage.saveUserProfile()...');
            await _storage.saveUserProfile(user);
            debugPrint('🔐 [CHK7] _storage.saveUserProfile() completed');
            debugPrint('✅ saveSession: user profile saved to storage');
          } catch (profileErr) {
            debugPrint('❌ saveSession: Error saving user profile: $profileErr');
            debugPrint('📋 saveSession: Profile being saved: $user');
            rethrow;
          }
        } else {
          debugPrint(
            '⚠️ session_manager: user is not a Map (${user.runtimeType}) - skipping save',
          );
        }
      } else {
        debugPrint('ℹ️ session_manager: no user data in session');
      }
      debugPrint('🔐 [CHK8] Setting session active...');
      _isSessionActive = true;
      resetInactivityTimer();
      debugPrint('✅ Session saved');
      debugPrint('🔐 [DONE] saveSession completed successfully');
    } catch (e) {
      debugPrint('❌ saveSession FATAL ERROR: $e');
      debugPrint('🔥 Stack trace: $e');
      rethrow;
    }
  }

  void resetInactivityTimer() {
    if (!_isSessionActive) return;
    _lastInteraction = DateTime.now();
    _remainingSeconds = _sessionTimeout.inSeconds;
    if (_warningVisible) {
      _warningVisible = false;
      _onInactivityWarningCleared?.call();
    }
    _inactivityTimer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isSessionActive) return;
      final remaining =
          (_sessionTimeout.inSeconds -
                  DateTime.now().difference(_lastInteraction).inSeconds)
              .clamp(0, _sessionTimeout.inSeconds);
      _remainingSeconds = remaining;
      if (remaining > 0 && remaining <= _warningLeadTime.inSeconds) {
        _warningVisible = true;
        _onInactivityWarning?.call(remaining);
      } else if (_warningVisible && remaining > _warningLeadTime.inSeconds) {
        _warningVisible = false;
        _onInactivityWarningCleared?.call();
      }
      if (remaining <= 0) {
        await performAutoLogout();
      }
    });
    debugPrint('🔄 Activity heartbeat received');
  }

  Future<void> handleAppResumed() async {
    if (!_isSessionActive) return;
    if (hasTimedOut) {
      await performAutoLogout();
      return;
    }
    resetInactivityTimer();
  }

  void markSessionActive() {
    _isSessionActive = true;
    unawaited(_storage.clearReauthLockRequired());
    resetInactivityTimer();
  }

  void suspendInactivityMonitoring() {
    _isSessionActive = false;
    _remainingSeconds = _sessionTimeout.inSeconds;
    if (_warningVisible) {
      _warningVisible = false;
      _onInactivityWarningCleared?.call();
    }
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Set callback to execute when session expires
  void setOnSessionExpired(VoidCallback callback) {
    _onSessionExpired = callback;
  }

  void setOnInactivityWarning(ValueChanged<int>? callback) {
    _onInactivityWarning = callback;
  }

  void setOnInactivityWarningCleared(VoidCallback? callback) {
    _onInactivityWarningCleared = callback;
  }

  /// Auto-logout after inactivity.
  /// Soft-lock only: keep session tokens and profile in storage.
  /// This lets users continue the same session after inactivity until
  /// backend token expiry or explicit logout.
  Future<void> performAutoLogout() async {
    if (!_isSessionActive && !_warningVisible) {
      debugPrint(
        '⏱️ performAutoLogout called, but session is already inactive',
      );
    }

    // Ensure we stop any active timer path before callback navigation.
    _isSessionActive = false;
    _warningVisible = false;
    _remainingSeconds = 0;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    await _storage.setReauthLockRequired(true);

    debugPrint('🔒 Session soft-locked due to inactivity (token retained)');

    // Trigger the callback (usually navigates to login)
    if (_onSessionExpired != null) {
      try {
        _onSessionExpired!.call();
        debugPrint('📲 Auto-logout callback executed');
      } catch (e, st) {
        debugPrint('❌ Auto-logout callback failed: $e\n$st');
      }
    } else {
      debugPrint('⚠️ onSessionExpired callback is not set');
    }
  }

  /// Manual user-initiated logout
  Future<void> clearSession() async {
    suspendInactivityMonitoring();
    await _storage.clearSessionOnly();
    debugPrint('👋 Session cleared (user logout)');
  }

  /// Cleanup on app dispose
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Retrieve the stored access token
  Future<String?> getStoredToken() async {
    return await _storage.getToken();
  }

  /// Retrieve the stored user profile
  Future<Map<String, dynamic>?> getStoredProfile() async {
    return await _storage.getUserProfile();
  }
}
