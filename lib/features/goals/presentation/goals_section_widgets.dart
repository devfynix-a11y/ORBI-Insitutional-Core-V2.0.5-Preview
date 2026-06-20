import 'package:flutter/material.dart';

import '../../../core/widgets/orbi_empty_state.dart';
import 'goals_carousel_widgets.dart';

class GoalsCarouselSection extends StatelessWidget {
  const GoalsCarouselSection({
    super.key,
    required this.items,
    required this.controller,
    required this.activeIndex,
    required this.onPageChanged,
    required this.onPauseChanged,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.height,
  });

  final List<Widget> items;
  final PageController controller;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onPauseChanged;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return OrbiEmptyStateCard(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return GoalsCardCarousel(
      controller: controller,
      activeIndex: activeIndex,
      onPageChanged: onPageChanged,
      onPauseChanged: onPauseChanged,
      height: height,
      children: items,
    );
  }
}
