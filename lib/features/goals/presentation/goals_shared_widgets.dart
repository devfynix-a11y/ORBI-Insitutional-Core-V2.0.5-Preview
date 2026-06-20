import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/theme/orbi_card_styles.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

class StatusBadgeData {
  const StatusBadgeData({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}

class GoalBarData {
  const GoalBarData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.data});

  final StatusBadgeData data;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.accent.withValues(alpha: 0.12),
            ui.card.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: data.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 12, color: data.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: data.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalsPremiumCardShell extends StatelessWidget {
  const GoalsPremiumCardShell({
    super.key,
    required this.accent,
    required this.glow,
    required this.visualToken,
    required this.child,
    this.artAlignment = Alignment.topRight,
  });

  final Color accent;
  final Color glow;
  final int visualToken;
  final Widget child;
  final Alignment artAlignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        decoration: _tokenizedCardDecoration(
          context,
          accent: accent,
          glow: glow,
          visualToken: visualToken,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: GoalsCardArtworkPainter(
                      accent: accent,
                      glow: glow,
                      alignment: artAlignment,
                      visualToken: visualToken,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _tokenizedCardDecoration(
  BuildContext context, {
  required Color accent,
  required Color glow,
  required int visualToken,
}) {
  final ui = OrbiTheme.uiOf(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final recipe = visualToken % 6;
  const directions = <(Alignment, Alignment)>[
    (Alignment.topLeft, Alignment.bottomRight),
    (Alignment.topRight, Alignment.bottomLeft),
    (Alignment.centerLeft, Alignment.centerRight),
    (Alignment.bottomLeft, Alignment.topRight),
    (Alignment.topCenter, Alignment.bottomCenter),
    (Alignment.bottomRight, Alignment.topLeft),
  ];
  const lightMixes = <(double, double, double)>[
    (0.15, 0.09, 0.035),
    (0.10, 0.16, 0.045),
    (0.18, 0.07, 0.025),
    (0.08, 0.18, 0.040),
    (0.14, 0.12, 0.030),
    (0.11, 0.14, 0.050),
  ];
  const darkMixes = <(double, double, double)>[
    (0.27, 0.15, 0.07),
    (0.18, 0.25, 0.08),
    (0.30, 0.12, 0.06),
    (0.16, 0.28, 0.09),
    (0.24, 0.19, 0.07),
    (0.20, 0.22, 0.10),
  ];
  final direction = directions[recipe];
  final mix = isDark ? darkMixes[recipe] : lightMixes[recipe];
  final base = isDark ? ui.cardStrong : ui.card;
  final middleBase = isDark ? ui.cardMuted : ui.cardMuted;
  final finishBase = isDark ? ui.card : ui.card;

  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: LinearGradient(
      begin: direction.$1,
      end: direction.$2,
      colors: [
        Color.lerp(base, accent, mix.$1) ?? base,
        Color.lerp(middleBase, glow, mix.$2) ?? middleBase,
        Color.lerp(finishBase, accent, mix.$3) ?? finishBase,
      ],
      stops: recipe.isEven ? const [0, 0.54, 1] : const [0, 0.42, 1],
    ),
    border: Border.all(color: accent.withValues(alpha: isDark ? 0.15 : 0.08)),
    boxShadow: isDark
        ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF1E2F3A).withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
  );
}

class GoalsCardMenuButton extends StatelessWidget {
  const GoalsCardMenuButton({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final isSwahili =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: isSwahili ? 'Menyu ya kadi' : 'Card menu',
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.goalsEditButton)),
        PopupMenuItem(value: 'delete', child: Text(l10n.goalsDeleteButton)),
      ],
      icon: Container(
        width: 32,
        height: 32,
        decoration: OrbiCardStyles.iconBadgeDecoration(
          context,
          accent: ui.iconMuted,
          radius: 11,
        ),
        child: Icon(Icons.more_horiz_rounded, size: 17, color: ui.textPrimary),
      ),
      padding: EdgeInsets.zero,
    );
  }
}

class GoalsActionPillButton extends StatelessWidget {
  const GoalsActionPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    this.filled = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: filled
                  ? [
                      color.withValues(alpha: 0.16),
                      ui.card.withValues(alpha: 0.90),
                    ]
                  : [
                      ui.card.withValues(alpha: 0.96),
                      ui.cardMuted.withValues(alpha: 0.82),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: color.withValues(alpha: destructive ? 0.24 : 0.18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalsInlineMetric extends StatelessWidget {
  const GoalsInlineMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: ui.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class GoalsCompactMetaChip extends StatelessWidget {
  const GoalsCompactMetaChip({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.10),
            ui.card.withValues(alpha: 0.76),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalsCardArtworkPainter extends CustomPainter {
  const GoalsCardArtworkPainter({
    required this.accent,
    required this.glow,
    required this.alignment,
    required this.visualToken,
  });

  final Color accent;
  final Color glow;
  final Alignment alignment;
  final int visualToken;

  @override
  void paint(Canvas canvas, Size size) {
    final recipe = visualToken % 6;
    final phase = (visualToken % 29) / 29;
    final horizontalShift = ((visualToken % 9) - 4) * 0.012;
    final verticalShift = (((visualToken ~/ 9) % 9) - 4) * 0.012;
    final anchor = Offset(
      size.width * (0.5 + (alignment.x * 0.24) + horizontalShift),
      size.height * (0.5 + (alignment.y * 0.24) + verticalShift),
    );

    final softFill = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.07),
              glow.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: anchor,
              radius: size.shortestSide * (0.36 + (recipe * 0.018)),
            ),
          );
    canvas.drawCircle(
      anchor,
      size.shortestSide * (0.36 + (recipe * 0.018)),
      softFill,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    void drawGrowthLine(List<Offset> points, List<Color> colors) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        final mid = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      linePaint.shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(path.getBounds());
      canvas.drawPath(path, linePaint);
    }

    drawGrowthLine(
      [
        Offset(anchor.dx - 88, anchor.dy + 54 - (phase * 12)),
        Offset(anchor.dx - 34, anchor.dy + 18 + (phase * 8)),
        Offset(anchor.dx + 14, anchor.dy - 8 - (phase * 10)),
        Offset(anchor.dx + 62, anchor.dy - 34 + (phase * 6)),
      ],
      [
        Colors.transparent,
        glow.withValues(alpha: 0.10),
        accent.withValues(alpha: 0.16),
        Colors.transparent,
      ],
    );

    drawGrowthLine(
      [
        Offset(anchor.dx - 72, anchor.dy + 12 + (phase * 10)),
        Offset(anchor.dx - 24, anchor.dy - 20 - (phase * 7)),
        Offset(anchor.dx + 28, anchor.dy - 42 + (phase * 9)),
        Offset(anchor.dx + 78, anchor.dy - 58 - (phase * 5)),
      ],
      [
        Colors.transparent,
        accent.withValues(alpha: 0.08),
        glow.withValues(alpha: 0.14),
        Colors.transparent,
      ],
    );

    drawGrowthLine(
      [
        Offset(anchor.dx - 22, anchor.dy + 74),
        Offset(anchor.dx + 10, anchor.dy + 26),
        Offset(anchor.dx + 34, anchor.dy - 14),
        Offset(anchor.dx + 48, anchor.dy - 62),
      ],
      [
        Colors.transparent,
        glow.withValues(alpha: 0.08),
        accent.withValues(alpha: 0.12),
        Colors.transparent,
      ],
    );

    final dots = <(Offset, double, Color)>[
      (
        Offset(anchor.dx - 34 + (recipe * 2), anchor.dy + 18),
        4.2,
        accent.withValues(alpha: 0.14),
      ),
      (
        Offset(anchor.dx + 14, anchor.dy - 8 + (phase * 8)),
        3.0,
        glow.withValues(alpha: 0.16),
      ),
      (
        Offset(anchor.dx + 28, anchor.dy - 42),
        5.0,
        accent.withValues(alpha: 0.12),
      ),
      (
        Offset(anchor.dx + 48, anchor.dy - 62),
        2.6,
        glow.withValues(alpha: 0.18),
      ),
      (
        Offset(anchor.dx - 8, anchor.dy + 40),
        2.8,
        accent.withValues(alpha: 0.10),
      ),
    ];

    for (final dot in dots) {
      dotPaint.color = dot.$3;
      canvas.drawCircle(dot.$1, dot.$2, dotPaint);
    }

    final skinDots = <Offset>[];
    for (var x = 18.0; x < size.width - 12; x += 24) {
      for (var y = 18.0; y < size.height - 12; y += 22) {
        final wave = math.sin((x * 0.042) + (y * 0.028) + (alignment.x * 0.9));
        final drift = math.cos((y * 0.038) + (alignment.y * 0.7));
        skinDots.add(Offset(x + (wave * 1.8), y + (drift * 1.4)));
      }
    }

    for (var i = 0; i < skinDots.length; i++) {
      final point = skinDots[i];
      final distance = (point - anchor).distance;
      final normalized = (distance / (size.longestSide * 0.9)).clamp(0.0, 1.0);
      final intensity = (1 - normalized) * 0.055;
      if (intensity <= 0.005) continue;
      dotPaint.color =
          Color.lerp(
            glow.withValues(alpha: 0.025),
            accent.withValues(alpha: 0.08),
            (i % 5) / 4,
          ) ??
          accent.withValues(alpha: 0.04);
      dotPaint.color = dotPaint.color.withValues(alpha: intensity + 0.012);
      canvas.drawCircle(point, (i % 4 == 0) ? 0.95 : 0.7, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GoalsCardArtworkPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.glow != glow ||
        oldDelegate.alignment != alignment ||
        oldDelegate.visualToken != visualToken;
  }
}
