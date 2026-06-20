import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/orbi_theme.dart';

class OrbiOrbitLoader extends StatefulWidget {
  const OrbiOrbitLoader({
    super.key,
    this.label,
    this.size = 64,
    this.compact = false,
    this.showPanel = true,
    this.centerIcon = Icons.lock_rounded,
    this.centerText,
    this.centerAsset,
  });

  final String? label;
  final double size;
  final bool compact;
  final bool showPanel;
  final IconData? centerIcon;
  final String? centerText;
  final String? centerAsset;

  @override
  State<OrbiOrbitLoader> createState() => _OrbiOrbitLoaderState();
}

class _OrbiOrbitLoaderState extends State<OrbiOrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OrbitMark(
          animation: _controller,
          size: widget.size,
          centerIcon: widget.centerIcon,
          centerText: widget.centerText,
          centerAsset: widget.centerAsset,
        ),
        if (widget.label != null && widget.label!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ui.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: widget.compact ? 12 : 13,
            ),
          ),
        ],
      ],
    );

    if (!widget.showPanel) return content;

    return Container(
      padding: EdgeInsets.all(widget.compact ? 16 : 24),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(widget.compact ? 22 : 24),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: ui.accent.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: content,
    );
  }
}

class OrbiOrbitLoadingPane extends StatelessWidget {
  const OrbiOrbitLoadingPane({
    super.key,
    this.label,
    this.minHeight = 220,
    this.centerIcon = Icons.lock_rounded,
  });

  final String? label;
  final double minHeight;
  final IconData? centerIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: minHeight,
      child: Center(
        child: OrbiOrbitLoader(label: label, centerIcon: centerIcon),
      ),
    );
  }
}

class OrbiOrbitBlockingOverlay extends StatelessWidget {
  const OrbiOrbitBlockingOverlay({
    super.key,
    this.label,
    this.absorbing = true,
  });

  final String? label;
  final bool absorbing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: absorbing,
        child: Material(
          color: Colors.transparent,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: ColoredBox(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.16)
                    : const Color(0xFF03131D).withValues(alpha: 0.10),
                child: const Center(
                  child: OrbiOrbitLoader(
                    size: 64,
                    compact: true,
                    showPanel: false,
                    centerIcon: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitMark extends StatelessWidget {
  const _OrbitMark({
    required this.animation,
    required this.size,
    required this.centerIcon,
    required this.centerText,
    required this.centerAsset,
  });

  final Animation<double> animation;
  final double size;
  final IconData? centerIcon;
  final String? centerText;
  final String? centerAsset;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: reduceMotion ? kAlwaysDismissedAnimation : animation,
        builder: (context, _) {
          final progress = reduceMotion ? 0.42 : animation.value;
          final angle = progress * math.pi * 2;
          final pulse = reduceMotion ? 0.0 : math.sin(angle).abs();
          final orbitColor = Color.lerp(
            ui.accent,
            ui.borderStrong,
            isDark ? 0.24 : 0.34,
          )!.withValues(alpha: isDark ? 0.78 : 0.86);
          final orbitGlow = ui.accent.withValues(alpha: isDark ? 0.24 : 0.18);
          final dotColor = ui.accent;
          return Transform.scale(
            scale: 0.98 + (pulse * 0.035),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size * 0.92,
                    height: size * 0.92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: orbitGlow,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: orbitColor, width: 1.8),
                    ),
                  ),
                  Transform.rotate(
                    angle: angle,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: size * 0.22,
                        height: size * 0.22,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.42),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (centerAsset != null &&
                      centerAsset!.trim().isNotEmpty &&
                      size >= 36)
                    Container(
                      width: size * 0.48,
                      height: size * 0.48,
                      padding: EdgeInsets.all(size * 0.08),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ui.card.withValues(alpha: isDark ? 0.24 : 0.70),
                        border: Border.all(
                          color: ui.accent.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ui.accent.withValues(alpha: 0.16),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        centerAsset!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                  else if (centerIcon != null && size >= 36)
                    Icon(centerIcon, color: ui.accent, size: size * 0.36)
                  else if (centerText != null &&
                      centerText!.trim().isNotEmpty &&
                      size >= 36)
                    Container(
                      width: size * 0.42,
                      height: size * 0.42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ui.card.withValues(alpha: isDark ? 0.28 : 0.74),
                        border: Border.all(
                          color: ui.accent.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ui.accent.withValues(alpha: 0.18),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        centerText!,
                        style: TextStyle(
                          color: ui.accent,
                          fontSize: size * 0.23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
