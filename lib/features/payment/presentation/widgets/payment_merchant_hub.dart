import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/widgets/orbi_responsive.dart';

class PaymentMerchantModeOption {
  const PaymentMerchantModeOption({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class PaymentMerchantHub extends StatelessWidget {
  const PaymentMerchantHub({
    super.key,
    required this.ui,
    required this.l10n,
    required this.title,
    required this.subtitle,
    required this.modeOptions,
    required this.selectedModeIndex,
    required this.onModeSelected,
    required this.content,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final String title;
  final String subtitle;
  final List<PaymentMerchantModeOption> modeOptions;
  final int selectedModeIndex;
  final ValueChanged<int> onModeSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return OrbiResponsiveContent(
      maxWidth: 860,
      padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 24),
      child: ListView(
        children: [
          _MerchantIntroCard(ui: ui, title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(modeOptions.length, (index) {
                final option = modeOptions[index];
                final selected = selectedModeIndex == index;
                return Padding(
                  padding: EdgeInsets.only(right: index == modeOptions.length - 1 ? 0 : 10),
                  child: SizedBox(
                    width: 136,
                    child: InkWell(
                      onTap: () => onModeSelected(index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? ui.accent.withValues(alpha: 0.10)
                              : ui.card.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? ui.accent.withValues(alpha: 0.24)
                                : ui.border.withValues(alpha: 0.72),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (selected ? ui.accent : Colors.black).withValues(
                                alpha: selected ? 0.08 : 0.03,
                              ),
                              blurRadius: selected ? 14 : 10,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected
                                    ? ui.accent.withValues(alpha: 0.14)
                                    : ui.cardStrong.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option.icon,
                                size: 20,
                                color: selected ? ui.accent : ui.textMuted,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? ui.textPrimary : ui.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }
}

class _MerchantIntroCard extends StatelessWidget {
  const _MerchantIntroCard({
    required this.ui,
    required this.title,
    required this.subtitle,
  });

  final OrbiUiTokens ui;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.card.withValues(alpha: 0.98),
            ui.cardStrong.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ui.border.withValues(alpha: 0.72)),
            ),
            child: Icon(Icons.payments_rounded, color: ui.iconMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
