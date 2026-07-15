import 'dart:convert';
import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart'; // Needed for debugPrint
import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/auth/auth_repository.dart';
import 'package:orbi_mobileapp/core/auth/passkey_response_parser.dart';
import 'package:orbi_mobileapp/core/auth/auth_service.dart';
import 'package:orbi_mobileapp/core/config/app_config.dart';
import 'package:orbi_mobileapp/core/device/device_info_service.dart';
import 'package:orbi_mobileapp/core/session/session_manager.dart';
import 'package:orbi_mobileapp/core/auth/orbi_auth_client.dart';
import 'package:orbi_mobileapp/core/auth/passkey_auth_service.dart';
import 'package:orbi_mobileapp/core/auth/token_manager.dart';
import 'package:orbi_mobileapp/core/security/device_fingerprint.dart';
import 'package:orbi_mobileapp/core/security/device_integrity_service.dart';
import 'package:orbi_mobileapp/core/security/behavior_telemetry_service.dart';
import 'package:orbi_mobileapp/core/storage/secure_storage_service.dart';
import 'package:orbi_mobileapp/core/utils/user_facing_error.dart';
import 'package:orbi_mobileapp/core/services/firebase_service.dart';
import 'package:orbi_mobileapp/core/services/notification_preferences_service.dart';
import 'package:orbi_mobileapp/core/state/app_settings_controller.dart';
import 'package:orbi_mobileapp/core/state/app_runtime_cache.dart';
import 'package:orbi_mobileapp/features/auth/auth_models.dart';
import 'package:orbi_mobileapp/features/profile/data/profile_service.dart';

part 'auth_controller_biometrics.dart';
part 'auth_controller_session.dart';

// ==========================================
// AUTH CONTROLLER
// ==========================================

class AuthController extends ChangeNotifier {
  static const Duration _lockExpiryTimeout = Duration(hours: 8);
  static const Duration _proactiveRefreshCheckInterval = Duration(minutes: 1);
  static const Duration _proactiveRefreshThreshold = Duration(minutes: 3);

  late final OrbiAuthClient _client;
  late final AuthRepository _repo;
  late final AuthService _service;
  final SessionManager _sessionManager = SessionManager();
  final PasskeyAuthService _passkeyService = PasskeyAuthService();
  final TokenManager _tokenManager = TokenManager();
  final SecureStorageService _storage = SecureStorageService();

  bool _isLoading = false;
  bool _hasInitialized = false;
  bool _isAuthenticated = false;
  String? _error;
  bool _biometricInFlight = false;
  bool _isReauthLocked = false;
  bool _accountActivationRequired = false;
  String? _pendingActivationIdentifier;
  String? _pendingActivationRequestId;
  String? _pendingActivationDelivery;
  Completer<bool>? _passkeyRegistrationCompleter;
  Completer<bool>? _passkeyLoginCompleter;
  Timer? _lockExpiryTimer;
  Timer? _tokenRefreshTimer;
  bool _biometricSetupRequired = false;

  // Strongly typed session object
  SessionModel? currentSession;

  // Legacy fallback for UI bindings that still expect a raw Map.
  // (Update your UI to use currentSession.user.fullName when you have time!)
  Map<String, dynamic> get session => currentSession?.toJson() ?? {};

  // Biometric preference
  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricSetupRequired => _biometricSetupRequired;

  AuthController() {
    _client = OrbiAuthClient(baseUrl: AppConfig.apiUrl);
    _repo = AuthRepository(_client);
    _service = AuthService(_repo, _sessionManager, _storage, _tokenManager);
    _loadBiometricState();
  }

  bool get isLoading => _isLoading;
  bool get isInitializing => _isLoading && !_hasInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isReauthLocked => _isReauthLocked;
  bool get accountActivationRequired => _accountActivationRequired;
  String? get pendingActivationIdentifier => _pendingActivationIdentifier;
  String? get pendingActivationRequestId => _pendingActivationRequestId;
  String? get pendingActivationDelivery => _pendingActivationDelivery;
  bool get biometricInFlight => _biometricInFlight;
  String? get error => _error;
  SessionManager get sessionManager => _sessionManager;
  String get organizationId {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['organization_id'] ??
            raw['organizationId'] ??
            raw['org_id'] ??
            '')
        .toString();
  }

  String get orgRole {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['org_role'] ?? raw['orgRole'] ?? raw['role'] ?? 'EMPLOYEE')
        .toString();
  }

  String get accountRole {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['role'] ?? raw['user_role'] ?? 'USER').toString().toUpperCase();
  }

  String get registryType {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['registry_type'] ?? raw['registryType'] ?? 'CONSUMER')
        .toString()
        .toUpperCase();
  }

  bool get isAgent => accountRole == 'AGENT' || registryType == 'AGENT';
  bool get isMerchant =>
      accountRole == 'MERCHANT' || registryType == 'MERCHANT';

  String get userId {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['id'] ?? raw['user_id'] ?? raw['userId'] ?? raw['uid'] ?? '')
        .toString();
  }

  String get displayName {
    final raw = currentSession?.user.rawData ?? const <String, dynamic>{};
    return (raw['full_name'] ??
            raw['fullName'] ??
            raw['name'] ??
            raw['first_name'] ??
            '')
        .toString()
        .trim();
  }

  void _notifyChanged() => notifyListeners();

  Future<void> _handleSessionExpired({
    String message = 'Session expired. Please log in again.',
  }) => _authHandleSessionExpired(this, message: message);

  Future<String?> getValidAccessToken({
    bool expireSessionIfMissing = true,
  }) async {
    final token = await _service.getValidAccessToken();
    if (token != null && token.isNotEmpty) {
      if (currentSession != null && currentSession!.accessToken != token) {
        currentSession = SessionModel.fromJson({
          'access_token': token,
          'user': currentSession!.user.rawData,
        });
        await _sessionManager.saveSession(currentSession!.toJson());
      }
      _client.setAccessToken(token);
      _ensureProactiveTokenRefresh();
      _error = null;
      return token;
    }
    if (expireSessionIfMissing &&
        (_isAuthenticated || currentSession != null)) {
      await _handleSessionExpired();
    }
    return null;
  }

  void _ensureProactiveTokenRefresh() {
    _tokenRefreshTimer ??= Timer.periodic(
      _proactiveRefreshCheckInterval,
      (_) => _proactivelyRefreshTokenIfNeeded(),
    );
  }

  void _stopProactiveTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  Future<void> _proactivelyRefreshTokenIfNeeded() async {
    if (!_isAuthenticated || _isLoading || _isReauthLocked) return;

    final currentToken =
        currentSession?.accessToken ?? await _sessionManager.getStoredToken();
    if (currentToken == null || currentToken.isEmpty) {
      await getValidAccessToken();
      return;
    }

    final timeLeft = _tokenManager.timeUntilExpiry(currentToken);
    if (timeLeft == null || timeLeft <= _proactiveRefreshThreshold) {
      final refreshedToken = await getValidAccessToken();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        if (currentSession != null &&
            currentSession!.accessToken != refreshedToken) {
          currentSession = SessionModel.fromJson({
            'access_token': refreshedToken,
            'user': currentSession!.user.rawData,
          });
        }
        _client.setAccessToken(refreshedToken);
      }
    }
  }

  Future<bool> hasSecurityPinConfigured() => _storage.hasPin();

  Future<bool> verifySecurityPin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.isEmpty) return Future.value(false);
    return _storage.verifyPin(trimmed);
  }

  Future<bool> enrollSecurityPin(String pin) async {
    final trimmed = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      _error = 'PIN must be exactly 4 digits.';
      notifyListeners();
      return false;
    }

    try {
      final token = currentSession?.accessToken ?? await getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Your session could not be confirmed. Try again.');
      }

      final devicePayload = await _buildDevicePayload();
      String? ip;
      try {
        final ipResponse = await HttpClient()
            .getUrl(Uri.parse('https://api.ipify.org?format=json'))
            .then((req) => req.close())
            .then((resp) => resp.transform(utf8.decoder).join());
        final ipJson = jsonDecode(ipResponse);
        ip = ipJson['ip']?.toString();
      } catch (_) {}

      await _repo.pinEnroll(
        pin: trimmed,
        token: token,
        ip: ip,
        device: devicePayload,
      );
      await _storage.setPin(trimmed);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to secure this PIN right now. Try again.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSecurityPin(String pin) async {
    final trimmed = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      _error = 'PIN must be exactly 4 digits.';
      notifyListeners();
      return false;
    }

    try {
      final token = currentSession?.accessToken ?? await getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Your session could not be confirmed. Try again.');
      }

      final devicePayload = await _buildDevicePayload();
      String? ip;
      try {
        final ipResponse = await HttpClient()
            .getUrl(Uri.parse('https://api.ipify.org?format=json'))
            .then((req) => req.close())
            .then((resp) => resp.transform(utf8.decoder).join());
        final ipJson = jsonDecode(ipResponse);
        ip = ipJson['ip']?.toString();
      } catch (_) {}

      await _repo.pinUpdate(
        pin: trimmed,
        token: token,
        ip: ip,
        device: devicePayload,
      );
      await _storage.setPin(trimmed);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to update your PIN right now. Try again.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, String>> startSensitiveActionChallenge({
    required String action,
  }) async {
    final token = await getValidAccessToken(expireSessionIfMissing: false);
    if (token == null || token.isEmpty) {
      throw Exception('Your session could not be confirmed. Try again.');
    }

    final resolvedUserId = _pickString([
      userId,
      currentSession?.user.id,
      currentSession?.user.rawData['id'],
      currentSession?.user.rawData['user_id'],
      currentSession?.user.rawData['userId'],
    ]);
    if (resolvedUserId.isEmpty) {
      throw Exception('Unable to verify your identity right now.');
    }

    final contact = _pickString([
      currentSession?.user.email,
      currentSession?.user.rawData['email'],
      currentSession?.user.rawData['phone'],
      currentSession?.user.rawData['phone_number'],
      currentSession?.user.rawData['msisdn'],
    ]);
    if (contact.isEmpty) {
      throw Exception(
        'No registered email or phone is available for security verification.',
      );
    }

    final devicePayload = await _buildDevicePayload();
    final resolvedDeviceName = _pickString([
      devicePayload['deviceName'],
      devicePayload['device_name'],
      devicePayload['deviceModel'],
      devicePayload['model'],
    ]);
    final resolvedName = _pickString([
      currentSession?.user.fullName,
      currentSession?.user.rawData['full_name'],
      currentSession?.user.rawData['fullName'],
      currentSession?.user.rawData['name'],
      currentSession?.user.email,
    ]);
    final deliveryType = contact.contains('@') ? 'email' : 'sms';
    final response = await _repo.initiateSensitiveAction(
      userId: resolvedUserId,
      contact: contact,
      action: action,
      type: deliveryType,
      token: token,
      device: devicePayload,
      deviceName: resolvedDeviceName,
      name: resolvedName,
    );
    final requestId = _pickString([
      response['requestId'],
      response['request_id'],
      response['otpRequestId'],
      response['otp_request_id'],
    ]);
    if (requestId.isEmpty) {
      throw Exception('Security verification could not be started.');
    }

    return {'requestId': requestId, 'contact': contact, 'type': deliveryType};
  }

  Future<void> _ensureSessionIdentity({
    String? fallbackEmail,
    String? fallbackFullName,
  }) => _authEnsureSessionIdentity(
    this,
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
  );

  Future<void> _syncBiometricIdentity({
    String? fallbackEmail,
    String? fallbackFullName,
  }) => _authSyncBiometricIdentity(
    this,
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
  );

  Future<Map<String, dynamic>> _storedProfileSnapshot() =>
      _authStoredProfileSnapshot(this);

  Future<void> _triggerBootstrapProvisioning() =>
      _authTriggerBootstrapProvisioning(this);

  Future<void> _populateInMemorySessionFromStorage() =>
      _authPopulateInMemorySessionFromStorage(this);

  Future<void> _refreshFullSessionProfile({bool includeKyc = true}) =>
      _authRefreshFullSessionProfile(this, includeKyc: includeKyc);

  void _startDeferredSessionHydration({
    String? fallbackEmail,
    String? fallbackFullName,
    bool registerPasskeyAfterAuth = false,
  }) => _authStartDeferredSessionHydration(
    this,
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
    registerPasskeyAfterAuth: registerPasskeyAfterAuth,
  );

  Future<void> _finalizeAuthenticatedSession({
    String? fallbackEmail,
    String? fallbackFullName,
    bool registerPasskeyAfterAuth = false,
  }) => _authFinalizeAuthenticatedSession(
    this,
    fallbackEmail: fallbackEmail,
    fallbackFullName: fallbackFullName,
    registerPasskeyAfterAuth: registerPasskeyAfterAuth,
  );

  Future<bool> login(
    String email,
    String password, {
    Future<String?> Function()? requestOtp,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConfig.enforceDeviceIntegrity &&
          (DeviceIntegrityService.isCompromised ?? false)) {
        _error =
            'Device security check failed. Please use a trusted device to log in.';
        return false;
      }
      final healthy = await _client.preflightHealth();
      if (!healthy) {
        _error =
            'Network/DNS unavailable or Connection to the Saver has been Lost. Please check your connection and try again.';
        return false;
      }

      debugPrint('🔐 [LOGIN] Starting login flow...');
      final deviceId = DeviceFingerprint.generate();
      final devicePayload = await _buildDevicePayload();
      String? ip;
      try {
        final ipResponse = await HttpClient()
            .getUrl(Uri.parse('https://api.ipify.org?format=json'))
            .then((req) => req.close())
            .then((resp) => resp.transform(utf8.decoder).join());
        final ipJson = jsonDecode(ipResponse);
        ip = ipJson['ip']?.toString();
        debugPrint('🌐 [LOGIN] Device IP: $ip');
      } catch (e) {
        debugPrint('⚠️ [LOGIN] Failed to fetch IP: $e');
      }
      final loginResponse = await _repo.login(
        email,
        password,
        deviceId: deviceId,
        ip: ip,
        device: devicePayload,
      );
      debugPrint('✅ [LOGIN] Got response from server');
      _accountActivationRequired = false;
      _pendingActivationIdentifier = null;
      _pendingActivationDelivery = null;

      // Handle STEP_UP_REQUIRED
      if (loginResponse['status'] == 'STEP_UP_REQUIRED') {
        debugPrint(
          '🔐 [LOGIN] STEP_UP_REQUIRED detected, prompting OTP dialog',
        );
        _isLoading = false;
        notifyListeners();
        final otpDialog = await requestOtp?.call();
        if (otpDialog == null || otpDialog.isEmpty) {
          _error = 'OTP verification cancelled.';
          return false;
        }
        _isLoading = true;
        notifyListeners();
        final verifyResult = await _client.verifyOtp(
          requestId: loginResponse['requestId'],
          code: otpDialog,
        );
        final hasSessionToken =
            verifyResult['access_token']?.toString().trim().isNotEmpty == true;
        final verified =
            verifyResult['success'] == true ||
            verifyResult['verified'] == true ||
            hasSessionToken;
        if (verified) {
          if (!hasSessionToken) {
            throw Exception('OTP verification succeeded without a session.');
          }
          await _service.establishSession(verifyResult);
          _client.setAccessToken(verifyResult['access_token']?.toString());
          await _finalizeAuthenticatedSession(
            fallbackEmail: email,
            registerPasskeyAfterAuth: false,
          );
          _isAuthenticated = true;
          _clearReauthLock();
          debugPrint('✅ [LOGIN] Login completed after OTP verification');
          return true;
        } else {
          _error = verifyResult['error'] ?? 'OTP verification failed.';
          return false;
        }
      }

      final requiresBiometricSetup =
          _boolFrom(
            loginResponse['biometric_setup_required'] ??
                loginResponse['biometricSetupRequired'] ??
                loginResponse['biometric_required'] ??
                loginResponse['biometricRequired'] ??
                loginResponse['requires_biometric'] ??
                loginResponse['require_biometric'],
          ) ??
          false;
      await _service.establishSession(loginResponse);
      await _finalizeAuthenticatedSession(
        fallbackEmail: email,
        registerPasskeyAfterAuth: false,
      );

      await _setBiometricSetupRequired(requiresBiometricSetup);
      _isAuthenticated = !requiresBiometricSetup;
      _clearReauthLock();
      debugPrint(
        _isAuthenticated
            ? '✅ [LOGIN] Login fully completed - authenticated'
            : '⚠️ [LOGIN] Biometric setup required before authentication',
      );
      return true;
    } catch (e) {
      if (e is AuthApiException && e.requiresAccountActivation) {
        _accountActivationRequired = true;
        _pendingActivationIdentifier = email.trim();
        _error =
            'Your account is not active yet. Confirm the OTP sent to your phone or email to continue.';
        debugPrint('🔐 [LOGIN] Account activation required for $email');
        currentSession = null;
        _isAuthenticated = false;
        return false;
      }
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to log in right now. Please try again.',
      );
      debugPrint('❌ [LOGIN] Login error: $_error');
      currentSession = null;
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Full PIN login - retrieves new session with fresh tokens
  /// Similar to biometric login, but uses PIN instead
  Future<bool> pinLogin(
    String email,
    String pin, {
    Future<String?> Function()? requestOtp,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConfig.enforceDeviceIntegrity &&
          (DeviceIntegrityService.isCompromised ?? false)) {
        _error =
            'Device security check failed. Please use a trusted device to log in.';
        return false;
      }

      final healthy = await _client.preflightHealth();
      if (!healthy) {
        _error =
            'Network/DNS unavailable or Connection to the Saver has been Lost. Please check your connection and try again.';
        return false;
      }

      debugPrint('🔐 [PIN_LOGIN] Starting PIN login flow...');

      // Verify PIN locally first
      final pinValid = await verifySecurityPin(pin);
      if (!pinValid) {
        _error = 'Invalid PIN. Please try again.';
        return false;
      }

      debugPrint('✅ [PIN_LOGIN] PIN verified');

      final devicePayload = await _buildDevicePayload();
      String? ip;
      try {
        final ipResponse = await HttpClient()
            .getUrl(Uri.parse('https://api.ipify.org?format=json'))
            .then((req) => req.close())
            .then((resp) => resp.transform(utf8.decoder).join());
        final ipJson = jsonDecode(ipResponse);
        ip = ipJson['ip']?.toString();
        debugPrint('🌐 [PIN_LOGIN] Device IP: $ip');
      } catch (e) {
        debugPrint('⚠️ [PIN_LOGIN] Failed to fetch IP: $e');
      }

      // Call backend with PIN authentication
      final pinLoginResponse = await _repo.pinLogin(
        email,
        pin,
        ip: ip,
        device: devicePayload,
      );
      debugPrint('✅ [PIN_LOGIN] Got response from server');

      // Handle STEP_UP_REQUIRED
      if (pinLoginResponse['status'] == 'STEP_UP_REQUIRED') {
        debugPrint('🔐 [PIN_LOGIN] STEP_UP_REQUIRED detected');
        _isLoading = false;
        notifyListeners();
        final otpCode = await requestOtp?.call();
        if (otpCode == null || otpCode.isEmpty) {
          _error = 'OTP verification cancelled.';
          return false;
        }
        _isLoading = true;
        notifyListeners();

        final requestId =
            pinLoginResponse['requestId'] ??
            pinLoginResponse['request_id'] ??
            pinLoginResponse['otp_request_id'];
        if (requestId == null) {
          _error = 'OTP request ID missing from server response.';
          return false;
        }

        final verifyResult = await _client.verifyOtp(
          requestId: requestId,
          code: otpCode,
        );

        final hasSessionToken =
            verifyResult['access_token']?.toString().trim().isNotEmpty == true;
        if (!hasSessionToken) {
          _error = 'OTP verification succeeded but no session token returned.';
          return false;
        }

        await _service.establishSession(verifyResult);
        _client.setAccessToken(verifyResult['access_token']?.toString());
        await _finalizeAuthenticatedSession(
          fallbackEmail: email,
          registerPasskeyAfterAuth: false,
        );
        _isAuthenticated = true;
        _clearReauthLock();
        debugPrint('✅ [PIN_LOGIN] PIN login completed after OTP verification');
        return true;
      }

      // Establish session with PIN login response
      final requiresBiometricSetup =
          _boolFrom(
            pinLoginResponse['biometric_setup_required'] ??
                pinLoginResponse['biometricSetupRequired'] ??
                pinLoginResponse['biometric_required'] ??
                pinLoginResponse['biometricRequired'] ??
                pinLoginResponse['requires_biometric'] ??
                pinLoginResponse['require_biometric'],
          ) ??
          false;

      await _service.establishSession(pinLoginResponse);
      await _finalizeAuthenticatedSession(
        fallbackEmail: email,
        registerPasskeyAfterAuth: false,
      );

      await _setBiometricSetupRequired(requiresBiometricSetup);
      _isAuthenticated = !requiresBiometricSetup;
      _clearReauthLock();
      debugPrint(
        _isAuthenticated
            ? '✅ [PIN_LOGIN] PIN login fully completed - authenticated'
            : '⚠️ [PIN_LOGIN] Biometric setup required before authentication',
      );
      return true;
    } catch (e) {
      if (_looksLikeActivationRequirement(e)) {
        _markAccountActivationRequired(
          identifier: email,
          message:
              'This account still needs confirmation. Enter the OTP sent to your phone or email to continue.',
        );
        debugPrint('🔐 [PIN_LOGIN] Account activation required for $email');
        return false;
      }
      _error = UserFacingError.from(
        e,
        fallback: 'PIN login failed. Please try again.',
      );
      debugPrint('❌ [PIN_LOGIN] Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String currency,
    String? nationality,
    String? address,
    String? languageCode,
    String? countryCode,
    String? countryName,
    String? dialCode,
    Future<String?> Function()? requestOtp,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (AppConfig.enforceDeviceIntegrity &&
          (DeviceIntegrityService.isCompromised ?? false)) {
        _error =
            'Device security check failed. Please use a trusted device to sign up.';
        return false;
      }
      debugPrint('📝 [SIGNUP] Starting signup flow...');
      final normalizedCurrency = currency.trim().toUpperCase();
      if (normalizedCurrency.isEmpty) {
        _error = 'Account currency is required for signup.';
        return false;
      }

      // Get FCM token
      final firebaseService = FirebaseService();
      final fcmToken = await firebaseService.getToken();

      final signupResponse = await _repo.signup(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        nationality: nationality,
        address: address,
        currency: normalizedCurrency,
        languageCode: languageCode,
        countryCode: countryCode,
        countryName: countryName,
        dialCode: dialCode,
        fcmToken: fcmToken,
      );

      final activation = signupResponse['activation'];
      if (activation is Map) {
        _pendingActivationRequestId =
            activation['requestId']?.toString() ??
            activation['request_id']?.toString();
        _pendingActivationDelivery =
            activation['deliveryContact']?.toString() ??
            activation['delivery_contact']?.toString();
      }
      _accountActivationRequired = true;
      _pendingActivationIdentifier = email.trim().isNotEmpty
          ? email.trim()
          : phone.trim();

      if (languageCode != null && languageCode.trim().isNotEmpty) {
        await AppSettingsController.persistAppLanguage(
          languageCode: languageCode,
          applyToApp: true,
        );
      }
      debugPrint('✅ [SIGNUP] Account created pending OTP activation');
      return true;
    } catch (e) {
      if (_looksLikeActivationRequirement(e)) {
        _markAccountActivationRequired(
          identifier: email.trim().isNotEmpty ? email : phone,
          message:
              'This account already exists but is not confirmed yet. Confirm the OTP to finish opening it.',
        );
        debugPrint(
          '📝 [SIGNUP] Existing unconfirmed account detected for ${_pendingActivationIdentifier ?? email}',
        );
        return false;
      }
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to complete signup right now. Please try again.',
      );
      debugPrint('❌ [SIGNUP] Signup error: $_error');
      currentSession = null;
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> initiatePasswordReset(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      _error = 'Enter your email address to reset password.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.initiatePasswordReset(normalized);
      _pendingActivationRequestId = _pickString([
        result['requestId'],
        result['request_id'],
        result['otpRequestId'],
        result['otp_request_id'],
        if (result['challenge'] is Map)
          (result['challenge'] as Map)['requestId'],
        if (result['challenge'] is Map)
          (result['challenge'] as Map)['request_id'],
      ]);
      _pendingActivationDelivery =
          result['deliveryContact']?.toString() ??
          result['delivery_contact']?.toString();
      final resolvedRequestId = (_pendingActivationRequestId ?? '').trim();
      if (resolvedRequestId.isEmpty) {
        _error =
            'Password reset could not be started for this account. Confirm the email/phone is registered and active, then request a new OTP.';
        return false;
      }
      if (_isRejectedOtpRequestId(resolvedRequestId)) {
        _pendingActivationRequestId = null;
        _error =
            'Too many OTP requests. Please wait about 60 seconds, then request a fresh OTP.';
        return false;
      }
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback:
            'Unable to start password reset right now. Please try again later.',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completePasswordReset(
    String password, {
    String? identifier,
    String? requestId,
    String? code,
  }) async {
    final normalized = password.trim();
    final passwordPolicyError = _passwordPolicyError(normalized);
    if (passwordPolicyError != null) {
      _error = passwordPolicyError;
      notifyListeners();
      return false;
    }

    final normalizedIdentifier = (identifier ?? '').trim();
    final normalizedRequestId = (requestId ?? '').trim();
    final normalizedCode = _normalizeOtp(code);
    if (normalizedRequestId.isNotEmpty &&
        _isRejectedOtpRequestId(normalizedRequestId)) {
      _error = 'Request a fresh OTP before changing your password.';
      notifyListeners();
      return false;
    }
    final usingOtp =
        normalizedIdentifier.isNotEmpty &&
        normalizedRequestId.isNotEmpty &&
        normalizedCode.isNotEmpty;
    final token = usingOtp ? null : await getValidAccessToken();
    if (!usingOtp && (token == null || token.isEmpty)) {
      _error = 'Request and verify an OTP before changing your password.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repo.completePasswordReset(
        normalized,
        accessToken: token,
        identifier: normalizedIdentifier,
        requestId: normalizedRequestId,
        code: normalizedCode,
      );
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback:
            'Unable to update password right now. Please try again later.',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _passwordPolicyError(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include a lowercase letter.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include an uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include a number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must include a special character, for example @, #, or !.';
    }
    return null;
  }

  Future<bool> initiateAccountConfirmation(
    String identifier, {
    String? replacementContact,
  }) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      _error = 'Enter the email or phone used during signup.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.initiateAccountConfirmation(
        normalized,
        replacementContact: replacementContact,
      );
      _pendingActivationIdentifier = normalized;
      _pendingActivationRequestId =
          result['requestId']?.toString() ?? result['request_id']?.toString();
      _pendingActivationDelivery =
          result['deliveryContact']?.toString() ??
          result['delivery_contact']?.toString();
      _accountActivationRequired = result['confirmationRequired'] != false;
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to request activation code right now.',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeAccountConfirmation({
    required String identifier,
    required String requestId,
    required String code,
  }) async {
    if (identifier.trim().isEmpty ||
        requestId.trim().isEmpty ||
        code.trim().isEmpty) {
      _error = 'Enter the activation code to continue.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.completeAccountConfirmation(
        identifier: identifier.trim(),
        requestId: requestId.trim(),
        code: code.trim(),
      );
      final status = (result['status'] ?? result['data']?['status'])
          ?.toString()
          .toLowerCase();
      final ok = result['success'] == true || status == 'active';
      if (ok) {
        _accountActivationRequired = false;
        _pendingActivationIdentifier = null;
        _pendingActivationRequestId = null;
        _pendingActivationDelivery = null;
      }
      return ok;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to activate account right now.',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _repo.logout(refreshToken);
      } catch (_) {}
    }
    await _service.clearSession();
    await _setBiometricSetupRequired(false);
    currentSession = null;
    _isAuthenticated = false;
    _sessionManager.suspendInactivityMonitoring();
    _stopProactiveTokenRefresh();
    _clearReauthLock();
    notifyListeners();
  }

  void loginSuccess(String token, {Map<String, dynamic>? user}) {
    _isAuthenticated = true;
    _biometricSetupRequired = false;
    _sessionManager.markSessionActive();
    _ensureProactiveTokenRefresh();
    _clearReauthLock();
    currentSession = SessionModel.fromJson({
      'access_token': token,
      ...?(user == null ? null : {'user': user}),
    });
    notifyListeners();
  }

  Future<void> _loadBiometricState() => _authLoadBiometricState(this);

  bool? _boolFrom(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }

  String _pickString(List<dynamic> values) {
    for (final v in values) {
      final text = v?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  String _normalizeOtp(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[\s-]'), '').trim();
  }

  bool _isRejectedOtpRequestId(String requestId) {
    final upper = requestId.trim().toUpperCase();
    return upper.isEmpty ||
        upper == 'THROTTLED' ||
        upper.startsWith('ERROR_') ||
        upper == 'ERROR';
  }

  bool _looksLikeActivationRequirement(Object error) {
    if (error is AuthApiException && error.requiresAccountActivation) {
      return true;
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('account_not_activated') ||
        lower.contains('account_not_active') ||
        lower.contains('account_unconfirmed') ||
        lower.contains('unconfirmed') ||
        lower.contains('not confirmed') ||
        lower.contains('confirm your account') ||
        lower.contains('activate your account');
  }

  void _markAccountActivationRequired({
    required String identifier,
    String? message,
  }) {
    _accountActivationRequired = true;
    _pendingActivationIdentifier = identifier.trim();
    _error =
        message ??
        'Your account is not active yet. Confirm the OTP sent to your phone or email to continue.';
    currentSession = null;
    _isAuthenticated = false;
  }

  bool _isBiometricChallengeRequired(Map<String, dynamic> start) =>
      PasskeyResponseParser.requiresOtpChallenge(start);

  Future<void> _setBiometricSetupRequired(bool required) =>
      _authSetBiometricSetupRequired(this, required);

  Future<void> setBiometricEnabled(
    bool enabled, {
    bool preserveIdentity = false,
  }) => _authSetBiometricEnabled(
    this,
    enabled,
    preserveIdentity: preserveIdentity,
  );

  Future<bool> registerPasskey({
    String? email,
    Future<String?> Function()? requestOtp,
  }) => _authRegisterPasskey(this, email: email, requestOtp: requestOtp);

  dynamic _extractBiometricOptions(Map<String, dynamic> start) =>
      _authExtractBiometricOptions(start);

  String _extractPasskeyChallenge(Map<String, dynamic> options) =>
      _authExtractPasskeyChallenge(options);

  String _extractBiometricRequestId(Map<String, dynamic> start) {
    return PasskeyResponseParser.extractRequestId(start);
  }

  String _extractBiometricChallengeType(Map<String, dynamic> start) {
    return PasskeyResponseParser.extractChallengeType(start);
  }

  void _debugBiometricRegisterStart(
    Map<String, dynamic> start, {
    required String context,
  }) => _authDebugBiometricRegisterStart(this, start, context: context);

  void _debugPasskeyOptions(String mode, Map<String, dynamic> options) =>
      _authDebugPasskeyOptions(this, mode, options);

  void _debugPasskeyResult(String mode, Map<String, dynamic> result) =>
      _authDebugPasskeyResult(this, mode, result);

  void _injectPasskeyRpId(Map<String, dynamic> options) =>
      _authInjectPasskeyRpId(options);

  Future<bool> completeMandatoryBiometricSetup({
    Future<String?> Function()? requestOtp,
  }) => _authCompleteMandatoryBiometricSetup(this, requestOtp: requestOtp);

  Future<bool> biometricPasskeyLogin({
    Future<String?> Function()? requestOtp,
  }) => _authBiometricPasskeyLogin(this, requestOtp: requestOtp);

  Future<Map<String, dynamic>> _getAssertionWithFallback(
    Map<String, dynamic> options,
  ) => _authGetAssertionWithFallback(this, options);

  Future<bool> biometricLogin({Future<String?> Function()? requestOtp}) =>
      biometricPasskeyLogin(requestOtp: requestOtp);

  Future<bool> _restoreSessionFromPin() => _authRestoreSessionFromPin(this);

  Future<bool> unlockWithPin(String pin) async {
    if (!_isReauthLocked) {
      _error = 'PIN unlock is only available when session is locked.';
      notifyListeners();
      return false;
    }
    final ok = await _storage.verifyPin(pin);
    if (!ok) {
      _error = 'Invalid PIN. Please try again.';
      notifyListeners();
      return false;
    }
    return _restoreSessionFromPin();
  }

  Future<bool> resumeWithPin(String pin) async {
    final ok = await _storage.verifyPin(pin);
    if (!ok) {
      _error = 'Invalid PIN. Please try again.';
      notifyListeners();
      return false;
    }
    return _restoreSessionFromPin();
  }

  Future<void> markAppBackgrounded() => _storage.markAppBackgrounded();

  Future<void> clearAppBackgroundMarker() => _storage.clearAppBackgroundedAt();

  void setAutoLogoutCallback(VoidCallback callback) {
    _sessionManager.setOnSessionExpired(() {
      lockForReauth();
      callback();
    });
  }

  Future<Map<String, dynamic>> _buildDevicePayload() {
    return DeviceInfoService.buildPayload();
  }

  Map<String, dynamic> _buildBehaviorMetrics() {
    return BehaviorTelemetryService.instance.snapshot();
  }

  Map<String, dynamic> _normalizePasskeyLoginResponse(
    Map<String, dynamic> response,
  ) => _authNormalizePasskeyLoginResponse(this, response);

  /// Inactivity lock: requires password/biometric re-authentication
  /// while preserving stored session for secure resume flows.
  void lockForReauth() {
    _isAuthenticated = false;
    _isReauthLocked = true;
    _error = null;
    _sessionManager.suspendInactivityMonitoring();
    _stopProactiveTokenRefresh();
    unawaited(_storage.setReauthLockRequired(true));
    _restartLockExpiryTimer();
    notifyListeners();
  }

  /// Called by global activity listener while lock screen is shown.
  /// If user is interacting but not yet re-authenticated, keep lock alive
  /// and delay full session expiration.
  void registerUserActivity() {
    if (!_isReauthLocked) return;
    _restartLockExpiryTimer();
  }

  void _restartLockExpiryTimer([Duration? delay]) =>
      _authRestartLockExpiryTimer(this, delay);

  Future<void> _expireLockedSessionCompletely() =>
      _authExpireLockedSessionCompletely(this);

  void _clearReauthLock() => _authClearReauthLock(this);

  Future<void> initialize() => _authInitialize(this);

  Future<void> refreshCurrentProfile() => _authRefreshCurrentProfile(this);

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _lockExpiryTimer?.cancel();
    _sessionManager.dispose();
    super.dispose();
  }
}
