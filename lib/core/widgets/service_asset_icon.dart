import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ServiceAssetIcon extends StatelessWidget {
  const ServiceAssetIcon({
    super.key,
    required this.assetPath,
    required this.color,
    this.size = 18,
    this.background = false,
  });

  final String assetPath;
  final Color color;
  final double size;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (!background) return icon;

    return Container(
      width: size + 14,
      height: size + 14,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: icon),
    );
  }
}
