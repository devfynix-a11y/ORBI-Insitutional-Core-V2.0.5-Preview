import '../../services/data/service_actor_service.dart';
import 'models/bill_provider_catalog.dart';

class PaymentBillCatalogRepository {
  PaymentBillCatalogRepository({ServiceActorService? service})
    : _service = service ?? ServiceActorService();

  final ServiceActorService _service;

  Future<List<BillProviderCategory>> fetchBillCategories() async {
    final records = await _service.listBillPaymentProviders();
    final categories = _normalizeCategories(records)
        .map(BillProviderCategory.fromJson)
        .where((item) => item.key.trim().isNotEmpty && item.providers.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return categories;
  }

  List<Map<String, dynamic>> _normalizeCategories(
    List<Map<String, dynamic>> records,
  ) {
    if (records.isEmpty) return const <Map<String, dynamic>>[];

    final alreadyGrouped = records.where(_looksLikeCategoryRecord).toList();
    if (alreadyGrouped.isNotEmpty) return alreadyGrouped;

    final grouped = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final categoryKey = _readCategoryKey(record);
      if (categoryKey == null) continue;
      final normalizedKey = categoryKey.trim();
      final category = grouped.putIfAbsent(
        normalizedKey,
        () => <String, dynamic>{
          'key': normalizedKey,
          'label': _readCategoryLabel(record) ?? normalizedKey,
          'providers': <Map<String, dynamic>>[],
        },
      );
      final providers = (category['providers'] as List<Map<String, dynamic>>);
      providers.add(_toProviderEntry(record));
    }

    return grouped.values.toList(growable: false);
  }

  bool _looksLikeCategoryRecord(Map<String, dynamic> record) {
    return record['providers'] is List &&
        ((record['key'] ?? record['id'] ?? record['category']) != null);
  }

  String? _readCategoryKey(Map<String, dynamic> record) {
    final candidates = [
      record['category_key'],
      record['categoryKey'],
      record['bill_category_key'],
      record['billCategoryKey'],
      record['category'],
      record['bill_category'],
      record['billCategory'],
      record['group'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _readCategoryLabel(Map<String, dynamic> record) {
    final candidates = [
      record['category_label'],
      record['categoryLabel'],
      record['bill_category_label'],
      record['billCategoryLabel'],
      record['group_label'],
      record['groupLabel'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Map<String, dynamic> _toProviderEntry(Map<String, dynamic> record) {
    final metadata = record['metadata'];
    return <String, dynamic>{
      'label':
          (record['label'] ??
                  record['name'] ??
                  record['display_name'] ??
                  record['displayName'] ??
                  record['provider'] ??
                  record['brand_name'] ??
                  record['brandName'] ??
                  '')
              .toString(),
      if (record['provider_code'] != null) 'provider_code': record['provider_code'],
      if (record['providerCode'] != null) 'providerCode': record['providerCode'],
      if (record['display_icon'] != null) 'display_icon': record['display_icon'],
      if (record['displayIcon'] != null) 'displayIcon': record['displayIcon'],
      if (record['provider_icon'] != null) 'provider_icon': record['provider_icon'],
      if (record['providerIcon'] != null) 'providerIcon': record['providerIcon'],
      if (record['icon'] != null) 'icon': record['icon'],
      if (record['color'] != null) 'color': record['color'],
      if (record['provider_color'] != null) 'provider_color': record['provider_color'],
      if (record['providerColor'] != null) 'providerColor': record['providerColor'],
      if (record['logo_url'] != null) 'logo_url': record['logo_url'],
      if (record['logoUrl'] != null) 'logoUrl': record['logoUrl'],
      if (record['asset_url'] != null) 'asset_url': record['asset_url'],
      if (record['assetUrl'] != null) 'assetUrl': record['assetUrl'],
      if (metadata is Map) 'metadata': Map<String, dynamic>.from(metadata),
    };
  }
}
