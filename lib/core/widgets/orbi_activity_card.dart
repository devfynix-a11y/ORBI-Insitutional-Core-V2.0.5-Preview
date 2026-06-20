import 'package:flutter/material.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiActivityCard extends StatelessWidget {
  const OrbiActivityCard({
    super.key,
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.hero = false,
    this.variant = OrbiGradientCardVariant.oceanic,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool hero;
  final OrbiGradientCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      decoration: OrbiCardStyles.activityCardDecoration(
        context,
        accent: accent,
        hero: hero,
        radius: radius,
        variant: variant,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (!isDark)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: hero ? 0.12 : 0.05),
                          Colors.white.withValues(alpha: hero ? 0.025 : 0.01),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.38, 0.72],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            if (hero && !isDark)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LightHeroArtworkPainter(variant: variant),
                  ),
                ),
              ),
            if (hero && !isDark)
              Positioned(
                right: -74,
                top: -92,
                child: IgnorePointer(
                  child: Container(
                    width: 196,
                    height: 196,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.075),
                    ),
                  ),
                ),
              ),
            if (hero && !isDark)
              Positioned(
                right: 48,
                bottom: -112,
                child: IgnorePointer(
                  child: Container(
                    width: 184,
                    height: 184,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.035),
                    ),
                  ),
                ),
              ),
            if (hero && isDark)
              Positioned(
                right: -42,
                top: -54,
                child: IgnorePointer(
                  child: _HeroGlowDisc(
                    size: 150,
                    color: ui.accent,
                    opacity: 0.16,
                  ),
                ),
              ),
            if (hero && isDark)
              Positioned(
                left: -38,
                bottom: -48,
                child: IgnorePointer(
                  child: _HeroGlowDisc(
                    size: 124,
                    color: ui.accent,
                    opacity: 0.08,
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _LightHeroArtworkPainter extends CustomPainter {
  const _LightHeroArtworkPainter({required this.variant});

  final OrbiGradientCardVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = Colors.white.withValues(alpha: 0.13);
    final fineLineColor = Colors.white.withValues(alpha: 0.075);
    final accentColor = switch (variant) {
      OrbiGradientCardVariant.oceanic => const Color(0xFFBDF7FF),
      OrbiGradientCardVariant.neon => const Color(0xFFD8D5FF),
      OrbiGradientCardVariant.sunset => const Color(0xFFFFE1C8),
      OrbiGradientCardVariant.passion => const Color(0xFFFFD4E4),
    };

    final primary = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    final fine = Paint()
      ..color = fineLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    final node = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final upperOrbit = Path()
      ..moveTo(size.width * 0.45, size.height * 0.02)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.17,
        size.width * 0.76,
        size.height * 0.00,
        size.width * 1.08,
        size.height * 0.18,
      );
    canvas.drawPath(upperOrbit, primary);

    final middleOrbit = Path()
      ..moveTo(size.width * 0.58, size.height * 0.36)
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.23,
        size.width * 0.89,
        size.height * 0.46,
        size.width * 1.05,
        size.height * 0.31,
      );
    canvas.drawPath(middleOrbit, fine);

    final lowerOrbit = Path()
      ..moveTo(-size.width * 0.06, size.height * 0.86)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.70,
        size.width * 0.40,
        size.height * 0.99,
        size.width * 0.68,
        size.height * 0.82,
      );
    canvas.drawPath(lowerOrbit, fine);

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.93, size.height * 0.17),
        radius: size.shortestSide * 0.13,
      ),
      0.5,
      4.2,
      false,
      primary,
    );

    for (final point in <Offset>[
      Offset(size.width * 0.60, size.height * 0.10),
      Offset(size.width * 0.80, size.height * 0.10),
      Offset(size.width * 0.76, size.height * 0.32),
      Offset(size.width * 0.94, size.height * 0.36),
      Offset(size.width * 0.31, size.height * 0.86),
    ]) {
      canvas.drawCircle(point, 2.2, node);
      canvas.drawCircle(
        point,
        5.3,
        Paint()
          ..color = accentColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightHeroArtworkPainter oldDelegate) {
    return oldDelegate.variant != variant;
  }
}

class _HeroGlowDisc extends StatelessWidget {
  const _HeroGlowDisc({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}
