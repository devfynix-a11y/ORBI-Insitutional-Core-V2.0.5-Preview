import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistent storage of idempotency keys.
/// Each key is associated with a local transaction ID (UUID) and stored
/// until the transaction is definitively completed or failed.
class IdempotencyStorage {
  static const String _prefix = 'idempotency_';

  /// Saves an idempotency key for a given local transaction ID.
  Future<void> saveKey(String localTxId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + localTxId, key);
  }

  /// Retrieves the idempotency key for a local transaction ID, if any.
  Future<String?> getKey(String localTxId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefix + localTxId);
  }

  /// Removes the stored key for a local transaction ID (called after final outcome).
  Future<void> removeKey(String localTxId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + localTxId);
  }

  /// Returns all pending keys (useful for reconciliation on app start).
  Future<Map<String, String>> getAllPendingKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final localTxId = key.substring(_prefix.length);
        final idemKey = prefs.getString(key);
        if (idemKey != null) result[localTxId] = idemKey;
      }
    }
    return result;
  }
}
