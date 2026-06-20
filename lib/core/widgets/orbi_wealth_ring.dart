import 'dart:math' as math;

import 'package:flutter/material.dart';

class OrbiWealthRingSegment {
  const OrbiWealthRingSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

class OrbiWealthRing extends StatelessWidget {
  const OrbiWealthRing({
    super.key,
    required this.segments,
    required this.center,
    this.size = 94,
    this.duration = const Duration(milliseconds: 900),
    this.separatorColor,
    this.trackColor,
    this.segmentGapAngle,
  });

  final List<OrbiWealthRingSegment> segments;
  final Widget center;
  final double size;
  final Duration duration;
  final Color? separatorColor;
  final Color? trackColor;
  final double? segmentGapAngle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: reduceMotion ? Duration.zero : duration,
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return CustomPaint(
                size: Size.square(size),
                painter: _OrbiWealthRingPainter(
                  segments: segments,
                  progress: progress,
                  separatorColor:
                      separatorColor ??
                      Theme.of(context).scaffoldBackgroundColor,
                  trackColor:
                      trackColor ?? Colors.white.withValues(alpha: 0.18),
                  segmentGapAngle: segmentGapAngle,
                ),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1),
            duration: reduceMotion ? Duration.zero : duration,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : Duration(milliseconds: duration.inMilliseconds + 120),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size * 0.54,
                    height: size * 0.54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.01),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.62, 1],
                      ),
                    ),
                  ),
                  center,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbiWealthRingPainter extends CustomPainter {
  const _OrbiWealthRingPainter({
    required this.segments,
    required this.progress,
    required this.separatorColor,
    required this.trackColor,
    this.segmentGapAngle,
  });

  final List<OrbiWealthRingSegment> segments;
  final double progress;
  final Color separatorColor;
  final Color trackColor;
  final double? segmentGapAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final easedProgress = progress.clamp(0.0, 1.0);
    final stroke = math.max(10.0, size.width * 0.115);
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final background = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (trackColor.a > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, background);
    }

    final valid = segments.where((segment) => segment.value > 0).toList();
    final total = valid.fold<double>(0, (sum, segment) => sum + segment.value);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 1.65 * easedProgress,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    var start = -math.pi / 2;
    final gapAngle =
        valid.length > 1
            ? (segmentGapAngle ?? math.min(0.14, math.pi * 0.032))
            : 0.0;
    final separatorPaint = Paint()
      ..color = separatorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, stroke * 0.18)
      ..strokeCap = StrokeCap.round;
    final totalSweep = (math.pi * 2 * easedProgress) -
        (gapAngle * valid.length * easedProgress);
    final drawableSweep = math.max(0.0, totalSweep);

    for (final segment in valid) {
      final sweep = (segment.value / total) * drawableSweep;
      if (sweep <= 0) continue;
      final segmentStart = start + (gapAngle / 2);
      canvas.drawArc(
        rect,
        segmentStart,
        math.max(0.06, sweep),
        false,
        Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      if (gapAngle > 0) {
        final separatorAngle = segmentStart + sweep + (gapAngle / 2);
        canvas.drawArc(
          rect,
          separatorAngle - 0.001,
          0.002,
          false,
          separatorPaint,
        );
      }
      start += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _OrbiWealthRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.progress != progress ||
        oldDelegate.separatorColor != separatorColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.segmentGapAngle != segmentGapAngle;
  }
}
