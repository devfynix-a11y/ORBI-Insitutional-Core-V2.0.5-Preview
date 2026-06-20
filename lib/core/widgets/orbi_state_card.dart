import 'package:flutter/material.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color? accentColor;
  final Color? accentBackground;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const OrbiStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accentColor,
    this.accentBackground,
    this.action,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final resolvedAccent = accentColor ?? ui.iconMuted;
    final resolvedBackground = accentBackground;
    final compact = MediaQuery.sizeOf(context).width < 380;

    final card = Container(
      width: double.infinity,
      decoration: OrbiCardStyles.elevatedCardDecoration(
        context,
        radius: 20,
        accent: resolvedAccent,
        branded: true,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: resolvedBackground == null
                  ? OrbiCardStyles.iconBadgeDecoration(
                      context,
                      accent: resolvedAccent,
                      radius: 15,
                    )
                  : BoxDecoration(
                      color: resolvedBackground,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: resolvedAccent.withValues(
                          alpha: isDark ? 0.28 : 0.22,
                        ),
                      ),
                    ),
              child: Icon(icon, color: resolvedAccent, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: compact ? 13 : 13.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                maxLines: compact ? 4 : 5,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 14),
              Center(child: action!),
            ],
          ],
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
      child: card,
      builder: (context, progress, child) {
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - progress)),
            child: Transform.scale(
              scale: 0.99 + (0.01 * progress),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
