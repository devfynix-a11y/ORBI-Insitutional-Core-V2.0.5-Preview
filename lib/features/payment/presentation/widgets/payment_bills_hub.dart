import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/widgets/orbi_responsive.dart';
import 'payment_shared_widgets.dart';

class PaymentBillsHubCategory {
  const PaymentBillsHubCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String subtitle;
}

class PaymentBillsHub extends StatelessWidget {
  const PaymentBillsHub({
    super.key,
    required this.ui,
    required this.l10n,
    required this.isSwahili,
    required this.isLoading,
    required this.categories,
    required this.selectedIndex,
    required this.onCategoryTap,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final bool isSwahili;
  final bool isLoading;
  final List<PaymentBillsHubCategory> categories;
  final int selectedIndex;
  final Future<void> Function(int index) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return OrbiResponsiveContent(
      maxWidth: 860,
      padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final categoryColumns = (constraints.maxWidth / 116).floor().clamp(3, 4);
          const spacing = 12.0;
          final categoryWidth = ((constraints.maxWidth - (spacing * (categoryColumns - 1))) /
                  categoryColumns)
              .clamp(0, 148)
              .toDouble();

          return ListView(
            children: [
              Text(
                l10n.paymentBillsTitle,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSwahili ? 'Chagua aina ya bili.' : 'Choose a bill type.',
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(color: ui.accent),
                  ),
                )
              else
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List.generate(categories.length, (index) {
                    final item = categories[index];
                    return SizedBox(
                      width: categoryWidth,
                      child: PaymentBillCategoryTile(
                        ui: ui,
                        label: item.label,
                        icon: item.icon,
                        color: item.color,
                        selected: index == selectedIndex,
                        subtitle: item.subtitle,
                        onTap: () {
                          onCategoryTap(index);
                        },
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: ui.cardMuted.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: ui.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSwahili ? 'Chagua aina ya bili.' : 'Choose a bill type.',
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
