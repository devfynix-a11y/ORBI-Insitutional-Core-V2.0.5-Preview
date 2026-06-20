import 'package:flutter/material.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/money_text.dart';

class GoalsMetricItem {
  const GoalsMetricItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class GoalsSwitchItem {
  const GoalsSwitchItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class GoalsSectionHeader extends StatelessWidget {
  const GoalsSectionHeader({
    super.key,
    required this.width,
    required this.wide,
    required this.eyebrow,
    required this.helper,
    required this.createButton,
  });

  final double width;
  final bool wide;
  final String eyebrow;
  final String helper;
  final Widget createButton;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return wide
        ? Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: (width - 320).clamp(260.0, double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoalsSectionEyebrow(text: eyebrow),
                    const SizedBox(height: 6),
                    Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              createButton,
            ],
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoalsSectionEyebrow(text: eyebrow),
                    const SizedBox(height: 6),
                    Text(
                      helper,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    createButton,
                  ],
                ),
              ),
            ],
          );
  }
}

class GoalsSectionEyebrow extends StatelessWidget {
  const GoalsSectionEyebrow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border.withValues(alpha: 0.72)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ui.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class GoalsOverviewCard extends StatelessWidget {
  const GoalsOverviewCard({
    super.key,
    required this.title,
    required this.description,
    required this.hideBalances,
    required this.onToggleHideBalances,
    required this.hideBalancesTooltip,
    required this.showBalancesTooltip,
    required this.planningTitle,
    required this.planningAmount,
    required this.progressLabel,
    required this.tasksLabel,
    required this.insightMessage,
    required this.completion,
    required this.metrics,
    required this.budgetLockTitle,
    required this.budgetLockSubtitle,
    required this.budgetLockStatusLabel,
    required this.budgetLockEnabled,
    required this.onBudgetLockChanged,
    required this.budgetLockIcon,
    required this.budgetLockAccent,
  });

  final String title;
  final String description;
  final bool hideBalances;
  final VoidCallback onToggleHideBalances;
  final String hideBalancesTooltip;
  final String showBalancesTooltip;
  final String planningTitle;
  final String planningAmount;
  final String progressLabel;
  final String tasksLabel;
  final String insightMessage;
  final double completion;
  final List<GoalsMetricItem> metrics;
  final String budgetLockTitle;
  final String budgetLockSubtitle;
  final String budgetLockStatusLabel;
  final bool budgetLockEnabled;
  final ValueChanged<bool> onBudgetLockChanged;
  final IconData budgetLockIcon;
  final Color budgetLockAccent;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ui.accent.withValues(alpha: isDark ? 0.22 : 0.14),
            ui.card.withValues(alpha: 0.98),
            ui.cardStrong.withValues(alpha: isDark ? 0.96 : 0.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ui.accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: ui.accent.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeader = constraints.maxWidth < 540;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ui.accent.withValues(alpha: 0.20),
                          ui.accent.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ui.accent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      Icons.savings_rounded,
                      color: ui.accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleHideBalances,
                    tooltip: hideBalances
                        ? showBalancesTooltip
                        : hideBalancesTooltip,
                    icon: Icon(
                      hideBalances
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: ui.iconMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PlanningPanel(
                compact: compactHeader,
                planningTitle: planningTitle,
                planningAmount: planningAmount,
                progressLabel: progressLabel,
                tasksLabel: tasksLabel,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ui.card.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ui.border.withValues(alpha: 0.55)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ui.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        completion >= 1
                            ? Icons.check_circle_outline_rounded
                            : Icons.tips_and_updates_outlined,
                        size: 16,
                        color: completion >= 1 ? ui.success : ui.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        insightMessage,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 7,
                  color: ui.success,
                  backgroundColor: ui.cardMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metrics
                    .map(
                      (metric) => GoalsMetricChip(
                        label: metric.label,
                        value: metric.value,
                        icon: metric.icon,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              GoalsBudgetLockTile(
                title: budgetLockTitle,
                subtitle: budgetLockSubtitle,
                statusLabel: budgetLockStatusLabel,
                enabled: budgetLockEnabled,
                onChanged: onBudgetLockChanged,
                icon: budgetLockIcon,
                accentColor: budgetLockAccent,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanningPanel extends StatelessWidget {
  const _PlanningPanel({
    required this.compact,
    required this.planningTitle,
    required this.planningAmount,
    required this.progressLabel,
    required this.tasksLabel,
  });

  final bool compact;
  final String planningTitle;
  final String planningAmount;
  final String progressLabel;
  final String tasksLabel;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: isDark ? 0.46 : 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.accent.withValues(alpha: 0.10)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planningTitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                MoneyText(
                  value: planningAmount,
                  mainFontSize: 22,
                  sideFontSize: 11,
                  fontWeight: FontWeight.w900,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GoalsTopPill(
                      value: progressLabel,
                      backgroundColor: ui.successSoft,
                      textColor: ui.success,
                    ),
                    GoalsTopPill(
                      value: tasksLabel,
                      backgroundColor: ui.accentSoft,
                      textColor: ui.accent,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planningTitle,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      MoneyText(
                        value: planningAmount,
                        mainFontSize: 22,
                        sideFontSize: 11,
                        fontWeight: FontWeight.w900,
                        mainColor: ui.textPrimary,
                        sideColor: ui.textMuted,
                        fitToWidth: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      GoalsTopPill(
                        value: progressLabel,
                        backgroundColor: ui.successSoft,
                        textColor: ui.success,
                      ),
                      GoalsTopPill(
                        value: tasksLabel,
                        backgroundColor: ui.accentSoft,
                        textColor: ui.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class GoalsMetricChip extends StatelessWidget {
  const GoalsMetricChip({
    super.key,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? ui.cardStrong.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.96),
            ui.cardMuted.withValues(alpha: isDark ? 0.82 : 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: ui.accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ui.textMuted, fontSize: 10.2),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.2,
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

class GoalsBudgetLockTile extends StatelessWidget {
  const GoalsBudgetLockTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.enabled,
    required this.onChanged,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBackground = enabled
        ? (isDark ? ui.success : const Color(0xFF0D5A49))
        : ui.card.withValues(alpha: 0.92);
    final statusForeground = enabled
        ? (isDark ? const Color(0xFF04100D) : Colors.white)
        : ui.textMuted;
    final statusBorder = enabled
        ? (isDark
              ? Colors.white.withValues(alpha: 0.20)
              : const Color(0xFF073F34))
        : ui.border.withValues(alpha: 0.62);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 10),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusBorder),
                        boxShadow: enabled
                            ? [
                                BoxShadow(
                                  color: ui.success.withValues(
                                    alpha: isDark ? 0.18 : 0.16,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusForeground,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    height: 1.25,
                    fontSize: 11.2,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class GoalsTopPill extends StatelessWidget {
  const GoalsTopPill({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.textColor,
  });

  final String value;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class GoalsViewSwitcher extends StatelessWidget {
  const GoalsViewSwitcher({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectedIndex,
  });

  final List<GoalsSwitchItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndex;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.accent.withValues(alpha: isDark ? 0.16 : 0.10),
            ui.card.withValues(alpha: 0.98),
            ui.cardStrong.withValues(alpha: isDark ? 0.94 : 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: ui.accent.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const SizedBox(width: 6);
          }
          final itemIndex = index ~/ 2;
          final item = items[itemIndex];
          return Expanded(
            child: _GoalsSwitchChip(
              title: item.title,
              subtitle: item.subtitle,
              selected: selectedIndex == itemIndex,
              onTap: () => onSelectedIndex(itemIndex),
            ),
          );
        }),
      ),
    );
  }
}

class _GoalsSwitchChip extends StatelessWidget {
  const _GoalsSwitchChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ui.accent.withValues(alpha: 0.18),
                      ui.card.withValues(alpha: 0.88),
                    ],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? ui.accent.withValues(alpha: 0.20)
                  : ui.border.withValues(alpha: 0.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? ui.textPrimary : ui.textMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
