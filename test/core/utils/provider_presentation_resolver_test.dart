import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_mobileapp/core/utils/provider_presentation_resolver.dart';
import 'package:orbi_mobileapp/features/payment/data/gateway_payment_models.dart';

void main() {
  group('ProviderPresentationResolver', () {
    test('uses curated bill provider preset before backend hints', () {
      final spec = ProviderPresentationResolver.resolveBillProvider(
        providerName: 'Vodacom M-Pesa',
        providerCode: 'MPESA_TZ',
        colorHint: '#123456',
        iconHint: 'bank',
        categoryKey: 'bundles',
        categoryColor: Colors.purple,
        categoryIcon: Icons.request_quote_rounded,
        assetCandidates: const ['assets/providers/Tanzania/Logos/mpesa.png'],
      );

      expect(spec.color, const Color(0xFFE53935));
      expect(spec.icon, Icons.sim_card_rounded);
      expect(spec.assetCandidates, isNotEmpty);
    });

    test('uses backend color and icon hints for unknown bill providers', () {
      final spec = ProviderPresentationResolver.resolveBillProvider(
        providerName: 'Future Utility',
        colorHint: '#123456',
        iconHint: 'water_drop',
        logoUrlHint: 'https://cdn.orbi.africa/future-utility.png',
        categoryKey: 'other-bills',
        categoryColor: Colors.grey,
        categoryIcon: Icons.request_quote_rounded,
        assetCandidates: const [],
      );

      expect(spec.color, const Color(0xFF123456));
      expect(spec.icon, Icons.water_drop_rounded);
      expect(spec.logoUrl, 'https://cdn.orbi.africa/future-utility.png');
    });

    test('ignores unsafe logo URLs', () {
      final spec = ProviderPresentationResolver.resolveBillProvider(
        providerName: 'Future Utility',
        logoUrlHint: 'javascript:alert(1)',
        categoryKey: 'other-bills',
        categoryColor: Colors.grey,
        categoryIcon: Icons.request_quote_rounded,
        assetCandidates: const [],
      );

      expect(spec.logoUrl, isNull);
    });

    test('uses curated gateway color over backend color', () {
      const provider = GatewayProvider(
        id: '1',
        name: 'CRDB Bank',
        brandName: 'CRDB Bank',
        type: 'bank',
        group: 'Bank',
        logicType: 'REGISTRY',
        status: 'ACTIVE',
        supportedCurrencies: ['TZS'],
        icon: 'bank',
        color: '#123456',
        checkoutMode: 'server_to_server',
        channels: ['bank_transfer'],
        sortOrder: 10,
        metadata: {},
      );

      expect(
        ProviderPresentationResolver.resolveGatewayColor(
          provider,
          Colors.teal,
        ),
        const Color(0xFF2E7D32),
      );
      expect(
        ProviderPresentationResolver.resolveGatewayIcon(provider),
        Icons.account_balance_rounded,
      );
    });
  });
}
