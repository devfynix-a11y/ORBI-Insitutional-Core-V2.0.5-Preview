import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/orbi_theme.dart';
import '../utils/money_format.dart';

class MoneyText extends StatelessWidget {
  final String value;
  final int maxLines;
  final TextAlign textAlign;
  final double mainFontSize;
  final double sideFontSize;
  final FontWeight fontWeight;
  final Color? mainColor;
  final Color? sideColor;
  final bool fitToWidth;
  final bool animateValue;
  final Duration animationDuration;

  const MoneyText({
    super.key,
    required this.value,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.mainFontSize = 32,
    this.sideFontSize = 18,
    this.fontWeight = FontWeight.w800,
    this.mainColor,
    this.sideColor,
    this.fitToWidth = true,
    this.animateValue = true,
    this.animationDuration = const Duration(milliseconds: 950),
  });

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final hidden = _isHiddenMoneyValue(value);
    if (hidden) {
      return _PrivateMoneyMask(
        height: mainFontSize * 1.08,
        color: mainColor ?? ui.textPrimary,
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : textAlign == TextAlign.end
            ? Alignment.centerRight
            : Alignment.centerLeft,
      );
    }
    final animatedPattern = _AnimatedMoneyPattern.tryParse(value);
    final shouldAnimate =
        animateValue &&
        animatedPattern != null &&
        !MediaQuery.disableAnimationsOf(context);

    if (!shouldAnimate) {
      return _buildResponsiveText(context, value);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: animatedPattern.rawValue),
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return _buildResponsiveText(
          context,
          animatedPattern.format(animatedValue),
        );
      },
    );
  }

  Widget _buildResponsiveText(BuildContext context, String displayValue) {
    final text = _buildMoneyText(context, displayValue);

    if (!fitToWidth || maxLines != 1) {
      return text;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return text;
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: textAlign == TextAlign.center
                ? Alignment.center
                : textAlign == TextAlign.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: text,
          ),
        );
      },
    );
  }

  Widget _buildMoneyText(BuildContext context, String displayValue) {
    final ui = OrbiTheme.uiOf(context);
    final parts = splitMoneyParts(displayValue);

    TextStyle moneyStyle({
      required Color color,
      required double fontSize,
      required FontWeight weight,
      double letterSpacing = 0,
    }) {
      return GoogleFonts.robotoMono(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }

    final text = Text.rich(
      TextSpan(
        children: [
          if (parts.prefix.isNotEmpty)
            TextSpan(
              text: parts.prefix,
              style: moneyStyle(
                color: sideColor ?? ui.textMuted,
                fontSize: sideFontSize,
                weight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: parts.main,
            style: moneyStyle(
              color: mainColor ?? ui.textPrimary,
              fontSize: mainFontSize,
              weight: fontWeight,
              letterSpacing: -0.9,
            ),
          ),
          if (parts.decimals.isNotEmpty)
            TextSpan(
              text: parts.decimals,
              style: moneyStyle(
                color: sideColor ?? ui.textMuted,
                fontSize: sideFontSize,
                weight: FontWeight.w700,
              ),
            ),
          if (parts.suffix.isNotEmpty)
            TextSpan(
              text: parts.suffix,
              style: moneyStyle(
                color: sideColor ?? ui.textMuted,
                fontSize: sideFontSize,
                weight: FontWeight.w700,
              ),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: fitToWidth && maxLines == 1
          ? TextOverflow.visible
          : TextOverflow.ellipsis,
      textAlign: textAlign,
    );

    return text;
  }

  bool _isHiddenMoneyValue(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    return normalized.isNotEmpty &&
        (normalized.contains('•') ||
            normalized.contains('*') ||
            normalized.contains('●'));
  }
}

class _PrivateMoneyMask extends StatefulWidget {
  const _PrivateMoneyMask({
    required this.height,
    required this.color,
    required this.alignment,
  });

  final double height;
  final Color color;
  final Alignment alignment;

  @override
  State<_PrivateMoneyMask> createState() => _PrivateMoneyMaskState();
}

class _PrivateMoneyMaskState extends State<_PrivateMoneyMask>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
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
    final width = (widget.height * 3.7).clamp(76.0, 180.0);
    return Align(
      alignment: widget.alignment,
      child: Semantics(
        label: 'Balance hidden',
        child: SizedBox(
          width: width,
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final travel = (_controller.value * 2) - 1;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _maskBar(
                              widget.color.withValues(alpha: 0.66),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: _maskBar(
                              widget.color.withValues(alpha: 0.38),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _maskBar(
                              widget.color.withValues(alpha: 0.24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FractionalTranslation(
                      translation: Offset(travel, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              ui.accent.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.26),
                              ui.accent.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _maskBar(Color color) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        height: widget.height * 0.48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.height),
        ),
      ),
    );
  }
}

class _AnimatedMoneyPattern {
  const _AnimatedMoneyPattern({
    required this.prefix,
    required this.suffix,
    required this.rawValue,
    required this.fractionDigits,
    required this.compactUnit,
  });

  final String prefix;
  final String suffix;
  final double rawValue;
  final int fractionDigits;
  final String? compactUnit;

  static _AnimatedMoneyPattern? tryParse(String value) {
    final compactMatch = RegExp(
      r'^([^\d-]*)(-?[\d,]+(?:\.\d+)?)([KMBT])(\s+.+)?$',
    ).firstMatch(value);
    if (compactMatch != null) {
      final numeric = compactMatch.group(2)!.replaceAll(',', '');
      final parsed = double.tryParse(numeric);
      final unit = compactMatch.group(3)!;
      if (parsed == null) return null;
      final multiplier = _multiplierFor(unit);
      return _AnimatedMoneyPattern(
        prefix: compactMatch.group(1) ?? '',
        suffix: compactMatch.group(4) ?? '',
        rawValue: parsed * multiplier,
        fractionDigits: _fractionDigitsFor(numeric),
        compactUnit: unit,
      );
    }

    final exactMatch = RegExp(
      r'^([^\d-]*)(-?[\d,]+)(\.\d+)?(\s+.+)?$',
    ).firstMatch(value);
    if (exactMatch == null) return null;
    final integer = exactMatch.group(2)?.replaceAll(',', '') ?? '';
    final decimals = exactMatch.group(3) ?? '';
    final parsed = double.tryParse('$integer$decimals');
    if (parsed == null) return null;
    return _AnimatedMoneyPattern(
      prefix: exactMatch.group(1) ?? '',
      suffix: exactMatch.group(4) ?? '',
      rawValue: parsed,
      fractionDigits: decimals.isEmpty ? 0 : decimals.length - 1,
      compactUnit: null,
    );
  }

  String format(double animatedValue) {
    if (compactUnit != null) {
      final multiplier = _multiplierFor(compactUnit!);
      final scaled = animatedValue / multiplier;
      final formatter = NumberFormat.decimalPattern()
        ..minimumFractionDigits = 0
        ..maximumFractionDigits = fractionDigits;
      return '$prefix${formatter.format(scaled)}$compactUnit$suffix';
    }

    final formatter = NumberFormat.decimalPattern()
      ..minimumFractionDigits = fractionDigits
      ..maximumFractionDigits = fractionDigits;
    return '$prefix${formatter.format(animatedValue)}$suffix';
  }

  static double _multiplierFor(String unit) {
    switch (unit) {
      case 'T':
        return 1000000000000;
      case 'B':
        return 1000000000;
      case 'M':
        return 1000000;
      case 'K':
      default:
        return 1000;
    }
  }

  static int _fractionDigitsFor(String numeric) {
    final parts = numeric.split('.');
    return parts.length > 1 ? parts[1].length : 0;
  }
}
