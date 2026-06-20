class BillProviderEntry {
  const BillProviderEntry({
    required this.label,
    this.providerCode,
    this.displayIcon,
    this.color,
    this.logoUrl,
    this.metadata = const <String, dynamic>{},
  });

  final String label;
  final String? providerCode;
  final String? displayIcon;
  final String? color;
  final String? logoUrl;
  final Map<String, dynamic> metadata;

  factory BillProviderEntry.fromJson(dynamic raw) {
    if (raw is String) {
      final label = raw.trim();
      return BillProviderEntry(label: label);
    }

    if (raw is Map) {
      final normalized = Map<String, dynamic>.from(raw);
      final metadataRaw = normalized['metadata'];
      final metadata = metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : const <String, dynamic>{};
      return BillProviderEntry(
        label:
            (normalized['label'] ??
                    normalized['name'] ??
                    normalized['display_name'] ??
                    normalized['displayName'] ??
                    normalized['provider'] ??
                    '')
                .toString()
                .trim(),
        providerCode: _readNullableString(
          normalized['provider_code'] ??
              normalized['providerCode'] ??
              normalized['code'] ??
              metadata['provider_code'] ??
              metadata['providerCode'],
        ),
        displayIcon: _readNullableString(
          normalized['display_icon'] ??
              normalized['displayIcon'] ??
              normalized['provider_icon'] ??
              normalized['providerIcon'] ??
              normalized['icon'] ??
              metadata['display_icon'] ??
              metadata['displayIcon'] ??
              metadata['provider_icon'] ??
              metadata['providerIcon'] ??
              metadata['icon'],
        ),
        color: _readNullableString(
          normalized['color'] ??
              normalized['provider_color'] ??
              normalized['providerColor'] ??
              metadata['color'] ??
              metadata['provider_color'] ??
              metadata['providerColor'],
        ),
        logoUrl: _readNullableString(
          normalized['logo_url'] ??
              normalized['logoUrl'] ??
              normalized['asset_url'] ??
              normalized['assetUrl'] ??
              metadata['logo_url'] ??
              metadata['logoUrl'] ??
              metadata['asset_url'] ??
              metadata['assetUrl'],
        ),
        metadata: metadata,
      );
    }

    return BillProviderEntry(label: raw?.toString().trim() ?? '');
  }
}

class BillProviderCategory {
  const BillProviderCategory({
    required this.key,
    required this.label,
    required this.providers,
  });

  final String key;
  final String label;
  final List<BillProviderEntry> providers;

  factory BillProviderCategory.fromJson(Map<String, dynamic> json) {
    return BillProviderCategory(
      key: (json['key'] ?? json['id'] ?? json['category'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? json['key'] ?? '').toString(),
      providers: _readProviders(json['providers']),
    );
  }

  static List<BillProviderEntry> _readProviders(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(BillProviderEntry.fromJson)
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
  }
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
