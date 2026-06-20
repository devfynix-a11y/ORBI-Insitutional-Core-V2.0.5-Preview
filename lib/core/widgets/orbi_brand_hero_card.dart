import 'package:flutter/material.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiBrandHeroCard extends StatelessWidget {
  const OrbiBrandHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.variant = OrbiGradientCardVariant.oceanic,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final OrbiGradientCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ui.textPrimary : Colors.white;
    final softTextColor = isDark
        ? ui.textMuted
        : Colors.white.withValues(alpha: 0.82);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: OrbiCardStyles.primaryHeroDecoration(
        context,
        variant: variant,
      ),
      child: Stack(
        children: [
          if (!isDark) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.055),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.62],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              right: -50,
              top: -58,
              child: _GlowDisc(size: 150, opacity: 0.13, color: ui.accent),
            ),
            Positioned(
              left: -46,
              bottom: -58,
              child: _GlowDisc(size: 132, opacity: 0.07, color: ui.accent),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OrbiHeroLineArtPainter(
                    color: OrbiCardStyles.heroLineColor(context),
                    nodeColor: OrbiCardStyles.heroNodeColor(context),
                  ),
                ),
              ),
            ),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? ui.accentSoft
                          : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                      border: isDark
                          ? Border.all(color: ui.border.withValues(alpha: 0.45))
                          : null,
                    ),
                    child: Icon(icon, color: textColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: softTextColor,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
              if (child != null) ...[const SizedBox(height: 14), child!],
            ],
          ),
        ],
      ),
    );
  }
}

class OrbiHeroMetricChip extends StatelessWidget {
  const OrbiHeroMetricChip({
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
    final foreground = isDark ? ui.textPrimary : Colors.white;
    final subdued = isDark
        ? ui.textMuted
        : Colors.white.withValues(alpha: 0.76);

    return Container(
      constraints: const BoxConstraints(minWidth: 86, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? ui.card.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
        border: isDark
            ? Border.all(color: ui.border.withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subdued,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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

class _GlowDisc extends StatelessWidget {
  const _GlowDisc({
    required this.size,
    required this.opacity,
    this.color = Colors.white,
  });

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _OrbiHeroLineArtPainter extends CustomPainter {
  const _OrbiHeroLineArtPainter({required this.color, required this.nodeColor});

  final Color color;
  final Color nodeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    final fineStroke = Paint()
      ..color = color.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.82
      ..strokeCap = StrokeCap.round;
    final node = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    final topPath = Path()
      ..moveTo(size.width * 0.48, size.height * 0.18)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.00,
        size.width * 0.86,
        size.height * 0.18,
        size.width * 1.04,
        size.height * 0.05,
      );
    canvas.drawPath(topPath, stroke);

    final lowerPath = Path()
      ..moveTo(size.width * 0.40, size.height * 0.76)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.54,
        size.width * 0.82,
        size.height * 0.70,
        size.width * 1.05,
        size.height * 0.43,
      );
    canvas.drawPath(lowerPath, fineStroke);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.76, size.height * 0.13)
        ..lineTo(size.width * 1.03, size.height * 0.36),
      fineStroke,
    );

    for (final point in <Offset>[
      Offset(size.width * 0.60, size.height * 0.12),
      Offset(size.width * 0.80, size.height * 0.17),
      Offset(size.width * 0.68, size.height * 0.60),
      Offset(size.width * 0.91, size.height * 0.49),
    ]) {
      canvas.drawCircle(point, 2.3, node);
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = nodeColor.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbiHeroLineArtPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.nodeColor != nodeColor;
  }
}
