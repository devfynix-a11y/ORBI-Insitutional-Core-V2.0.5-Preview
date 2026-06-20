import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../../core/widgets/orbi_state_card.dart';

class WealthSnapshotData {
  const WealthSnapshotData({
    required this.currency,
    required this.operatingBalance,
    required this.plannedAmount,
    required this.protectedAmount,
    required this.growingAmount,
    required this.linkedWalletBalance,
    required this.goalCount,
    required this.budgetCount,
    required this.linkedWalletCount,
    required this.sharedPotInvitationCount,
    required this.sharedBudgetInvitationCount,
  });

  final String currency;
  final double operatingBalance;
  final double plannedAmount;
  final double protectedAmount;
  final double growingAmount;
  final double linkedWalletBalance;
  final int goalCount;
  final int budgetCount;
  final int linkedWalletCount;
  final int sharedPotInvitationCount;
  final int sharedBudgetInvitationCount;

  double get mainBalance => operatingBalance;

  double get totalManaged => operatingBalance + protectedAmount + growingAmount;

  double get totalWealth =>
      operatingBalance + protectedAmount + growingAmount + linkedWalletBalance;

  bool get needsBudgetAttention =>
      plannedAmount > 0 && operatingBalance < plannedAmount;

  bool get needsGoalStart => goalCount == 0 || growingAmount <= 0;

  bool get needsProtection => protectedAmount <= 0;
}

class WealthFoundationSection extends StatelessWidget {
  const WealthFoundationSection({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.errorMessage,
    required this.isMerchant,
    required this.isAgent,
    required this.isEnterprise,
    required this.onRetry,
    required this.onOpenGoals,
    required this.onOpenPaySafe,
    required this.onOpenBusiness,
    required this.onOpenEnterprise,
    required this.onOpenBillReserves,
    required this.onOpenSharedPots,
    required this.onOpenAllocationRules,
  });

  final WealthSnapshotData? snapshot;
  final bool loading;
  final String? errorMessage;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;
  final VoidCallback onRetry;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenPaySafe;
  final VoidCallback onOpenBusiness;
  final VoidCallback onOpenEnterprise;
  final VoidCallback onOpenBillReserves;
  final VoidCallback onOpenSharedPots;
  final VoidCallback onOpenAllocationRules;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw = _isSw(context);

    if (loading && snapshot == null) {
      return OrbiSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              title: sw ? 'Utajiri' : 'Wealth',
              subtitle: sw ? 'Inapakia...' : 'Loading...',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: ui.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sw ? 'Inapakia fedha...' : 'Loading balances...',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (errorMessage != null && snapshot == null) {
      return OrbiSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              title: sw ? 'Utajiri' : 'Wealth',
              subtitle: sw ? 'Jaribu tena.' : 'Try again.',
            ),
            const SizedBox(height: 14),
            OrbiStateCard(
              icon: Icons.sync_problem_rounded,
              title: sw ? 'Utajiri haukupatikana' : 'Wealth could not load',
              message: errorMessage,
              accentColor: ui.warning,
              accentBackground: ui.warningSoft,
              action: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(sw ? 'Jaribu tena' : 'Try again'),
              ),
            ),
          ],
        ),
      );
    }

    final data = snapshot;
    if (data == null) return const SizedBox.shrink();

    return Column(
      children: [
        OrbiSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                title: sw ? 'Fedha' : 'Balances',
                subtitle: sw ? 'Muhtasari' : 'Overview',
              ),
              const SizedBox(height: 14),
              _ClarityBanner(snapshot: data),
              const SizedBox(height: 14),
              _BucketGrid(snapshot: data),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OrbiSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                title: sw ? 'Njia' : 'Modes',
                subtitle: sw
                    ? 'Binafsi, biashara, taasisi'
                    : 'Personal, business, enterprise',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AudienceCard(
                    width: 250,
                    icon: Icons.family_restroom_rounded,
                    title: sw ? 'Mtumiaji wa kawaida' : 'Everyday users',
                    message: sw
                        ? 'Goals, bajeti, na matumizi.'
                        : 'Goals, budgets, and spending.',
                    accent: ui.success,
                    actionLabel: sw ? 'Goals' : 'Goals',
                    onTap: onOpenGoals,
                  ),
                  _AudienceCard(
                    width: 250,
                    icon: isAgent
                        ? Icons.point_of_sale_rounded
                        : Icons.storefront_rounded,
                    title: isMerchant || isAgent
                        ? (sw ? 'Biashara' : 'Business')
                        : (sw ? 'Wamiliki wa biashara' : 'Business owners'),
                    message: sw
                        ? 'Float, makusanyo, na ukuaji.'
                        : 'Float, collections, and growth.',
                    accent: ui.accent,
                    actionLabel: sw ? 'Biashara' : 'Business',
                    onTap: onOpenBusiness,
                  ),
                  _AudienceCard(
                    width: 250,
                    icon: Icons.apartment_rounded,
                    title: isEnterprise
                        ? (sw ? 'Taasisi' : 'Enterprise')
                        : (sw ? 'Taasisi na timu' : 'Enterprise teams'),
                    message: sw
                        ? 'Idara, malipo, na timu.'
                        : 'Departments, payouts, and teams.',
                    accent: ui.warning,
                    actionLabel: sw
                        ? (isEnterprise ? 'Timu' : 'Taasisi')
                        : (isEnterprise ? 'Teams' : 'Enterprise'),
                    onTap: onOpenEnterprise,
                  ),
                  _AudienceCard(
                    width: 250,
                    icon: Icons.verified_user_rounded,
                    title: sw
                        ? 'Fedha kubwa na uaminifu'
                        : 'Premium and trusted payments',
                    message: sw
                        ? 'Malipo yenye ulinzi.'
                        : 'Protected payments.',
                    accent: ui.iconMuted,
                    actionLabel: sw ? 'PaySafe' : 'PaySafe',
                    onTap: onOpenPaySafe,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OrbiSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                title: sw ? 'Huduma' : 'Tools',
                subtitle: sw
                    ? 'Bili, pots, na rules'
                    : 'Bills, pots, and rules',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AudienceCard(
                    width: 250,
                    icon: Icons.receipt_long_rounded,
                    title: sw ? 'Bill Reserves' : 'Bill Reserves',
                    message: sw
                        ? 'Tenga fedha za bili.'
                        : 'Set bill money aside.',
                    accent: ui.warning,
                    actionLabel: sw ? 'Bill Reserve' : 'Bill Reserve',
                    onTap: onOpenBillReserves,
                  ),
                  _AudienceCard(
                    width: 250,
                    icon: Icons.groups_rounded,
                    title: sw ? 'Shared Pots' : 'Shared Pots',
                    message: sw ? 'Changia pamoja.' : 'Save together.',
                    accent: ui.accent,
                    badgeCount: data.sharedPotInvitationCount,
                    actionLabel: sw ? 'Shared Pot' : 'Shared Pot',
                    onTap: onOpenSharedPots,
                  ),
                  _AudienceCard(
                    width: 250,
                    icon: Icons.route_rounded,
                    title: sw ? 'Allocation Rules' : 'Allocation Rules',
                    message: sw
                        ? 'Gawanya fedha kwa rules.'
                        : 'Split money by rules.',
                    accent: ui.success,
                    actionLabel: sw ? 'Rules' : 'Rules',
                    onTap: onOpenAllocationRules,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = OrbiTheme.uiOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: ui.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: ui.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ClarityBanner extends StatelessWidget {
  const _ClarityBanner({required this.snapshot});

  final WealthSnapshotData snapshot;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _money(BuildContext context, double amount) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return formatCompactMoney(
      amount,
      snapshot.currency,
      locale: localeTag,
      compactFrom: kCompactMoneyThreshold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    final ui = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);
    final tone = snapshot.needsBudgetAttention ? ui.warning : ui.success;
    final title = snapshot.needsBudgetAttention
        ? (sw
              ? 'Mikakati ya matumizi inahitaji uangalizi'
              : 'Your planned spending needs attention')
        : (sw
              ? 'Fedha za matumizi ziko wazi'
              : 'Your spendable money is clear');
    final message = snapshot.needsBudgetAttention
        ? (sw
              ? 'Bajeti ya sasa ni kubwa kuliko fedha ya matumizi. Punguza bajeti au ongeza fedha kwenye operating wallet.'
              : 'Your current budget plans are bigger than your spendable money. Reduce plans or top up the operating wallet.')
        : (sw
              ? 'Unaweza kutumia ${_money(context, snapshot.operatingBalance)} sasa, huku ${_money(context, snapshot.growingAmount)} ikiendelea kwenye malengo.'
              : 'You can use ${_money(context, snapshot.operatingBalance)} now, while ${_money(context, snapshot.growingAmount)} keeps working in goals.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              snapshot.needsBudgetAttention
                  ? Icons.rule_folder_outlined
                  : Icons.verified_rounded,
              color: tone,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _headlineStat(
                      context,
                      label: sw ? 'Main Balance' : 'Main Balance',
                      value: _money(context, snapshot.mainBalance),
                      accent: ui.success,
                    ),
                    _headlineStat(
                      context,
                      label: sw ? 'Total Wealth' : 'Total Wealth',
                      value: _money(context, snapshot.totalWealth),
                      accent: ui.iconMuted,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ui.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headlineStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color accent,
    bool emphasized = false,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasized ? 12 : 10,
        vertical: emphasized ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: emphasized ? 0.26 : 0.18),
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          MoneyText(
            value: value,
            mainFontSize: emphasized ? 12.8 : 11.8,
            sideFontSize: emphasized ? 9.5 : 9,
            fontWeight: FontWeight.w900,
            mainColor: accent.withValues(alpha: 0.96),
            sideColor: accent.withValues(alpha: 0.72),
            fitToWidth: true,
          ),
        ],
      ),
    );
  }
}

class _BucketGrid extends StatelessWidget {
  const _BucketGrid({required this.snapshot});

  final WealthSnapshotData snapshot;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _money(BuildContext context, double amount) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return formatCompactMoney(
      amount,
      snapshot.currency,
      locale: localeTag,
      compactFrom: kCompactMoneyThreshold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    final ui = OrbiTheme.uiOf(context);
    final cards = [
      (
        icon: Icons.account_balance_wallet_rounded,
        title: sw ? 'Main Balance' : 'Main Balance',
        value: _money(context, snapshot.mainBalance),
        subtitle: sw ? 'Fedha za ndani tayari' : 'Internal money ready now',
        accent: ui.success,
        emphasized: false,
      ),
      (
        icon: Icons.account_balance_rounded,
        title: sw ? 'Total Wealth' : 'Total Wealth',
        value: _money(context, snapshot.totalWealth),
        subtitle: sw
            ? '${snapshot.linkedWalletCount} linked wallets'
            : '${snapshot.linkedWalletCount} linked wallets',
        accent: ui.iconMuted,
        emphasized: true,
      ),
      (
        icon: Icons.event_note_rounded,
        title: sw ? 'Mipango' : 'Planned',
        value: _money(context, snapshot.plannedAmount),
        subtitle: sw
            ? '${snapshot.budgetCount} bajeti hai'
            : '${snapshot.budgetCount} active budgets',
        accent: ui.warning,
        emphasized: false,
      ),
      (
        icon: Icons.shield_outlined,
        title: sw ? 'Iliyolindwa' : 'Protected',
        value: _money(context, snapshot.protectedAmount),
        subtitle: sw ? 'PaySafe na holds' : 'PaySafe and holds',
        accent: ui.iconMuted,
        emphasized: false,
      ),
      (
        icon: Icons.trending_up_rounded,
        title: sw ? 'Ukuaji' : 'Growing',
        value: _money(context, snapshot.growingAmount),
        subtitle: sw
            ? '${snapshot.goalCount} malengo'
            : '${snapshot.goalCount} goals in motion',
        accent: ui.accent,
        emphasized: false,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.06,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return _BucketCard(
          icon: item.icon,
          title: item.title,
          value: item.value,
          subtitle: item.subtitle,
          accent: item.accent,
          emphasized: item.emphasized,
        );
      },
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasized
            ? accent.withValues(alpha: 0.10)
            : ui.cardMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasized
              ? accent.withValues(alpha: 0.24)
              : ui.border.withValues(alpha: 0.72),
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ui.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          MoneyText(
            value: value,
            mainFontSize: emphasized ? 18 : 16,
            sideFontSize: emphasized ? 10.5 : 10,
            fontWeight: FontWeight.w900,
            mainColor: emphasized
                ? accent.withValues(alpha: 0.96)
                : ui.textPrimary,
            sideColor: emphasized
                ? accent.withValues(alpha: 0.74)
                : ui.textMuted,
            fitToWidth: true,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ui.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
    this.badgeCount = 0,
  });

  final double width;
  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final String actionLabel;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';
    final badgeColor = badgeCount >= 5 ? Colors.orange : accent;
    return SizedBox(
      width: width,
      child: OrbiStateCard(
        icon: icon,
        title: title,
        message: message,
        accentColor: accent,
        accentBackground: accent.withValues(alpha: 0.16),
        action: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
