class PasskeyResponseParser {
  static dynamic extractOptions(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final options =
        payload['options'] ??
        payload['publicKey'] ??
        data['options'] ??
        data['publicKey'] ??
        data['webauthn'] ??
        data['credentialCreationOptions'];
    if (options != null) return options;

    if (payload['challenge'] != null ||
        payload['rp'] != null ||
        payload['pubKeyCredParams'] != null) {
      return payload;
    }
    if (data['challenge'] != null ||
        data['rp'] != null ||
        data['pubKeyCredParams'] != null) {
      return data;
    }

    return null;
  }

  static bool hasOptions(Map<String, dynamic> payload) {
    return extractOptions(payload) is Map;
  }

  static String pickString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return '';
  }

  static bool? boolFrom(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }

  static String extractRequestId(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final challenge = data['challenge'] is Map
        ? Map<String, dynamic>.from(data['challenge'] as Map)
        : <String, dynamic>{};
    return pickString([
      payload['requestId'],
      payload['request_id'],
      payload['challenge_id'],
      payload['challengeId'],
      payload['verification_id'],
      payload['verificationId'],
      data['requestId'],
      data['request_id'],
      data['challenge_id'],
      data['challengeId'],
      data['verification_id'],
      data['verificationId'],
      challenge['requestId'],
      challenge['request_id'],
      challenge['challenge_id'],
      challenge['challengeId'],
      challenge['verification_id'],
      challenge['verificationId'],
    ]);
  }

  static String extractChallengeType(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final challenge = data['challenge'] is Map
        ? Map<String, dynamic>.from(data['challenge'] as Map)
        : <String, dynamic>{};
    return pickString([
      payload['challengeType'],
      payload['challenge_type'],
      data['challengeType'],
      data['challenge_type'],
      challenge['challengeType'],
      challenge['challenge_type'],
    ]);
  }

  static bool requiresOtpChallenge(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final challenge = data['challenge'] is Map
        ? Map<String, dynamic>.from(data['challenge'] as Map)
        : <String, dynamic>{};

    final statuses = [
      payload['status'],
      payload['decision'],
      payload['security_decision'],
      payload['securityDecision'],
      payload['code'],
      data['status'],
      data['decision'],
      data['security_decision'],
      data['securityDecision'],
      data['code'],
      challenge['status'],
      challenge['decision'],
      challenge['security_decision'],
      challenge['securityDecision'],
      challenge['code'],
      extractChallengeType(payload),
    ].map((value) => pickString([value]).toUpperCase());

    for (final status in statuses) {
      if (status.contains('CHALLENGE') ||
          status.contains('OTP') ||
          status.contains('STEP_UP') ||
          status.contains('VERIFY')) {
        return true;
      }
    }

    final flags = [
      payload['challenge_required'],
      payload['challengeRequired'],
      payload['otp_required'],
      payload['otpRequired'],
      payload['require_otp'],
      payload['requires_otp'],
      payload['two_fa_required'],
      payload['twoFaRequired'],
      payload['mfa_required'],
      payload['mfaRequired'],
      payload['verification_required'],
      payload['verificationRequired'],
      data['challenge_required'],
      data['challengeRequired'],
      data['otp_required'],
      data['otpRequired'],
      data['require_otp'],
      data['requires_otp'],
      data['two_fa_required'],
      data['twoFaRequired'],
      data['mfa_required'],
      data['mfaRequired'],
      data['verification_required'],
      data['verificationRequired'],
      challenge['challenge_required'],
      challenge['challengeRequired'],
      challenge['otp_required'],
      challenge['otpRequired'],
      challenge['require_otp'],
      challenge['requires_otp'],
      challenge['two_fa_required'],
      challenge['twoFaRequired'],
      challenge['mfa_required'],
      challenge['mfaRequired'],
      challenge['verification_required'],
      challenge['verificationRequired'],
    ];

    for (final flag in flags) {
      if (boolFrom(flag) == true) return true;
    }

    if (hasOptions(payload)) {
      return false;
    }

    return extractRequestId(payload).isNotEmpty;
  }
}
