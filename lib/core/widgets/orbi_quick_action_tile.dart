import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiQuickActionTile extends StatelessWidget {
  const OrbiQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.assetPath,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool compact;
  final String? assetPath;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final accent = color ?? ui.accent;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 9 : 12,
            ),
            decoration: OrbiCardStyles.elevatedCardDecoration(
              context,
              radius: 18,
              accent: accent,
              branded: true,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 62 : 88),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 32 : 36,
                    height: compact ? 32 : 36,
                    decoration: OrbiCardStyles.iconBadgeDecoration(
                      context,
                      accent: accent,
                      radius: 14,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: compact ? 19 : 21,
                        height: compact ? 19 : 21,
                        child: assetPath == null
                            ? Icon(icon, color: accent, size: compact ? 19 : 21)
                            : Padding(
                                padding: const EdgeInsets.all(1),
                                child: SvgPicture.asset(
                                  assetPath!,
                                  colorFilter: ColorFilter.mode(
                                    accent,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ui.textPrimary,
                      fontSize: compact ? 10.5 : 11.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ui.textMuted,
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
