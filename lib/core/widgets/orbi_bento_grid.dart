import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/orbi_card_styles.dart';
import '../theme/orbi_theme.dart';

class OrbiBentoItem {
  const OrbiBentoItem({
    required this.child,
    this.columns = 1,
    this.rows = 1,
    this.accent,
    this.branded = false,
    this.framed = true,
    this.onTap,
  });

  final Widget child;
  final int columns;
  final int rows;
  final Color? accent;
  final bool branded;
  final bool framed;
  final VoidCallback? onTap;
}

class OrbiBentoGrid extends StatelessWidget {
  const OrbiBentoGrid({
    super.key,
    required this.items,
    this.spacing = 14,
    this.minTileHeight = 148,
  });

  final List<OrbiBentoItem> items;
  final double spacing;
  final double minTileHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 4
            : width >= 680
            ? 2
            : 1;
        final tileWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final span = item.columns.clamp(1, columns);
            final itemWidth =
                (tileWidth * span) + (spacing * math.max(0, span - 1));
            final targetHeight = item.rows <= 1
                ? null
                : (minTileHeight * item.rows) + (spacing * (item.rows - 1));
            return SizedBox(
              width: itemWidth,
              height: targetHeight,
              child: item.framed
                  ? OrbiBentoCard(
                      accent: item.accent,
                      branded: item.branded,
                      delay: Duration(milliseconds: 70 + (index * 75)),
                      onTap: item.onTap,
                      child: item.child,
                    )
                  : OrbiBentoReveal(
                      delay: Duration(milliseconds: 70 + (index * 75)),
                      child: item.child,
                    ),
            );
          }),
        );
      },
    );
  }
}

class OrbiBentoReveal extends StatelessWidget {
  const OrbiBentoReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _BentoReveal(delay: delay, child: child);
  }
}

class OrbiBentoCard extends StatelessWidget {
  const OrbiBentoCard({
    super.key,
    required this.child,
    this.accent,
    this.branded = false,
    this.delay = Duration.zero,
    this.onTap,
  });

  final Widget child;
  final Color? accent;
  final bool branded;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: OrbiCardStyles.elevatedCardDecoration(
        context,
        radius: 24,
        accent: accent ?? ui.accent,
        branded: branded,
        elevated: true,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.018
                            : 0.040,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -42,
                top: -46,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (accent ?? ui.accent).withValues(
                        alpha: branded ? 0.10 : 0.045,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.all(14), child: child),
            ],
          ),
        ),
      ),
    );

    final tappable = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap?.call();
              },
              child: card,
            ),
          );

    if (MediaQuery.disableAnimationsOf(context)) return tappable;
    return _BentoReveal(delay: delay, child: tappable);
  }
}

class _BentoReveal extends StatefulWidget {
  const _BentoReveal({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_BentoReveal> createState() => _BentoRevealState();
}

class _BentoRevealState extends State<_BentoReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
