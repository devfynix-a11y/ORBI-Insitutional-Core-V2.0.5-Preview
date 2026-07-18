import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/state/app_runtime_cache.dart';

class WalletService {
  static const Duration _requestTimeout = Duration(seconds: 15);
  final Dio _dio = ApiClient().client;

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get(AppConfig.endpoints['profile']!);
    return response.data['data'];
  }

  Future<List<Map<String, dynamic>>> getWallets({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = AppRuntimeCache.freshWallets;
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final walletPaths = <String>[
      '${AppConfig.baseUrl}/api/v1${AppConfig.endpoints['wallets'] ?? '/wallets'}',
      '${AppConfig.baseUrl}/v1${AppConfig.endpoints['wallets'] ?? '/wallets'}',
    ];
    for (final path in walletPaths) {
      try {
        final response = await _dio.getUri(Uri.parse(path));
        final apiWallets = _extractWalletsFromPayload(
          response.data,
          includeEscrow: false,
        );
        if (apiWallets.isNotEmpty) {
          AppRuntimeCache.rememberWallets(apiWallets);
          return apiWallets;
        }
      } on DioException {
        // Try next fallback endpoint.
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getLinkedWallets() async {
    return _fetchWalletCollection(
      endpoint: AppConfig.endpoints['walletsLinked'] ?? '/wallets/linked',
      includeEscrow: false,
    );
  }

  Future<List<Map<String, dynamic>>> getSovereignWallets({
    bool includeEscrow = true,
  }) async {
    return _fetchWalletCollection(
      endpoint: AppConfig.endpoints['walletsSovereign'] ?? '/wallets/sovereign',
      includeEscrow: includeEscrow,
    );
  }

  Future<Map<String, dynamic>> createWallet(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      AppConfig.endpoints['wallets'] ?? '/wallets',
      data: payload,
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> lockWallet(
    String walletId, {
    String? pin,
    String? reason,
  }) async {
    final response = await _dio.post(
      '/wallets/$walletId/lock',
      data: _compactMap({'pin': pin, 'reason': reason}),
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> unlockWallet(
    String walletId, {
    String? pin,
  }) async {
    final response = await _dio.post(
      '/wallets/$walletId/unlock',
      data: _compactMap({'pin': pin}),
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<void> deleteWallet(String walletId) async {
    await _dio.delete('/wallets/$walletId');
  }

  Future<Map<String, dynamic>> lockTransaction(
    String transactionId, {
    required String reason,
  }) async {
    final response = await _dio.post(
      '/transactions/$transactionId/lock',
      data: _compactMap({'reason': reason}),
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<List<Map<String, dynamic>>> _fetchWalletCollection({
    required String endpoint,
    required bool includeEscrow,
  }) async {
    final response = await _dio.get(endpoint);
    return _extractWalletsFromPayload(
      response.data,
      includeEscrow: includeEscrow,
    );
  }

  List<Map<String, dynamic>> _extractWalletsFromPayload(
    dynamic raw, {
    bool includeEscrow = true,
  }) {
    dynamic data;
    if (raw is Map<String, dynamic>) {
      data = raw['data'] ?? raw;
    } else {
      data = raw;
    }

    final wallets = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void appendFromList(dynamic source) {
      if (source is! List) return;
      for (final item in source.whereType<Map>()) {
        final normalized = _normalizeWalletMap(Map<String, dynamic>.from(item));
        if (!includeEscrow && _isEscrowWallet(normalized)) continue;
        final id = (normalized['canonical_wallet_id'] ??
                normalized['wallet_uuid'] ??
                normalized['id'] ??
                normalized['wallet_id'] ??
                '')
            .toString()
            .trim();
        final dedupeKey = id.isEmpty
            ? '${normalized['name'] ?? normalized['wallet_name'] ?? normalized.hashCode}'
            : id;
        if (seenIds.add(dedupeKey)) {
          wallets.add(normalized);
        }
      }
    }

    if (data is List) {
      appendFromList(data);
      return wallets;
    }

    if (data is Map) {
      appendFromList(data['wallets']);
      appendFromList(data['items']);
      appendFromList(data['results']);
      appendFromList(data['rows']);
      appendFromList(data['sovereignWallets']);
      appendFromList(data['sovereign_wallets']);
      appendFromList(data['platformVaults']);
      appendFromList(data['platform_vaults']);
      appendFromList(data['vaults']);
      appendFromList(data['linkedWallets']);
      appendFromList(data['linked_wallets']);
      appendFromList(data['internalWallets']);
      appendFromList(data['internal_wallets']);
      appendFromList(data['externalWallets']);
      appendFromList(data['external_wallets']);
      appendFromList(data['accounts']);
      appendFromList(data['walletAccounts']);
      appendFromList(data['wallet_accounts']);
      if (wallets.isNotEmpty) return wallets;
    }

    return wallets;
  }

  Map<String, dynamic> _normalizeWalletMap(Map<String, dynamic> wallet) {
    final normalized = Map<String, dynamic>.from(wallet);
    final metadata = normalized['metadata'];
    final metadataMap = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};

    final canonicalWalletId = _canonicalWalletId(normalized, metadataMap);
    if (canonicalWalletId.isNotEmpty) {
      normalized['canonical_wallet_id'] = canonicalWalletId;
      normalized['wallet_uuid'] = canonicalWalletId;
      normalized['walletUuid'] = canonicalWalletId;
      normalized['id'] = canonicalWalletId;
      if (!_isUuid(normalized['wallet_id'])) {
        normalized['wallet_id'] = canonicalWalletId;
      }
      if (!_isUuid(normalized['walletId'])) {
        normalized['walletId'] = canonicalWalletId;
      }
    } else {
      normalized['wallet_id'] ??= normalized['id'];
    }
    normalized['wallet_type'] ??=
        normalized['type'] ??
        normalized['vault_role'] ??
        normalized['management_tier'];
    normalized['type'] ??= normalized['wallet_type'];
    normalized['management_tier'] ??= normalized['vault_role'] != null
        ? 'sovereign'
        : normalized['management_tier'];
    normalized['available_balance'] ??=
        normalized['availableBalance'] ??
        normalized['balance'] ??
        normalized['ledger_balance'];
    normalized['ledger_balance'] ??=
        normalized['balance'] ?? normalized['available_balance'];
    normalized['wallet_name'] ??= normalized['name'];
    normalized['currency'] ??=
        normalized['currency_code'] ??
        normalized['currencyCode'] ??
        normalized['asset_currency'] ??
        normalized['assetCurrency'] ??
        metadataMap['currency'] ??
        metadataMap['currency_code'] ??
        metadataMap['currencyCode'] ??
        metadataMap['asset_currency'];
    normalized['currency_code'] ??= normalized['currency'];

    normalized['accountNumber'] ??=
        normalized['account_number'] ??
        metadataMap['account_number'] ??
        metadataMap['linked_customer_id'];

    if (metadataMap.isNotEmpty) {
      normalized['metadata'] = metadataMap;
    }
    return normalized;
  }

  String _canonicalWalletId(
    Map<String, dynamic> wallet,
    Map<String, dynamic> metadata,
  ) {
    for (final value in [
      wallet['canonical_wallet_id'],
      wallet['wallet_uuid'],
      wallet['walletUuid'],
      wallet['id'],
      wallet['wallet_id'],
      wallet['walletId'],
      wallet['source_wallet_id'],
      wallet['sourceWalletId'],
      wallet['operating_wallet_id'],
      wallet['operatingWalletId'],
      metadata['canonical_wallet_id'],
      metadata['wallet_uuid'],
      metadata['walletUuid'],
      metadata['id'],
      metadata['wallet_id'],
      metadata['walletId'],
      metadata['source_wallet_id'],
      metadata['sourceWalletId'],
      metadata['operating_wallet_id'],
      metadata['operatingWalletId'],
    ]) {
      final raw = value is String ? value.trim() : '';
      if (_isUuid(raw)) return raw;
    }
    return '';
  }

  bool _isUuid(dynamic value) {
    final raw = value is String ? value.trim() : '';
    if (raw.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(raw);
  }

  Map<String, dynamic> _walletMetadata(Map<String, dynamic> wallet) {
    final data = wallet['metadata'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  String _walletAccountNumber(Map<String, dynamic> wallet) {
    final metadata = _walletMetadata(wallet);
    return (wallet['accountNumber'] ??
            wallet['account_number'] ??
            metadata['account_number'] ??
            metadata['linked_customer_id'] ??
            '')
        .toString();
  }

  bool _isEscrowWallet(Map<String, dynamic> wallet) {
    final name = (wallet['name'] ?? wallet['wallet_name'] ?? '')
        .toString()
        .toLowerCase();
    final type = (wallet['wallet_type'] ?? wallet['type'] ?? '')
        .toString()
        .toLowerCase();
    final role = (wallet['vault_role'] ?? wallet['role'] ?? '')
        .toString()
        .toLowerCase();
    final metadata = _walletMetadata(wallet);
    final accountNumber = _walletAccountNumber(wallet).toUpperCase();
    final isEscrowMeta = metadata['is_secure_escrow'] == true;
    return role.contains('internal_transfer') ||
        type.contains('internal_transfer') ||
        name.contains('paysafe') ||
        isEscrowMeta ||
        accountNumber.startsWith('ESC-');
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(
    String walletId, {
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final trimmedWalletId = walletId.trim();
    final hasWalletId = trimmedWalletId.isNotEmpty && trimmedWalletId != '--';
    if (!forceRefresh && !hasWalletId && offset == 0) {
      final cached = AppRuntimeCache.freshRecentTransactions;
      if (cached != null && cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
    }
    final baseUris = <Uri>[
      Uri.parse('${AppConfig.baseUrl}/api/v1/transactions'),
      Uri.parse('${AppConfig.baseUrl}/v1/transactions'),
    ];

    final attempts = <Uri>[];
    for (final base in baseUris) {
      final baseParams = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (hasWalletId) {
        attempts.add(
          base.replace(
            queryParameters: {...baseParams, 'wallet_id': trimmedWalletId},
          ),
        );
        attempts.add(
          base.replace(
            queryParameters: {...baseParams, 'walletId': trimmedWalletId},
          ),
        );
        attempts.add(
          base.replace(
            queryParameters: {
              ...baseParams,
              'source_wallet_id': trimmedWalletId,
            },
          ),
        );
      }
      // Some deployments reject unknown wallet filters or use account-scoped tx listing.
      attempts.add(base.replace(queryParameters: baseParams));
    }

    DioException? lastException;
    for (var i = 0; i < attempts.length; i++) {
      final uri = attempts[i];
      _traceTxFetch('attempt=${i + 1}/${attempts.length} | GET $uri');
      try {
        final response = await _dio.getUri(uri).timeout(_requestTimeout);
        final txs = _extractTransactionsFromPayload(response.data);
        _traceTxFetch(
          'status=${response.statusCode} | parsed_count=${txs.length}',
        );
        if (txs.isNotEmpty) {
          if (!hasWalletId && offset == 0) {
            AppRuntimeCache.rememberRecentTransactions(txs);
          }
          return txs;
        }
      } on TimeoutException catch (_) {
        _traceTxFetch('timeout | GET $uri');
        throw DioException(
          requestOptions: RequestOptions(path: uri.toString()),
          type: DioExceptionType.connectionTimeout,
          error: 'Transaction request timed out. Please try again.',
          message: 'Transaction request timed out. Please try again.',
        );
      } on DioException catch (e) {
        lastException = e;
        _traceTxFetch(
          'failed_status=${e.response?.statusCode} | type=${e.type.name} | '
          'message=${e.message} | body=${_short(e.response?.data)}',
        );
      }
    }

    if (lastException != null) {
      final status = lastException.response?.statusCode ?? 0;
      // Ignore common "no rows/unsupported filter" statuses and return empty list.
      if (status != 400 && status != 404) {
        throw lastException;
      }
    }
    _traceTxFetch(
      'completed_with_empty_result | wallet_id=${hasWalletId ? trimmedWalletId : 'none'} '
      '| limit=$limit | offset=$offset',
    );
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _extractTransactionsFromPayload(dynamic raw) {
    dynamic data;
    if (raw is Map<String, dynamic>) {
      data = raw['data'] ?? raw;
    } else {
      data = raw;
    }

    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (data is Map) {
      final items =
          data['transactions'] ??
          data['items'] ??
          data['results'] ??
          data['rows'] ??
          data['history'];
      if (items is List) {
        return items.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _compactMap(Map<String, dynamic> values) {
    final result = <String, dynamic>{};
    values.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }
}

void _traceTxFetch(String message) {
  if (kDebugMode) {
    debugPrint('🧾 TX_FETCH | $message');
  }
}

String _short(dynamic data) {
  final text = data?.toString() ?? '';
  if (text.length <= 260) return text;
  return '${text.substring(0, 260)}...';
}
