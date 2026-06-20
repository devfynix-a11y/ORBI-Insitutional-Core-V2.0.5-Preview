import 'dart:convert';

class TokenManager {
  /// Returns true if the JWT is expired or about to expire.
  ///
  /// We decode the JWT payload locally to read the `exp` claim.
  /// This does NOT verify signature — backend does that.
  ///
  /// Early refresh buffer:
  /// We refresh 30 seconds before actual expiration to prevent
  /// race conditions during API calls.
  bool isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      final exp = payload['exp'];
      if (exp == null) return true;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      return DateTime.now().isAfter(
        expiry.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true;
    }
  }

  Duration? timeUntilExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      final exp = payload['exp'];
      if (exp == null) return null;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiry.difference(DateTime.now());
    } catch (_) {
      return null;
    }
  }
}
