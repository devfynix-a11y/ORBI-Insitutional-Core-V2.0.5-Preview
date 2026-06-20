import 'package:flutter/material.dart';

class GatewayProvider {
  const GatewayProvider({
    required this.id,
    required this.name,
    required this.brandName,
    required this.type,
    required this.group,
    required this.logicType,
    required this.status,
    required this.supportedCurrencies,
    required this.icon,
    required this.color,
    required this.checkoutMode,
    required this.channels,
    required this.sortOrder,
    required this.metadata,
  });

  final String id;
  final String name;
  final String brandName;
  final String type;
  final String group;
  final String logicType;
  final String status;
  final List<String> supportedCurrencies;
  final String? icon;
  final String? color;
  final String? checkoutMode;
  final List<String> channels;
  final int sortOrder;
  final Map<String, dynamic> metadata;

  bool get isActive => status.trim().toUpperCase() == 'ACTIVE';
  bool get supportsCards =>
      _hasChannel('card') || type.trim().toUpperCase().contains('CARD');
  bool get supportsBank =>
      _hasChannel('bank_transfer') ||
      _hasChannel('bank_account') ||
      type.trim().toUpperCase().contains('BANK');
  bool get supportsMobileMoney {
    final normalized = type.trim().toUpperCase();
    return _hasChannel('mobile_money') ||
        normalized.contains('MOBILE') ||
        normalized.contains('MPESA');
  }

  bool get supportsCrypto =>
      _hasChannel('crypto') || type.trim().toUpperCase().contains('CRYPTO');

  bool _hasChannel(String channel) {
    return channels.map((c) => c.toLowerCase()).contains(channel.toLowerCase());
  }

  String get brandLabel => brandName.trim().isEmpty ? name : brandName;
  String get groupLabel => group.trim().isEmpty ? 'Gateways' : group;

  Color? get colorValue {
    final raw = (color ?? '').trim();
    if (raw.isEmpty) return null;
    var hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  factory GatewayProvider.fromJson(Map<String, dynamic> json) {
    return GatewayProvider(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['label'] ?? json['capabilityCode'] ?? '')
          .toString(),
      brandName:
          (json['brandName'] ??
                  json['brand_name'] ??
                  json['label'] ??
                  json['display_name'] ??
                  json['displayName'] ??
                  '')
              .toString(),
      type: (json['type'] ?? json['rail'] ?? '').toString(),
      group:
          (json['group'] ??
                  json['provider_group'] ??
                  _groupFromRail(json['rail']))
              .toString(),
      logicType: (json['logicType'] ?? json['logic_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      supportedCurrencies: _readStringList(
        json['supportedCurrencies'] ??
            json['supported_currencies'] ??
            json['currencies'] ??
            json['currency'],
      ),
      icon: _readNullableString(
        json['icon'] ?? json['display_icon'] ?? json['displayIcon'],
      ),
      color: _readNullableString(json['color']),
      checkoutMode: _readNullableString(
        json['checkoutMode'] ?? json['checkout_mode'],
      ),
      channels: _readStringList(
        json['channels'] ??
            json['rail'] ??
            (json['metadata'] is Map
                ? (json['metadata'] as Map)['channels']
                : null),
      ),
      sortOrder:
          _readInt(
            json['sortOrder'] ?? json['sort_order'] ?? json['priority'],
          ) ??
          0,
      metadata: {
        ..._readMap(json['metadata']),
        if (json['capabilityCode'] != null ||
            json['capability_code'] != null ||
            json['payGateway'] != null)
          'payment_rail_capability': Map<String, dynamic>.from(json),
      },
    );
  }
}

class GatewayPaymentInitiationResult {
  const GatewayPaymentInitiationResult({
    required this.success,
    required this.orderId,
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.currency,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String orderId;
  final String transactionId;
  final String status;
  final double amount;
  final String currency;
  final Map<String, dynamic> raw;

  factory GatewayPaymentInitiationResult.fromJson(Map<String, dynamic> json) {
    return GatewayPaymentInitiationResult(
      success: _readBool(json['success']),
      orderId: (json['orderId'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class GatewayOrder {
  const GatewayOrder({
    required this.id,
    required this.providerId,
    required this.status,
    required this.amount,
    required this.currency,
    this.authorizationId,
    this.settlementId,
    this.createdAt,
    this.updatedAt,
    this.metadata = const <String, dynamic>{},
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String providerId;
  final String status;
  final double amount;
  final String currency;
  final String? authorizationId;
  final String? settlementId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> raw;

  factory GatewayOrder.fromJson(Map<String, dynamic> json) {
    return GatewayOrder(
      id: (json['id'] ?? '').toString(),
      providerId: (json['provider_id'] ?? json['providerId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      authorizationId: _readNullableString(
        json['authorization_id'] ?? json['authorizationId'],
      ),
      settlementId: _readNullableString(
        json['settlement_id'] ?? json['settlementId'],
      ),
      createdAt: _readDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _readDateTime(json['updated_at'] ?? json['updatedAt']),
      metadata: _readMap(json['metadata']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class GatewaySettlementRecord {
  const GatewaySettlementRecord({
    required this.success,
    required this.phase,
    required this.settlementId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.status,
    this.walletId,
    this.autoSettleMinutes,
    this.autoSettleAt,
    this.message,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String phase;
  final String settlementId;
  final String orderId;
  final double amount;
  final String currency;
  final String status;
  final String? walletId;
  final int? autoSettleMinutes;
  final DateTime? autoSettleAt;
  final String? message;
  final Map<String, dynamic> raw;

  factory GatewaySettlementRecord.fromJson(Map<String, dynamic> json) {
    return GatewaySettlementRecord(
      success: _readBool(json['success']),
      phase: (json['phase'] ?? '').toString(),
      settlementId: (json['settlementId'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      walletId: _readNullableString(json['walletId']),
      autoSettleMinutes: _readInt(json['autoSettleMinutes']),
      autoSettleAt: _readDateTime(json['autoSettleAt']),
      message: _readNullableString(json['message']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class GatewaySettlementStatus {
  const GatewaySettlementStatus({
    required this.success,
    required this.settlementId,
    required this.currentPhase,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
    this.message,
    this.autoSettleAt,
    this.settledAt,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String settlementId;
  final String currentPhase;
  final double amount;
  final String currency;
  final String provider;
  final String status;
  final String? message;
  final DateTime? autoSettleAt;
  final DateTime? settledAt;
  final Map<String, dynamic> raw;

  bool get isFinalPhase =>
      currentPhase == 'INTERNALLY_SETTLED' ||
      currentPhase == 'SETTLEMENT_FAILED' ||
      currentPhase == 'REVERSED';

  factory GatewaySettlementStatus.fromJson(Map<String, dynamic> json) {
    return GatewaySettlementStatus(
      success: _readBool(json['success']),
      settlementId: (json['settlementId'] ?? '').toString(),
      currentPhase: (json['currentPhase'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      message: _readNullableString(json['message']),
      autoSettleAt: _readDateTime(json['autoSettleAt']),
      settledAt: _readDateTime(json['settledAt']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class GatewaySettlementActionResult {
  const GatewaySettlementActionResult({
    required this.success,
    required this.message,
    this.settlementId,
    this.status,
    this.newPhase,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String message;
  final String? settlementId;
  final String? status;
  final String? newPhase;
  final Map<String, dynamic> raw;

  factory GatewaySettlementActionResult.fromJson(Map<String, dynamic> json) {
    return GatewaySettlementActionResult(
      success: _readBool(json['success']),
      message: (json['message'] ?? '').toString(),
      settlementId: _readNullableString(json['settlementId']),
      status: _readNullableString(json['status']),
      newPhase: _readNullableString(json['newPhase']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class GatewaySettlementSummary {
  const GatewaySettlementSummary({
    required this.id,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.phase,
    this.phaseStartedAt,
    this.autoSettleAt,
    this.createdAt,
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final double amount;
  final String currency;
  final String provider;
  final String phase;
  final DateTime? phaseStartedAt;
  final DateTime? autoSettleAt;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  factory GatewaySettlementSummary.fromJson(Map<String, dynamic> json) {
    return GatewaySettlementSummary(
      id: (json['id'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      phaseStartedAt: _readDateTime(json['phaseStartedAt']),
      autoSettleAt: _readDateTime(json['autoSettleAt']),
      createdAt: _readDateTime(json['createdAt']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .map((item) => item.toString())
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _groupFromRail(dynamic value) {
  final rail = (value ?? '').toString().trim().toUpperCase();
  switch (rail) {
    case 'MOBILE_MONEY':
      return 'Mobile Money';
    case 'BANK':
      return 'Bank';
    case 'CARD_GATEWAY':
      return 'Cards';
    case 'CRYPTO':
      return 'Crypto';
    case 'WALLET':
      return 'Wallet';
    default:
      return '';
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final normalized = (value ?? '').toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String? _readNullableString(dynamic value) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _readDateTime(dynamic value) {
  final normalized = _readNullableString(value);
  if (normalized == null) return null;
  return DateTime.tryParse(normalized);
}
