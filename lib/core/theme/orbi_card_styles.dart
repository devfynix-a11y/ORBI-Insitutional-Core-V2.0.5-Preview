import 'package:flutter/material.dart';

import 'orbi_theme.dart';

enum OrbiGradientCardVariant { oceanic, sunset, neon, passion }

class OrbiCardStyles {
  const OrbiCardStyles._();

  static const Color brandBlue = Color(0xFF0F6C7A);
  static const Color brandBlueDeep = Color(0xFF0A5C63);
  static const Color brandText = Color(0xFF1E2F3A);
  static const Color darkBase = Color(0xFF0B131A);
  static const Color darkSurface = Color(0xFF15232E);
  static const Color darkGlow = Color(0xFF4AC5F2);

  static LinearGradient _lightVariantGradient(OrbiGradientCardVariant variant) {
    switch (variant) {
      case OrbiGradientCardVariant.sunset:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8D73), Color(0xFFFFA982), Color(0xFFFFBE93)],
          stops: [0.0, 0.55, 1.0],
        );
      case OrbiGradientCardVariant.neon:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF673BD7), Color(0xFF5365E8), Color(0xFF3289E8)],
          stops: [0.0, 0.50, 1.0],
        );
      case OrbiGradientCardVariant.passion:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEE5C91), Color(0xFFF36E91), Color(0xFFF77F89)],
          stops: [0.0, 0.56, 1.0],
        );
      case OrbiGradientCardVariant.oceanic:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF32B7D0), Color(0xFF169BB9), Color(0xFF087F9F)],
          stops: [0.0, 0.48, 1.0],
        );
    }
  }

  static LinearGradient _darkVariantGradient(OrbiGradientCardVariant variant) {
    switch (variant) {
      case OrbiGradientCardVariant.sunset:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B1B24),
            Color(0xFF533020),
            Color(0xFF182633),
            Color(0xFF071018),
          ],
          stops: [0.0, 0.34, 0.72, 1.0],
        );
      case OrbiGradientCardVariant.neon:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF28205B),
            Color(0xFF1B4B73),
            Color(0xFF112A3A),
            Color(0xFF071018),
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
        );
      case OrbiGradientCardVariant.passion:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF401B35),
            Color(0xFF6A294C),
            Color(0xFF182633),
            Color(0xFF071018),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        );
      case OrbiGradientCardVariant.oceanic:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E4B64),
            Color(0xFF116E86),
            Color(0xFF123044),
            Color(0xFF071018),
          ],
          stops: [0.0, 0.36, 0.70, 1.0],
        );
    }
  }

  static Color lightVariantAccent(OrbiGradientCardVariant variant) {
    switch (variant) {
      case OrbiGradientCardVariant.sunset:
        return const Color(0xFFFFB08F);
      case OrbiGradientCardVariant.neon:
        return const Color(0xFF7F58E4);
      case OrbiGradientCardVariant.passion:
        return const Color(0xFFF97CB3);
      case OrbiGradientCardVariant.oceanic:
        return const Color(0xFF37C2E3);
    }
  }

  static LinearGradient primaryHeroGradient(
    BuildContext context, {
    OrbiGradientCardVariant variant = OrbiGradientCardVariant.oceanic,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _darkVariantGradient(variant)
        : _lightVariantGradient(variant);
  }

  static BoxDecoration primaryHeroDecoration(
    BuildContext context, {
    double radius = 24,
    Color? borderColor,
    OrbiGradientCardVariant variant = OrbiGradientCardVariant.oceanic,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final effectiveBorder =
        borderColor ??
        (isDark ? ui.accent.withValues(alpha: 0.30) : Colors.transparent);

    return BoxDecoration(
      gradient: primaryHeroGradient(context, variant: variant),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: effectiveBorder),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: lightVariantAccent(variant).withValues(alpha: 0.14),
                blurRadius: 34,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: lightVariantAccent(variant).withValues(alpha: 0.16),
                blurRadius: 34,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  static BoxDecoration elevatedCardDecoration(
    BuildContext context, {
    double radius = 16,
    bool elevated = true,
    Color? accent,
    bool branded = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final resolvedAccent = accent ?? ui.accent;
    final lightColors = branded
        ? <Color>[
            Color.lerp(ui.card, resolvedAccent, 0.015) ?? ui.card,
            Color.lerp(ui.cardMuted, resolvedAccent, 0.04) ?? ui.cardMuted,
          ]
        : <Color>[Colors.white, ui.cardMuted];
    return BoxDecoration(
      gradient: isDark
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: branded
                  ? [
                      Color.lerp(darkSurface, resolvedAccent, 0.14) ??
                          darkSurface,
                      darkSurface,
                      ui.card,
                    ]
                  : [
                      Color.lerp(ui.cardStrong, resolvedAccent, 0.045) ??
                          ui.cardStrong,
                      ui.card,
                    ],
              stops: branded ? const [0.0, 0.52, 1.0] : null,
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: lightColors,
              stops: const [0.0, 1.0],
            ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? resolvedAccent.withValues(alpha: 0.14)
            : resolvedAccent.withValues(alpha: branded ? 0.08 : 0.05),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: elevated ? 0.26 : 0.16),
                blurRadius: elevated ? 22 : 12,
                offset: Offset(0, elevated ? 12 : 6),
              ),
              if (branded)
                BoxShadow(
                  color: resolvedAccent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 5),
                ),
            ]
          : elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.075),
                blurRadius: branded ? 22 : 16,
                offset: Offset(0, branded ? 12 : 8),
              ),
              if (branded)
                BoxShadow(
                  color: resolvedAccent.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 7),
                ),
            ]
          : null,
    );
  }

  static BoxDecoration activityCardDecoration(
    BuildContext context, {
    required Color accent,
    bool hero = false,
    double radius = 24,
    OrbiGradientCardVariant variant = OrbiGradientCardVariant.oceanic,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final lightHeroGradient = _lightVariantGradient(variant);
    return BoxDecoration(
      gradient: isDark
          ? (hero
                ? primaryHeroGradient(context)
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(ui.cardMuted, accent, 0.10) ?? ui.cardMuted,
                      ui.card,
                    ],
                  ))
          : (hero
                ? lightHeroGradient
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(ui.card, accent, 0.02) ?? ui.card,
                      Color.lerp(ui.cardMuted, accent, 0.035) ?? ui.cardMuted,
                    ],
                  )),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? accent.withValues(alpha: hero ? 0.22 : 0.14)
            : accent.withValues(alpha: hero ? 0.10 : 0.06),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: hero ? 0.34 : 0.24),
                blurRadius: hero ? 30 : 18,
                offset: Offset(0, hero ? 16 : 9),
              ),
              if (hero)
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 4),
                ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: hero ? 0.12 : 0.065),
                blurRadius: hero ? 28 : 18,
                offset: Offset(0, hero ? 16 : 9),
              ),
              if (hero)
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 6),
                ),
            ],
    );
  }

  static Color heroLineColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF4AC5F2).withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.18);
  }

  static Color heroNodeColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF4AC5F2).withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.24);
  }

  static BoxDecoration iconBadgeDecoration(
    BuildContext context, {
    required Color accent,
    double radius = 14,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.lerp(ui.cardStrong, accent, 0.18) ?? ui.cardStrong,
                ui.cardMuted,
              ]
            : [
                Color.lerp(ui.cardStrong, accent, 0.10) ?? ui.cardStrong,
                Color.lerp(ui.cardMuted, accent, 0.06) ?? ui.cardMuted,
              ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: isDark ? 0.28 : 0.18)),
    );
  }
}
