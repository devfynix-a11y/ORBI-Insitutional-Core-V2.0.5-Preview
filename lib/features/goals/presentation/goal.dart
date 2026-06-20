import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/core/widgets/money_text.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import 'goals_shared_widgets.dart';

class GoalMiniBars extends StatelessWidget {
  const GoalMiniBars({super.key, required this.bars, this.valueFormatter});

  final List<GoalBarData> bars;
  final String Function(double value)? valueFormatter;

  Color _solidChartColor(Color color, Color surface) {
    final normalized = color.withValues(
      alpha: math.max(0.82, color.a).clamp(0.0, 1.0),
    );
    return Color.alphaBlend(normalized, surface.withValues(alpha: 1));
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final maxValue = bars.fold<double>(
      1,
      (max, item) => math.max(max, item.value),
    );
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.12;

    String topLabel(int index) {
      final value = bars[index].value;
      return valueFormatter?.call(value) ??
          (value % 1 == 0
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(1));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ui.card.withValues(alpha: 0.94),
            ui.cardMuted.withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border.withValues(alpha: 0.64)),
      ),
      child: SizedBox(
        height: 74,
        child: BarChart(
          BarChartData(
            maxY: chartMax,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                tooltipMargin: 6,
                getTooltipColor: (_) => ui.cardStrong.withValues(alpha: 0.96),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final item = bars[group.x];
                  return BarTooltipItem(
                    '${item.label}\n${topLabel(group.x)}',
                    TextStyle(
                      color: ui.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  );
                },
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: chartMax / 2,
              getDrawingHorizontalLine: (_) => FlLine(
                color: ui.border.withValues(alpha: 0.22),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= bars.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 1,
                      child: Text(
                        topLabel(index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color.lerp(
                            _solidChartColor(bars[index].color, ui.cardStrong),
                            ui.textPrimary,
                            0.08,
                          ),
                          fontSize: 7.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= bars.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        bars[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(bars.length, (index) {
              final item = bars[index];
              final barColor = _solidChartColor(item.color, ui.cardStrong);
              final topColor = Color.lerp(barColor, Colors.white, 0.16)!;
              return BarChartGroupData(
                x: index,
                barsSpace: 0,
                barRods: [
                  BarChartRodData(
                    toY: item.value.clamp(0, double.infinity),
                    width: 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [barColor, topColor],
                      stops: const [0.1, 1],
                    ),
                    borderSide: BorderSide(
                      color: Color.lerp(barColor, ui.textPrimary, 0.14)!,
                      width: 0.95,
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: chartMax,
                      color: barColor.withValues(alpha: 0.11),
                    ),
                  ),
                ],
              );
            }),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: ui.border.withValues(alpha: 0.22),
                  strokeWidth: 1.1,
                ),
              ],
            ),
          ),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 950),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.title,
    required this.accent,
    required this.glow,
    required this.visualToken,
    required this.progressColor,
    required this.icon,
    required this.amountLabel,
    required this.progressLabel,
    required this.strategyBadge,
    required this.statusBadge,
    required this.analyticsTitle,
    required this.analyticsSubtitle,
    required this.savedValue,
    required this.remainingValue,
    required this.targetValue,
    required this.deadlineLabel,
    required this.chartValueFormatter,
    required this.goalBars,
    required this.onMenuSelected,
    required this.onAllocate,
    required this.onWithdraw,
    required this.onEdit,
    required this.onDelete,
    required this.isSwahili,
    required this.l10n,
    this.monthlyPaceLabel,
  });

  final String title;
  final Color accent;
  final Color glow;
  final int visualToken;
  final Color progressColor;
  final IconData icon;
  final String amountLabel;
  final String progressLabel;
  final StatusBadgeData strategyBadge;
  final StatusBadgeData statusBadge;
  final String analyticsTitle;
  final String analyticsSubtitle;
  final String savedValue;
  final String remainingValue;
  final String targetValue;
  final String deadlineLabel;
  final String Function(double value) chartValueFormatter;
  final String? monthlyPaceLabel;
  final List<GoalBarData> goalBars;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onAllocate;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isSwahili;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return GoalsPremiumCardShell(
      accent: accent,
      glow: glow,
      visualToken: visualToken,
      artAlignment: Alignment.topRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(data: strategyBadge),
                        StatusBadge(data: statusBadge),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GoalsCardMenuButton(onSelected: onMenuSelected),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(
                      value: amountLabel,
                      mainFontSize: 17,
                      sideFontSize: 9.5,
                      fitToWidth: true,
                      mainColor: ui.textPrimary,
                      sideColor: ui.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoalMiniBars(
                  bars: goalBars,
                  valueFormatter: chartValueFormatter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GoalsInlineMetric(
                    label: isSwahili ? 'Akiba' : 'Saved',
                    value: savedValue,
                    color: progressColor,
                  ),
                ),
                Expanded(
                  child: GoalsInlineMetric(
                    label: isSwahili ? 'Kilichobaki' : 'Remaining',
                    value: remainingValue,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GoalsCompactMetaChip(
                color: accent,
                icon: Icons.event_outlined,
                label: deadlineLabel,
              ),
              if (monthlyPaceLabel != null)
                GoalsCompactMetaChip(
                  color: progressColor,
                  icon: Icons.calendar_view_month_rounded,
                  label: monthlyPaceLabel!,
                ),
              GoalsCompactMetaChip(
                color: accent.withValues(alpha: 0.82),
                icon: Icons.track_changes_outlined,
                label: targetValue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GoalsActionPillButton(
                  label: l10n.goalsAllocateButton,
                  icon: icon,
                  onTap: onAllocate,
                  color: accent,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GoalsActionPillButton(
                  label: l10n.goalsWithdrawButton,
                  icon: Icons.lock_open_outlined,
                  onTap: onWithdraw,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
