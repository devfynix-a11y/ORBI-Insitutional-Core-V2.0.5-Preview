import 'package:flutter/material.dart';

import 'orbi_background.dart';
import 'orbi_logo.dart';

class OrbiLoadingLanding extends StatelessWidget {
  final String subtitle;
  final String status;
  final String? detail;

  const OrbiLoadingLanding({
    super.key,
    required this.subtitle,
    required this.status,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoWidth = shortestSide.clamp(280.0, 430.0) * 0.74;

    return OrbiBackground(
      padding: EdgeInsets.zero,
      child: Center(
        child: RepaintBoundary(
          child: AnimatedOrbiLogoV2(width: logoWidth, loop: true),
        ),
      ),
    );
  }
}
