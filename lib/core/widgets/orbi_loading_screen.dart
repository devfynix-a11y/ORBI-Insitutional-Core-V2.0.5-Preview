/// Beautiful skeleton loading screen for ORBI
///
/// Usage:
/// ```dart
/// OrbiLoadingScreen(
///   title: 'Loading transactions...',
///   subtitle: 'Please wait',
/// )
/// ```
library;

import 'package:flutter/material.dart';
import '../theme/orbi_theme.dart';

class OrbiLoadingScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final int skeletonCount;
  final SkeletonType type;

  const OrbiLoadingScreen({
    super.key,
    this.title,
    this.subtitle,
    this.skeletonCount = 4,
    this.type = SkeletonType.card,
  });

  @override
  State<OrbiLoadingScreen> createState() => _OrbiLoadingScreenState();
}

enum SkeletonType { card, list, transaction }

class _OrbiLoadingScreenState extends State<OrbiLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title/subtitle
              if (widget.title != null || widget.subtitle != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null)
                      _SkeletonShimmer(
                        animation: _shimmerAnimation,
                        child: Container(
                          height: 24,
                          width: 200,
                          decoration: BoxDecoration(
                            color: ui.cardMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      _SkeletonShimmer(
                        animation: _shimmerAnimation,
                        child: Container(
                          height: 16,
                          width: 250,
                          decoration: BoxDecoration(
                            color: ui.cardMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Skeleton items based on type
              ...List.generate(widget.skeletonCount, (index) {
                switch (widget.type) {
                  case SkeletonType.card:
                    return _SkeletonCard(
                      animation: _shimmerAnimation,
                      index: index,
                    );
                  case SkeletonType.list:
                    return _SkeletonListItem(
                      animation: _shimmerAnimation,
                      index: index,
                    );
                  case SkeletonType.transaction:
                    return _SkeletonTransaction(
                      animation: _shimmerAnimation,
                      index: index,
                    );
                }
              }),

              const SizedBox(height: 16),

              // Loading indicator with pulsing dot
              Center(
                child: Column(
                  children: [
                    _PulsingDot(color: ui.accent),
                    const SizedBox(height: 12),
                    Text(
                      widget.title ?? 'Loading',
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonShimmer extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SkeletonShimmer({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(animation.value - 1, 0),
              end: Alignment(animation.value, 0),
              colors: [
                Colors.transparent,
                OrbiTheme.uiOf(context).accent.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _SkeletonCard({required this.animation, required this.index});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 12),
      child: _SkeletonShimmer(
        animation: animation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ui.cardMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ui.border.withValues(alpha: 0.42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: 150,
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 24,
                width: 200,
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonListItem extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _SkeletonListItem({required this.animation, required this.index});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 12),
      child: _SkeletonShimmer(
        animation: animation,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ui.cardMuted,
                shape: BoxShape.circle,
                border: Border.all(color: ui.border.withValues(alpha: 0.42)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ui.cardMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: ui.cardMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 16,
              width: 60,
              decoration: BoxDecoration(
                color: ui.cardMuted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTransaction extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _SkeletonTransaction({required this.animation, required this.index});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 12),
      child: _SkeletonShimmer(
        animation: animation,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ui.cardMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ui.border.withValues(alpha: 0.42)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 150,
                      decoration: BoxDecoration(
                        color: ui.card,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: ui.card,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    height: 14,
                    width: 70,
                    decoration: BoxDecoration(
                      color: ui.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 50,
                    decoration: BoxDecoration(
                      color: ui.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
