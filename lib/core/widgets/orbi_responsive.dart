import 'dart:math' as math;

import 'package:flutter/material.dart';

class OrbiResponsive {
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 380;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 700;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 12,
    double bottom = 24,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1280
        ? 32.0
        : width >= 960
        ? 24.0
        : width >= 600
        ? 20.0
        : 16.0;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static double contentMaxWidth(BuildContext context, {double max = 1180}) {
    return math.min(MediaQuery.sizeOf(context).width, max);
  }
}

class OrbiResponsiveContent extends StatelessWidget {
  const OrbiResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
