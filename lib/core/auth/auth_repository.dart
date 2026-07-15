import 'package:orbi_mobileapp/core/auth/orbi_auth_client.dart';
import 'package:orbi_mobileapp/core/auth/keycloak_pkce_auth_service.dart';
import 'package:orbi_mobileapp/core/config/app_config.dart';

class AuthRepository {
  final OrbiAuthClient _client;
  final KeycloakPkceAuthService _keycloakPkce;

  AuthRepository(this._client, {KeycloakPkceAuthService? keycloakPkce})
    : _keycloakPkce = keycloakPkce ?? KeycloakPkceAuthService();

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? deviceId,
    String? ip,
    Map<String, dynamic>? device,
  }) async {
    if (AppConfig.keycloakPkceEnabled) {
      return _keycloakPkce.signIn();
    }
    return _client.login(
      email,
      password,
      deviceId: deviceId,
      ip: ip,
      device: device,
    );
  }

  Future<Map<String, dynamic>> pinLogin(
    String email,
    String pin, {
    String? deviceId,
    String? ip,
    Map<String, dynamic>? device,
  }) async {
    return _client.pinLogin(
      email,
      pin,
      deviceId: deviceId,
      ip: ip,
      device: device,
    );
  }

  Future<Map<String, dynamic>> pinEnroll({
    required String pin,
    String? deviceId,
    Map<String, dynamic>? device,
    String? token,
    String? ip,
  }) async {
    return _client.pinEnroll(
      pin: pin,
      deviceId: deviceId,
      device: device,
      token: token,
      ip: ip,
    );
  }

  Future<Map<String, dynamic>> pinUpdate({
    required String pin,
    String? deviceId,
    Map<String, dynamic>? device,
    String? token,
    String? ip,
  }) async {
    return _client.pinUpdate(
      pin: pin,
      deviceId: deviceId,
      device: device,
      token: token,
      ip: ip,
    );
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String currency,
    String? nationality,
    String? address,
    String? languageCode,
    String? countryCode,
    String? countryName,
    String? dialCode,
    String? fcmToken,
  }) async {
    return _client.signup(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      nationality: nationality,
      address: address,
      currency: currency,
      languageCode: languageCode,
      countryCode: countryCode,
      countryName: countryName,
      dialCode: dialCode,
      fcmToken: fcmToken,
    );
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    return _client.refreshSession(refreshToken);
  }

  Future<Map<String, dynamic>> initiatePasswordReset(String identifier) async {
    return _client.initiatePasswordReset(identifier);
  }

  Future<Map<String, dynamic>> completePasswordReset(
    String password, {
    String? accessToken,
    String? identifier,
    String? requestId,
    String? code,
  }) async {
    return _client.completePasswordReset(
      password,
      accessToken: accessToken,
      identifier: identifier,
      requestId: requestId,
      code: code,
    );
  }

  Future<Map<String, dynamic>> initiateAccountConfirmation(
    String identifier, {
    String? replacementContact,
  }) {
    return _client.initiateAccountConfirmation(
      identifier,
      replacementContact: replacementContact,
    );
  }

  Future<Map<String, dynamic>> completeAccountConfirmation({
    required String identifier,
    required String requestId,
    required String code,
  }) {
    return _client.completeAccountConfirmation(
      identifier: identifier,
      requestId: requestId,
      code: code,
    );
  }

  Future<void> logout(String refreshToken) async {
    await _client.logout(refreshToken);
  }

  Future<Map<String, dynamic>> bootstrapProvisioning() async {
    return _client.bootstrapProvisioning();
  }

  Future<Map<String, dynamic>> biometricRegisterStart({
    String? email,
    String? userId,
    String? otpCode,
    String? otpRequestId,
  }) async {
    return _client.biometricRegisterStart(
      email: email,
      userId: userId,
      otpCode: otpCode,
      otpRequestId: otpRequestId,
    );
  }

  Future<Map<String, dynamic>> biometricRegisterFinish(
    Map<String, dynamic> credentialPayload,
  ) async {
    return _client.biometricRegisterFinish(credentialPayload);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String requestId,
    required String code,
  }) async {
    return _client.verifyOtp(requestId: requestId, code: code);
  }

  Future<Map<String, dynamic>> initiateSensitiveAction({
    required String userId,
    required String contact,
    required String action,
    required String type,
    String? token,
    Map<String, dynamic>? device,
    String? deviceName,
    String? name,
  }) async {
    return _client.initiateSensitiveAction(
      userId: userId,
      contact: contact,
      action: action,
      type: type,
      token: token,
      device: device,
      deviceName: deviceName,
      name: name,
    );
  }

  Future<Map<String, dynamic>> verifySensitiveAction({
    required String requestId,
    required String code,
    String? token,
    bool refreshSession = false,
    Map<String, dynamic>? device,
  }) async {
    return _client.verifySensitiveAction(
      requestId: requestId,
      code: code,
      token: token,
      refreshSession: refreshSession,
      device: device,
    );
  }

  Future<Map<String, dynamic>> biometricLoginStart({
    String? email,
    String? identifier,
    String? userId,
    String? fullName,
  }) async {
    return _client.biometricLoginStart(
      email: email,
      identifier: identifier,
      userId: userId,
      fullName: fullName,
    );
  }

  Future<Map<String, dynamic>> biometricLoginFinish(
    Map<String, dynamic> assertionPayload,
  ) async {
    return _client.biometricLoginFinish(assertionPayload);
  }
}
