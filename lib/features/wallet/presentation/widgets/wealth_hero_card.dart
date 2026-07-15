import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_card_styles.dart';
import '../../../../core/widgets/orbi_brand_hero_card.dart';

class WealthHeroCard extends StatelessWidget {
  const WealthHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.child,
    this.trailing,
    this.variant = OrbiGradientCardVariant.oceanic,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? child;
  final Widget? trailing;
  final OrbiGradientCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return OrbiBrandHeroCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      variant: variant,
      child: child,
    );
  }
}
