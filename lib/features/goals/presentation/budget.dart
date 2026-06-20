import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/core/widgets/mini_analytics_widget.dart';
import 'package:orbi_mobileapp/core/widgets/money_text.dart';

import 'goals_shared_widgets.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.title,
    required this.accent,
    required this.glow,
    required this.visualToken,
    required this.icon,
    required this.amountLabel,
    required this.periodLabel,
    required this.limitBadge,
    required this.analyticsTitle,
    required this.analyticsSubtitle,
    required this.analyticsValues,
    required this.analyticsLabels,
    this.analyticsColors,
    this.analyticsValueFormatter,
    required this.activeCount,
    required this.onMenuSelected,
    this.eyebrow,
    this.subtitle,
    this.statusBadge,
  });

  final String title;
  final Color accent;
  final Color glow;
  final int visualToken;
  final IconData icon;
  final String? eyebrow;
  final String? subtitle;
  final String amountLabel;
  final String periodLabel;
  final StatusBadgeData limitBadge;
  final StatusBadgeData? statusBadge;
  final String analyticsTitle;
  final String analyticsSubtitle;
  final List<double> analyticsValues;
  final List<String> analyticsLabels;
  final List<Color>? analyticsColors;
  final String Function(double value)? analyticsValueFormatter;
  final int activeCount;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return GoalsPremiumCardShell(
      accent: accent,
      glow: glow,
      visualToken: visualToken,
      artAlignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.20)),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow case final text?) ...[
                      Text(
                        text,
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle case final helper?) ...[
                      const SizedBox(height: 4),
                      Text(
                        helper,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 9.4,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GoalsCardMenuButton(onSelected: onMenuSelected),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: MoneyText(
                    value: amountLabel,
                    mainFontSize: 14,
                    sideFontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    mainColor: ui.textPrimary,
                    sideColor: ui.textMuted,
                    fitToWidth: true,
                  ),
                ),
                const SizedBox(width: 8),
                GoalsCompactMetaChip(
                  color: accent,
                  icon: Icons.timelapse_rounded,
                  label: periodLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [StatusBadge(data: limitBadge)],
          ),
          const SizedBox(height: 6),
          MiniAnalyticsWidget(
            accent: accent,
            values: analyticsValues,
            labels: analyticsLabels,
            title: analyticsTitle,
            subtitle: analyticsSubtitle,
            barColors: analyticsColors,
            tooltipValueFormatter: analyticsValueFormatter,
            topValueFormatter: analyticsValueFormatter,
            statusIcon: statusBadge?.icon,
            statusLabel: statusBadge?.label,
            statusAccent: statusBadge?.accent,
          ),
        ],
      ),
    );
  }
}
