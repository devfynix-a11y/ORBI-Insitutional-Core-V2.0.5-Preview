import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/app_settings_controller.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_activity_card.dart';
import '../../../../core/widgets/orbi_background.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../../core/widgets/orbi_state_card.dart';
import '../../../../core/widgets/orbi_wealth_ring.dart';
import 'wealth_foundation_sections.dart';

enum WealthScreenTab { home, plans, growth, protection }

class WealthTabSelector extends StatelessWidget {
  const WealthTabSelector({
    super.key,
    required this.currentTab,
    required this.onChanged,
  });

  final WealthScreenTab currentTab;
  final ValueChanged<WealthScreenTab> onChanged;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw = _isSw(context);
    final tabs = <(WealthScreenTab, String, IconData)>[
      (
        WealthScreenTab.home,
        sw ? 'Nyumbani' : 'Home',
        Icons.dashboard_customize_outlined,
      ),
      (
        WealthScreenTab.plans,
        sw ? 'Matumizi' : 'Spending',
        Icons.event_note_rounded,
      ),
      (
        WealthScreenTab.growth,
        sw ? 'Akiba' : 'Savings',
        Icons.trending_up_rounded,
      ),
      (
        WealthScreenTab.protection,
        sw ? 'Ulinzi' : 'Protection',
        Icons.shield_outlined,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            _WealthTabChip(
              label: tab.$2,
              icon: tab.$3,
              selected: currentTab == tab.$1,
              onTap: () => onChanged(tab.$1),
              ui: ui,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class WealthHomeTab extends StatelessWidget {
  const WealthHomeTab({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenGoals,
    required this.onOpenPlans,
    required this.onOpenProtection,
    this.isMerchant = false,
    this.isAgent = false,
    this.isEnterprise = false,
  });

  final WealthSnapshotData? snapshot;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenProtection;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    if (loading && snapshot == null) {
      return OrbiSectionCard(
        child: Row(
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
                sw ? 'Inapakia utajiri...' : 'Loading wealth...',
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (errorMessage != null && snapshot == null) {
      return OrbiStateCard(
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
      );
    }
    final data = snapshot;
    if (data == null) return const SizedBox.shrink();
    final hideBalances = context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );

    final focus = sw
        ? 'Studio ya mali zako: angalia thamani, mgawanyo, na mwendo wa ukuaji.'
        : 'Your asset studio: view total value, allocation, and growth movement.';

    return OrbiMotionReveal(
      duration: const Duration(milliseconds: 780),
      beginOffset: const Offset(0, 0.075),
      child: OrbiActivityCard(
        accent: ui.accent,
        hero: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: sw ? 'Studio ya mali' : 'Wealth studio',
              subtitle: focus,
            ),
            const SizedBox(height: 18),
            _WealthPortfolioVisual(snapshot: data, hideBalances: hideBalances),
            const SizedBox(height: 16),
            OrbiMotionReveal(
              delay: const Duration(milliseconds: 360),
              duration: const Duration(milliseconds: 620),
              child: _InsightBanner(snapshot: data),
            ),
          ],
        ),
      ),
    );
  }
}

class WealthMainSectionsCard extends StatelessWidget {
  const WealthMainSectionsCard({
    super.key,
    required this.onOpenPlans,
    required this.onOpenGoals,
    required this.onOpenProtection,
  });

  final VoidCallback onOpenPlans;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenProtection;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    return OrbiActivityCard(
      accent: OrbiTheme.uiOf(context).accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: sw ? 'Sehemu kuu' : 'Main sections',
            subtitle: sw ? 'Chagua sehemu.' : 'Choose a section.',
          ),
          const SizedBox(height: 14),
          _FeatureActionList(
            items: [
              _FeatureAction(
                icon: Icons.event_note_rounded,
                title: sw ? 'Plans' : 'Plans',
                message: sw
                    ? 'Vikomo, bili, na rules.'
                    : 'Limits, bills, and rules.',
                actionLabel: sw ? 'Plans' : 'Plans',
                onTap: onOpenPlans,
              ),
              _FeatureAction(
                icon: Icons.trending_up_rounded,
                title: sw ? 'Growth' : 'Growth',
                message: sw
                    ? 'Goals na shared pots.'
                    : 'Goals and shared pots.',
                actionLabel: sw ? 'Growth' : 'Growth',
                onTap: onOpenGoals,
              ),
              _FeatureAction(
                icon: Icons.shield_outlined,
                title: sw ? 'Protection' : 'Protection',
                message: sw ? 'PaySafe na ulinzi.' : 'PaySafe and protection.',
                actionLabel: sw ? 'Protection' : 'Protection',
                onTap: onOpenProtection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WealthPlansTab extends StatelessWidget {
  const WealthPlansTab({
    super.key,
    required this.snapshot,
    required this.onOpenBillReserve,
    required this.onOpenAllocationRules,
    required this.onOpenSharedBudget,
    this.isMerchant = false,
    this.isAgent = false,
    this.isEnterprise = false,
  });
  final WealthSnapshotData? snapshot;
  final VoidCallback onOpenBillReserve;
  final VoidCallback onOpenAllocationRules;
  final VoidCallback onOpenSharedBudget;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;
  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    final planned = snapshot?.plannedAmount ?? 0;
    final budgetCount = snapshot?.budgetCount ?? 0;
    final budgetInvites = snapshot?.sharedBudgetInvitationCount ?? 0;
    return Column(
      children: [
        OrbiActivityCard(
          accent: OrbiTheme.uiOf(context).warning,
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: sw ? 'Matumizi' : 'Spending',
                subtitle: sw
                    ? 'Bajeti, bili, na rules.'
                    : 'Budgets, bills, and rules.',
              ),
              const SizedBox(height: 14),
              _MiniSummaryRow(
                items: [
                  _MiniSummaryItem(
                    label: sw ? 'Vikomo' : 'Limits',
                    value: '$budgetCount',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _MiniSummaryItem(
                    label: sw ? 'Zilizopangwa' : 'Planned',
                    value: _money(
                      context,
                      planned,
                      snapshot?.currency ?? 'TZS',
                    ),
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PreviewBanner(
                title: sw ? 'Leo' : 'Today',
                items: [
                  sw ? 'Matumizi' : 'Spending',
                  sw ? 'Bili' : 'Bills',
                  sw ? 'Rules' : 'Rules',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FeatureActionList(
          items: [
            _FeatureAction(
              icon: Icons.receipt_long_outlined,
              title: sw ? 'Bill Reserve' : 'Bill Reserve',
              message: sw ? 'Tenga fedha za bili.' : 'Set bill money aside.',
              actionLabel: sw ? 'Bill Reserve' : 'Bill Reserve',
              onTap: onOpenBillReserve,
            ),
            _FeatureAction(
              icon: Icons.rule_folder_outlined,
              title: sw ? 'Allocation Rules' : 'Allocation Rules',
              message: sw
                  ? 'Panga mgawanyo wa fedha.'
                  : 'Split money by rules.',
              actionLabel: sw ? 'Rules' : 'Rules',
              onTap: onOpenAllocationRules,
            ),
            _FeatureAction(
              icon: Icons.account_tree_outlined,
              title: 'Mezani',
              message: sw ? 'Matumizi ya pamoja.' : 'Shared spending.',
              actionLabel: 'Mezani',
              onTap: onOpenSharedBudget,
              badgeCount: budgetInvites,
            ),
          ],
        ),
      ],
    );
  }
}

class WealthGrowthTab extends StatelessWidget {
  const WealthGrowthTab({
    super.key,
    required this.snapshot,
    required this.onOpenGoals,
    required this.onOpenSharedPot,
    required this.onOpenSharedBudget,
    this.isMerchant = false,
    this.isAgent = false,
    this.isEnterprise = false,
  });
  final WealthSnapshotData? snapshot;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenSharedPot;
  final VoidCallback onOpenSharedBudget;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;
  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    final goals = snapshot?.goalCount ?? 0;
    final growing = snapshot?.growingAmount ?? 0;
    final potInvites = snapshot?.sharedPotInvitationCount ?? 0;
    final budgetInvites = snapshot?.sharedBudgetInvitationCount ?? 0;
    return Column(
      children: [
        OrbiActivityCard(
          accent: OrbiTheme.uiOf(context).success,
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: sw ? 'Akiba' : 'Savings',
                subtitle: sw ? 'Goals na Fungu.' : 'Goals and shared pots.',
              ),
              const SizedBox(height: 14),
              _MiniSummaryRow(
                items: [
                  _MiniSummaryItem(
                    label: sw ? 'Malengo' : 'Goals',
                    value: '$goals',
                    icon: Icons.flag_circle_outlined,
                  ),
                  _MiniSummaryItem(
                    label: sw ? 'Akiba' : 'Saved',
                    value: _money(
                      context,
                      growing,
                      snapshot?.currency ?? 'TZS',
                    ),
                    icon: Icons.trending_up_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PreviewBanner(
                title: sw ? 'Leo' : 'Today',
                items: [
                  goals > 0
                      ? (sw ? '$goals goals' : '$goals goals')
                      : (sw ? 'Anza' : 'Start'),
                  'Fungu',
                  'Mezani',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FeatureActionList(
          items: [
            _FeatureAction(
              icon: Icons.track_changes_outlined,
              title: sw ? 'Goals' : 'Goals',
              message: sw ? 'Akiba ya malengo.' : 'Goal savings.',
              actionLabel: sw ? 'Goals' : 'Goals',
              onTap: onOpenGoals,
            ),
            _FeatureAction(
              icon: Icons.groups_2_outlined,
              title: 'Fungu',
              message: sw ? 'Akiba ya pamoja.' : 'Shared saving.',
              actionLabel: 'Fungu',
              onTap: onOpenSharedPot,
              badgeCount: potInvites,
            ),
            _FeatureAction(
              icon: Icons.account_tree_outlined,
              title: 'Mezani',
              message: sw ? 'Matumizi ya pamoja.' : 'Shared spending.',
              actionLabel: 'Mezani',
              onTap: onOpenSharedBudget,
              badgeCount: budgetInvites,
            ),
          ],
        ),
      ],
    );
  }
}

class WealthProtectionTab extends StatelessWidget {
  const WealthProtectionTab({
    super.key,
    required this.snapshot,
    required this.onOpenPaySafe,
    required this.onOpenLinkWallet,
    this.isMerchant = false,
    this.isAgent = false,
    this.isEnterprise = false,
  });
  final WealthSnapshotData? snapshot;
  final VoidCallback onOpenPaySafe;
  final VoidCallback onOpenLinkWallet;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;
  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  @override
  Widget build(BuildContext context) {
    final sw = _isSw(context);
    final protected = snapshot?.protectedAmount ?? 0;
    final linked = snapshot?.linkedWalletCount ?? 0;
    return Column(
      children: [
        OrbiActivityCard(
          accent: OrbiTheme.uiOf(context).accent,
          hero: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: sw ? 'Ulinzi' : 'Protection',
                subtitle: sw
                    ? 'PaySafe na linked wallets.'
                    : 'PaySafe and linked wallets.',
              ),
              const SizedBox(height: 14),
              _MiniSummaryRow(
                items: [
                  _MiniSummaryItem(
                    label: sw ? 'Zilizolindwa' : 'Protected',
                    value: _money(
                      context,
                      protected,
                      snapshot?.currency ?? 'TZS',
                    ),
                    icon: Icons.shield_moon_outlined,
                  ),
                  _MiniSummaryItem(
                    label: sw ? 'Linked' : 'Linked',
                    value: '$linked',
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PreviewBanner(
                title: sw ? 'Leo' : 'Today',
                items: [
                  protected > 0 ? 'PaySafe' : (sw ? 'Anza' : 'Start'),
                  sw ? 'Trust' : 'Trust',
                  sw ? 'Wallets' : 'Wallets',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FeatureActionList(
          items: [
            _FeatureAction(
              icon: Icons.lock_clock_outlined,
              title: sw ? 'ORBI PaySafe' : 'ORBI PaySafe',
              message: sw ? 'Malipo yenye ulinzi.' : 'Protected payments.',
              actionLabel: sw ? 'PaySafe' : 'PaySafe',
              onTap: onOpenPaySafe,
            ),
            _FeatureAction(
              icon: Icons.account_balance_outlined,
              title: sw ? 'Link Wallet' : 'Link Wallet',
              message: sw ? 'Unganisha wallet.' : 'Connect wallets.',
              actionLabel: sw ? 'Link Wallet' : 'Link Wallet',
              onTap: onOpenLinkWallet,
            ),
          ],
        ),
      ],
    );
  }
}

class _WealthTabChip extends StatelessWidget {
  const _WealthTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.ui,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final OrbiUiTokens ui;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ui.accent.withValues(alpha: 0.12) : ui.cardMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? ui.accent.withValues(alpha: 0.35) : ui.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ui.accent.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? ui.accent : ui.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? ui.textPrimary : ui.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.snapshot});
  final WealthSnapshotData snapshot;
  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw = _isSw(context);
    final message = snapshot.needsBudgetAttention
        ? (sw
              ? 'Mipango yako ya matumizi ni mikubwa kuliko fedha uliyonayo tayari kutumia. Punguza bajeti au ongeza salio.'
              : 'Your spending plans are higher than the money currently ready to use. Reduce the budget or add funds.')
        : snapshot.needsProtection
        ? (sw
              ? 'Bado hujatenga fedha salama. Tenga kiasi kwa bili muhimu au malipo yenye masharti.'
              : 'You have not set aside protected money yet. Reserve funds for important bills or conditional payments.')
        : (sw
              ? 'Mali zako zimegawanywa vizuri. Endelea kuongeza akiba ya malengo na fedha salama.'
              : 'Your assets are well balanced. Keep growing goal savings and protected funds.');
    return OrbiSectionCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      accentColor: ui.accent,
      branded: true,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.insights_outlined, color: ui.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.title, required this.items});
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return OrbiSectionCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      accentColor: ui.iconMuted,
      branded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in items) _PreviewChip(label: item)],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ui.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WealthPortfolioVisual extends StatelessWidget {
  const _WealthPortfolioVisual({
    required this.snapshot,
    required this.hideBalances,
  });

  final WealthSnapshotData snapshot;
  final bool hideBalances;

  bool _isSw(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw = _isSw(context);
    final total = snapshot.totalWealth;
    final allocations = <_WealthAllocation>[
      _WealthAllocation(
        label: sw ? 'Fedha ya kutumia' : 'Spendable money',
        description: sw ? 'Salio la wallet ya ORBI' : 'ORBI wallet balance',
        value: snapshot.operatingBalance,
        color: ui.accent,
        icon: Icons.bolt_rounded,
      ),
      _WealthAllocation(
        label: sw ? 'Fedha iliyolindwa' : 'Protected money',
        description: sw
            ? 'PaySafe na fedha zilizotengwa'
            : 'PaySafe and reserved funds',
        value: snapshot.protectedAmount,
        color: ui.iconMuted,
        icon: Icons.shield_rounded,
      ),
      _WealthAllocation(
        label: sw ? 'Akiba ya malengo' : 'Goal savings',
        description: sw
            ? 'Fedha zilizohifadhiwa kwa malengo'
            : 'Money saved for goals',
        value: snapshot.growingAmount,
        color: ui.success,
        icon: Icons.trending_up_rounded,
      ),
      _WealthAllocation(
        label: sw ? 'Akaunti zilizounganishwa' : 'Linked accounts',
        description: sw
            ? 'Benki na wallet za nje'
            : 'Banks and external wallets',
        value: snapshot.linkedWalletBalance,
        color: ui.warning,
        icon: Icons.hub_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final ringSize = compact ? 150.0 : 174.0;
        final chart = OrbiMotionReveal(
          delay: const Duration(milliseconds: 120),
          duration: const Duration(milliseconds: 900),
          child: Semantics(
            label: sw
                ? 'Jumla ya thamani ya mali zako ni ${_wealthChartMoney(context, total, snapshot.currency, hideBalances: hideBalances)}'
                : 'Your total asset value is ${_wealthChartMoney(context, total, snapshot.currency, hideBalances: hideBalances)}',
            child: OrbiWealthRing(
              size: ringSize,
              duration: const Duration(milliseconds: 1050),
              segments: [
                for (final allocation in allocations)
                  OrbiWealthRingSegment(
                    value: allocation.value,
                    color: allocation.color,
                    label: allocation.label,
                  ),
              ],
              center: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sw ? 'Jumla ya mali' : 'Total assets',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(
                      value: _wealthChartMoney(
                        context,
                        total,
                        snapshot.currency,
                        hideBalances: hideBalances,
                      ),
                      mainFontSize: 18,
                      sideFontSize: 10,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        const badgeAlignments = <Alignment>[
          Alignment(-1, -0.92),
          Alignment(1, -0.48),
          Alignment(-0.96, 0.62),
          Alignment(0.98, 0.98),
        ];
        const badgeOffsets = <Offset>[
          Offset.zero,
          Offset(0, -2),
          Offset(2, 0),
          Offset(0, -4),
        ];

        return SizedBox(
          height: compact ? 300 : 326,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WealthOrbitFieldPainter(
                      colors: [for (final item in allocations) item.color],
                    ),
                  ),
                ),
              ),
              Align(alignment: const Alignment(0, 0.04), child: chart),
              for (var i = 0; i < allocations.length; i++)
                Align(
                  alignment: badgeAlignments[i],
                  child: Transform.translate(
                    offset: badgeOffsets[i],
                    child: OrbiMotionReveal(
                      delay: Duration(milliseconds: 180 + (i * 95)),
                      duration: const Duration(milliseconds: 680),
                      beginOffset: Offset(
                        i.isEven ? -0.08 : 0.08,
                        i < 2 ? -0.04 : 0.04,
                      ),
                      child: _WealthOrbitBadge(
                        allocation: allocations[i],
                        total: total,
                        currency: snapshot.currency,
                        hideBalances: hideBalances,
                        variant: i,
                        compact: compact,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WealthAllocation {
  const _WealthAllocation({
    required this.label,
    required this.description,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String description;
  final double value;
  final Color color;
  final IconData icon;
}

class _WealthOrbitBadge extends StatefulWidget {
  const _WealthOrbitBadge({
    required this.allocation,
    required this.total,
    required this.currency,
    required this.hideBalances,
    required this.variant,
    required this.compact,
  });

  final _WealthAllocation allocation;
  final double total;
  final String currency;
  final bool hideBalances;
  final int variant;
  final bool compact;

  @override
  State<_WealthOrbitBadge> createState() => _WealthOrbitBadgeState();
}

class _WealthOrbitBadgeState extends State<_WealthOrbitBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3600 + (widget.variant * 430)),
      value: widget.variant * 0.17,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final allocation = widget.allocation;
    final percentage = widget.total <= 0
        ? 0.0
        : (allocation.value / widget.total) * 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radii = <BorderRadius>[
      BorderRadius.circular(18),
      const BorderRadius.only(
        topLeft: Radius.circular(25),
        topRight: Radius.circular(13),
        bottomLeft: Radius.circular(13),
        bottomRight: Radius.circular(25),
      ),
      const BorderRadius.only(
        topLeft: Radius.circular(13),
        topRight: Radius.circular(25),
        bottomLeft: Radius.circular(25),
        bottomRight: Radius.circular(13),
      ),
      BorderRadius.circular(26),
    ];
    final value = _wealthChartMoney(
      context,
      allocation.value,
      widget.currency,
      hideBalances: widget.hideBalances,
    );
    final badge = Semantics(
      label:
          '${allocation.label}. ${allocation.description}. $value'
          '${widget.hideBalances ? '' : ', ${percentage.toStringAsFixed(0)} percent'}',
      child: Container(
        width: widget.compact ? 124 : 142,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 12,
          vertical: widget.compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                    ui.cardStrong,
                    allocation.color,
                    isDark ? 0.22 : 0.18,
                  ) ??
                  ui.cardStrong,
              Color.lerp(ui.card, allocation.color, isDark ? 0.07 : 0.035) ??
                  ui.card,
            ],
          ),
          borderRadius: radii[widget.variant],
          border: Border.all(
            color: allocation.color.withValues(alpha: isDark ? 0.34 : 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: allocation.color.withValues(alpha: isDark ? 0.13 : 0.09),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: widget.compact ? 25 : 28,
                  height: widget.compact ? 25 : 28,
                  decoration: BoxDecoration(
                    color: allocation.color.withValues(
                      alpha: isDark ? 0.20 : 0.13,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    allocation.icon,
                    color: allocation.color,
                    size: widget.compact ? 14 : 16,
                  ),
                ),
                const Spacer(),
                if (!widget.hideBalances)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: allocation.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: allocation.color,
                        fontSize: widget.compact ? 9 : 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              allocation.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: widget.compact ? 10.5 : 11.5,
                height: 1.12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              allocation.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textMuted,
                fontSize: widget.compact ? 8 : 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            MoneyText(
              value: value,
              mainFontSize: widget.compact ? 12 : 13.5,
              sideFontSize: widget.compact ? 8 : 9,
            ),
          ],
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return badge;
    return AnimatedBuilder(
      animation: _controller,
      child: badge,
      builder: (context, child) {
        final phase =
            (_controller.value * math.pi * 2) + (widget.variant * 0.85);
        final amplitude = widget.compact ? 2.2 : 3.2;
        return Transform.translate(
          offset: Offset(
            math.cos(phase) * amplitude * 0.45,
            math.sin(phase) * amplitude,
          ),
          child: child,
        );
      },
    );
  }
}

class _WealthOrbitFieldPainter extends CustomPainter {
  const _WealthOrbitFieldPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRect = Rect.fromCenter(
      center: center,
      width: math.min(size.width * 0.76, 270),
      height: math.min(size.height * 0.66, 205),
    );
    canvas.drawOval(
      orbitRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    const angles = <double>[-2.38, -0.58, 2.46, 0.72];
    for (var i = 0; i < angles.length; i++) {
      final point = Offset(
        center.dx + math.cos(angles[i]) * orbitRect.width / 2,
        center.dy + math.sin(angles[i]) * orbitRect.height / 2,
      );
      canvas.drawCircle(
        point,
        3.2,
        Paint()..color = colors[i].withValues(alpha: 0.62),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WealthOrbitFieldPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

String _wealthChartMoney(
  BuildContext context,
  double amount,
  String currency, {
  required bool hideBalances,
}) {
  final locale = Localizations.localeOf(context);
  final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';
  return formatCompactMoney(
    amount,
    currency,
    locale: localeTag,
    hideBalances: hideBalances,
    compactFrom: 1000,
  );
}

class _MiniSummaryRow extends StatelessWidget {
  const _MiniSummaryRow({required this.items});
  final List<_MiniSummaryItem> items;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        Expanded(child: items[i]),
        if (i != items.length - 1) const SizedBox(width: 12),
      ],
    ],
  );
}

class _MiniSummaryItem extends StatelessWidget {
  const _MiniSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ui.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
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

class _FeatureActionList extends StatelessWidget {
  const _FeatureActionList({required this.items});
  final List<_FeatureAction> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        items[i],
        if (i != items.length - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class _FeatureAction extends StatelessWidget {
  const _FeatureAction({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
    this.badgeCount = 0,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;
  final int badgeCount;
  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';
    final badgeColor = badgeCount >= 5 ? ui.warning : ui.accent;
    return OrbiActivityCard(
      accent: ui.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ui.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _money(BuildContext context, double amount, String currency) {
  final locale = Localizations.localeOf(context);
  final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';
  return formatCompactMoney(
    amount,
    currency,
    locale: localeTag,
    compactFrom: kLargeCardCompactThreshold,
  );
}
