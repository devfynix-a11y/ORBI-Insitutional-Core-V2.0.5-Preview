import 'package:flutter/material.dart';

import '../theme/orbi_theme.dart';

class OrbiShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const OrbiShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  State<OrbiShimmerBlock> createState() => _OrbiShimmerBlockState();
}

class _OrbiShimmerBlockState extends State<OrbiShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + (t * 2.4), -0.2),
              end: Alignment(0.2 + (t * 2.4), 0.2),
              colors: [ui.cardMuted, ui.cardStrong, ui.cardMuted],
            ),
          ),
        );
      },
    );
  }
}

class OrbiShimmerLines extends StatelessWidget {
  final List<double> lines;
  final double spacing;

  const OrbiShimmerLines({super.key, required this.lines, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          OrbiShimmerBlock(width: double.infinity, height: line),
          SizedBox(height: spacing),
        ],
      ],
    );
  }
}
