import 'package:flutter/material.dart';
import 'dart:math';

import '../theme/orbi_theme.dart';

/// A clean ORBI screen background. Light mode stays simple and app-like; dark
/// mode keeps a little atmosphere without competing with the UI.
class OrbiBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const OrbiBackground({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final surfaces = OrbiTheme.surfacesOf(context);
        final isDark = theme.brightness == Brightness.dark;
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final shortestSide = min(screenWidth, screenHeight);
        final density = (shortestSide / 390).clamp(0.82, 1.28);
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final canRenderRichBackground = shortestSide >= 420 && !reduceMotion && isDark && devicePixelRatio <= 2.5;

        return SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? surfaces.shellStart : const Color(0xFFF7FBFF),
            ),
            child: Stack(
              children: [
                if (isDark)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            surfaces.shellStart,
                            surfaces.heroTop,
                            surfaces.shellEnd,
                          ],
                          stops: const [0.0, 0.42, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (!isDark)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFFFFF),
                            surfaces.heroTop,
                            const Color(0xFFEFF7FB),
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                    ),
                  ),

                if (!isDark) ...[
                  Positioned(
                    top: screenHeight * -0.18,
                    right: screenWidth * -0.18,
                    child: Container(
                      width: screenWidth * (0.72 * density),
                      height: screenWidth * (0.72 * density),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OrbiTheme.uiOf(
                              context,
                            ).accent.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          radius: 0.72,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: screenWidth * -0.24,
                    bottom: screenHeight * -0.16,
                    child: Container(
                      width: screenWidth * (0.68 * density),
                      height: screenWidth * (0.68 * density),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x10E57C3C), Colors.transparent],
                          radius: 0.70,
                        ),
                      ),
                    ),
                  ),
                ],

                if (canRenderRichBackground) ...[
                  // --- 3. 60° diagonal gradient lines (thick & thin) ---
                  ..._buildGradientLines(
                    screenWidth,
                    screenHeight,
                    density,
                    accent: OrbiTheme.uiOf(context).accent,
                    isDark: isDark,
                  ),
                ],

                // --- 4. Network flow lines for visual motion depth ---
                if (canRenderRichBackground)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: AuroraWavePainter(
                            density: density,
                            colorA:
                                (isDark
                                        ? const Color(0xFF42E2CF)
                                        : const Color(0xFF00A7C2))
                                    .withValues(alpha: isDark ? 0.08 : 0.06),
                            colorB:
                                (isDark
                                        ? const Color(0xFF75D7E8)
                                        : const Color(0xFF006B64))
                                    .withValues(alpha: isDark ? 0.06 : 0.045),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (isDark) ...[
                  Positioned(
                    top: screenHeight * -0.15,
                    right: screenWidth * -0.1,
                    child: Container(
                      width: screenWidth * (0.56 * density),
                      height: screenWidth * (0.56 * density),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x1642E2CF), Colors.transparent],
                          radius: 0.78,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: screenWidth * -0.18,
                    bottom: screenHeight * -0.12,
                    child: Container(
                      width: screenWidth * (0.58 * density),
                      height: screenWidth * (0.58 * density),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OrbiTheme.uiOf(
                              context,
                            ).accent.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          radius: 0.72,
                        ),
                      ),
                    ),
                  ),
                ],

                // --- 6. Geometric shapes (subtle, low-luminance) ---
                if (canRenderRichBackground) ...[
                  Positioned(
                    left: screenWidth * 0.06,
                    bottom: screenHeight * 0.02,
                    child: Transform.rotate(
                      angle: 60 * pi / 180,
                      child: Container(
                        width: screenWidth * (0.42 * density),
                        height: screenHeight * (0.20 * density),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0x16FFFFFF),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0x08FFFFFF),
                              const Color(0x0A42E2CF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: screenWidth * 0.02,
                    top: screenHeight * 0.15,
                    child: ClipPath(
                      clipper: const TriangleClipper(angle: 60),
                      child: Container(
                        width: screenWidth * (0.26 * density),
                        height: screenWidth * (0.26 * density),
                        color: isDark
                            ? const Color(0x1042E2CF)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ],

                // --- 7. Faint dotted grid texture ---
                if (canRenderRichBackground)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: DottedGridPainter(
                          color: const Color(0x1042E2CF),
                          spacing: 28.0 * density,
                        ),
                      ),
                    ),
                  ),

                if (isDark)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x08FFFFFF),
                            Color(0x2A031018),
                          ],
                          stops: [0.68, 0.9, 1.0],
                        ),
                      ),
                    ),
                  ),

                // Main content
                Positioned.fill(
                  child: _OrbiScreenEntrance(
                    child: Padding(
                      padding: padding ?? const EdgeInsets.all(16.0),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a list of thick diagonal gradient lines at 60°.
  List<Widget> _buildGradientLines(
    double width,
    double height,
    double density, {
    required Color accent,
    required bool isDark,
  }) {
    final lines = <Widget>[];
    // Five layered lines with varied opacities to avoid flat backgrounds.
    final positions = [
      Offset(width * 0.16, height * 0.08),
      Offset(width * 0.38, height * -0.10),
      Offset(width * 0.62, height * 0.14),
      Offset(width * 0.78, height * 0.30),
      Offset(width * -0.04, height * 0.36),
    ];
    final sizes = [
      Size(width * (0.13 * density), height * (0.52 * density)),
      Size(width * (0.09 * density), height * (0.80 * density)),
      Size(width * (0.10 * density), height * (0.42 * density)),
      Size(width * (0.08 * density), height * (0.55 * density)),
      Size(width * (0.11 * density), height * (0.38 * density)),
    ];
    final gradients = [
      LinearGradient(
        colors: [
          isDark ? const Color(0x1242E2CF) : const Color(0x14006B64),
          const Color(0x00006B64),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [
          isDark ? const Color(0x1075D7E8) : const Color(0x1200A7C2),
          const Color(0x0000A7C2),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      LinearGradient(
        colors: [
          isDark ? accent.withValues(alpha: 0.14) : const Color(0x10006B64),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      LinearGradient(
        colors: [
          isDark ? const Color(0x1042E2CF) : const Color(0x1000A7C2),
          const Color(0x00006B64),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [
          isDark ? const Color(0x1075D7E8) : const Color(0x12006B64),
          const Color(0x0003131D),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    ];

    for (int i = 0; i < 5; i++) {
      lines.add(
        Positioned(
          left: positions[i].dx,
          top: positions[i].dy,
          child: Transform.rotate(
            angle: 60 * pi / 180,
            child: Container(
              width: sizes[i].width,
              height: sizes[i].height,
              decoration: BoxDecoration(
                gradient: gradients[i],
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      );
    }
    return lines;
  }
}

class OrbiMotionReveal extends StatelessWidget {
  const OrbiMotionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.05),
    this.duration = const Duration(milliseconds: 560),
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return _OrbiDelayedReveal(
      delay: delay,
      beginOffset: beginOffset,
      duration: duration,
      child: child,
    );
  }
}

class OrbiMotionCascade extends StatelessWidget {
  const OrbiMotionCascade({
    super.key,
    required this.children,
    this.initialDelay = const Duration(milliseconds: 60),
    this.step = const Duration(milliseconds: 90),
    this.axis = Axis.vertical,
  });

  final List<Widget> children;
  final Duration initialDelay;
  final Duration step;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(children.length, (index) {
        final beginOffset = switch (axis) {
          Axis.horizontal => Offset(index.isEven ? 0.07 : -0.07, 0),
          Axis.vertical => Offset(0, 0.06 + (index % 2 == 0 ? 0.0 : 0.015)),
        };
        return OrbiMotionReveal(
          delay: initialDelay + (step * index),
          beginOffset: beginOffset,
          child: children[index],
        );
      }),
    );
  }
}

class _OrbiScreenEntrance extends StatefulWidget {
  const _OrbiScreenEntrance({required this.child});

  final Widget child;

  @override
  State<_OrbiScreenEntrance> createState() => _OrbiScreenEntranceState();
}

class _OrbiScreenEntranceState extends State<_OrbiScreenEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slide;
  bool _didConfigureMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didConfigureMotion) return;
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    final motionSeed = routeName.hashCode.abs() % 4;
    final begin = switch (motionSeed) {
      0 => const Offset(0.065, 0),
      1 => const Offset(-0.065, 0),
      2 => const Offset(0, 0.095),
      _ => const Offset(0, -0.075),
    };
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInOutQuart,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(curve);
    _slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(curve);
    _didConfigureMotion = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _OrbiDelayedReveal extends StatefulWidget {
  const _OrbiDelayedReveal({
    required this.child,
    required this.delay,
    required this.beginOffset,
    required this.duration,
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;

  @override
  State<_OrbiDelayedReveal> createState() => _OrbiDelayedRevealState();
}

class _OrbiDelayedRevealState extends State<_OrbiDelayedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInOutQuart,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: 0.972, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curve);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// Custom clipper for a triangle with a given apex angle.
class TriangleClipper extends CustomClipper<Path> {
  final double angle;
  const TriangleClipper({required this.angle});

  @override
  Path getClip(Size size) {
    final path = Path();
    final radAngle = angle * pi / 180;
    final halfBase = size.height * tan(radAngle / 2);
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width / 2 - halfBase, size.height);
    path.lineTo(size.width / 2 + halfBase, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

/// Custom painter for a faint dotted grid.
class DottedGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  DottedGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dotRadius = 1.5;
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Curved light ribbons that add depth without overpowering foreground content.
class AuroraWavePainter extends CustomPainter {
  final double density;
  final Color colorA;
  final Color colorB;

  AuroraWavePainter({
    required this.density,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintA = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * density
      ..color = colorA;
    final paintB = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * density
      ..color = colorB;

    final p1 = Path()
      ..moveTo(-size.width * 0.1, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.58,
        size.height * 0.28,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.42,
        size.width * 1.15,
        size.height * 0.16,
      );

    final p2 = Path()
      ..moveTo(-size.width * 0.2, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.58,
        size.width * 0.56,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.88,
        size.width * 1.20,
        size.height * 0.64,
      );

    canvas.drawPath(p1, paintA);
    canvas.drawPath(p2, paintB);
  }

  @override
  bool shouldRepaint(covariant AuroraWavePainter oldDelegate) {
    return oldDelegate.density != density ||
        oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB;
  }
}
