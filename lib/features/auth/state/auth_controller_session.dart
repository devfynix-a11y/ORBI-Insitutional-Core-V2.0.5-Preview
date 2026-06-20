part of 'auth_controller.dart';

Future<void> _authHandleSessionExpired(
  AuthController controller, {
  String message = 'Session expired. Please log in again.',
}) async {
  controller.currentSession = null;
  controller._client.setAccessToken(null);
  controller._isAuthenticated = false;
  controller._isReauthLocked = false;
  controller._error = message;
  controller._sessionManager.suspendInactivityMonitoring();
  controller._stopProactiveTokenRefresh();
  controller._lockExpiryTimer?.cancel();
  controller._lockExpiryTimer = null;
  await controller._storage.clearReauthLockRequired();
  controller._notifyChanged();
}

Future<void> _authEnsureSessionIdentity(
  AuthController controller, {
  String? fallbackEmail,
  String? fallbackFullName,
}) async {
  if (controller.currentSession == null) return;

  final raw = Map<String, dynamic>.from(
    controller.currentSession!.user.rawData,
  );
  final hasName =
      (raw['full_name']?.toString().trim().isNotEmpty ?? false) ||
      (raw['fullName']?.toString().trim().isNotEmpty ?? false) ||
      (raw['name']?.toString().trim().isNotEmpty ?? false) ||
      ((raw['first_name']?.toString().trim().isNotEmpty ?? false) &&
          (raw['last_name']?.toString().trim().isNotEmpty ?? false));
  final hasEmail = raw['email']?.toString().trim().isNotEmpty ?? false;

  var changed = false;
  if (!hasEmail && fallbackEmail != null && fallbackEmail.trim().isNotEmpty) {
    raw['email'] = fallbackEmail.trim();
    changed = true;
  }

  if (!hasName &&
      fallbackFullName != null &&
      fallbackFullName.trim().isNotEmpty) {
    final normalized = fallbackFullName.trim();
    raw['full_name'] = normalized;
    raw['name'] = normalized;
    changed = true;
  }

  if (!changed) return;

  controller.currentSession = SessionModel.fromJson({
    'access_token': controller.currentSession!.accessToken,
    'user': raw,
  });
  await controller._sessionManager.saveSession(
    controller.currentSession!.toJson(),
  );
}

Future<void> _authSyncBiometricIdentity(
  AuthController controller, {
  String? fallbackEmail,
  String? fallbackFullName,
}) async {
  final existing = await controller._storage.getBiometricIdentity() ?? {};
  final resolvedUserId = controller._pickString([
    controller.currentSession?.user.id,
    controller.currentSession?.user.rawData['id'],
    controller.currentSession?.user.rawData['user_id'],
    controller.currentSession?.user.rawData['userId'],
    existing['userId'],
    existing['user_id'],
  ]);
  final resolvedEmail = controller._pickString([
    controller.currentSession?.user.email,
    controller.currentSession?.user.rawData['email'],
    fallbackEmail,
    existing['email'],
    existing['identifier'],
  ]);
  final resolvedName = controller._pickString([
    controller.currentSession?.user.fullName,
    controller.currentSession?.user.rawData['full_name'],
    controller.currentSession?.user.rawData['fullName'],
    controller.currentSession?.user.rawData['name'],
    fallbackFullName,
    existing['fullName'],
    existing['full_name'],
  ]);

  if (resolvedUserId.isEmpty && resolvedEmail.isEmpty) {
    return;
  }

  await controller._storage.saveBiometricIdentity({
    ...existing,
    if (resolvedUserId.isNotEmpty) 'userId': resolvedUserId,
    if (resolvedEmail.isNotEmpty) ...{
      'email': resolvedEmail,
      'identifier': resolvedEmail,
    },
    if (resolvedName.isNotEmpty) ...{
      'fullName': resolvedName,
      'full_name': resolvedName,
    },
  });
}

Future<Map<String, dynamic>> _authStoredProfileSnapshot(
  AuthController controller,
) async {
  return await controller._sessionManager.getStoredProfile() ??
      await controller._storage.getRememberedUserProfile() ??
      const <String, dynamic>{};
}

Future<void> _authTriggerBootstrapProvisioning(
  AuthController controller,
) async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await controller._repo.bootstrapProvisioning();
      debugPrint('[AUTH] Bootstrap provisioning completed');
      return;
    } catch (e) {
      debugPrint(
        '[AUTH] Bootstrap provisioning attempt $attempt/$maxAttempts failed: $e',
      );
      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }
}

Future<void> _authPopulateInMemorySessionFromStorage(
  AuthController controller,
) async {
  final token = await controller._sessionManager.getStoredToken();
  if (token == null) {
    throw Exception('No access token after session establishment');
  }

  final storedProfile = await controller._sessionManager.getStoredProfile();
  controller.currentSession = SessionModel.fromJson({
    'access_token': token,
    'user': storedProfile ?? {},
  });
}

Future<void> _authRefreshFullSessionProfile(
  AuthController controller, {
  bool includeKyc = true,
}) async {
  final token = controller.currentSession?.accessToken;
  if (token == null || token.isEmpty || controller.currentSession == null) {
    return;
  }

  final merged = <String, dynamic>{...controller.currentSession!.user.rawData};

  try {
    final profile = await controller._client.getUserProfile();
    if (profile.isNotEmpty) {
      merged.addAll(profile);
    }
  } catch (e) {
    debugPrint('[AUTH] Failed to fetch full profile: $e');
  }

  if (includeKyc) {
    try {
      final kyc = await controller._client.fetchKycStatus(token);
      if (kyc.isNotEmpty) {
        merged.addAll(kyc);
      }
    } catch (e) {
      debugPrint('[AUTH] Failed to refresh KYC status: $e');
    }
  }

  controller.currentSession = SessionModel.fromJson({
    'access_token': token,
    'user': merged,
  });
  await controller._sessionManager.saveSession(
    controller.currentSession!.toJson(),
  );
}

void _authStartDeferredSessionHydration(
  AuthController controller, {
  String? fallbackEmail,
  String? fallbackFullName,
  bool registerPasskeyAfterAuth = false,
}) {
  Future<void>(() async {
    try {
      await controller._refreshFullSessionProfile(includeKyc: true);
      await controller._ensureSessionIdentity(
        fallbackEmail: fallbackEmail,
        fallbackFullName: fallbackFullName,
      );
      await controller._syncBiometricIdentity(
        fallbackEmail: fallbackEmail,
        fallbackFullName: fallbackFullName,
      );
      await controller._triggerBootstrapProvisioning();
      await controller._storage.resetBiometricFailedAttempts();
      await controller._storage.resetBiometricTemporaryDisable();
      if (registerPasskeyAfterAuth) {
        await controller.registerPasskey(email: fallbackEmail);
      }
      controller._notifyChanged();
    } catch (e) {
      debugPrint('[AUTH] Deferred session hydration failed: $e');
    }
  });
}

Future<void> _authFinalizeAuthenticatedSession(
  AuthController controller, {
  String? fallbackEmail,
  String? fallbackFullName,
  bool registerPasskeyAfterAuth = false,
}) async {
  await controller._populateInMemorySessionFromStorage();
  controller._client.setAccessToken(controller.currentSession?.accessToken);
  unawaited(_authSyncNotificationDeliveryState(controller));
  controller._startDeferredSessionHydration(
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
    registerPasskeyAfterAuth: registerPasskeyAfterAuth,
  );
}

Future<void> _authSyncNotificationDeliveryState(
  AuthController controller,
) async {
  try {
    final snapshot = await NotificationPreferencesService.instance.load();
    final firebase = FirebaseService();
    final token = snapshot.pushEnabled
        ? await firebase.syncTokenAfterAuthentication()
        : await firebase.setPushEnabled(false);
    await ProfileService().updateProfile({
      'notif_push': snapshot.pushEnabled,
      'notif_email': snapshot.emailAlertsEnabled,
      'fcm_token': token,
    });
  } catch (e) {
    debugPrint('⚠️ [AUTH] Failed to sync notification delivery state: $e');
  }
}

Future<bool> _authRestoreSessionFromPin(AuthController controller) async {
  final token = await controller._service.getValidAccessToken();
  if (token == null || token.isEmpty) {
    controller._error = 'Session expired. Please log in again.';
    controller._isAuthenticated = false;
    controller._sessionManager.suspendInactivityMonitoring();
    controller._stopProactiveTokenRefresh();
    controller._notifyChanged();
    return false;
  }
  final storedProfile =
      await controller._sessionManager.getStoredProfile() ??
      await controller._storage.getRememberedUserProfile();
  final fallbackEmail = controller._pickString([
    storedProfile?['email'],
    storedProfile?['mail'],
    controller.currentSession?.user.email,
  ]);
  final fallbackFullName = controller._pickString([
    storedProfile?['full_name'],
    storedProfile?['fullName'],
    storedProfile?['name'],
    controller.currentSession?.user.fullName,
  ]);
  controller.currentSession = SessionModel.fromJson({
    'access_token': token,
    'user':
        storedProfile ??
        controller.currentSession?.user.rawData ??
        const <String, dynamic>{},
  });
  controller._client.setAccessToken(token);
  await controller._finalizeAuthenticatedSession(
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
  );
  controller._isAuthenticated = true;
  controller._sessionManager.markSessionActive();
  controller._ensureProactiveTokenRefresh();
  controller._clearReauthLock();
  controller._error = null;
  controller._notifyChanged();
  return true;
}

void _authRestartLockExpiryTimer(AuthController controller, [Duration? delay]) {
  controller._lockExpiryTimer?.cancel();
  controller._lockExpiryTimer = Timer(
    delay ?? AuthController._lockExpiryTimeout,
    () async {
      if (!controller._isReauthLocked) return;
      await controller._expireLockedSessionCompletely();
    },
  );
}

Future<void> _authExpireLockedSessionCompletely(
  AuthController controller,
) async {
  await controller._service.clearSessionPreservingResume();
  controller.currentSession = null;
  controller._isAuthenticated = false;
  controller._isReauthLocked = true;
  controller._stopProactiveTokenRefresh();
  await controller._storage.setReauthLockRequired(true);
  controller._error = 'Session lock expired. Re-authenticate to continue.';
  controller._lockExpiryTimer?.cancel();
  controller._lockExpiryTimer = null;
  controller._notifyChanged();
}

void _authClearReauthLock(AuthController controller) {
  controller._isReauthLocked = false;
  controller._lockExpiryTimer?.cancel();
  controller._lockExpiryTimer = null;
  unawaited(controller._storage.clearReauthLockRequired());
  unawaited(controller._storage.clearAppBackgroundedAt());
}

Future<void> _authInitialize(AuthController controller) async {
  controller._isLoading = true;
  controller._error = null;
  controller._notifyChanged();

  try {
    await controller._loadBiometricState();
    final reauthLockRequired = await controller._storage.isReauthLockRequired();
    final reauthLockStartedAt = await controller._storage
        .getReauthLockStartedAt();
    final appBackgroundedAt = await controller._storage.getAppBackgroundedAt();
    final token = await controller.getValidAccessToken(
      expireSessionIfMissing: false,
    );
    final profile = await controller._sessionManager.getStoredProfile();

    if (token != null) {
      controller.currentSession = SessionModel.fromJson({
        'access_token': token,
        'user': profile ?? {},
      });
      controller._client.setAccessToken(token);
      final coldStartFromBackground =
          appBackgroundedAt != null && !reauthLockRequired;
      final lockRequired = reauthLockRequired || coldStartFromBackground;
      final effectiveLockStartedAt = reauthLockStartedAt ?? appBackgroundedAt;
      final effectiveLockAge = effectiveLockStartedAt == null
          ? Duration.zero
          : DateTime.now().toUtc().difference(effectiveLockStartedAt);
      final lockExpired =
          lockRequired && effectiveLockAge >= AuthController._lockExpiryTimeout;

      if (lockExpired) {
        await controller._expireLockedSessionCompletely();
      } else if (lockRequired) {
        controller._isAuthenticated = false;
        controller._isReauthLocked = true;
        controller._sessionManager.suspendInactivityMonitoring();
        controller._stopProactiveTokenRefresh();
        if (coldStartFromBackground) {
          await controller._storage.setReauthLockRequired(true);
        }
        final remaining = effectiveLockStartedAt == null
            ? AuthController._lockExpiryTimeout
            : AuthController._lockExpiryTimeout - effectiveLockAge;
        controller._restartLockExpiryTimer(
          remaining > Duration.zero ? remaining : const Duration(seconds: 1),
        );
      } else {
        controller._isAuthenticated = !controller._biometricSetupRequired;
        if (controller._isAuthenticated) {
          controller._sessionManager.markSessionActive();
          controller._ensureProactiveTokenRefresh();
        } else {
          controller._sessionManager.suspendInactivityMonitoring();
          controller._stopProactiveTokenRefresh();
        }
        controller._clearReauthLock();
        await controller._storage.clearAppBackgroundedAt();
      }
    } else {
      await controller._setBiometricSetupRequired(false);
      controller.currentSession = null;
      controller._isAuthenticated = false;
      controller._sessionManager.suspendInactivityMonitoring();
      controller._stopProactiveTokenRefresh();
      controller._clearReauthLock();
      await controller._storage.clearAppBackgroundedAt();
    }
  } catch (e) {
    controller._error = UserFacingError.from(
      e,
      fallback: 'Unable to initialize session. Please log in again.',
    );
    controller.currentSession = null;
    controller._isAuthenticated = false;
    controller._sessionManager.suspendInactivityMonitoring();
    controller._stopProactiveTokenRefresh();
    controller._clearReauthLock();
    await controller._storage.clearAppBackgroundedAt();
  } finally {
    controller._isLoading = false;
    controller._notifyChanged();
  }
}

Future<void> _authRefreshCurrentProfile(AuthController controller) async {
  if (controller.currentSession == null) return;
  controller._client.setAccessToken(controller.currentSession?.accessToken);
  await controller._refreshFullSessionProfile(includeKyc: true);
  controller._notifyChanged();
}
