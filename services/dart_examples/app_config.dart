
/// ORBI APP CONFIGURATION (DART)
/// ------------------------------
/// Centralized configuration for the Orbi Mobile App.
/// Supports multiple environments (Dev, Prod).

enum Environment {
  dev,
  prod,
  render,
}

class AppConfig {
  // 1. CURRENT ENVIRONMENT
  // Change this to Environment.render for live Render deployment
  static const Environment _currentEnv = Environment.render;

  // 2. BASE URLS
  // NOTE: 
  // - For Android Emulator: Use 'http://10.0.2.2:3000'
  // - For iOS Simulator: Use 'http://localhost:3000'
  // - For Physical Device: Use your computer's LAN IP (e.g., 'http://192.168.1.x:3000')
  
  // Defaulting to User's LAN IP for Physical Device Testing
  static const String _devUrl = 'http://192.168.0.107:3000'; 
  
  // AI Studio Preview URL (Deprecated - Redirecting to Render)
  static const String _aiStudioUrl = 'https://orbi-financial-technologies-c0re-v2026.onrender.com';

  // Render Deployment URL
  static const String _renderUrl = 'https://orbi-financial-technologies-c0re-v2026.onrender.com';

  static String get baseUrl {
    switch (_currentEnv) {
      case Environment.dev:
        return _devUrl;
      case Environment.prod:
        return _aiStudioUrl;
      case Environment.render:
        return _renderUrl;
    }
  }

  static const String apiVersion = 'v1';
  static String get apiUrl => '$baseUrl/$apiVersion';

  static String get wsUrl {
    final scheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/nexus-stream';
  }

  // --- ENDPOINTS ---
  static const Map<String, String> endpoints = {
    // Auth
    'login': '/auth/login',
    'signup': '/auth/signup',
    'profile': '/user/profile',
    'lookup': '/user/lookup',
    
    // Next-Gen Biometrics (Passkeys)
    'biometricRegisterStart': '/auth/passkey/register/start',
    'biometricRegisterFinish': '/auth/passkey/register/finish',
    'biometricLoginStart': '/auth/passkey/login/start',
    'biometricLoginFinish': '/auth/passkey/login/finish',
    'behaviorRecord': '/auth/behavior/record',
    
    // Wealth
    'wallets': '/wallets',
    'transactions': '/transactions',
    'settle': '/transactions/settle',
    
    // Strategy
    'goals': '/goals',
    'categories': '/categories',
    
    // Merchants
    'merchants': '/merchants',
    'merchantCategories': '/merchants/categories',
    
    // System
    'bootstrap': '/sys/bootstrap',
    'metrics': '/sys/metrics',
  };

  // --- TIMEOUTS ---
  static const int connectTimeout = 15000; // 15s
  static const int receiveTimeout = 15000; // 15s
}

/// MERCHANT CATEGORIES
/// Matches backend MerchantCategory type
enum MerchantCategory {
  bundles,
  internet,
  utilities,
  entertainment,
  education,
  government,
  business,
  general
}

extension MerchantCategoryExtension on MerchantCategory {
  String get value => toString().split('.').last;

  static MerchantCategory fromString(String value) {
    return MerchantCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MerchantCategory.general,
    );
  }
}

/// TRANSACTION TYPES
/// Matches backend TransactionType
enum TransactionType {
  deposit,
  expense,
  transfer,
  escrow,
  goal_allocation,
  salary,
  interest,
  dividend,
  refund,
  fee,
  bill_payment,
  withdrawal
}
