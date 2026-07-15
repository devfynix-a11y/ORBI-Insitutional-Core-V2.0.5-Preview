import 'package:flutter/material.dart';

enum WalletFilter { all, internal, linked }

enum TransactionLifecycle {
  available,
  allocated,
  budgeted,
  saved,
  locked,
  spent,
}

enum TransactionDirection { credit, debit, neutral }

class WalletRecord {
  WalletRecord({
    required this.raw,
    required this.metadata,
    required this.id,
    required this.name,
    required this.currency,
    required this.type,
    required this.tier,
    required this.role,
    required this.accountNumber,
    required this.balance,
    required this.status,
    required this.iconHint,
    required this.accentHex,
  });

  final Map<String, dynamic> raw;
  final Map<String, dynamic> metadata;
  final String id;
  final String name;
  final String currency;
  final String type;
  final String tier;
  final String role;
  final String accountNumber;
  final double balance;
  final String status;
  final String iconHint;
  final String accentHex;

  factory WalletRecord.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};

    return WalletRecord(
      raw: Map<String, dynamic>.from(json),
      metadata: metadata,
      id: _firstNonEmptyString([json['wallet_id'], json['id']], fallback: '--'),
      name: _firstNonEmptyString([
        json['name'],
        json['wallet_name'],
        json['title'],
      ], fallback: 'Unnamed Wallet'),
      currency: _firstNonEmptyString([
        json['currency'],
        json['currency_code'],
        json['currencyCode'],
        json['asset_currency'],
        json['assetCurrency'],
        metadata['currency'],
        metadata['currency_code'],
        metadata['currencyCode'],
        metadata['asset_currency'],
      ]),
      type: _firstNonEmptyString([json['wallet_type'], json['type']]),
      tier: _firstNonEmptyString([
        json['management_tier'],
        json['managementTier'],
      ]),
      role: _firstNonEmptyString([
        json['vault_role'],
        json['vaultRole'],
        json['system_role'],
        json['role'],
      ]),
      accountNumber: _firstNonEmptyString([
        json['accountNumber'],
        json['account_number'],
        metadata['account_number'],
        metadata['linked_customer_id'],
      ]),
      balance: _firstDouble([
        json['available_balance'],
        json['balance'],
        json['ledger_balance'],
        json['current_balance'],
        json['amount'],
      ]),
      status: _firstNonEmptyString([json['status']], fallback: 'active'),
      iconHint: _firstNonEmptyString([
        json['icon'],
        json['wallet_icon'],
        json['icon_name'],
        metadata['icon'],
        metadata['wallet_icon'],
        metadata['icon_name'],
      ]),
      accentHex: _firstNonEmptyString([
        json['color'],
        json['accent_color'],
        json['accentColor'],
        metadata['color'],
        metadata['accent_color'],
        metadata['accentColor'],
      ]),
    );
  }

  bool get isEscrow {
    final lowName = name.toLowerCase();
    final lowType = type.toLowerCase();
    final lowRole = role.toLowerCase();
    final isEscrowMeta = metadata['is_secure_escrow'] == true;
    return lowRole.contains('internal_transfer') ||
        lowType.contains('internal_transfer') ||
        lowName.contains('paysafe') ||
        isEscrowMeta ||
        accountNumber.toUpperCase().startsWith('ESC-');
  }

  bool get isInternal {
    final lowType = type.toLowerCase();
    final lowTier = tier.toLowerCase();
    final lowRole = role.toLowerCase();
    return lowType.contains('internal') ||
        lowType.contains('vault') ||
        lowType.contains('sovereign') ||
        lowTier == 'sovereign' ||
        lowRole == 'operating' ||
        lowRole == 'internal_transfer';
  }

  bool get isLinked {
    final lowType = type.toLowerCase();
    final lowTier = tier.toLowerCase();
    return lowType.contains('linked') ||
        lowType.contains('external') ||
        lowType.contains('bank') ||
        lowType.contains('card') ||
        lowTier.contains('linked') ||
        lowTier.contains('external');
  }

  /// Prefer backend role-based operating vault detection, with branded
  /// sovereign fallbacks for deployments that omit a strong role field.
  bool get isPrimaryOperatingVault {
    if (isEscrow) return false;
    final lowName = name.toLowerCase();
    final lowType = type.toLowerCase();
    final lowRole = role.toLowerCase();
    final lowTier = tier.toLowerCase();
    final productName = _firstNonEmptyString([
      metadata['product_name'],
      metadata['productName'],
    ]).toLowerCase();
    final looksDilPesa =
        lowName.contains('dilpesa') || productName.contains('dilpesa');
    return lowRole == 'operating' ||
        lowType == 'internal_main' ||
        lowRole == 'internal_main' ||
        (lowTier == 'sovereign' && looksDilPesa) ||
        looksDilPesa;
  }

  String get displayLabel => isInternal
      ? 'Operating Wallet'
      : _firstNonEmptyString([
          metadata['product_name'],
          metadata['productName'],
        ], fallback: name);

  String get cardType => _firstNonEmptyString([
    metadata['card_type'],
    metadata['cardType'],
  ], fallback: 'Virtual Master');

  String get displayName => _firstNonEmptyString([
    metadata['display_name'],
    metadata['displayName'],
  ], fallback: name);

  String get linkedCustomerId => _firstNonEmptyString([
    metadata['linked_customer_id'],
    metadata['linkedCustomerId'],
    metadata['account_number'],
    accountNumber,
  ]);

  String? get providerIcon {
    final value = _firstNonEmptyString([
      metadata['provider_icon'],
      metadata['providerIcon'],
      metadata['display_icon'],
      metadata['displayIcon'],
      metadata['icon'],
    ], fallback: '');
    return value.isEmpty ? null : value;
  }

  String? get providerColor {
    final value = _firstNonEmptyString([
      metadata['provider_color'],
      metadata['providerColor'],
      metadata['color'],
    ], fallback: '');
    return value.isEmpty ? null : value;
  }

  Color get accentColor {
    final backend = _parseColor(accentHex);
    if (backend != null) return backend;
    if (isLinked) return const Color(0xFFD59D80);
    if (isInternal) return const Color(0xFF69B766);
    return _seedColor(
      _firstNonEmptyString([id, accountNumber, name], fallback: 'wallet'),
    );
  }

  IconData get icon {
    final hint = iconHint.toLowerCase();
    final lowName = name.toLowerCase();
    if (hint.contains('vault')) return Icons.lock_rounded;
    if (hint.contains('bank')) return Icons.account_balance_rounded;
    if (hint.contains('card')) return Icons.credit_card_rounded;
    if (hint.contains('cash')) return Icons.payments_rounded;
    if (hint.contains('coin')) return Icons.monetization_on_rounded;
    if (hint.contains('shield')) return Icons.shield_outlined;
    if (hint.contains('savings')) return Icons.savings_outlined;
    if (hint.contains('store')) return Icons.storefront_outlined;
    if (hint.contains('wallet')) return Icons.wallet_rounded;
    if (lowName.contains('escrow') || lowName.contains('safe')) {
      return Icons.lock_rounded;
    }
    if (lowName.contains('bank')) return Icons.account_balance_rounded;
    if (lowName.contains('card')) return Icons.credit_card_rounded;
    return Icons.wallet_rounded;
  }

  String get kindLabel {
    if (isInternal) return 'OPERATING WALLET';
    if (role.isNotEmpty) return role.toUpperCase();
    if (tier.isNotEmpty) return tier.toUpperCase();
    if (type.isNotEmpty) return type.toUpperCase();
    return 'WALLET';
  }

  bool get isLocked {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('lock') ||
        statusLower.contains('freeze') ||
        statusLower.contains('blocked') ||
        statusLower.contains('suspend')) {
      return true;
    }
    final rawLocked =
        raw['is_locked'] ?? raw['isLocked'] ?? raw['locked'] ?? false;
    if (rawLocked == true) return true;
    final metaStatus = (metadata['status'] ?? metadata['state'] ?? '')
        .toString()
        .toLowerCase();
    if (metaStatus.contains('lock') ||
        metaStatus.contains('freeze') ||
        metaStatus.contains('blocked') ||
        metaStatus.contains('suspend')) {
      return true;
    }
    final metaLocked =
        metadata['is_locked'] ?? metadata['isLocked'] ?? metadata['locked'];
    if (metaLocked == true) return true;
    final metaFrozen = metadata['is_frozen'] ?? metadata['isFrozen'] ?? false;
    if (metaFrozen == true) return true;
    return false;
  }

  WalletRecord copyWith({double? balance}) {
    final nextRaw = Map<String, dynamic>.from(raw)
      ..['balance'] = balance ?? this.balance
      ..['available_balance'] = balance ?? this.balance
      ..['current_balance'] = balance ?? this.balance;
    return WalletRecord.fromJson(nextRaw);
  }

  static Color? _parseColor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    var hex = trimmed;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static Color _seedColor(String seed) {
    const palette = [
      Color(0xFF104C64),
      Color(0xFF2E7D8F),
      Color(0xFF6F9A37),
      Color(0xFFC76B29),
      Color(0xFF7A5AF8),
      Color(0xFFB54749),
      Color(0xFFD59D80),
      Color(0xFF356AE6),
    ];
    final hash = seed.runes.fold<int>(0, (value, rune) => value * 31 + rune);
    return palette[hash.abs() % palette.length];
  }
}

class WalletTransactionRecord {
  WalletTransactionRecord({
    required this.raw,
    required this.id,
    required this.reference,
    required this.kind,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.lifecycle,
    required this.direction,
  });

  final Map<String, dynamic> raw;
  final String id;
  final String reference;
  final String kind;
  final double amount;
  final String currency;
  final String createdAt;
  final TransactionLifecycle lifecycle;
  final TransactionDirection direction;

  factory WalletTransactionRecord.fromJson(
    Map<String, dynamic> json, {
    required String fallbackCurrency,
  }) {
    final kind = _firstNonEmptyString([
      json['type'],
      json['transaction_type'],
      json['kind'],
      json['category'],
      json['description'],
    ], fallback: 'transaction');
    return WalletTransactionRecord(
      raw: Map<String, dynamic>.from(json),
      id: _firstNonEmptyString([
        json['id'],
        json['reference'],
        json['ref'],
        json['tx_ref'],
      ], fallback: UniqueKey().toString()),
      reference: _firstNonEmptyString([
        json['reference'],
        json['ref'],
        json['tx_ref'],
        json['id'],
      ], fallback: '--'),
      kind: kind,
      amount: _firstDouble([
        json['amount'],
        json['value'],
        json['total'],
        json['net_amount'],
        json['gross_amount'],
      ]),
      currency: _firstNonEmptyString([
        json['currency'],
        json['currency_code'],
        json['asset_currency'],
      ], fallback: fallbackCurrency),
      createdAt: _firstNonEmptyString([json['created_at'], json['timestamp']]),
      lifecycle: _resolveLifecycle(json),
      direction: _resolveDirection(kind),
    );
  }

  bool get isCredit => direction == TransactionDirection.credit;
  bool get isDebit => direction == TransactionDirection.debit;
}

TransactionLifecycle _resolveLifecycle(Map<String, dynamic> json) {
  final raw = [
    json['transaction_type'],
    json['type'],
    json['kind'],
    json['category'],
    json['description'],
  ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');

  if (raw.contains('goal') || raw.contains('saving')) {
    if (raw.contains('withdraw')) return TransactionLifecycle.available;
    if (raw.contains('lock')) return TransactionLifecycle.locked;
    return TransactionLifecycle.saved;
  }
  if (raw.contains('budget') || raw.contains('category')) {
    return TransactionLifecycle.budgeted;
  }
  if (raw.contains('bill') ||
      raw.contains('payment') ||
      raw.contains('transfer') ||
      raw.contains('withdraw') ||
      raw.contains('expense') ||
      raw.contains('merchant') ||
      raw.contains('shop')) {
    return TransactionLifecycle.spent;
  }
  if (_isCreditKind(raw)) return TransactionLifecycle.available;
  return TransactionLifecycle.allocated;
}

TransactionDirection _resolveDirection(String kind) {
  final low = kind.toLowerCase();
  if (_isCreditKind(low)) return TransactionDirection.credit;
  if (_isDebitKind(low)) return TransactionDirection.debit;
  return TransactionDirection.neutral;
}

bool _isCreditKind(String raw) {
  return raw.contains('credit') ||
      raw.contains('deposit') ||
      raw.contains('refund') ||
      raw.contains('income') ||
      raw.contains('salary') ||
      raw.contains('interest') ||
      raw.contains('topup') ||
      raw.contains('top_up');
}

bool _isDebitKind(String raw) {
  return raw.contains('debit') ||
      raw.contains('expense') ||
      raw.contains('withdraw') ||
      raw.contains('fee') ||
      raw.contains('charge') ||
      raw.contains('payment');
}

String _firstNonEmptyString(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

double _firstDouble(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}
