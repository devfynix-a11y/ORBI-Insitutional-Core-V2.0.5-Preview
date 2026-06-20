import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_card_styles.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/provider_logo_image.dart';

class PaymentBillCategoryTile extends StatelessWidget {
  const PaymentBillCategoryTile({
    super.key,
    required this.ui,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final OrbiUiTokens ui;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: OrbiCardStyles.elevatedCardDecoration(
          context,
          radius: 22,
          accent: color,
          branded: selected,
          elevated: selected,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 40 : 22,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.92)
                    : ui.border.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: OrbiCardStyles.iconBadgeDecoration(
                    context,
                    accent: color,
                    radius: 999,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: selected ? color : ui.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.2,
                height: 1.2,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? color.withValues(alpha: 0.92) : ui.textMuted,
                fontSize: 9.8,
                height: 1.15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentBillProviderTile extends StatelessWidget {
  const PaymentBillProviderTile({
    super.key,
    required this.ui,
    required this.label,
    required this.icon,
    required this.color,
    required this.assetCandidates,
    required this.selected,
    required this.onTap,
    this.logoUrl,
  });

  final OrbiUiTokens ui;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> assetCandidates;
  final String? logoUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 73),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
        decoration: OrbiCardStyles.elevatedCardDecoration(
          context,
          radius: 14,
          accent: color,
          branded: selected,
          elevated: selected,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 24 : 13,
              margin: const EdgeInsets.only(left: 2, bottom: 4),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.94)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(
              height: 45,
              child: PaymentProviderAvatar(
                assetCandidates: assetCandidates,
                logoUrl: logoUrl,
                icon: icon,
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color.withValues(alpha: 0.95) : ui.textMuted,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.15,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentProviderAvatar extends StatelessWidget {
  const PaymentProviderAvatar({
    super.key,
    required this.assetCandidates,
    required this.icon,
    required this.color,
    this.size = 22,
    this.index = 0,
    this.logoUrl,
  });

  final List<String> assetCandidates;
  final IconData icon;
  final Color color;
  final double size;
  final int index;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return ProviderLogoImage(
      candidates: assetCandidates.skip(index).toList(growable: false),
      remoteLogoUrl: logoUrl,
      placeholderColor: color,
      placeholderIcon: icon,
      placeholderLabel: 'Logo',
      debugPathLabel: assetCandidates.isEmpty
          ? 'no asset candidate'
          : assetCandidates.first,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }
}

class PaymentResultRow extends StatelessWidget {
  const PaymentResultRow({
    super.key,
    required this.label,
    required this.value,
    this.moneyValue = false,
  });

  final String label;
  final String value;
  final bool moneyValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                moneyValue
                    ? MoneyText(
                        value: value.isEmpty ? '-' : value,
                        mainFontSize: 14,
                        sideFontSize: 10.5,
                        fitToWidth: true,
                      )
                    : Text(value.isEmpty ? '-' : value),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: moneyValue
                    ? MoneyText(
                        value: value.isEmpty ? '-' : value,
                        textAlign: TextAlign.right,
                        mainFontSize: 14,
                        sideFontSize: 10.5,
                        fitToWidth: true,
                      )
                    : Text(
                        value.isEmpty ? '-' : value,
                        textAlign: TextAlign.right,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
