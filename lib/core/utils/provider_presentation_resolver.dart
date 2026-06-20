import 'package:flutter/material.dart';

import '../../features/payment/data/gateway_payment_models.dart';
import 'provider_asset_resolver.dart';

class ProviderPresentationSpec {
  const ProviderPresentationSpec({
    required this.color,
    required this.icon,
    this.assetCandidates = const [],
    this.logoUrl,
  });

  final Color color;
  final IconData icon;
  final List<String> assetCandidates;
  final String? logoUrl;
}

class ProviderPresentationResolver {
  const ProviderPresentationResolver._();

  static ProviderPresentationSpec resolveBillProvider({
    required String providerName,
    String? providerCode,
    String? colorHint,
    String? iconHint,
    String? logoUrlHint,
    required String categoryKey,
    required Color categoryColor,
    required IconData categoryIcon,
    required List<String> assetCandidates,
  }) {
    final identityKeys = <String>[
      ProviderAssetResolver.normalizeProviderName(providerCode ?? ''),
      ProviderAssetResolver.normalizeProviderName(providerName),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    final category = ProviderAssetResolver.normalizeProviderName(categoryKey);
    final hintedColor = _parseColor(colorHint);
    final brandColor = _firstBrandColor(identityKeys);
    final brandIcon = _firstBillIcon(identityKeys, category);

    return ProviderPresentationSpec(
      color:
          brandColor ??
          hintedColor ??
          _billCategoryColor(category) ??
          categoryColor,
      icon:
          brandIcon ??
          _iconFromHint(iconHint) ??
          categoryIcon,
      assetCandidates: assetCandidates,
      logoUrl: _cleanUrl(logoUrlHint),
    );
  }

  static Color resolveGatewayColor(
    GatewayProvider provider,
    Color fallback,
  ) {
    final normalized = ProviderAssetResolver.normalizeProviderName(
      provider.brandLabel,
    );
    return _brandColor(normalized) ?? provider.colorValue ?? fallback;
  }

  static IconData resolveGatewayIcon(
    GatewayProvider provider, {
    IconData fallback = Icons.hub_rounded,
  }) {
    final normalized = ProviderAssetResolver.normalizeProviderName(
      provider.brandLabel,
    );
    return _gatewayIconFromIdentity(
          normalized: normalized,
          iconKey: provider.icon,
          groupLabel: provider.groupLabel,
          type: provider.type,
          channels: provider.channels,
        ) ??
        fallback;
  }

  static Color? _firstBrandColor(Iterable<String> normalizedKeys) {
    for (final key in normalizedKeys) {
      final color = _brandColor(key);
      if (color != null) return color;
    }
    return null;
  }

  static IconData? _firstBillIcon(
    Iterable<String> normalizedKeys,
    String normalizedCategory,
  ) {
    for (final key in normalizedKeys) {
      final icon = _billIcon(key, normalizedCategory);
      if (icon != null) return icon;
    }
    return null;
  }

  static Color? _brandColor(String normalized) {
    switch (normalized) {
      case 'mix_by_yas':
        return const Color(0xFF1976D2);
      case 'halotel':
        return const Color(0xFFF28C28);
      case 'airtel':
        return const Color(0xFFFF7043);
      case 'vodacom':
        return const Color(0xFFE53935);
      case 'crdb_bank':
        return const Color(0xFF2E7D32);
      case 'nmb_bank':
        return const Color(0xFF00897B);
      case 'nbc':
        return const Color(0xFF1565C0);
      case 'absa_bank':
        return const Color(0xFFC62828);
      case 'equity_bank':
        return const Color(0xFF8E24AA);
      case 'diamond_trust_bank':
        return const Color(0xFF3949AB);
      case 'tanesco':
        return const Color(0xFFE29A2D);
      case 'dawasa':
      case 'ruwasa':
      case 'dawasco':
        return const Color(0xFF3E8ED0);
      case 'oryx_gas':
        return const Color(0xFFE26A3C);
      case 'ttcl':
      case 'ttcl_voice':
      case 'zuku':
      case 'simbanet':
      case 'liquid_telecom':
        return const Color(0xFF476FD6);
      case 'dstv':
      case 'azam_tv':
      case 'startimes':
      case 'netflix':
        return const Color(0xFFC7507A);
      case 'nhif':
      case 'jubilee':
      case 'nic':
      case 'alliance_life':
        return const Color(0xFF16806D);
      case 'tra':
      case 'egovernment':
      case 'nida':
      case 'local_government':
        return const Color(0xFF2F6F9F);
      case 'ada_ya_shule':
      case 'ada_ya_chuo':
      case 'hosteli':
        return const Color(0xFF2E8B79);
      default:
        return null;
    }
  }

  static Color? _billCategoryColor(String normalizedCategory) {
    switch (normalizedCategory) {
      case 'electricity':
        return const Color(0xFFE29A2D);
      case 'water_bills':
        return const Color(0xFF3E8ED0);
      case 'gas':
        return const Color(0xFFE26A3C);
      case 'bundles':
        return const Color(0xFF6D5CE7);
      case 'internet':
        return const Color(0xFF476FD6);
      case 'school_fees':
        return const Color(0xFF2E8B79);
      case 'government_bills':
        return const Color(0xFF2F6F9F);
      case 'insurance':
        return const Color(0xFF16806D);
      case 'telephone':
        return const Color(0xFF8A5A44);
      case 'entertainment':
        return const Color(0xFFC7507A);
      case 'other_bills':
        return const Color(0xFF7B8694);
      default:
        return null;
    }
  }

  static Color? _parseColor(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    var hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String? _cleanUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return null;
  }

  static IconData? _iconFromHint(String? rawHint) {
    final hint = ProviderAssetResolver.normalizeProviderName(rawHint ?? '');
    if (hint.isEmpty) return null;
    if (hint.contains('water')) return Icons.water_drop_rounded;
    if (hint.contains('bolt') || hint.contains('electric')) {
      return Icons.electric_bolt_rounded;
    }
    if (hint.contains('fire') || hint.contains('gas')) {
      return Icons.local_fire_department_rounded;
    }
    if (hint.contains('school')) return Icons.school_rounded;
    if (hint.contains('shield') || hint.contains('insurance')) {
      return Icons.shield_outlined;
    }
    if (hint.contains('router') || hint.contains('internet')) {
      return Icons.router_rounded;
    }
    if (hint.contains('tv') || hint.contains('entertainment')) {
      return Icons.live_tv_rounded;
    }
    if (hint.contains('bank')) return Icons.account_balance_rounded;
    if (hint.contains('wallet')) return Icons.account_balance_wallet_rounded;
    if (hint.contains('phone') || hint.contains('mobile') || hint.contains('sim')) {
      return Icons.phone_android_rounded;
    }
    if (hint.contains('call')) return Icons.call_rounded;
    return null;
  }

  static IconData? _billIcon(String normalizedProvider, String normalizedCategory) {
    switch (normalizedProvider) {
      case 'tanesco':
        return Icons.electric_bolt_rounded;
      case 'dawasa':
      case 'ruwasa':
      case 'dawasco':
        return Icons.water_drop_rounded;
      case 'oryx_gas':
        return Icons.local_fire_department_rounded;
      case 'vodacom':
      case 'airtel':
      case 'mix_by_yas':
      case 'halotel':
        return Icons.sim_card_rounded;
      case 'ttcl':
      case 'ttcl_voice':
      case 'zuku':
      case 'simbanet':
      case 'liquid_telecom':
        return Icons.router_rounded;
      case 'dstv':
      case 'azam_tv':
      case 'startimes':
      case 'netflix':
        return Icons.live_tv_rounded;
      case 'ada_ya_shule':
      case 'ada_ya_chuo':
      case 'hosteli':
        return Icons.school_rounded;
      case 'tra':
      case 'egovernment':
      case 'nida':
      case 'local_government':
        return Icons.account_balance_rounded;
      case 'nhif':
      case 'jubilee':
      case 'nic':
      case 'alliance_life':
        return Icons.shield_outlined;
    }

    switch (normalizedCategory) {
      case 'electricity':
        return Icons.electric_bolt_rounded;
      case 'water_bills':
        return Icons.water_drop_rounded;
      case 'gas':
        return Icons.local_fire_department_rounded;
      case 'bundles':
        return Icons.sim_card_rounded;
      case 'internet':
        return Icons.router_rounded;
      case 'school_fees':
        return Icons.school_rounded;
      case 'government_bills':
        return Icons.account_balance_rounded;
      case 'insurance':
        return Icons.shield_outlined;
      case 'telephone':
        return Icons.call_rounded;
      case 'entertainment':
        return Icons.live_tv_rounded;
      default:
        return null;
    }
  }

  static IconData? _gatewayIconFromIdentity({
    required String normalized,
    required String? iconKey,
    required String groupLabel,
    required String type,
    required Iterable<String> channels,
  }) {
    switch (normalized) {
      case 'vodacom':
      case 'airtel':
      case 'mix_by_yas':
      case 'halotel':
        return Icons.phone_android_rounded;
      case 'crdb_bank':
      case 'nmb_bank':
      case 'nbc':
      case 'absa_bank':
      case 'equity_bank':
      case 'diamond_trust_bank':
        return Icons.account_balance_rounded;
    }

    final iconHint = ProviderAssetResolver.normalizeProviderName(iconKey ?? '');
    if (iconHint.contains('bank')) return Icons.account_balance_rounded;
    if (iconHint.contains('card')) return Icons.credit_card_rounded;
    if (iconHint.contains('crypto')) return Icons.currency_bitcoin_rounded;
    if (iconHint.contains('wallet') || iconHint.contains('paypal')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (iconHint.contains('mobile') ||
        iconHint.contains('phone') ||
        iconHint.contains('sim') ||
        iconHint.contains('mpesa')) {
      return Icons.phone_android_rounded;
    }

    final descriptor = '$groupLabel $type ${channels.join(' ')} $normalized'
        .toLowerCase();
    if (descriptor.contains('mobile') || descriptor.contains('mpesa')) {
      return Icons.phone_android_rounded;
    }
    if (descriptor.contains('bank')) return Icons.account_balance_rounded;
    if (descriptor.contains('card')) return Icons.credit_card_rounded;
    if (descriptor.contains('crypto')) return Icons.currency_bitcoin_rounded;
    if (descriptor.contains('paypal') || descriptor.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    }
    return null;
  }
}
