import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Lightweight wrapper around sms_autofill to start/stop SMS Retriever
/// and parse the first numeric code it finds (default length 6).
class OtpAutoFillService {
  final SmsAutoFill _autoFill = SmsAutoFill();
  StreamSubscription<String>? _sub;

  /// Returns the Android SMS Retriever app signature hash.
  ///
  /// Your backend must include this hash in the OTP SMS for auto-read to work.
  /// Returns null on non-Android platforms or if the platform call fails.
  Future<String?> getAndroidHash() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _autoFill.getAppSignature;
    } catch (e) {
      // If this fails in release, logcat will show the reason.
      dev.log('Failed to get app signature: $e', name: 'OTP');
      return null;
    }
  }

  Future<void> startListening({
    int codeLength = 6,
    void Function(String code)? onCode,
  }) async {
    await stopListening();
    final hash = await getAndroidHash();
    if (hash != null && hash.isNotEmpty) {
      // Use dev.log so it shows up reliably in release logcat.
      dev.log('Android SMS Retriever hash: $hash', name: 'OTP');
      debugPrint('[OTP] Android SMS Retriever hash: $hash');
    }
    _sub = _autoFill.code.listen((msg) {
      final code = _extractCode(msg, codeLength);
      if (code != null && onCode != null) onCode(code);
    });
    await _autoFill.listenForCode();
  }

  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _autoFill.unregisterListener();
    } catch (_) {
      // ignore: best-effort cleanup
    }
  }

  String? _extractCode(String msg, int len) {
    final match = RegExp('\\d{$len}').firstMatch(msg);
    return match?.group(0);
  }
}
