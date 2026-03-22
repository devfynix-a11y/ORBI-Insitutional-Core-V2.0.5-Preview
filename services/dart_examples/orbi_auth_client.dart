import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'nexus_stream_client.dart';

/// ORBI AUTHENTICATION CLIENT (DART)
/// ----------------------------------
/// A production-ready client for interacting with the Orbi Sovereign Backend.
/// Handles Login, Signup, Token Management, and Authenticated Requests.

class OrbiAuthClient {
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userProfile;

  OrbiAuthClient({required this.baseUrl});

  /// 1. LOGIN
  /// Authenticates a user and stores the session token.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['login']}');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'e': email, 'p': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          
          // Extract Token (Handle both direct and nested structures)
          _accessToken = data['access_token'] ?? data['session']?['access_token'];
          _refreshToken = data['session']?['refresh_token'];
          _userProfile = data['user'];
          
          // DEMO: How to safely store this in SharedPreferences/SecureStorage
          // This prevents the "type 'Map<String, dynamic>' is not a subtype of type 'String'" error
          await TokenStorage.saveSession(_accessToken!, _refreshToken, _userProfile);
          
          print('✅ Login Successful. Token stored.');
          return data;
        } else {
          throw Exception(body['error'] ?? 'Login failed');
        }
      } else {
        throw Exception('Server Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Login Error: $e');
      rethrow;
    }
  }

  /// 2. SIGNUP
  /// Registers a new user and automatically logs them in if successful.
  Future<Map<String, dynamic>> signup(String email, String password, String fullName, String phone) async {
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['signup']}');
    
    final payload = {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      'metadata': {
        'app_origin': 'OBI_MOBILE_V1',
        'registry_type': 'CONSUMER'
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          
          // Auto-login if session is returned
          if (data['session'] != null) {
            _accessToken = data['session']['access_token'];
            _userProfile = data['user'];
            print('✅ Signup & Auto-Login Successful.');
          } else {
            print('✅ Signup Successful. Please verify email.');
          }
          
          return data;
        } else {
          throw Exception(body['error'] ?? 'Signup failed');
        }
      } else {
        throw Exception('Server Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Signup Error: $e');
      rethrow;
    }
  }

  /// 3. AUTHENTICATED GET REQUEST
  /// Fetches the user's profile using the stored token.
  Future<Map<String, dynamic>> getUserProfile() async {
    if (_accessToken == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl${AppConfig.endpoints['profile']}');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Profile Fetch Error: $e');
      rethrow;
    }
  }

  /// 4. AUTHENTICATED POST REQUEST (Example: Create Wallet)
  Future<Map<String, dynamic>> createWallet(String name, String currency) async {
    if (_accessToken == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl${AppConfig.endpoints['wallets']}');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'name': name,
          'currency': currency,
          'type': 'standard'
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Failed to create wallet: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Wallet Creation Error: $e');
      rethrow;
    }
  }
}

/// MOCK STORAGE CLASS
/// Demonstrates how to fix the "Map<String, dynamic> is not a subtype of String" error
class TokenStorage {
  static Future<void> saveSession(String accessToken, String? refreshToken, Map<String, dynamic>? user) async {
    // 1. Save Token (String) - This is fine
    print('💾 Saving Access Token: ${accessToken.substring(0, 10)}...');
    
    // 2. Save User (Map) - THIS IS WHERE THE ERROR HAPPENS IF NOT ENCODED
    if (user != null) {
      // ❌ BAD: await storage.write(key: 'user', value: user); // Crash!
      
      // ✅ GOOD: Encode to JSON String first
      final userJson = jsonEncode(user);
      print('💾 Saving User Profile (Encoded): ${userJson.substring(0, 20)}...');
      // await storage.write(key: 'user', value: userJson);
    }
  }
}

class OrbiWalletClient {
  final String baseUrl;
  final String accessToken;

  OrbiWalletClient({required this.baseUrl, required this.accessToken});

  /// 5. FETCH WALLETS (Dashboard)
  /// Returns all sovereign vaults and linked accounts.
  Future<List<dynamic>> getWallets() async {
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['wallets']}');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Failed to fetch wallets: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Wallet Fetch Error: $e');
      rethrow;
    }
  }

  /// 6. MAKE TRANSFER (Atomic Settlement)
  /// Executes a secure money transfer.
  Future<Map<String, dynamic>> transferFunds({
    required String sourceWalletId,
    required String targetWalletId,
    required double amount,
    required String currency,
    String description = 'Transfer',
  }) async {
    final url = Uri.parse('$baseUrl${AppConfig.endpoints['settle']}');
    // Generate a random UUID for idempotency (in a real app, use the uuid package)
    final idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString(); 
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'x-idempotency-key': idempotencyKey, // Critical for network safety
        },
        body: jsonEncode({
          'type': 'PEER_TRANSFER',
          'amount': amount,
          'currency': currency,
          'sourceWalletId': sourceWalletId,
          'targetWalletId': targetWalletId,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else {
        throw Exception('Transfer failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Transfer Error: $e');
      rethrow;
    }
  }
}
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  // Allow bad certificates for development debugging
  HttpOverrides.global = DevHttpOverrides();

  // Use the centralized AppConfig for the base URL
  final client = OrbiAuthClient(baseUrl: AppConfig.apiUrl);

  try {
    print('Connecting to: ${client.baseUrl}');
    
    // 1. Login
    final loginData = await client.login('user@orbi.io', 'SecurePass123!');
    final accessToken = loginData['access_token'] ?? loginData['session']['access_token'];

    // 2. Initialize Wallet Client
    final walletClient = OrbiWalletClient(baseUrl: AppConfig.apiUrl, accessToken: accessToken);

    // 3. Fetch Wallets (Dashboard)
    final wallets = await walletClient.getWallets();
    print('💰 Wallets: ${wallets.length} found');
    if (wallets.isNotEmpty) {
      print('   - Primary: ${wallets[0]['id']} (${wallets[0]['balance']} ${wallets[0]['currency']})');
    }

    // 4. Connect to Real-Time Stream
    final nexus = NexusClient();
    await nexus.connect(accessToken);
    
    nexus.events.listen((event) {
      print('🔔 UI Update: ${event['type']}');
    });

    // Keep alive for demo
    await Future.delayed(Duration(seconds: 10));
    nexus.disconnect();

  } catch (e) {
    print('Operation failed: $e');
  }
}
