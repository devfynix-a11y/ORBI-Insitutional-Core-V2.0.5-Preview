import 'package:flutter/material.dart';

import 'orbi_quick_action_tile.dart';

class OrbiQuickActionRowItem {
  const OrbiQuickActionRowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.assetPath,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final String? assetPath;
  final Color? color;
}

class OrbiQuickActionRow extends StatelessWidget {
  const OrbiQuickActionRow({
    super.key,
    required this.items,
    this.compact = false,
    this.spacing = 8,
  });

  final List<OrbiQuickActionRowItem> items;
  final bool compact;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: OrbiQuickActionTile(
              icon: items[i].icon,
              assetPath: items[i].assetPath,
              color: items[i].color,
              label: items[i].label,
              subtitle: items[i].subtitle,
              onTap: items[i].onTap,
              compact: compact,
            ),
          ),
          if (i != items.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}
