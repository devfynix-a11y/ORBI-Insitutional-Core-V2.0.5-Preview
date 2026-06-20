import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class TlsPinning {
  static bool get enabled =>
      AppConfig.tlsCertPins.isNotEmpty && kReleaseMode;

  static bool validate(X509Certificate cert) {
    final pins = AppConfig.tlsCertPins;
    if (pins.isEmpty) return true;
    final digest = sha256.convert(cert.der).toString();
    return pins.contains(digest);
  }
}

class TlsPinningHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: false),
    );
    client.badCertificateCallback = (cert, host, port) {
      final ok = TlsPinning.validate(cert);
      if (!ok) {
        debugPrint(
          '❌ TLS pinning failed for $host:$port (fingerprint mismatch)',
        );
      }
      return ok;
    };
    return client;
  }
}

class TlsPinningInstaller {
  static void install() {
    if (!TlsPinning.enabled) return;
    HttpOverrides.global = TlsPinningHttpOverrides();
  }
}
