import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';

enum MiniAnalyticsStyle { bars, line }

class MiniAnalyticsWidget extends StatelessWidget {
  const MiniAnalyticsWidget({
    super.key,
    required this.accent,
    required this.values,
    required this.labels,
    required this.title,
    required this.subtitle,
    this.style = MiniAnalyticsStyle.bars,
    this.barColors,
    this.tooltipValueFormatter,
    this.topValueFormatter,
    this.showTopValues,
    this.statusIcon,
    this.statusLabel,
    this.statusAccent,
  });

  final Color accent;
  final List<double> values;
  final List<String> labels;
  final String title;
  final String subtitle;
  final MiniAnalyticsStyle style;
  final List<Color>? barColors;
  final String Function(double value)? tooltipValueFormatter;
  final String Function(double value)? topValueFormatter;
  final bool? showTopValues;
  final IconData? statusIcon;
  final String? statusLabel;
  final Color? statusAccent;

  String _formatTopValue(double value) {
    return topValueFormatter?.call(value) ??
        (value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1));
  }

  String _formatTooltipValue(double value) {
    return tooltipValueFormatter?.call(value) ?? _formatTopValue(value);
  }

  String _formatAxisLabel(String label) {
    return label.trim();
  }

  Color _chartColorAt(
    int index,
    Color fallback,
    List<Color>? palette,
    Color surface,
  ) {
    final source = palette != null && palette.isNotEmpty
        ? palette[index % palette.length]
        : fallback;
    final normalized = source.withValues(
      alpha: math.max(0.82, source.a).clamp(0.0, 1.0),
    );
    return Color.alphaBlend(normalized, surface.withValues(alpha: 1));
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final points = math.min(values.length, labels.length);
    final chartValues = points == 0
        ? const <double>[0]
        : values.take(points).toList();
    final chartLabels = points == 0
        ? const <String>['-']
        : labels.take(points).toList();
    final maxValue = chartValues.fold<double>(
      0,
      (max, value) => math.max(max, value),
    );
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.18;
    final effectiveShowTopValues = showTopValues ?? true;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (statusIcon != null && statusLabel != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusAccent ?? accent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusAccent ?? accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 9.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: style == MiniAnalyticsStyle.line
                ? _MiniLineChart(
                    accent: accent,
                    values: chartValues,
                    labels: chartLabels,
                    chartMax: chartMax,
                    showTopValues: effectiveShowTopValues,
                    formatTopValue: _formatTopValue,
                    formatTooltipValue: _formatTooltipValue,
                    formatAxisLabel: _formatAxisLabel,
                  )
                : _MiniBarChart(
                    accent: accent,
                    values: chartValues,
                    labels: chartLabels,
                    chartMax: chartMax,
                    palette: barColors,
                    showTopValues: effectiveShowTopValues,
                    formatTopValue: _formatTopValue,
                    formatTooltipValue: _formatTooltipValue,
                    formatAxisLabel: _formatAxisLabel,
                    resolveColor: (index, color, surface) =>
                        _chartColorAt(index, color, barColors, surface),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.accent,
    required this.values,
    required this.labels,
    required this.chartMax,
    required this.palette,
    required this.showTopValues,
    required this.formatTopValue,
    required this.formatTooltipValue,
    required this.formatAxisLabel,
    required this.resolveColor,
  });

  final Color accent;
  final List<double> values;
  final List<String> labels;
  final double chartMax;
  final List<Color>? palette;
  final bool showTopValues;
  final String Function(double value) formatTopValue;
  final String Function(double value) formatTooltipValue;
  final String Function(String label) formatAxisLabel;
  final Color Function(int index, Color fallback, Color surface) resolveColor;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BarChart(
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
              final index = group.x;
              return BarTooltipItem(
                '${labels[index]}\n${formatTooltipValue(values[index])}',
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
            color: ui.border.withValues(alpha: 0.16),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showTopValues,
              reservedSize: showTopValues ? 17 : 0,
              getTitlesWidget: (value, meta) {
                if (!showTopValues) {
                  return const SizedBox.shrink();
                }
                final index = value.toInt();
                if (index < 0 || index >= values.length) {
                  return const SizedBox.shrink();
                }
                final color = resolveColor(index, accent, ui.cardStrong);
                return SideTitleWidget(
                  meta: meta,
                  space: 1,
                  child: Text(
                    formatTopValue(values[index]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color.lerp(color, ui.textPrimary, 0.08),
                      fontSize: 7.3,
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
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 3,
                  child: Text(
                    formatAxisLabel(labels[index]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 7.1,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(values.length, (index) {
          final barColor = resolveColor(index, accent, ui.cardStrong);
          final topColor = Color.lerp(barColor, Colors.white, 0.16)!;
          return BarChartGroupData(
            x: index,
            barsSpace: 0,
            barRods: [
              BarChartRodData(
                toY: values[index].clamp(0, double.infinity),
                width: values.length >= 5 ? 8.5 : 10,
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
                  color: barColor.withValues(alpha: 0.09),
                ),
              ),
            ],
          );
        }),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: ui.border.withValues(alpha: 0.16),
              strokeWidth: 0.9,
            ),
          ],
        ),
      ),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({
    required this.accent,
    required this.values,
    required this.labels,
    required this.chartMax,
    required this.showTopValues,
    required this.formatTopValue,
    required this.formatTooltipValue,
    required this.formatAxisLabel,
  });

  final Color accent;
  final List<double> values;
  final List<String> labels;
  final double chartMax;
  final bool showTopValues;
  final String Function(double value) formatTopValue;
  final String Function(double value) formatTooltipValue;
  final String Function(String label) formatAxisLabel;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final spots = List.generate(
      values.length,
      (index) => FlSpot(index.toDouble(), values[index]),
    );
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, values.length - 1).toDouble(),
        minY: 0,
        maxY: chartMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMax / 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: ui.border.withValues(alpha: 0.16),
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showTopValues,
              reservedSize: showTopValues ? 17 : 0,
              getTitlesWidget: (value, meta) {
                if (!showTopValues) {
                  return const SizedBox.shrink();
                }
                final index = value.toInt();
                if (index < 0 || index >= values.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 1,
                  child: Text(
                    formatTopValue(values[index]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 7.3,
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
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 3,
                  child: Text(
                    formatAxisLabel(labels[index]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 7.1,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ui.cardStrong.withValues(alpha: 0.96),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            tooltipMargin: 6,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${labels[spot.x.toInt()]}\n${formatTooltipValue(spot.y)}',
                    TextStyle(
                      color: ui.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accent,
            barWidth: 2.4,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.02),
                ],
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 2.6,
                    color: accent,
                    strokeWidth: 1,
                    strokeColor: ui.cardStrong,
                  ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: ui.border.withValues(alpha: 0.16),
              strokeWidth: 0.9,
            ),
          ],
        ),
      ),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
    );
  }
}
