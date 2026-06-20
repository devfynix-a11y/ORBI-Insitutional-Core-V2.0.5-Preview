import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Simple client-side password hasher for storing biometric credentials locally.
/// Uses SHA256 with email salt for a reasonable level of security.
///
/// **IMPORTANT**: This is for CLIENT-SIDE credential storage only.
/// Passwords should NEVER be sent to backend as hashes - always send plaintext
/// over HTTPS and let the backend hash with proper algorithms (bcrypt, argon2, etc).
class PasswordHasher {
  /// Hashes a password using email as salt.
  /// Returns a hex-encoded SHA256 hash of (email + password).
  ///
  /// This approach ensures the same password hashed under different emails
  /// produces different hashes, and makes rainbow tables ineffective.
  static String hashPassword(String email, String password) {
    final combined = '$email:$password';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Verifies a password by re-hashing it and comparing to stored hash.
  static bool verifyPassword(String email, String password, String storedHash) {
    final computed = hashPassword(email, password);
    return computed == storedHash;
  }
}
