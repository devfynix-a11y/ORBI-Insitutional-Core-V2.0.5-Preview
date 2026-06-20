import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/state/app_settings_controller.dart';
import '../../../../core/theme/orbi_card_styles.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_activity_card.dart';
import 'wealth_foundation_sections.dart';
import '../../state/wallet_view_model.dart';

class WalletSectionHeader extends StatelessWidget {
  const WalletSectionHeader({super.key, required this.theme, required this.ui});

  final ThemeData theme;
  final OrbiUiTokens ui;

  @override
  Widget build(BuildContext context) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sw ? 'Utajiri' : 'Wealth',
              style: theme.textTheme.titleLarge?.copyWith(
                color: ui.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ui.accentSoft.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ui.accent.withValues(alpha: 0.16)),
            ),
            child: Text(
              sw ? 'Money map' : 'Money map',
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletEnterpriseHeader extends StatelessWidget {
  const WalletEnterpriseHeader({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.hideBalances,
    required this.onToggleBalanceVisibility,
    required this.mainBalanceText,
    required this.currency,
  });

  final WealthSnapshotData? snapshot;
  final bool loading;
  final bool hideBalances;
  final VoidCallback onToggleBalanceVisibility;
  final String mainBalanceText;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final totalWealthText = snapshot == null
        ? (hideBalances
              ? AppSettingsController.hiddenBalanceText
              : formatDisplayMoney(0, currency, hideBalances: hideBalances))
        : (hideBalances
              ? AppSettingsController.hiddenBalanceText
              : formatDisplayMoney(
                  snapshot!.totalWealth,
                  snapshot!.currency,
                  hideBalances: hideBalances,
                ));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = Colors.white;
    final heroSubtle = Colors.white.withValues(alpha: isDark ? 0.68 : 0.78);
    String assetValue(double value) {
      if (hideBalances) return AppSettingsController.hiddenBalanceText;
      return formatDisplayMoney(
        value,
        snapshot?.currency ?? currency,
        hideBalances: false,
      );
    }

    Widget assetTile({
      required String label,
      required String value,
      required IconData icon,
      required Color accent,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.055 : 0.13),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15.5, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: heroSubtle,
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MoneyText(
                    value: value,
                    mainFontSize: 11.8,
                    sideFontSize: 8.4,
                    fontWeight: FontWeight.w900,
                    mainColor: heroText,
                    sideColor: heroSubtle,
                    fitToWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return OrbiActivityCard(
      accent: ui.accent,
      hero: true,
      variant: OrbiGradientCardVariant.oceanic,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      child: loading && snapshot == null
          ? const InitialWalletLoadingCard()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sw ? 'Jumla ya utajiri' : 'Total wealth',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.08 : 0.90,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: onToggleBalanceVisibility,
                        tooltip: hideBalances
                            ? (sw ? 'Onesha salio' : 'Show balances')
                            : (sw ? 'Ficha salio' : 'Hide balances'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          hideBalances
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.88)
                              : const Color(0xFF07566B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  sw ? 'Thamani ya mali zako' : 'Your asset value',
                  style: TextStyle(
                    color: heroSubtle,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                MoneyText(
                  value: totalWealthText,
                  mainFontSize: 30,
                  sideFontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  mainColor: heroText,
                  sideColor: heroSubtle,
                  fitToWidth: true,
                ),
                const SizedBox(height: 5),
                Text(
                  sw
                      ? 'Fedha zako za ORBI na akaunti zilizounganishwa.'
                      : 'Your ORBI funds and connected accounts.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: heroSubtle,
                    fontSize: 11.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 13),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.55,
                  children: [
                    assetTile(
                      label: sw ? 'Ya kutumia' : 'Operating',
                      value: mainBalanceText,
                      icon: Icons.account_balance_wallet_rounded,
                      accent: const Color(0xFF7DE2F2),
                    ),
                    assetTile(
                      label: sw ? 'Imelindwa' : 'Protected',
                      value: assetValue(snapshot?.protectedAmount ?? 0),
                      icon: Icons.shield_outlined,
                      accent: const Color(0xFF68E0B8),
                    ),
                    assetTile(
                      label: sw ? 'Inakua' : 'Growing',
                      value: assetValue(snapshot?.growingAmount ?? 0),
                      icon: Icons.trending_up_rounded,
                      accent: const Color(0xFFFFD166),
                    ),
                    assetTile(
                      label: sw ? 'Zilizounganishwa' : 'Linked',
                      value: assetValue(snapshot?.linkedWalletBalance ?? 0),
                      icon: Icons.link_rounded,
                      accent: const Color(0xFFC8B6FF),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class InlineSectionHeader extends StatelessWidget {
  const InlineSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class InitialWalletLoadingCard extends StatelessWidget {
  const InitialWalletLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: ui.cardMuted,
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.walletLoadingAccounts,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProvisioningBanner extends StatelessWidget {
  const ProvisioningBanner({super.key, required this.viewModel});

  final WalletViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;

    final message =
        viewModel.provisioningRefreshAttempts <
            viewModel.maxProvisioningAutoRefreshAttempts
        ? 'Wallets are still getting ready. We will keep checking in the background.'
        : l10n.walletProvisioningPreparingManual;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: ui.warningSoft,
        border: Border.all(color: ui.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_rounded, size: 18, color: ui.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
