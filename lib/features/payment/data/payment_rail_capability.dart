import 'package:flutter/material.dart';

class PaymentRailCapability {
  const PaymentRailCapability({
    required this.id,
    required this.capabilityCode,
    required this.label,
    required this.rail,
    required this.countryCode,
    required this.currency,
    required this.operations,
    required this.status,
    required this.priority,
    this.minAmount,
    this.maxAmount,
    this.icon,
    this.color,
    this.requires = const <String, dynamic>{},
    this.feeProfileCode,
    this.switchPartner = const <String, dynamic>{},
    this.payGateway = const <String, dynamic>{},
    this.metadata = const <String, dynamic>{},
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String capabilityCode;
  final String label;
  final String rail;
  final String countryCode;
  final String currency;
  final List<String> operations;
  final String status;
  final int priority;
  final double? minAmount;
  final double? maxAmount;
  final String? icon;
  final String? color;
  final Map<String, dynamic> requires;
  final String? feeProfileCode;
  final Map<String, dynamic> switchPartner;
  final Map<String, dynamic> payGateway;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> raw;

  bool get isActive => status.trim().toUpperCase() == 'ACTIVE';
  bool get isBank => rail.trim().toUpperCase() == 'BANK';
  bool get isMobileMoney => rail.trim().toUpperCase() == 'MOBILE_MONEY';
  bool get isCardGateway => rail.trim().toUpperCase() == 'CARD_GATEWAY';
  bool get isCrypto => rail.trim().toUpperCase() == 'CRYPTO';
  bool get isWallet => rail.trim().toUpperCase() == 'WALLET';

  String get brandLabel => label.trim().isEmpty ? capabilityCode : label;

  String get groupLabel {
    if (isMobileMoney) return 'Mobile Money';
    if (isBank) return 'Bank';
    if (isCardGateway) return 'Cards';
    if (isCrypto) return 'Crypto';
    if (isWallet) return 'Wallet';
    return rail.replaceAll('_', ' ');
  }

  String? get providerCode {
    final code = payGateway['providerCode'] ?? payGateway['provider_code'];
    final value = code?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get partnerName {
    final name = switchPartner['name'] ?? switchPartner['displayName'];
    final value = name?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool supportsOperation(String operation) {
    final target = operation.trim().toUpperCase();
    return operations.map((item) => item.trim().toUpperCase()).contains(target);
  }

  Color? get colorValue {
    final rawColor = (color ?? '').trim();
    if (rawColor.isEmpty) return null;
    var hex = rawColor.startsWith('#') ? rawColor.substring(1) : rawColor;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  factory PaymentRailCapability.fromJson(Map<String, dynamic> json) {
    final capabilityCode = _readString([
      json['capabilityCode'],
      json['capability_code'],
      json['code'],
      json['id'],
    ]);
    return PaymentRailCapability(
      id: _readString([json['id'], capabilityCode]),
      capabilityCode: capabilityCode,
      label: _readString([
        json['label'],
        json['displayName'],
        json['display_name'],
        json['name'],
        capabilityCode,
      ]),
      rail: _readString([
        json['rail'],
        json['railType'],
        json['type'],
      ]).toUpperCase(),
      countryCode: _readString([
        json['countryCode'],
        json['country_code'],
      ]).toUpperCase(),
      currency: _readString([json['currency']]).toUpperCase(),
      operations: _readStringList(
        json['operations'] ?? json['operationCodes'] ?? json['operation_codes'],
      ),
      status: _readString([json['status'], 'ACTIVE']).toUpperCase(),
      priority: _readInt(json['priority']) ?? _readInt(json['sortOrder']) ?? 0,
      minAmount: _readDouble(json['minAmount'] ?? json['min_amount']),
      maxAmount: _readDouble(json['maxAmount'] ?? json['max_amount']),
      icon: _readNullableString(json['icon']),
      color: _readNullableString(json['color']),
      requires: _readMap(json['requires']),
      feeProfileCode: _readNullableString(
        json['feeProfileCode'] ?? json['fee_profile_code'],
      ),
      switchPartner: _readMap(json['switchPartner'] ?? json['switch_partner']),
      payGateway: _readMap(json['payGateway'] ?? json['pay_gateway']),
      metadata: _readMap(json['metadata']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

String _readString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
