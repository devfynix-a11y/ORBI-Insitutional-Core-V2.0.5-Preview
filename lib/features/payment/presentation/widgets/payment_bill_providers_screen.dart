import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';
import 'payment_shared_widgets.dart';

class PaymentBillProviderOption {
  const PaymentBillProviderOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.assetCandidates,
    this.logoUrl,
  });

  final String label;
  final IconData icon;
  final Color color;
  final List<String> assetCandidates;
  final String? logoUrl;
}

class PaymentBillProvidersScreen extends StatefulWidget {
  const PaymentBillProvidersScreen({
    super.key,
    required this.categoryTitle,
    required this.providers,
    required this.initialSelectedIndex,
    required this.isSwahili,
  });

  final String categoryTitle;
  final List<PaymentBillProviderOption> providers;
  final int initialSelectedIndex;
  final bool isSwahili;

  @override
  State<PaymentBillProvidersScreen> createState() =>
      _PaymentBillProvidersScreenState();
}

class _PaymentBillProvidersScreenState extends State<PaymentBillProvidersScreen> {
  late int _selectedProviderIndex;

  @override
  void initState() {
    super.initState();
    _selectedProviderIndex = widget.initialSelectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final providerColumns = ((width - 32) / 108).floor().clamp(3, 4);
    const spacing = 12.0;
    final providerWidth =
        ((width - 32 - (spacing * (providerColumns - 1))) / providerColumns)
            .clamp(0, 140)
            .toDouble();
    final selectedProvider = widget.providers.isEmpty
        ? null
        : widget.providers[
            _selectedProviderIndex.clamp(0, widget.providers.length - 1)
          ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.paymentBillProvidersTitle,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isSwahili ? 'Chagua mtoa huduma.' : 'Choose provider.',
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: widget.providers.isEmpty
                    ? Center(
                        child: Text(
                          l10n.paymentBillProvidersEmpty,
                          style: TextStyle(color: ui.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: List.generate(widget.providers.length, (index) {
                            final provider = widget.providers[index];
                            return SizedBox(
                              width: providerWidth,
                              child: PaymentBillProviderTile(
                                ui: ui,
                                label: provider.label,
                                icon: provider.icon,
                                color: provider.color,
                                assetCandidates: provider.assetCandidates,
                                logoUrl: provider.logoUrl,
                                selected: index == _selectedProviderIndex,
                                onTap: () => setState(() {
                                  _selectedProviderIndex = index;
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
              ),
              if (selectedProvider != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selectedProviderIndex),
                  icon: Icon(selectedProvider.icon),
                  label: Text(l10n.goalsContinueAction),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: selectedProvider.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
