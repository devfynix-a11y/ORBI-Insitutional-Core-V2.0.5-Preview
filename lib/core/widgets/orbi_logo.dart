import 'package:flutter/material.dart';

class OrbiLogoV2 extends StatelessWidget {
  const OrbiLogoV2({
    super.key,
    this.width = 220,
    this.color,
    this.progress = 1,
    this.showWord = true,
  });

  static const _wordAsset = 'assets/icons/orbi_logo_v2_mask.png';
  static const _markAsset = 'assets/icons/orbi_logo_v2_mark_mask.png';
  static const _wordAspect = 305 / 683;
  static const _markAspect = 296 / 334;

  final double width;
  final Color? color;
  final double progress;
  final bool showWord;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoColor =
        color ?? (isDark ? const Color(0xFFF7FBFC) : const Color(0xFF073456));
    final clamped = progress.clamp(0.0, 1.0);
    final asset = showWord ? _wordAsset : _markAsset;
    final height = width * (showWord ? _wordAspect : _markAspect);

    Widget logo = ColorFiltered(
      colorFilter: ColorFilter.mode(logoColor, BlendMode.srcIn),
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (clamped < 1) {
      logo = ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: clamped,
          child: logo,
        ),
      );
    }

    return SizedBox(width: width, height: height, child: logo);
  }
}

class AnimatedOrbiLogoV2 extends StatefulWidget {
  const AnimatedOrbiLogoV2({
    super.key,
    this.width = 240,
    this.color,
    this.loop = true,
    this.showWord = true,
  });

  final double width;
  final Color? color;
  final bool loop;
  final bool showWord;

  @override
  State<AnimatedOrbiLogoV2> createState() => _AnimatedOrbiLogoV2State();
}

class _AnimatedOrbiLogoV2State extends State<AnimatedOrbiLogoV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (widget.loop && !_controller.isAnimating) {
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = reduceMotion ? 1.0 : _controller.value;
        if (!widget.showWord || reduceMotion) {
          return OrbiLogoV2(
            width: widget.width,
            color: widget.color,
            showWord: widget.showWord,
            progress: reduceMotion ? 1 : _stage(value, 0.04, 0.70),
          );
        }

        final fade = value < 0.94
            ? 1.0
            : 1 - Curves.easeIn.transform(_stage(value, 0.94, 1));

        return Opacity(
          opacity: fade,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              _LogoMaskSegment(
                width: widget.width,
                color: widget.color,
                bounds: const Rect.fromLTRB(0, 0, 0.515, 1),
                progress: _stage(value, 0.02, 0.28),
                reveal: _LogoReveal.centerOut,
              ),
              _LogoMaskSegment(
                width: widget.width,
                color: widget.color,
                bounds: const Rect.fromLTRB(0.455, 0, 0.645, 1),
                progress: _stage(value, 0.25, 0.46),
                reveal: _LogoReveal.bottomUp,
              ),
              _LogoMaskSegment(
                width: widget.width,
                color: widget.color,
                bounds: const Rect.fromLTRB(0.60, 0, 0.875, 1),
                progress: _stage(value, 0.43, 0.66),
              ),
              _LogoMaskSegment(
                width: widget.width,
                color: widget.color,
                bounds: const Rect.fromLTRB(0.845, 0.34, 1, 1),
                progress: _stage(value, 0.62, 0.77),
                reveal: _LogoReveal.bottomUp,
              ),
              _LogoMaskSegment(
                width: widget.width,
                color: widget.color,
                bounds: const Rect.fromLTRB(0.845, 0, 1, 0.43),
                progress: _stage(value, 0.74, 0.84),
                reveal: _LogoReveal.scale,
              ),
              Opacity(
                opacity: _stage(value, 0.82, 0.88),
                child: OrbiLogoV2(width: widget.width, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }

  double _stage(double value, double start, double end) {
    final local = ((value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }
}

enum _LogoReveal { horizontal, centerOut, bottomUp, scale }

class _LogoMaskSegment extends StatelessWidget {
  const _LogoMaskSegment({
    required this.width,
    required this.bounds,
    required this.progress,
    this.reveal = _LogoReveal.horizontal,
    this.color,
  });

  final double width;
  final Rect bounds;
  final double progress;
  final _LogoReveal reveal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final logo = OrbiLogoV2(width: width, color: color);
    final clipped = ClipPath(
      clipper: _LogoSegmentClipper(
        bounds: bounds,
        progress: progress,
        reveal: reveal,
      ),
      child: logo,
    );

    if (reveal != _LogoReveal.scale) return clipped;
    return Transform.scale(
      scale: 0.72 + (0.28 * progress),
      alignment: Alignment(
        ((bounds.left + bounds.right) - 1).clamp(-1.0, 1.0),
        ((bounds.top + bounds.bottom) - 1).clamp(-1.0, 1.0),
      ),
      child: Opacity(opacity: progress, child: clipped),
    );
  }
}

class _LogoSegmentClipper extends CustomClipper<Path> {
  const _LogoSegmentClipper({
    required this.bounds,
    required this.progress,
    required this.reveal,
  });

  final Rect bounds;
  final double progress;
  final _LogoReveal reveal;

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTRB(
      bounds.left * size.width,
      bounds.top * size.height,
      bounds.right * size.width,
      bounds.bottom * size.height,
    );
    final amount = progress.clamp(0.0, 1.0);
    if (amount >= 0.999) {
      return Path()..addRect(rect);
    }

    switch (reveal) {
      case _LogoReveal.centerOut:
        final revealOval = Path()
          ..addOval(
            Rect.fromCenter(
              center: rect.center,
              width: rect.width * 1.45 * amount,
              height: rect.height * 1.45 * amount,
            ),
          );
        return Path.combine(
          PathOperation.intersect,
          Path()..addRect(rect),
          revealOval,
        );
      case _LogoReveal.bottomUp:
        return Path()..addRect(
          Rect.fromLTRB(
            rect.left,
            rect.bottom - (rect.height * amount),
            rect.right,
            rect.bottom,
          ),
        );
      case _LogoReveal.scale:
      case _LogoReveal.horizontal:
        return Path()..addRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width * amount, rect.height),
        );
    }
  }

  @override
  bool shouldReclip(covariant _LogoSegmentClipper oldClipper) {
    return oldClipper.bounds != bounds ||
        oldClipper.progress != progress ||
        oldClipper.reveal != reveal;
  }
}
