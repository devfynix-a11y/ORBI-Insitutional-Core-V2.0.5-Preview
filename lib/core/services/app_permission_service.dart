import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  AppPermissionService._();

  static final AppPermissionService instance = AppPermissionService._();

  bool _startupPrompted = false;

  Future<void> requestStartupPermissions() async {
    if (_startupPrompted) return;
    _startupPrompted = true;

    await Future.wait([
      _requestLocationForTransactionSafety(),
      _requestContactsForRecipientPicking(),
    ]);
  }

  Future<void> _requestLocationForTransactionSafety() async {
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.always ||
          current == LocationPermission.whileInUse ||
          current == LocationPermission.deniedForever) {
        return;
      }
      await Geolocator.requestPermission();
    } catch (error) {
      debugPrint('[PERMISSIONS] Location request skipped: $error');
    }
  }

  Future<void> _requestContactsForRecipientPicking() async {
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited || status.isPermanentlyDenied) {
        return;
      }
      await Permission.contacts.request();
    } catch (error) {
      debugPrint('[PERMISSIONS] Contacts request skipped: $error');
    }
  }
}
