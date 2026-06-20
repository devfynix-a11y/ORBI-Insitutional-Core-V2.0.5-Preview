part of 'auth_controller.dart';

Future<void> _authLoadBiometricState(AuthController controller) async {
  final enabled = await controller._storage.isBiometricEnabled();
  final setupRequired = await controller._storage.isBiometricSetupRequired();
  controller._biometricEnabled = enabled;
  controller._biometricSetupRequired = setupRequired;
  controller._notifyChanged();
}

Future<void> _authSetBiometricSetupRequired(
  AuthController controller,
  bool required,
) async {
  controller._biometricSetupRequired = required;
  if (required) {
    await controller._storage.setBiometricSetupRequired(true);
  } else {
    await controller._storage.clearBiometricSetupRequired();
  }
}

Future<void> _authSetBiometricEnabled(
  AuthController controller,
  bool enabled, {
  bool preserveIdentity = false,
}) async {
  controller._biometricEnabled = enabled;
  await controller._storage.setBiometricEnabled(enabled);
  if (!enabled && !preserveIdentity) {
    await controller._storage.clearBiometricIdentity();
    await controller._storage.resetBiometricFailedAttempts();
    await controller._storage.resetBiometricTemporaryDisable();
  }
  controller._notifyChanged();
}

Future<bool> _authRegisterPasskey(
  AuthController controller, {
  String? email,
  Future<String?> Function()? requestOtp,
}) async {
  if (controller._passkeyRegistrationCompleter != null) {
    return controller._passkeyRegistrationCompleter!.future;
  }

  final completer = Completer<bool>();
  controller._passkeyRegistrationCompleter = completer;
  controller._biometricInFlight = true;
  controller._error = null;
  controller._notifyChanged();

  try {
    final resolvedUserId = controller.userId;
    if (resolvedUserId.isEmpty) {
      throw Exception('Missing user ID for biometric registration.');
    }

    final resolvedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : controller.currentSession?.user.email;
    if (resolvedEmail == null || resolvedEmail.isEmpty) {
      throw Exception('Missing email for biometric registration.');
    }

    var start = await controller._repo.biometricRegisterStart(
      userId: resolvedUserId,
      email: resolvedEmail,
    );
    controller._debugBiometricRegisterStart(start, context: 'initial');

    if (controller._isBiometricChallengeRequired(start)) {
      final otpRequestId = controller._extractBiometricRequestId(start);
      if (otpRequestId.isEmpty) {
        throw Exception('OTP request ID missing for biometric setup.');
      }
      if (requestOtp == null) {
        throw Exception('OTP required to register this device.');
      }
      controller._biometricInFlight = false;
      controller._notifyChanged();
      final otpCode = await requestOtp();
      if (otpCode == null || otpCode.trim().isEmpty) {
        throw Exception('OTP verification cancelled.');
      }
      controller._biometricInFlight = true;
      controller._notifyChanged();
      start = await controller._repo.biometricRegisterStart(
        userId: resolvedUserId,
        email: resolvedEmail,
        otpCode: otpCode.trim(),
        otpRequestId: otpRequestId,
      );
      controller._debugBiometricRegisterStart(start, context: 'challenge');
    }

    final rawOptions = controller._extractBiometricOptions(start);
    if (rawOptions is! Map) {
      throw Exception('Biometric registration options missing.');
    }
    final options = Map<String, dynamic>.from(rawOptions);
    controller._injectPasskeyRpId(options);
    controller._debugPasskeyOptions('register', options);

    final credential = await controller._passkeyService.createCredential(
      options,
    );
    if (credential.isEmpty) {
      throw Exception('Biometric registration returned empty response.');
    }
    controller._debugPasskeyResult('register', credential);

    final challenge = controller._extractPasskeyChallenge(options);
    if (challenge.isEmpty) {
      throw Exception('Biometric challenge missing from registration options.');
    }

    final devicePayload = await controller._buildDevicePayload();
    final platformLabel = Platform.isIOS ? 'ios' : 'android';

    await controller._repo.biometricRegisterFinish({
      'userId': resolvedUserId,
      'challenge': challenge,
      'response': credential,
      'device': devicePayload,
      'deviceName': devicePayload['deviceName'],
      'platform': platformLabel,
    });

    final currentFullName =
        controller.currentSession?.user.fullName?.trim() ?? '';
    await controller._storage.saveBiometricIdentity({
      'userId': resolvedUserId,
      'email': resolvedEmail,
      'identifier': resolvedEmail,
      if (currentFullName.isNotEmpty) ...{
        'fullName': currentFullName,
        'full_name': currentFullName,
      },
    });
    await controller.setBiometricEnabled(true, preserveIdentity: true);
    await controller._setBiometricSetupRequired(false);
    completer.complete(true);
    return true;
  } catch (e) {
    controller._error = UserFacingError.from(
      e,
      fallback: 'Unable to register biometrics right now. Please try again.',
    );
    debugPrint('PASSKEY registration failed: ${controller._error}');
    completer.complete(false);
    return false;
  } finally {
    controller._biometricInFlight = false;
    controller._passkeyRegistrationCompleter = null;
    controller._notifyChanged();
  }
}

dynamic _authExtractBiometricOptions(Map<String, dynamic> start) {
  return PasskeyResponseParser.extractOptions(start);
}

String _authExtractPasskeyChallenge(Map<String, dynamic> options) {
  if (options['challenge'] is String) {
    return options['challenge'] as String;
  }
  if (options['publicKey'] is Map) {
    final pk = Map<String, dynamic>.from(options['publicKey'] as Map);
    if (pk['challenge'] is String) return pk['challenge'] as String;
  }
  return '';
}

void _authDebugBiometricRegisterStart(
  AuthController controller,
  Map<String, dynamic> start, {
  required String context,
}) {
  final data = start['data'] is Map
      ? Map<String, dynamic>.from(start['data'] as Map)
      : <String, dynamic>{};
  final options = _authExtractBiometricOptions(start);
  final optionsMap = options is Map ? Map<String, dynamic>.from(options) : null;
  final hasChallenge =
      optionsMap?['challenge'] != null ||
      (optionsMap?['publicKey'] is Map &&
          (optionsMap?['publicKey'] as Map)['challenge'] != null);
  final requestId = controller._extractBiometricRequestId(start);
  final challengeType = controller._extractBiometricChallengeType(start);
  debugPrint(
    'biometricRegisterStart[$context]: keys=${start.keys.toList()} '
    'dataKeys=${data.keys.toList()} '
    'optionsType=${options.runtimeType} '
    'hasChallenge=$hasChallenge '
    'requestId=$requestId '
    'challengeType=$challengeType',
  );
}

void _authDebugPasskeyOptions(
  AuthController controller,
  String mode,
  Map<String, dynamic> options,
) {
  Map<String, dynamic> resolvePublicKey(Map<String, dynamic> input) {
    if (input['publicKey'] is Map) {
      return Map<String, dynamic>.from(input['publicKey'] as Map);
    }
    return input;
  }

  final pk = resolvePublicKey(options);
  final rp = pk['rp'] is Map ? Map<String, dynamic>.from(pk['rp'] as Map) : {};
  final rpId = controller._pickString([pk['rpId'], rp['id']]);
  final origin = controller._pickString([pk['origin'], options['origin']]);
  final allow = pk['allowCredentials'] is List
      ? List.from(pk['allowCredentials'] as List)
      : const <dynamic>[];
  final allowIds = <String>[];
  for (final entry in allow) {
    if (entry is Map) {
      final id = controller._pickString([entry['id']]);
      if (id.isNotEmpty) allowIds.add(id);
    }
  }
  final challenge = controller._pickString([
    pk['challenge'],
    options['challenge'] ?? '',
  ]);
  debugPrint(
    '[PASSKEY] $mode options rpId=$rpId origin=$origin '
    'allowCredentials=${allowIds.length} '
    'challengeLen=${challenge.length}',
  );
  if (allowIds.isNotEmpty) {
    debugPrint('[PASSKEY] $mode allowCredentialIds=${allowIds.join(",")}');
  }
}

void _authDebugPasskeyResult(
  AuthController controller,
  String mode,
  Map<String, dynamic> result,
) {
  final id = controller._pickString([result['id'], result['rawId']]);
  final type = controller._pickString([result['type']]);
  debugPrint(
    '[PASSKEY] $mode result type=$type idLen=${id.length} keys=${result.keys.toList()}',
  );
  if (id.isNotEmpty) {
    debugPrint('[PASSKEY] $mode result id=$id');
  }
}

void _authInjectPasskeyRpId(Map<String, dynamic> options) {
  final rpId = AppConfig.passkeyRpId;

  Map<String, dynamic> pk = options['publicKey'] is Map
      ? Map<String, dynamic>.from(options['publicKey'] as Map)
      : options;
  pk.remove('origin');
  options.remove('origin');
  if (rpId.isNotEmpty) {
    if (pk['rpId'] == null) {
      pk['rpId'] = rpId;
    }
    if (pk['rp'] is Map) {
      final rp = Map<String, dynamic>.from(pk['rp'] as Map);
      rp['id'] ??= rpId;
      pk['rp'] = rp;
    } else if (pk['rp'] == null) {
      pk['rp'] = {'id': rpId};
    }
  }
  if (options['publicKey'] is Map) {
    options['publicKey'] = pk;
  }
}

Future<bool> _authCompleteMandatoryBiometricSetup(
  AuthController controller, {
  Future<String?> Function()? requestOtp,
}) async {
  controller._error = null;
  controller._notifyChanged();

  final success = await controller.registerPasskey(requestOtp: requestOtp);
  if (success) {
    controller._isAuthenticated = true;
    controller._clearReauthLock();
    controller._notifyChanged();
  }
  return success;
}

Future<bool> _authBiometricPasskeyLogin(
  AuthController controller, {
  Future<String?> Function()? requestOtp,
}) async {
  if (controller._passkeyLoginCompleter != null) {
    return controller._passkeyLoginCompleter!.future;
  }

  final completer = Completer<bool>();
  controller._passkeyLoginCompleter = completer;
  controller._biometricInFlight = true;
  controller._error = null;
  controller._notifyChanged();

  try {
    final identity = await controller._storage.getBiometricIdentity();
    final storedProfile = await controller._storedProfileSnapshot();
    final resolvedUserId = controller._pickString([
      identity?['userId'],
      identity?['user_id'],
      storedProfile['id'],
      storedProfile['user_id'],
      storedProfile['userId'],
      controller.userId,
    ]);
    if (resolvedUserId.isEmpty) {
      throw Exception('Missing biometric identity. Re-enable biometrics.');
    }

    final resolvedIdentifier = controller._pickString([
      identity?['identifier'],
      identity?['email'],
      identity?['mail'],
      storedProfile['email'],
      storedProfile['mail'],
      controller.currentSession?.user.email,
    ]);
    final resolvedFullName = controller._pickString([
      identity?['fullName'],
      identity?['full_name'],
      storedProfile['full_name'],
      storedProfile['fullName'],
      storedProfile['name'],
      controller.currentSession?.user.fullName,
    ]);

    final start = await controller._repo.biometricLoginStart(
      userId: resolvedUserId,
      identifier: resolvedIdentifier.isEmpty ? null : resolvedIdentifier,
      fullName: resolvedFullName.isEmpty ? null : resolvedFullName,
    );
    controller._debugBiometricRegisterStart(start, context: 'login');

    final rawOptions = controller._extractBiometricOptions(start);
    if (rawOptions is! Map) {
      throw Exception('Biometric login options missing.');
    }
    final options = Map<String, dynamic>.from(rawOptions);
    controller._injectPasskeyRpId(options);
    controller._debugPasskeyOptions('login', options);

    final assertion = await controller._getAssertionWithFallback(options);
    if (assertion.isEmpty) {
      throw Exception('Biometric login returned empty response.');
    }
    controller._debugPasskeyResult('login', assertion);

    final challenge = controller._extractPasskeyChallenge(options);
    if (challenge.isEmpty) {
      throw Exception('Biometric challenge missing from login options.');
    }

    final devicePayload = await controller._buildDevicePayload();
    final behaviorMetrics = controller._buildBehaviorMetrics();
    final platformLabel = Platform.isIOS ? 'ios' : 'android';

    final finishResponse = await controller._repo.biometricLoginFinish({
      'userId': resolvedUserId,
      if (resolvedIdentifier.isNotEmpty) 'identifier': resolvedIdentifier,
      'challenge': challenge,
      'response': assertion,
      'device': devicePayload,
      'behaviorMetrics': behaviorMetrics,
      'platform': platformLabel,
    });

    final status = finishResponse['status']?.toString().toUpperCase() ?? '';
    if (status == 'STEP_UP_REQUIRED') {
      final tempToken = controller._pickString([
        finishResponse['tempToken'],
        finishResponse['temp_token'],
      ]);
      final contactEmail = controller._pickString([
        identity?['email'],
        identity?['mail'],
        controller.currentSession?.user.email,
      ]);
      final otpRequestId = controller._pickString([
        finishResponse['requestId'],
        finishResponse['request_id'],
        finishResponse['otpRequestId'],
        finishResponse['otp_request_id'],
      ]);
      if (requestOtp != null &&
          tempToken.isNotEmpty &&
          contactEmail.isNotEmpty &&
          otpRequestId.isNotEmpty) {
        controller._biometricInFlight = false;
        controller._notifyChanged();
        final otpCode = await requestOtp();
        if (otpCode == null || otpCode.trim().isEmpty) {
          throw Exception('OTP verification cancelled.');
        }
        controller._biometricInFlight = true;
        controller._notifyChanged();
        final verificationResult = await controller._repo.verifySensitiveAction(
          requestId: otpRequestId,
          code: otpCode.trim(),
          token: tempToken,
          refreshSession: true,
          device: devicePayload,
        );
        final normalized = controller._normalizePasskeyLoginResponse(
          verificationResult,
        );
        final normalizedToken = controller._pickString([
          normalized['access_token'],
          normalized['session'] is Map
              ? (normalized['session'] as Map)['access_token']
              : null,
        ]);
        if (normalizedToken.isEmpty) {
          throw Exception(
            'Biometric step-up succeeded, but no fresh session was returned.',
          );
        }
        await controller._service.establishSession(normalized);
        controller._client.setAccessToken(normalizedToken);
        await controller._finalizeAuthenticatedSession(
          fallbackEmail: normalized['user'] is Map
              ? (normalized['user'] as Map)['email']?.toString()
              : null,
        );
        controller._isAuthenticated = true;
        controller._clearReauthLock();
        completer.complete(true);
        return true;
      }
      controller._error =
          finishResponse['message']?.toString() ?? 'OTP verification required.';
      completer.complete(false);
      return false;
    }

    final normalized = controller._normalizePasskeyLoginResponse(
      finishResponse,
    );
    await controller._service.establishSession(normalized);
    controller._client.setAccessToken(normalized['access_token']?.toString());
    await controller._finalizeAuthenticatedSession(
      fallbackEmail: normalized['user'] is Map
          ? (normalized['user'] as Map)['email']?.toString()
          : null,
    );
    controller._isAuthenticated = true;
    controller._clearReauthLock();
    completer.complete(true);
    return true;
  } catch (e) {
    controller._error = UserFacingError.from(
      e,
      fallback: 'Unable to sign in with biometrics. Please try again.',
    );
    debugPrint('PASSKEY login failed: ${controller._error}');
    completer.complete(false);
    return false;
  } finally {
    controller._biometricInFlight = false;
    controller._passkeyLoginCompleter = null;
    controller._notifyChanged();
  }
}

Future<Map<String, dynamic>> _authGetAssertionWithFallback(
  AuthController controller,
  Map<String, dynamic> options,
) async {
  try {
    return await controller._passkeyService.getAssertion(options);
  } catch (e) {
    final message = e.toString().toLowerCase();
    if (message.contains('cancel')) {
      rethrow;
    }
    final allow = options['allowCredentials'];
    if (allow is List && allow.isNotEmpty) {
      final fallback = Map<String, dynamic>.from(options);
      fallback.remove('allowCredentials');
      return await controller._passkeyService.getAssertion(fallback);
    }
    rethrow;
  }
}

Map<String, dynamic> _authNormalizePasskeyLoginResponse(
  AuthController controller,
  Map<String, dynamic> response,
) {
  if (response['session'] is Map ||
      response['access_token'] != null ||
      response['refresh_token'] != null) {
    return response;
  }

  final token = response['token'] ?? response['accessToken'];
  final refreshToken = response['refreshToken'] ?? response['refresh_token'];
  final user =
      response['user'] ?? controller.currentSession?.user.rawData ?? {};

  return {
    'access_token': token,
    ...?(refreshToken == null ? null : {'refresh_token': refreshToken}),
    'user': user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{},
  };
}
