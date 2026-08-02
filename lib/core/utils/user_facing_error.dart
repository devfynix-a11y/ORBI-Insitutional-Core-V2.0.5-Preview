import 'backend_status_message.dart';

class UserFacingError {
  static String from(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
    bool sw = false,
  }) {
    final mapped = mapBackendStatusMessage(
      error.toString(),
      sw: sw,
      fallback: fallback,
    );
    if (mapped != error.toString().trim()) return mapped;

    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return fallback;
    final lower = raw.toLowerCase();

    if (_containsAny(lower, const [
      'invalid_credentials',
      'invalid credential',
      'invalid login credentials',
      'invalid credentials',
      'authentication failed',
      'incorrect password',
      'wrong password',
      'email or password',
      'invalid email or password',
    ])) {
      return 'Invalid email or password. Please try again.';
    }

    if (_containsAny(lower, const [
      'failed host lookup',
      'no address associated with hostname',
      'name or service not known',
      'errno = 7',
      'dns',
    ])) {
      return 'Unable to reach the server. Check your internet connection and try again.';
    }

    if (_containsAny(lower, const [
      'socketexception',
      'network is unreachable',
      'no route to host',
      'connection refused',
      'connection reset',
      'timed out',
      'timeout',
      'software caused connection abort',
    ])) {
      return 'Network connection issue. Please check your internet and try again.';
    }

    if (_containsAny(lower, const [
      'handshakeexception',
      'certificate',
      'tls',
      'ssl',
    ])) {
      return 'Secure connection failed. Please try again in a moment.';
    }

    if (_containsAny(lower, const ['401', 'unauthorized', 'token expired'])) {
      return 'Your session expired. Please log in again.';
    }

    // KYC errors - enhanced matching for multiple backend formats
    if (_containsAny(lower, const [
      'kyc_limit_exceeded',
      'kyc_not_verified',
      'kyc_verification_required',
      'kyc_required',
      'kyc_incomplete',
      'kyc_failed',
      'kyc_pending',
      'please complete kyc',
      'complete your kyc',
      'must complete kyc',
      'unverified accounts are limited',
      'must be kyc verified',
      'kyc verification needed',
      'account not kyc verified',
      'requires kyc verification',
      'kyc verification incomplete',
      'enable kyc to proceed',
    ])) {
      return 'This action requires your account to be verified with our Know Your Customer (KYC) process. Please complete KYC in your profile settings.';
    }

    // Transaction limits - enhanced matching
    if (_containsAny(lower, const [
      'policy_violation',
      'exceeds policy limit',
      'amount exceeds policy limit',
      'exceeds transaction limit',
      'transaction limit exceeded',
      'daily limit exceeded',
      'weekly limit exceeded',
      'monthly limit exceeded',
      'daily_limit_exceeded',
      'weekly_limit_exceeded',
      'monthly_limit_exceeded',
      'limit exceeded',
      'max transaction amount',
      'maximum transaction amount',
      'exceeds maximum',
      'amount too large',
      'exceeds allowed',
    ])) {
      return 'This amount exceeds your current transaction limit. Check your account limits in settings or contact support for more details.';
    }

    if (_containsAny(lower, const [
      'use_email_for_non_tz_password_reset',
      'password reset by phone is available for tanzania accounts only',
    ])) {
      return 'For accounts outside Tanzania, password reset uses email only. Please enter your registered email.';
    }

    if (_containsAny(lower, const [
      'password_recently_used',
      'invalidpasswordhistory',
    ])) {
      return 'Choose a new password you have not used before.';
    }

    if (_containsAny(lower, const [
      'invalid_password_policy',
      'invalid password',
      'must contain at least 1 special',
      'must contain at least 1 uppercase',
      'must contain at least 1 lowercase',
      'must contain at least 1 number',
      'password must include',
      'password must be at least',
    ])) {
      return 'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.';
    }

    if (_containsAny(lower, const [
      'security_challenge',
      'challenge_required',
      'step_up_required',
      'otp required',
      'verification required',
    ])) {
      return 'Extra verification is required to continue.';
    }

    if (_containsAny(lower, const [
      'security_block',
      'sentinel_block',
      'blocked due to high risk',
      'high risk score',
      'fraud_detection',
      'suspicious activity',
      'blocked for security',
    ])) {
      return 'This action was blocked for security reasons. Please contact support if you believe this is an error.';
    }

    if (_containsAny(lower, const ['internal_balance_mismatch'])) {
      return 'Internal balance error. Please contact support if this persists.';
    }

    if (_containsAny(lower, const [
      'insufficient_funds',
      'insufficient goal funds',
      'exceeds saved goal funds',
    ])) {
      return 'Insufficient funds for this transaction.';
    }

    if (_containsAny(lower, const ['403', 'forbidden'])) {
      return 'You do not have permission to perform this action.';
    }

    if (_containsAny(lower, const [
      'access_denied',
      'maker-checker violation',
      'cannot approve your own request',
      'admin only',
    ])) {
      return 'You are not allowed to perform this action from this account.';
    }

    if (_containsAny(lower, const ['404'])) {
      return 'Service endpoint not found. Please try again later.';
    }

    if (_containsAny(lower, const [
      'missing_params',
      'missing required parameters',
      'missing_org_id',
      'missing required fields',
      'malformed payload',
    ])) {
      return 'Some required details are missing. Please review the form and try again.';
    }

    if (_containsAny(lower, const [
      '429',
      'too many requests',
      'rate limit',
      'throttle',
    ])) {
      return 'Too many attempts detected. Please wait about 60 seconds before trying again.';
    }

    if (_containsAny(lower, const [
      'invalid_otp',
      'invalid otp',
      'otp invalid',
      'wrong otp',
      'otp expired',
      'expired otp',
      'verification code',
    ])) {
      return 'The OTP code is invalid or expired. Request a new code and try again.';
    }

    if (_containsAny(lower, const [
      'identity_not_found',
      'user not found',
      'invalid or already processed',
      'not found',
      'goal not found',
      'escrow_not_found',
      'no receipt image provided',
    ])) {
      return 'We could not find the requested record. Refresh and try again.';
    }

    if (_containsAny(lower, const [
      'identity_link_required',
      'password_reset_challenge_required',
      'account_not_active',
      'account_not_activated',
      'account_unconfirmed',
      'unconfirmed_account',
    ])) {
      return 'This account needs activation or identity linking before password reset can continue.';
    }

    if (_containsAny(lower, const ['500', '502', '503', '504'])) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    if (_containsAny(lower, const [
      'lock_timeout',
      'ledger_commit_failed',
      'ledger_fault',
      'infrastructure_error',
      'concurrent_request',
    ])) {
      return 'The service is busy right now. Please wait a moment and try again.';
    }

    if (_looksTechnical(lower)) return fallback;
    return raw;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }

  static bool _looksTechnical(String text) {
    return _containsAny(text, const [
      'dioexception',
      'typeerror',
      'stack trace',
      'formatexception',
      'httpexception',
      'socketexception',
      'null check operator',
      'nosuchmethoderror',
      'json',
      'schema cache',
      'could not find a relationship',
      'relationship between',
      'postgrest',
      'pgrst',
      'supabase',
      'column ',
      ' relation ',
      ' table ',
      'endpoint',
      'http://',
      'https://',
    ]);
  }
}
