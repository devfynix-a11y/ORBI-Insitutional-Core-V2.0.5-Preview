import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final Color? accentColor;
  final bool branded;

  const OrbiSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.elevated = true,
    this.accentColor,
    this.branded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final compact = MediaQuery.sizeOf(context).width < 380;
    final effectiveRadius = compact ? radius.clamp(14, 20).toDouble() : radius;
    return Container(
      width: double.infinity,
      decoration: OrbiCardStyles.elevatedCardDecoration(
        context,
        radius: effectiveRadius,
        elevated: elevated,
        accent: accentColor,
        branded: branded,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: branded ? 12 : 8,
            sigmaY: branded ? 12 : 8,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.white).withValues(
                        alpha: isDark ? 0.018 : 0.035,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isDark)
                Positioned(
                  right: -46,
                  top: -64,
                  child: IgnorePointer(
                    child: Container(
                      width: 122,
                      height: 122,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (accentColor ?? ui.accent).withValues(
                          alpha: branded ? 0.075 : 0.045,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isDark)
                Positioned(
                  right: -54,
                  top: -70,
                  child: IgnorePointer(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (accentColor ?? ui.accent).withValues(
                          alpha: branded ? 0.11 : 0.07,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: compact ? const EdgeInsets.all(14) : padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
