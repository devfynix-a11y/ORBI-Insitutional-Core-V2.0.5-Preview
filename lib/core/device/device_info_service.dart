import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:orbi_mobileapp/core/config/app_config.dart';
import 'package:orbi_mobileapp/core/security/device_integrity_service.dart';

class DeviceInfoService {
  DeviceInfoService._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();
  static Map<String, dynamic>? _cachedPayload;

  static Future<Map<String, dynamic>> buildPayload() async {
    final cached = _cachedPayload;
    if (cached != null) return Map<String, dynamic>.from(cached);

    final view = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first
        : null;
    final physicalSize = view?.physicalSize;
    final resolution = physicalSize == null
        ? 'unknown'
        : '${physicalSize.width.toInt()}x${physicalSize.height.toInt()}';
    final locale = ui.PlatformDispatcher.instance.locale;

    final payload = <String, dynamic>{
      'model': Platform.operatingSystem,
      'deviceName': Platform.operatingSystem,
      'os': Platform.operatingSystemVersion,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'screenResolution': resolution,
      'timezone': DateTime.now().timeZoneName,
      'language': locale.toLanguageTag(),
      'appVersion': AppConfig.appVersion,
      if (DeviceIntegrityService.deviceState != null)
        'device_state': DeviceIntegrityService.deviceState,
      if (DeviceIntegrityService.isCompromised != null)
        'device_compromised': DeviceIntegrityService.isCompromised,
      if (DeviceIntegrityService.attestationToken != null)
        'attestation': DeviceIntegrityService.attestationToken,
    };

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final displayName = _resolveAndroidName(info);
        payload.addAll(
          {
            'manufacturer': _trimOrNull(info.manufacturer),
            'brand': _trimOrNull(info.brand),
            'model': _trimOrNull(info.model) ?? displayName,
            'deviceName': displayName,
            'deviceModel': _trimOrNull(info.model) ?? displayName,
            'deviceCodeName': _trimOrNull(info.device),
            'product': _trimOrNull(info.product),
            'sdkInt': info.version.sdkInt,
            'osRelease': _trimOrNull(info.version.release),
          }..removeWhere((key, value) => value == null),
        );
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final machine = _trimOrNull(info.utsname.machine);
        final displayName = _resolveIosName(machine);
        payload.addAll(
          {
            'manufacturer': 'Apple',
            'model': machine ?? displayName,
            'deviceName': displayName,
            'deviceModel': machine ?? displayName,
            'localizedModel': _trimOrNull(info.localizedModel),
            'systemName': _trimOrNull(info.systemName),
            'systemVersion': _trimOrNull(info.systemVersion),
          }..removeWhere((key, value) => value == null),
        );
      }
    } catch (e) {
      debugPrint('⚠️ device_info_service: failed to resolve device info: $e');
    }

    _cachedPayload = Map<String, dynamic>.from(payload);
    return Map<String, dynamic>.from(payload);
  }

  static String _resolveAndroidName(AndroidDeviceInfo info) {
    final brand = _trimOrNull(info.brand);
    final manufacturer = _trimOrNull(info.manufacturer);
    final model = _trimOrNull(info.model);

    if (model == null || model.isEmpty) {
      return brand ?? manufacturer ?? 'Android Device';
    }

    final normalizedBrand = (brand ?? manufacturer ?? '').toLowerCase();
    final normalizedModel = model.toLowerCase();
    if (normalizedBrand.isNotEmpty &&
        normalizedModel.startsWith(normalizedBrand)) {
      return _titleCase(model);
    }

    final prefix = brand ?? manufacturer;
    if (prefix == null || prefix.isEmpty) {
      return _titleCase(model);
    }
    return '${_titleCase(prefix)} ${model.trim()}';
  }

  static String _resolveIosName(String? machine) {
    final normalized = machine?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'iPhone';
    }
    return _iosMarketingNames[normalized] ?? normalized;
  }

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static const Map<String, String> _iosMarketingNames = {
    'iPhone10,1': 'iPhone 8',
    'iPhone10,4': 'iPhone 8',
    'iPhone10,2': 'iPhone 8 Plus',
    'iPhone10,5': 'iPhone 8 Plus',
    'iPhone10,3': 'iPhone X',
    'iPhone10,6': 'iPhone X',
    'iPhone11,2': 'iPhone XS',
    'iPhone11,4': 'iPhone XS Max',
    'iPhone11,6': 'iPhone XS Max',
    'iPhone11,8': 'iPhone XR',
    'iPhone12,1': 'iPhone 11',
    'iPhone12,3': 'iPhone 11 Pro',
    'iPhone12,5': 'iPhone 11 Pro Max',
    'iPhone12,8': 'iPhone SE (2nd generation)',
    'iPhone13,1': 'iPhone 12 mini',
    'iPhone13,2': 'iPhone 12',
    'iPhone13,3': 'iPhone 12 Pro',
    'iPhone13,4': 'iPhone 12 Pro Max',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,6': 'iPhone SE (3rd generation)',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
  };
}
