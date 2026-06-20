import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/orbi_theme.dart';
import 'orbi_orbit_loader.dart';

enum OrbiStatusTone { success, error, info }

class OrbiStatusBanner extends StatefulWidget {
  const OrbiStatusBanner({
    super.key,
    required this.message,
    required this.tone,
    this.onDismiss,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.showAutoHideProgress = false,
  });

  final String message;
  final OrbiStatusTone tone;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;
  final bool showAutoHideProgress;

  @override
  State<OrbiStatusBanner> createState() => _OrbiStatusBannerState();
}

class _OrbiStatusBannerState extends State<OrbiStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final style = _toneStyle(ui, widget.tone, Theme.of(context).brightness);
    final isSuccess = widget.tone == OrbiStatusTone.success;
    final isError = widget.tone == OrbiStatusTone.error;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${_toneLabel(widget.tone)} message: ${widget.message}',
      child: Container(
        width: double.infinity,
        margin: widget.margin,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: style.shadow.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [style.backgroundTop, style.backgroundBottom],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: style.border),
              ),
              child: Stack(
                children: [
                  if (widget.showAutoHideProgress)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1, end: 0),
                          duration: _OrbiLoadingOverlayState._autoHideDuration,
                          builder: (context, value, child) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 2.5,
                                backgroundColor: style.progressBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  style.progressForeground,
                                ),
                              ),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScaleTransition(
                        scale:
                            Tween<double>(
                              begin: isSuccess ? 0.68 : 0.75,
                              end: 1.0,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: isSuccess
                                    ? Curves.elasticOut
                                    : Curves.easeOutBack,
                              ),
                            ),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: style.iconSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: style.foreground.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Icon(
                            style.icon,
                            color: style.foreground,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _toneLabel(widget.tone),
                                style: TextStyle(
                                  color: style.foreground.withValues(
                                    alpha: isError ? 0.96 : 0.86,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isError ? 0.5 : 0.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  color: style.foreground,
                                  fontWeight: isError
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  fontSize: isSuccess ? 15 : 14.5,
                                  height: 1.32,
                                ),
                                child: Text(widget.message),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.onDismiss != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: widget.onDismiss,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Dismiss ${_toneLabel(widget.tone)} message',
                          style: IconButton.styleFrom(
                            backgroundColor: style.iconSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(34, 34),
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            color: style.foreground,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error widget for form validation feedback.
/// Displays validation errors with icon and styled container.
class OrbiInlineError extends StatefulWidget {
  const OrbiInlineError({
    super.key,
    required this.message,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final String message;
  final EdgeInsetsGeometry margin;

  @override
  State<OrbiInlineError> createState() => _OrbiInlineErrorState();
}

class _OrbiInlineErrorState extends State<OrbiInlineError>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final brightness = Theme.of(context).brightness;

    final errorBg = Color.alphaBlend(
      ui.card.withValues(alpha: 0.88),
      ui.dangerSoft.withValues(
        alpha: brightness == Brightness.dark ? 0.74 : 0.86,
      ),
    );

    final errorFg = _adaptiveToneForeground(
      background: errorBg,
      baseText: ui.textPrimary,
      tone: ui.danger,
      brightness: brightness,
    );

    return SizeTransition(
      sizeFactor: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      ),
      child: Container(
        margin: widget.margin,
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: errorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: errorFg.withValues(alpha: 0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: errorFg.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: errorFg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.priority_high_rounded,
                color: errorFg,
                size: 13,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  color: errorFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrbiLoadingOverlay extends StatefulWidget {
  const OrbiLoadingOverlay({
    super.key,
    required this.child,
    required this.loading,
    this.message,
    this.absorb = true,
    this.statusMessage,
    this.statusTone,
    this.onDismissStatus,
  });

  final Widget child;
  final bool loading;
  final String? message;
  final bool absorb;
  final String? statusMessage;
  final OrbiStatusTone? statusTone;
  final VoidCallback? onDismissStatus;

  @override
  State<OrbiLoadingOverlay> createState() => _OrbiLoadingOverlayState();
}

class _OrbiLoadingOverlayState extends State<OrbiLoadingOverlay> {
  static const Duration _autoHideDuration = Duration(seconds: 4);

  Timer? _statusTimer;
  OverlayEntry? _loadingEntry;
  bool _loadingEntryScheduled = false;
  bool _loadingSuppressedByStatus = false;
  String? _visibleStatusMessage;
  OrbiStatusTone? _visibleStatusTone;

  bool get _shouldShowBlockingLoader =>
      widget.loading &&
      widget.absorb &&
      !_loadingSuppressedByStatus &&
      (_visibleStatusMessage == null ||
          _visibleStatusMessage!.trim().isEmpty ||
          _visibleStatusTone == null);

  @override
  void initState() {
    super.initState();
    _syncStatus(initial: true);
  }

  @override
  void didUpdateWidget(covariant OrbiLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) {
      if (!widget.loading || (!oldWidget.loading && widget.loading)) {
        _loadingSuppressedByStatus = false;
      }
    }
    final statusChanged =
        oldWidget.statusMessage != widget.statusMessage ||
        oldWidget.statusTone != widget.statusTone;
    if (statusChanged) {
      _syncStatus();
    }
    if (oldWidget.loading != widget.loading ||
        oldWidget.message != widget.message ||
        oldWidget.absorb != widget.absorb) {
      _syncLoadingEntry();
    } else {
      _markLoadingEntryNeedsBuild();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _removeLoadingEntry();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoadingEntry();
  }

  void _syncStatus({bool initial = false}) {
    _statusTimer?.cancel();

    final nextMessage = widget.statusMessage?.trim();
    final nextTone = widget.statusTone;
    final hasStatus =
        nextMessage != null && nextMessage.isNotEmpty && nextTone != null;

    if (!hasStatus) {
      if (initial) {
        _visibleStatusMessage = null;
        _visibleStatusTone = null;
      } else if (mounted) {
        setState(() {
          _visibleStatusMessage = null;
          _visibleStatusTone = null;
        });
      }
      return;
    }

    _loadingSuppressedByStatus = true;
    _removeLoadingEntry();

    if (initial) {
      _visibleStatusMessage = nextMessage;
      _visibleStatusTone = nextTone;
    } else if (mounted) {
      setState(() {
        _visibleStatusMessage = nextMessage;
        _visibleStatusTone = nextTone;
      });
    }
    _markLoadingEntryNeedsBuild();

    if (nextTone == OrbiStatusTone.error) {
      HapticFeedback.mediumImpact();
    } else if (nextTone == OrbiStatusTone.success) {
      HapticFeedback.lightImpact();
    }

    if (nextTone != OrbiStatusTone.error) {
      _statusTimer = Timer(_autoHideDuration, () {
        if (!mounted) return;
        setState(() {
          _visibleStatusMessage = null;
          _visibleStatusTone = null;
        });
        _markLoadingEntryNeedsBuild();
        widget.onDismissStatus?.call();
      });
    }
  }

  void _dismissStatus() {
    _statusTimer?.cancel();
    if (mounted) {
      setState(() {
        _visibleStatusMessage = null;
        _visibleStatusTone = null;
      });
    }
    _markLoadingEntryNeedsBuild();
    widget.onDismissStatus?.call();
  }

  void _syncLoadingEntry() {
    if (!mounted) return;
    if (!_shouldShowBlockingLoader) {
      _removeLoadingEntry();
      return;
    }
    if (_loadingEntry != null || _loadingEntryScheduled) {
      _markLoadingEntryNeedsBuild();
      return;
    }
    _loadingEntryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadingEntryScheduled = false;
      if (!mounted || !_shouldShowBlockingLoader) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null || _loadingEntry != null) return;
      _loadingEntry = OverlayEntry(
        builder: (context) {
          return OrbiOrbitBlockingOverlay(label: widget.message);
        },
      );
      overlay.insert(_loadingEntry!);
    });
  }

  void _removeLoadingEntry() {
    _loadingEntry?.remove();
    _loadingEntry = null;
  }

  void _markLoadingEntryNeedsBuild() {
    final entry = _loadingEntry;
    if (entry == null || _loadingEntryScheduled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_loadingEntry, entry)) return;
      entry.markNeedsBuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    final showStatus =
        _visibleStatusMessage != null &&
        _visibleStatusMessage!.trim().isNotEmpty &&
        _visibleStatusTone != null;
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _shouldShowBlockingLoader,
          child: widget.child,
        ),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.center,
                child: AnimatedSlide(
                  duration: Duration(
                    milliseconds: _visibleStatusTone == OrbiStatusTone.error
                        ? 320
                        : 220,
                  ),
                  curve: _visibleStatusTone == OrbiStatusTone.error
                      ? Curves.easeOutBack
                      : Curves.easeOutCubic,
                  offset: showStatus ? Offset.zero : const Offset(0, -0.12),
                  child: AnimatedOpacity(
                    duration: Duration(
                      milliseconds: _visibleStatusTone == OrbiStatusTone.error
                          ? 260
                          : 180,
                    ),
                    curve: Curves.easeOut,
                    opacity: showStatus ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showStatus,
                      child: Material(
                        color: Colors.transparent,
                        child: showStatus
                            ? TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(
                                  milliseconds:
                                      _visibleStatusTone == OrbiStatusTone.error
                                      ? 420
                                      : 220,
                                ),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  final isError =
                                      _visibleStatusTone ==
                                      OrbiStatusTone.error;
                                  final isSuccess =
                                      _visibleStatusTone ==
                                      OrbiStatusTone.success;
                                  final wobble = isError
                                      ? math.sin(value * math.pi * 3) *
                                            (1 - value) *
                                            6
                                      : 0.0;
                                  final lift = isSuccess
                                      ? math.sin(value * math.pi) * 6
                                      : 0.0;
                                  return Transform.translate(
                                    offset: Offset(
                                      wobble,
                                      (widget.loading ? -72 : 0) - lift,
                                    ),
                                    child: child,
                                  );
                                },
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: OrbiStatusBanner(
                                    message: _visibleStatusMessage!,
                                    tone: _visibleStatusTone!,
                                    onDismiss: _dismissStatus,
                                    margin: EdgeInsets.zero,
                                    showAutoHideProgress:
                                        _visibleStatusTone !=
                                        OrbiStatusTone.error,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbiRootLoadingBlocker extends StatefulWidget {
  const _OrbiRootLoadingBlocker({
    required this.message,
    required this.dimmedForStatus,
  });

  final String? message;
  final bool dimmedForStatus;

  @override
  State<_OrbiRootLoadingBlocker> createState() =>
      _OrbiRootLoadingBlockerState();
}

class _OrbiRootLoadingBlockerState extends State<_OrbiRootLoadingBlocker>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            color: isDark
                ? Colors.black.withValues(
                    alpha: widget.dimmedForStatus ? 0.08 : 0.18,
                  )
                : const Color(
                    0xFF03131D,
                  ).withValues(alpha: widget.dimmedForStatus ? 0.08 : 0.16),
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: reduceMotion
                      ? kAlwaysDismissedAnimation
                      : _controller,
                  builder: (context, _) {
                    final progress = reduceMotion ? 0.42 : _controller.value;
                    final pulse = reduceMotion
                        ? 0.0
                        : math.sin(progress * math.pi * 2).abs();
                    return Transform.scale(
                      scale: 0.98 + (pulse * 0.035),
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(
                                alpha: isDark ? 0.10 : 0.92,
                              ),
                              ui.card.withValues(alpha: isDark ? 0.14 : 0.80),
                              ui.accent.withValues(alpha: isDark ? 0.10 : 0.10),
                            ],
                            stops: const [0.0, 0.58, 1.0],
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.13)
                                : ui.accent.withValues(alpha: 0.26),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ui.accent.withValues(
                                alpha: isDark ? 0.26 : 0.22,
                              ),
                              blurRadius: 34,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.26 : 0.12,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _OrbiMicroOrbitPainter(
                            progress: progress,
                            accent: ui.accent,
                            secondary: ui.success,
                            border: ui.borderStrong,
                            darkMode: isDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbiMicroOrbitPainter extends CustomPainter {
  const _OrbiMicroOrbitPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
    required this.border,
    required this.darkMode,
  });

  final double progress;
  final Color accent;
  final Color secondary;
  final Color border;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.24;
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: darkMode ? 0.18 : 0.14),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.38),
          );
    canvas.drawCircle(center, size.shortestSide * 0.38, haloPaint);

    final shellPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = darkMode ? 1.05 : 1.25
      ..color = border.withValues(alpha: darkMode ? 0.34 : 0.40);
    final brightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = darkMode ? 1.55 : 1.85
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: darkMode ? 0.9 : 0.86);

    _drawOrbit(canvas, center, radius, -0.68, shellPaint);
    _drawOrbit(canvas, center, radius, 0.68, shellPaint);
    _drawArc(canvas, center, radius, -0.68, progress, brightPaint);
    _drawArc(
      canvas,
      center,
      radius,
      0.68,
      (progress + 0.45) % 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = darkMode ? 1.25 : 1.55
        ..strokeCap = StrokeCap.round
        ..color = secondary.withValues(alpha: darkMode ? 0.66 : 0.72),
    );

    canvas.drawCircle(
      center,
      size.shortestSide * 0.082,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: darkMode ? 0.82 : 0.95),
            accent.withValues(alpha: darkMode ? 0.52 : 0.38),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 16)),
    );
    _drawDot(canvas, center, radius, -0.68, progress, accent, 2.9);
    _drawDot(
      canvas,
      center,
      radius,
      0.68,
      (progress + 0.45) % 1,
      secondary,
      2.4,
    );
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Paint paint,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2.5,
      height: radius * 0.82,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    double phase,
    Paint paint,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2.5,
      height: radius * 0.82,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, phase * math.pi * 2, 0.76, false, paint);
    canvas.restore();
  }

  void _drawDot(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    double phase,
    Color color,
    double dotSize,
  ) {
    final angle = phase * math.pi * 2;
    final raw = Offset(
      math.cos(angle) * radius * 1.25,
      math.sin(angle) * radius * 0.41,
    );
    final rotated = Offset(
      raw.dx * math.cos(rotation) - raw.dy * math.sin(rotation),
      raw.dx * math.sin(rotation) + raw.dy * math.cos(rotation),
    );
    canvas.drawCircle(
      center + rotated,
      dotSize,
      Paint()..color = color.withValues(alpha: darkMode ? 0.9 : 0.68),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbiMicroOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.border != border ||
        oldDelegate.darkMode != darkMode;
  }
}

class _ToneStyle {
  const _ToneStyle({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.foreground,
    required this.border,
    required this.shadow,
    required this.iconSurface,
    required this.icon,
    required this.progressBackground,
    required this.progressForeground,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color foreground;
  final Color border;
  final Color shadow;
  final Color iconSurface;
  final IconData icon;
  final Color progressBackground;
  final Color progressForeground;
}

_ToneStyle _toneStyle(
  OrbiUiTokens ui,
  OrbiStatusTone tone,
  Brightness brightness,
) {
  switch (tone) {
    case OrbiStatusTone.success:
      final background = Color.alphaBlend(
        ui.card.withValues(alpha: 0.86),
        ui.successSoft.withValues(
          alpha: brightness == Brightness.dark ? 0.82 : 0.90,
        ),
      );
      final successForeground = _adaptiveToneForeground(
        background: background,
        baseText: ui.textPrimary,
        tone: ui.success,
        brightness: brightness,
      );
      return _ToneStyle(
        backgroundTop: Color.alphaBlend(
          Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.07 : 0.28,
          ),
          background,
        ),
        backgroundBottom: background,
        foreground: successForeground,
        border: successForeground.withValues(alpha: 0.22),
        shadow: ui.success,
        iconSurface: successForeground.withValues(alpha: 0.13),
        icon: Icons.task_alt_rounded,
        progressBackground: successForeground.withValues(alpha: 0.10),
        progressForeground: successForeground.withValues(alpha: 0.96),
      );
    case OrbiStatusTone.error:
      final background = Color.alphaBlend(
        ui.card.withValues(alpha: 0.88),
        ui.dangerSoft.withValues(
          alpha: brightness == Brightness.dark ? 0.88 : 0.94,
        ),
      );
      final errorForeground = _adaptiveToneForeground(
        background: background,
        baseText: ui.textPrimary,
        tone: ui.danger,
        brightness: brightness,
      );
      return _ToneStyle(
        backgroundTop: Color.alphaBlend(
          Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.01 : 0.14,
          ),
          background,
        ),
        backgroundBottom: background,
        foreground: errorForeground,
        border: errorForeground.withValues(alpha: 0.26),
        shadow: ui.danger,
        iconSurface: errorForeground.withValues(alpha: 0.14),
        icon: Icons.warning_amber_rounded,
        progressBackground: errorForeground.withValues(alpha: 0.10),
        progressForeground: errorForeground.withValues(alpha: 0.96),
      );
    case OrbiStatusTone.info:
      final background = Color.alphaBlend(
        ui.card.withValues(alpha: 0.90),
        ui.accentSoft.withValues(
          alpha: brightness == Brightness.dark ? 0.68 : 0.82,
        ),
      );
      return _ToneStyle(
        backgroundTop: Color.alphaBlend(
          Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.04 : 0.20,
          ),
          background,
        ),
        backgroundBottom: background,
        foreground: _adaptiveToneForeground(
          background: background,
          baseText: ui.textPrimary,
          tone: ui.accent,
          brightness: brightness,
        ),
        border: ui.accent.withValues(alpha: 0.16),
        shadow: ui.accent,
        iconSurface: ui.accent.withValues(alpha: 0.10),
        icon: Icons.info_outline_rounded,
        progressBackground: ui.textPrimary.withValues(alpha: 0.10),
        progressForeground: ui.textPrimary.withValues(alpha: 0.94),
      );
  }
}

Color _adaptiveToneForeground({
  required Color background,
  required Color baseText,
  required Color tone,
  required Brightness brightness,
}) {
  final candidates = <Color>[
    baseText,
    Color.lerp(baseText, tone, brightness == Brightness.dark ? 0.18 : 0.28) ??
        baseText,
    Color.lerp(
          baseText,
          brightness == Brightness.dark ? Colors.white : Colors.black,
          brightness == Brightness.dark ? 0.06 : 0.14,
        ) ??
        baseText,
    tone,
  ];

  Color best = candidates.first;
  double bestRatio = _contrastRatio(background, best);
  for (final candidate in candidates.skip(1)) {
    final ratio = _contrastRatio(background, candidate);
    if (ratio > bestRatio) {
      best = candidate;
      bestRatio = ratio;
    }
  }
  return best;
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

String _toneLabel(OrbiStatusTone tone) {
  switch (tone) {
    case OrbiStatusTone.success:
      return 'Success';
    case OrbiStatusTone.error:
      return 'Error';
    case OrbiStatusTone.info:
      return 'Information';
  }
}
