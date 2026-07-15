class UserModel {
  final String id;
  final String? email;
  final String? fullName;
  final Map<String, dynamic> rawData;

  UserModel({
    required this.id,
    this.email,
    this.fullName,
    required this.rawData,
  });

  factory UserModel.fromJson(Map<dynamic, dynamic> json) {
    final raw = _normalizeUserCurrency(Map<String, dynamic>.from(json));

    String resolvedId = '';
    for (final key in ['id', 'user_id', 'userId', 'uid']) {
      if (raw[key] != null && raw[key].toString().isNotEmpty) {
        resolvedId = raw[key].toString();
        break;
      }
    }

    String? resolvedEmail;
    for (final key in ['email', 'e', 'mail']) {
      if (raw[key] is String && (raw[key] as String).isNotEmpty) {
        resolvedEmail = raw[key] as String;
        break;
      }
    }

    String? resolvedName;
    final nameCandidates = [
      raw['full_name'],
      raw['fullName'],
      raw['name'],
      if (raw['first_name'] != null && raw['last_name'] != null)
        '${raw['first_name']} ${raw['last_name']}',
    ];
    for (final value in nameCandidates) {
      if (value is String && value.trim().isNotEmpty) {
        resolvedName = value.trim();
        break;
      }
    }

    return UserModel(
      id: resolvedId,
      email: resolvedEmail,
      fullName: resolvedName,
      rawData: raw,
    );
  }

  UserModel copyWith(Map<String, dynamic> newData) {
    final merged = Map<String, dynamic>.from(rawData)..addAll(newData);
    return UserModel.fromJson(merged);
  }

  Map<String, dynamic> toJson() => rawData;
}

Map<String, dynamic> _normalizeUserCurrency(Map<String, dynamic> raw) {
  final currency = _resolveCurrencyFrom(raw);
  if (currency.isNotEmpty) {
    raw['currency'] = currency;
    raw['currency_code'] = currency;
    raw['preferred_currency'] = currency;
  }
  return raw;
}

String _resolveCurrencyFrom(Map<dynamic, dynamic> source) {
  final values = <dynamic>[
    source['currency'],
    source['currency_code'],
    source['currencyCode'],
    source['preferred_currency'],
    source['preferredCurrency'],
    source['account_currency'],
    source['accountCurrency'],
    source['default_currency'],
    source['defaultCurrency'],
  ];

  void addFrom(dynamic value) {
    if (value is Map) {
      values.add(_resolveCurrencyFrom(value));
    } else if (value is List) {
      for (final item in value) {
        addFrom(item);
      }
    }
  }

  for (final key in const [
    'account',
    'primary_account',
    'primaryAccount',
    'wallet',
    'primary_wallet',
    'primaryWallet',
    'metadata',
  ]) {
    addFrom(source[key]);
  }

  for (final key in const [
    'accounts',
    'wallets',
    'walletAccounts',
    'wallet_accounts',
    'balances',
    'vaults',
    'platformVaults',
    'platform_vaults',
  ]) {
    addFrom(source[key]);
  }

  for (final value in values) {
    final currency = value?.toString().trim().toUpperCase() ?? '';
    if (currency.isNotEmpty) return currency;
  }
  return '';
}

class SessionModel {
  final String accessToken;
  final UserModel user;

  SessionModel({required this.accessToken, required this.user});

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      accessToken: json['access_token'] as String? ?? '',
      user: UserModel.fromJson((json['user'] as Map?) ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    if ((user.rawData['currency']?.toString().trim().isNotEmpty ?? false))
      'currency': user.rawData['currency'],
    if ((user.rawData['currency_code']?.toString().trim().isNotEmpty ?? false))
      'currency_code': user.rawData['currency_code'],
    if ((user.rawData['preferred_currency']?.toString().trim().isNotEmpty ??
        false))
      'preferred_currency': user.rawData['preferred_currency'],
    'user': user.toJson(),
  };
}
