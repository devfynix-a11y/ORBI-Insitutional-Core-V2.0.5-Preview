import 'package:flutter/foundation.dart';
import 'package:orbi_mobileapp/core/auth/auth_repository.dart';
import 'package:orbi_mobileapp/core/auth/token_manager.dart';
import 'package:orbi_mobileapp/core/session/session_manager.dart';
import 'package:orbi_mobileapp/core/storage/secure_storage_service.dart';

class AuthService {
  final AuthRepository _repo;
  final SessionManager _session;
  final SecureStorageService _storage;
  final TokenManager _tokenManager;

  AuthService(this._repo, this._session, this._storage, this._tokenManager);

  Future<void> establishSession(Map<String, dynamic> response) async {
    final nested = response['session'];
    final nestedSession = nested is Map ? nested : const <String, dynamic>{};

    final accessToken =
        response['access_token'] ?? nestedSession['access_token'];
    final refreshToken =
        response['refresh_token'] ?? nestedSession['refresh_token'];
    final rawUser = response['user'] ?? nestedSession['user'];
    final existingProfile = await _session.getStoredProfile();
    final normalizedUser = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final user = normalizedUser.isNotEmpty
        ? normalizedUser
        : (existingProfile ?? const <String, dynamic>{});

    if (accessToken is! String || accessToken.isEmpty) {
      throw Exception('Access token missing in auth response');
    }

    await _session.saveSession({
      'access_token': accessToken,
      'user': user,
    });

    if (refreshToken is String && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    }
  }

  Future<String?> getValidAccessToken() async {
    final token = await _session.getStoredToken();
    if (token == null) {
      // Access token may be intentionally cleared on inactivity timeout.
      // Try refresh-token based silent re-authentication first.
      return _refresh();
    }

    if (!_tokenManager.isExpired(token)) {
      return token;
    }

    return _refresh();
  }

  Future<void> clearSession() async {
    await _session.clearSession();
    await _storage.clearRefreshToken();
  }

  Future<void> clearSessionPreservingResume() async {
    await _storage.clearAccessTokenAndProfile();
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _repo.refresh(refreshToken);
      await establishSession(response);
      return await _session.getStoredToken();
    } catch (error) {
      if (_shouldClearSessionAfterRefreshFailure(error)) {
        debugPrint('🔐 [AUTH] Refresh token rejected. Clearing stored session.');
        await clearSession();
      } else {
        debugPrint(
          '🔐 [AUTH] Refresh failed without a confirmed auth rejection. '
          'Keeping stored session for retry. Error: $error',
        );
      }
      return null;
    }
  }

  bool _shouldClearSessionAfterRefreshFailure(Object error) {
    final raw = error.toString().toLowerCase();

    const authRejectionSignals = <String>[
      '401',
      '403',
      'unauthorized',
      'forbidden',
      'invalid refresh',
      'refresh token invalid',
      'refresh token expired',
      'refresh token revoked',
      'token revoked',
      'jwt expired',
      'session expired',
      'invalid token',
      'token expired',
      're-authenticate',
      'reauthenticate',
      'login again',
      'log in again',
    ];

    const transientSignals = <String>[
      'socketexception',
      'failed host lookup',
      'network',
      'timeout',
      'timed out',
      'connection reset',
      'connection refused',
      'connection closed',
      'handshake',
      'tls',
      'certificate',
      '500',
      '502',
      '503',
      '504',
      'bad gateway',
      'service unavailable',
      'gateway timeout',
      'internal server error',
      'html',
      '<!doctype',
      '<html',
    ];

    final looksTransient = transientSignals.any(raw.contains);
    if (looksTransient) return false;

    return authRejectionSignals.any(raw.contains);
  }
}
