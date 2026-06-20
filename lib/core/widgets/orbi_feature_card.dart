import 'package:flutter/material.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';
import 'orbi_section_card.dart';

class OrbiFeatureCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  const OrbiFeatureCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final accent = accentColor ?? ui.iconMuted;
    final compact = MediaQuery.sizeOf(context).width < 380;
    return OrbiSectionCard(
      padding: padding,
      accentColor: accent,
      branded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: OrbiCardStyles.iconBadgeDecoration(
                    context,
                    accent: accent,
                  ),
                  child: Icon(icon, size: compact ? 17 : 18, color: accent),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: compact ? 14 : 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
