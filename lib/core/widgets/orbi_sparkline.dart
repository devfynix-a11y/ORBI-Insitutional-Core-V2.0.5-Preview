import 'dart:math' as math;

import 'package:flutter/material.dart';

class OrbiSparkline extends StatelessWidget {
  const OrbiSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 38,
    this.strokeWidth = 2.2,
    this.fill = true,
    this.animate = true,
    this.duration = const Duration(milliseconds: 900),
  });

  final List<double> values;
  final Color color;
  final double height;
  final double strokeWidth;
  final bool fill;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: reduceMotion || !animate ? Duration.zero : duration,
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return CustomPaint(
            painter: _OrbiSparklinePainter(
              values: values,
              color: color,
              strokeWidth: strokeWidth,
              fill: fill,
              progress: progress,
            ),
          );
        },
      ),
    );
  }
}

class _OrbiSparklinePainter extends CustomPainter {
  const _OrbiSparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.fill,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width
          : i * size.width / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height * 0.72) - 5;
      points.add(Offset(x, y.clamp(4.0, size.height - 4.0)));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final baseline = size.height - 4;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.00),
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.00),
          ],
        ).createShader(Offset.zero & size)
        ..strokeWidth = 1,
    );

    final visibleWidth = size.width * progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, visibleWidth, size.height));

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.00),
            ],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.36),
            color.withValues(alpha: 0.10),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth + 3.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(color, Colors.white, 0.18) ?? color,
            color,
            Color.lerp(color, Colors.white, 0.10) ?? color,
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth,
    );
    canvas.restore();

    final activeIndex = ((points.length - 1) * progress).round().clamp(
      0,
      points.length - 1,
    );
    final activePoint = points[activeIndex];
    canvas.drawCircle(
      activePoint,
      9.5,
      Paint()..color = color.withValues(alpha: 0.08),
    );
    canvas.drawCircle(activePoint, 3.3, Paint()..color = color);
    canvas.drawCircle(
      activePoint,
      7,
      Paint()..color = color.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbiSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fill != fill ||
        oldDelegate.progress != progress;
  }
}
