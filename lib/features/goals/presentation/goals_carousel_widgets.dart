import 'package:flutter/material.dart';

import '../../../core/theme/orbi_theme.dart';

class GoalsCardCarousel extends StatelessWidget {
  const GoalsCardCarousel({
    super.key,
    required this.children,
    required this.controller,
    required this.activeIndex,
    required this.onPageChanged,
    required this.onPauseChanged,
    this.height = 332,
  });

  final List<Widget> children;
  final PageController controller;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onPauseChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                onPauseChanged(true);
              } else if (notification is ScrollEndNotification) {
                onPauseChanged(false);
              }
              return false;
            },
            child: PageView.builder(
              controller: controller,
              itemCount: children.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => onPauseChanged(true),
                  onTapUp: (_) => onPauseChanged(false),
                  onTapCancel: () => onPauseChanged(false),
                  onLongPressStart: (_) => onPauseChanged(true),
                  onLongPressEnd: (_) => onPauseChanged(false),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: children[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (children.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              children.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: activeIndex == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeIndex == index
                      ? OrbiTheme.uiOf(context).accent
                      : OrbiTheme.uiOf(
                          context,
                        ).borderStrong.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
