import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'merchant_service.dart';

class PaymentMerchantDirectoryEntry {
  const PaymentMerchantDirectoryEntry({
    required this.reference,
    required this.displayName,
    this.aliases = const <String>[],
  });

  final String reference;
  final String displayName;
  final List<String> aliases;
}

class PaymentRoutingCatalog {
  const PaymentRoutingCatalog({
    this.merchantDirectory = const <PaymentMerchantDirectoryEntry>[],
    this.providerAliases = const <String, int>{},
  });

  final List<PaymentMerchantDirectoryEntry> merchantDirectory;
  final Map<String, int> providerAliases;

  bool get isEmpty => merchantDirectory.isEmpty && providerAliases.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'merchantDirectory': merchantDirectory
          .map(
            (entry) => {
              'reference': entry.reference,
              'displayName': entry.displayName,
              'aliases': entry.aliases,
            },
          )
          .toList(),
      'providerAliases': providerAliases,
    };
  }

  static PaymentRoutingCatalog fromJson(Map<String, dynamic> json) {
    final merchantDirectoryRaw = json['merchantDirectory'];
    final providerAliasesRaw = json['providerAliases'];
    return PaymentRoutingCatalog(
      merchantDirectory: merchantDirectoryRaw is List
          ? merchantDirectoryRaw
                .whereType<Map>()
                .map(
                  (item) => PaymentMerchantDirectoryEntry(
                    reference: (item['reference'] ?? '').toString(),
                    displayName: (item['displayName'] ?? '').toString(),
                    aliases: ((item['aliases'] as List?) ?? const <dynamic>[])
                        .map((alias) => alias.toString())
                        .where((alias) => alias.trim().isNotEmpty)
                        .toList(),
                  ),
                )
                .where((entry) => entry.reference.trim().isNotEmpty)
                .toList()
          : const <PaymentMerchantDirectoryEntry>[],
      providerAliases: providerAliasesRaw is Map
          ? providerAliasesRaw.map(
              (key, value) => MapEntry(
                key.toString().trim().toLowerCase(),
                int.tryParse(value.toString()) ?? 0,
              ),
            )
          : const <String, int>{},
    );
  }
}

class PaymentRoutingCatalogService {
  PaymentRoutingCatalogService([MerchantService? merchantService])
    : _merchantService = merchantService ?? MerchantService();

  static const String _cacheKey = 'payment_routing_catalog_v1';
  static const String _cacheTimestampKey = 'payment_routing_catalog_v1_ts';
  static const Duration _cacheTtl = Duration(hours: 6);
  static PaymentRoutingCatalog? _memoryCache;
  static DateTime? _memoryCacheAt;

  final MerchantService _merchantService;

  Future<PaymentRoutingCatalog> load() async {
    final memory = _readMemoryCache();
    if (memory != null && !memory.isEmpty) {
      _refreshInBackgroundIfStale();
      return memory;
    }

    final disk = await _readDiskCache();
    if (disk != null && !disk.isEmpty) {
      _writeMemoryCache(disk);
      _refreshInBackgroundIfStale();
      return disk;
    }

    final fresh = await _fetchFresh();
    if (!fresh.isEmpty) {
      await _writeDiskCache(fresh);
      _writeMemoryCache(fresh);
      return fresh;
    }

    return const PaymentRoutingCatalog();
  }

  Future<void> refreshInBackground() async {
    final fresh = await _fetchFresh();
    if (fresh.isEmpty) return;
    _writeMemoryCache(fresh);
    await _writeDiskCache(fresh);
  }

  Future<PaymentRoutingCatalog> _fetchFresh() async {
    try {
      final merchants = await _merchantService.listMerchants(
        queryParameters: const {'limit': 100},
      );
      final categories = await _merchantService.listMerchantCategories();
      return PaymentRoutingCatalog(
        merchantDirectory: _buildMerchantDirectory(merchants),
        providerAliases: _buildProviderAliases(categories),
      );
    } catch (_) {
      return const PaymentRoutingCatalog();
    }
  }

  PaymentRoutingCatalog? _readMemoryCache() {
    final cache = _memoryCache;
    final cacheAt = _memoryCacheAt;
    if (cache == null || cacheAt == null) return null;
    if (DateTime.now().difference(cacheAt) > _cacheTtl) return cache;
    return cache;
  }

  void _writeMemoryCache(PaymentRoutingCatalog catalog) {
    _memoryCache = catalog;
    _memoryCacheAt = DateTime.now();
  }

  Future<PaymentRoutingCatalog?> _readDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey)?.trim();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PaymentRoutingCatalog.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(PaymentRoutingCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(catalog.toJson()));
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  Future<void> _refreshInBackgroundIfStale() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTs = prefs.getString(_cacheTimestampKey)?.trim();
    if (rawTs == null || rawTs.isEmpty) {
      unawaited(refreshInBackground());
      return;
    }
    final ts = DateTime.tryParse(rawTs);
    if (ts == null || DateTime.now().difference(ts) > _cacheTtl) {
      unawaited(refreshInBackground());
    }
  }

  List<PaymentMerchantDirectoryEntry> _buildMerchantDirectory(
    List<Map<String, dynamic>> merchants,
  ) {
    final entries = <PaymentMerchantDirectoryEntry>[];
    for (final merchant in merchants) {
      final reference = _firstNonEmpty([
        merchant['pay_number']?.toString(),
        merchant['merchant_id']?.toString(),
        merchant['merchantId']?.toString(),
        merchant['id']?.toString(),
        merchant['reference']?.toString(),
      ]);
      if (reference == null) continue;
      final displayName =
          _firstNonEmpty([
            merchant['merchant_name']?.toString(),
            merchant['merchantName']?.toString(),
            merchant['name']?.toString(),
            merchant['label']?.toString(),
          ]) ??
          reference;
      final aliases = <String>{
        reference,
        displayName,
        _firstNonEmpty([
          merchant['short_name']?.toString(),
          merchant['shortName']?.toString(),
          merchant['code']?.toString(),
        ]) ??
            '',
      }.where((value) => value.trim().isNotEmpty).toList();
      entries.add(
        PaymentMerchantDirectoryEntry(
          reference: reference,
          displayName: displayName,
          aliases: aliases,
        ),
      );
    }
    return entries;
  }

  Map<String, int> _buildProviderAliases(List<Map<String, dynamic>> categories) {
    const indexByKeyword = <String, int>{
      'electric': 0,
      'power': 0,
      'school': 1,
      'education': 1,
      'water': 2,
      'gas': 3,
      'bundle': 4,
      'airtime': 4,
      'entertainment': 5,
      'tv': 5,
    };
    final aliases = <String, int>{};
    for (final category in categories) {
      final values = [
        category['name']?.toString(),
        category['label']?.toString(),
        category['code']?.toString(),
        category['description']?.toString(),
      ];
      for (final value in values) {
        final normalized = value?.trim().toLowerCase();
        if (normalized == null || normalized.isEmpty) continue;
        for (final entry in indexByKeyword.entries) {
          if (normalized.contains(entry.key)) {
            aliases[normalized] = entry.value;
          }
        }
      }
    }
    return aliases;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
