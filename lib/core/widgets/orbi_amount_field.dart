import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/orbi_theme.dart';

class OrbiAmountField extends StatefulWidget {
  const OrbiAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '0.00',
    this.helperText,
    this.currency,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;
  final String? currency;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  State<OrbiAmountField> createState() => _OrbiAmountFieldState();
}

class _OrbiAmountFieldState extends State<OrbiAmountField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
    widget.controller.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAmountChanged);
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) setState(() {});
  }

  void _handleAmountChanged() {
    if (mounted) setState(() {});
  }

  double _responsiveFontSize(double availableWidth) {
    const preferredSize = 21.0;
    const minimumSize = 13.0;
    final currency = widget.currency?.trim() ?? '';
    final rawValue = widget.controller.text.isEmpty
        ? widget.hint
        : widget.controller.text;
    final displayValue = currency.isEmpty ? rawValue : '$currency $rawValue';
    final painter = TextPainter(
      text: TextSpan(
        text: displayValue,
        style: GoogleFonts.robotoMono(
          fontSize: preferredSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.55,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final usableWidth = (availableWidth - 46).clamp(80.0, double.infinity);
    if (painter.width <= usableWidth) return preferredSize;
    return (preferredSize * usableWidth / painter.width).clamp(
      minimumSize,
      preferredSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final focused = _focusNode.hasFocus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _responsiveFontSize(
          constraints.hasBoundedWidth ? constraints.maxWidth : 360,
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: ui.accent.withValues(alpha: 0.13),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            validator: widget.validator,
            style: GoogleFonts.robotoMono(
              color: ui.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.55,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              helperText: widget.helperText,
              prefixText:
                  widget.currency == null || widget.currency!.trim().isEmpty
                  ? null
                  : '${widget.currency!.trim()} ',
              labelStyle: GoogleFonts.robotoMono(
                color: focused ? ui.accent : ui.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.15,
              ),
              floatingLabelStyle: GoogleFonts.robotoMono(
                color: ui.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              hintStyle: GoogleFonts.robotoMono(
                color: ui.textMuted.withValues(alpha: 0.58),
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              prefixStyle: GoogleFonts.robotoMono(
                color: focused ? ui.accent : ui.textMuted,
                fontSize: fontSize.clamp(12, 14),
                fontWeight: FontWeight.w800,
              ),
              filled: true,
              fillColor: focused
                  ? ui.accentSoft.withValues(alpha: 0.44)
                  : ui.cardMuted.withValues(alpha: 0.72),
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: ui.border.withValues(alpha: 0.76),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: ui.accent, width: 1.35),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: ui.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: ui.danger, width: 1.35),
              ),
            ),
          ),
        );
      },
    );
  }
}
