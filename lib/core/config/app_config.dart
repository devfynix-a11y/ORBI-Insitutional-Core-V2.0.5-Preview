/// ORBI APP CONFIGURATION
/// =======================
/// Centralised configuration for the Orbi Mobile App.
/// Supports multiple environments (Development / Production).
///
/// All environment‑specific values are derived from a single switch.
/// Change `_currentEnv` to `Environment.prod` for release builds.
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class AppConfig {
  // ------------------------------------
  // 1. ENVIRONMENT SELECTION
  // ------------------------------------
  // Set this to `Environment.prod` before building for production.
  static const Environment _currentEnv = Environment.prod;

  // ------------------------------------
  // 2. BASE URLS
  // ------------------------------------
  // Primary AWS backend and Google fallback backend. Both hosts run the same
  // ORBI Core API, with AWS kept as the canonical production endpoint.
  static const String _primaryApiHost = 'api.orbifinancial.com';
  static const String _googleFallbackApiHost = 'go-api.orbifinancial.com';

  // Override with --dart-define API_BASE_URL_DEV / API_BASE_URL_PROD as needed.
  static const String _devUrl = String.fromEnvironment(
    'API_BASE_URL_DEV',
    defaultValue: 'https://$_primaryApiHost',
  );
  static const String _prodUrl = String.fromEnvironment(
    'API_BASE_URL_PROD',
    defaultValue: 'https://$_primaryApiHost',
  );
  static const String _fallbackProdUrl = String.fromEnvironment(
    'API_FALLBACK_BASE_URL_PROD',
    defaultValue: 'https://$_googleFallbackApiHost',
  );

  /// Passkey defaults used for diagnostics and environment consistency.
  static const String _passkeyRpIdEnv = String.fromEnvironment(
    'PASSKEY_RP_ID',
    defaultValue: '',
  );

  /// For Android native passkeys, set PASSKEY_ORIGIN to
  /// `android:apk-key-hash:<YOUR_URLSAFE_BASE64_SHA256_CERT_HASH>`.
  static const String _passkeyOriginEnv = String.fromEnvironment(
    'PASSKEY_ORIGIN',
    defaultValue: '',
  );
  static const bool _forceReleasePasskeyOrigin = bool.fromEnvironment(
    'FORCE_RELEASE_PASSKEY_ORIGIN',
    defaultValue: false,
  );
  static const String _androidDebugApkHash =
      'ier+vRGLKMJTLzJPUJTUrWdHuCxU75VyOT0tMR7dgwo=';
  static const String _androidAppHashEnv = String.fromEnvironment(
    'ORBI_ANDROID_APP_HASH',
    defaultValue: '',
  );
  static const String _appVersionEnv = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.0.0',
  );
  static const String _tlsPinsEnv = String.fromEnvironment(
    'TLS_CERT_PINS',
    defaultValue: '',
  );
  static const bool _enforceDeviceIntegrity = bool.fromEnvironment(
    'ENFORCE_DEVICE_INTEGRITY',
    defaultValue: false,
  );

  static String get passkeyRpId =>
      _passkeyRpIdEnv.isNotEmpty ? _passkeyRpIdEnv : _primaryApiHost;

  static String get passkeyOrigin {
    if (_passkeyOriginEnv.isNotEmpty) return _passkeyOriginEnv;
    if (!kIsWeb && Platform.isAndroid) {
      return 'android:apk-key-hash:$androidAppHashUrlSafe';
    }
    return 'https://$_primaryApiHost';
  }

  static String get androidAppHash {
    if (_androidAppHashEnv.isNotEmpty) return _androidAppHashEnv;
    final useReleaseHash = kReleaseMode || _forceReleasePasskeyOrigin;
    if (useReleaseHash) return '';
    return _androidDebugApkHash;
  }

  /// URL-safe base64 without padding, required for Android `apk-key-hash`
  /// passkey origins.
  static String get androidAppHashUrlSafe {
    final normalized = androidAppHash.trim();
    if (normalized.isEmpty) return normalized;
    try {
      final bytes = base64.decode(normalized);
      return base64UrlEncode(bytes).replaceAll('=', '');
    } catch (_) {
      return normalized
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
    }
  }

  /// Colon-delimited uppercase SHA-256 fingerprint for
  /// `/.well-known/assetlinks.json`.
  static String get androidAssetLinksSha256Fingerprint {
    final normalized = androidAppHash.trim();
    if (normalized.isEmpty) return normalized;
    try {
      final bytes = base64.decode(normalized);
      return bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
    } catch (_) {
      return normalized;
    }
  }

  /// HTTP base URL for all REST API calls.
  static String get baseUrl {
    switch (_currentEnv) {
      case Environment.dev:
        return _devUrl;
      case Environment.prod:
        return _prodUrl;
    }
  }

  /// Secondary API root used only when the primary infrastructure is
  /// unreachable. Keep this host pointed at the Google VM fallback.
  static String get fallbackBaseUrl {
    switch (_currentEnv) {
      case Environment.dev:
        return _devUrl;
      case Environment.prod:
        return _fallbackProdUrl;
    }
  }

  static List<String> get baseUrls {
    final seen = <String>{};
    return [baseUrl, fallbackBaseUrl]
        .map(_stripTrailingSlash)
        .where((url) => url.isNotEmpty && seen.add(url))
        .toList(growable: false);
  }

  static String get appVersion => _appVersionEnv;
  static bool get enforceDeviceIntegrity => _enforceDeviceIntegrity;

  /// Comma-separated list of SHA-256 cert fingerprints.
  static List<String> get tlsCertPins {
    if (_tlsPinsEnv.trim().isEmpty) return const [];
    return _tlsPinsEnv
        .split(',')
        .map((pin) => pin.trim().toLowerCase())
        .where((pin) => pin.isNotEmpty)
        .toList();
  }

  // ------------------------------------
  // 3. API VERSIONING
  // ------------------------------------
  static const String apiVersion = 'v1';

  /// Full API base URL including version.
  ///
  /// NOTE: the server expects the version directly after the host (e.g. `/v1`),
  /// not `/api/v1`. The `/api` prefix was causing 404s on the Render deployment.
  static String get apiUrl => '$baseUrl/$apiVersion';

  static String get fallbackApiUrl => '$fallbackBaseUrl/$apiVersion';

  static List<String> get apiUrls => baseUrls
      .map((url) => '${_stripTrailingSlash(url)}/$apiVersion')
      .toList(growable: false);

  static String? fallbackForBaseUrl(String candidate) {
    final normalized = _stripTrailingSlash(candidate);
    if (normalized == _stripTrailingSlash(baseUrl)) return fallbackBaseUrl;
    if (normalized == _stripTrailingSlash(apiUrl)) return fallbackApiUrl;
    return null;
  }

  // ------------------------------------
  // 4. WEBSOCKET (REAL‑TIME NEXUS)
  // ------------------------------------
  /// Dynamically builds the WebSocket URL from the base HTTP URL.
  /// - Converts http → ws, https → wss.
  /// - Appends the mandatory `/nexus-stream` path (per integration manual).
  static String get wsUrl {
    final scheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/nexus-stream';
  }

  static String get fallbackWsUrl {
    final scheme = fallbackBaseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = fallbackBaseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/nexus-stream';
  }

  static List<String> get wsUrls {
    final seen = <String>{};
    return [
      wsUrl,
      fallbackWsUrl,
    ].where((url) => url.isNotEmpty && seen.add(url)).toList(growable: false);
  }

  static String _stripTrailingSlash(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  // ------------------------------------
  // 5. CLIENT IDENTIFICATION
  // ------------------------------------
  static const String _appIdEnv = String.fromEnvironment(
    'ORBI_APP_ID',
    defaultValue: '',
  );

  /// Required by backend contract (`x-orbi-app-id` header).
  static String get appId {
    if (_appIdEnv.isNotEmpty) return _appIdEnv;
    if (!kIsWeb && Platform.isIOS) return 'mobile-ios';
    return 'mobile-android';
  }

  static const String appOrigin = String.fromEnvironment(
    'ORBI_APP_ORIGIN',
    defaultValue: 'ORBI_MOBILE_V2026',
  );

  static bool get shouldSendAndroidApkHash =>
      !kIsWeb && Platform.isAndroid && androidAppHash.isNotEmpty;

  // ------------------------------------
  // 6. NETWORK TIMEOUTS
  // ------------------------------------
  static const int connectTimeout = 30000; // milliseconds (30s)
  static const int receiveTimeout = 30000; // milliseconds (30s)

  // ------------------------------------
  // 7. ENDPOINT PATHS (optional, for convenience)
  // ------------------------------------
  static const Map<String, String> endpoints = {
    // Auth
    'login': '/auth/login',
    'signup': '/auth/signup',
    'accountConfirmationInitiate': '/auth/account/confirmation/initiate',
    'accountConfirmationComplete': '/auth/account/confirmation/complete',
    'passwordResetInitiate': '/auth/password/reset/initiate',
    'passwordResetComplete': '/auth/password/reset/complete',
    'refresh': '/auth/refresh',
    'session': '/auth/session',
    'authVerify': '/auth/verify',
    'pinEnroll': '/auth/pin/enroll',
    'pinUpdate': '/auth/pin/update',
    'pinLogin': '/auth/pin-login',
    // Passkey (Biometric) auth per Integration Manual v30
    'biometricRegisterStart': '/auth/passkey/register/start',
    'biometricRegisterFinish': '/auth/passkey/register/finish',
    'biometricLoginStart': '/auth/passkey/login/start',
    'biometricLoginFinish': '/auth/passkey/login/finish',
    'sensitiveActionInitiate': '/auth/otp/initiate',
    'sensitiveActionVerify': '/auth/verify',
    'behaviorRecord': '/auth/behavior/record',
    'secureSign': '/transactions/secure-sign',
    'profile': '/user/profile',
    'loginInfo': '/user/login-info',
    'avatar': '/user/avatar',
    'kycScan': '/user/kyc/scan',
    'receiptScan': '/receipt/scan',
    'kycUpload': '/user/kyc/upload',
    'kycSubmit': '/user/kyc',
    'kycStatus': '/user/kyc/status',
    'lookup': '/user/lookup',
    'notifications': '/notifications',
    'lookupByCustomerTemplate': '/user/lookup/{customerId}',
    'userDevices': '/user/devices',
    'userDocuments': '/user/documents',
    'serviceAccessRequestCreate': '/service-access/requests',
    'serviceAccessRequestMine': '/service-access/requests/my',

    // Wealth
    'wallets': '/wallets',
    'walletsLinked': '/wallets/linked',
    'walletsSovereign': '/wallets/sovereign',
    'transactions': '/transactions',
    'transactionPreview': '/transactions/preview',
    'settle': '/transactions/settle',
    'fxQuote': '/fx/quote',
    'escrow': '/escrow',
    'escrowCreate': '/escrow/create',

    // Strategy
    'goals': '/goals',
    'categories': '/categories',
    'tasks': '/tasks',

    // Merchants
    'merchants': '/merchants',
    'merchantCategories': '/merchants/categories',
    'merchantAccounts': '/merchants/accounts',
    'merchantAccountsMine': '/merchants/accounts/my',
    'merchantWallets': '/merchant/wallets',
    'merchantTransactions': '/merchant/transactions',
    'merchantCustomers': '/merchant/customers',
    'merchantCustomerRegister': '/merchant/customers/register',
    'merchantPaymentPreview': '/merchant/payments/preview',
    'merchantPaymentSettle': '/merchant/payments/settle',
    'orbiPayPreview': '/payments/orbi-pay/preview',
    'orbiPaySettle': '/payments/orbi-pay/settle',
    'billPayProviders': '/payments/bills/providers',
    'billPayPreview': '/payments/bills/preview',
    'billPaySettle': '/payments/bills/settle',
    'billPayReservePreview': '/payments/bills/preview-from-reserve',
    'billPayReserveSettle': '/payments/bills/settle-from-reserve',
    'paymentMethods': '/payment-methods',
    'gatewayProviders': '/gateway/providers',
    'gatewayPaymentInitiate': '/gateway/payment/initiate',
    'gatewayPaymentOrders': '/gateway/orders',
    'gatewayPaymentOrderTemplate': '/gateway/order/{orderId}',
    'gatewayPaymentSettleTemplate': '/gateway/payment/{orderId}/settle',
    'gatewayPaymentRefundTemplate': '/gateway/payment/{orderId}/refund',
    'gatewaySettlements': '/gateway/settlements',
    'gatewaySettlementStatusTemplate':
        '/gateway/settlement/{settlementId}/status',
    'gatewaySettlementConfirmTemplate':
        '/gateway/settlement/{settlementId}/confirm',
    'gatewaySettlementDisputeTemplate':
        '/gateway/settlement/{settlementId}/dispute',
    'gatewaySchedulerHealth': '/gateway/scheduler/health',
    'agentWallets': '/agent/wallets',
    'agentTransactions': '/agent/transactions',
    'agentLookup': '/agent/lookup',
    'agentCustomers': '/agent/customers',
    'agentCustomerRegister': '/agent/customers/register',
    'agentCommissions': '/agent/commissions',
    'agentDepositPreview': '/agent/cash/deposit/preview',
    'agentDepositSettle': '/agent/cash/deposit/settle',
    'agentWithdrawPreview': '/agent/cash/withdraw/preview',
    'agentWithdrawSettle': '/agent/cash/withdraw/settle',
    'tenantMy': '/core/tenants/my',
    'tenantSettlementConfigTemplate': '/core/tenants/{id}/settlement/config',
    'tenantWalletsTemplate': '/core/tenants/{id}/wallets',
    'tenantSettlementHistoryTemplate': '/core/tenants/{id}/settlement/history',
    'transactionReceiptTemplate': '/transactions/{id}/receipt',

    // System
    'bootstrap': '/sys/bootstrap',
    'metrics': '/sys/metrics',
  };
}

// ----------------------------------------------------------------------
// ENUMS MATCHING BACKEND TYPES (for type‑safe coding)
// ----------------------------------------------------------------------

/// Merchant categories as defined in the backend.
enum MerchantCategory {
  bundles,
  internet,
  utilities,
  entertainment,
  education,
  government,
  business,
  general,
}

extension MerchantCategoryExtension on MerchantCategory {
  /// Returns the string value expected by the API (e.g., 'bundles').
  String get value => toString().split('.').last;

  /// Converts a raw string back to the enum.
  static MerchantCategory fromString(String value) {
    return MerchantCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MerchantCategory.general,
    );
  }
}

/// Transaction types as defined in the backend.
enum TransactionType {
  deposit,
  expense,
  transfer,
  escrow,
  // ignore: constant_identifier_names
  goal_allocation,
  salary,
  interest,
  dividend,
  refund,
  fee,
  // ignore: constant_identifier_names
  bill_payment,
  withdrawal,
}
