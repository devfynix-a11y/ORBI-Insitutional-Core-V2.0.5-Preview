import 'package:flutter/material.dart';

/// Advanced color tokens for professional financial UI patterns
/// Extends OrbiUiTokens with semantic states, interactive feedback, and specialized colors
@immutable
class OrbiAdvancedTokens extends ThemeExtension<OrbiAdvancedTokens> {
  // --- Semantic Information States ---
  final Color info;
  final Color infoSoft;
  final Color infoStrong;

  // --- Disabled/Inactive States ---
  final Color disabled;
  final Color disabledText;
  final Color disabledBorder;

  // --- Interactive Feedback States ---
  final Color hover;
  final Color pressed;
  final Color focus;
  final Color focusRing;

  // --- Specialized Financial UI ---
  final Color chatBubbleBot;
  final Color transactionPositive; // Incoming/Gain
  final Color transactionNegative; // Outgoing/Loss
  final Color transactionPending; // Awaiting confirmation
  final Color chartPositive;
  final Color chartNegative;
  final Color chartNeutral;

  // --- Premium/Elevated States ---
  final Color premiumAccent;
  final Color premiumGlow;

  // --- Shadow Colors (Multi-level) ---
  final Color shadowElevation1;
  final Color shadowElevation2;
  final Color shadowElevation3;

  // --- Gradient Definitions ---
  final Gradient elevatedGradient;
  final Gradient accentGradient;
  final Gradient warningGradient;

  const OrbiAdvancedTokens({
    required this.info,
    required this.infoSoft,
    required this.infoStrong,
    required this.disabled,
    required this.disabledText,
    required this.disabledBorder,
    required this.hover,
    required this.pressed,
    required this.focus,
    required this.focusRing,
    required this.chatBubbleBot,
    required this.transactionPositive,
    required this.transactionNegative,
    required this.transactionPending,
    required this.chartPositive,
    required this.chartNegative,
    required this.chartNeutral,
    required this.premiumAccent,
    required this.premiumGlow,
    required this.shadowElevation1,
    required this.shadowElevation2,
    required this.shadowElevation3,
    required this.elevatedGradient,
    required this.accentGradient,
    required this.warningGradient,
  });

  /// Light mode advanced tokens
  const OrbiAdvancedTokens.light()
    : info = const Color(0xFF196884),
      infoSoft = const Color(0x142596BE),
      infoStrong = const Color(0xFF0D3A4A),
      disabled = const Color(0xFFE9F4F8),
      disabledText = const Color(0xFF7EC1D9),
      disabledBorder = const Color(0x667EC1D9),
      hover = const Color(0xFFE9F4F8),
      pressed = const Color(0xFFD7ECF4),
      focus = const Color(0xFF2596BE),
      focusRing = const Color(0x332596BE),
      chatBubbleBot = const Color(0xFFFFFFFF),
      transactionPositive = const Color(0xFF2D8C5A),
      transactionNegative = const Color(0xFFE25A3A),
      transactionPending = const Color(0xFFC96F4A),
      chartPositive = const Color(0xFF2D8C5A),
      chartNegative = const Color(0xFFE25A3A),
      chartNeutral = const Color(0xFF0D3A4A),
      premiumAccent = const Color(0xFF2596BE),
      premiumGlow = const Color(0x262596BE),
      shadowElevation1 = const Color(0x0F03131D),
      shadowElevation2 = const Color(0x1803131D),
      shadowElevation3 = const Color(0x2403131D),
      elevatedGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFE9F4F8)],
      ),
      accentGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7EC1D9), Color(0xFF196884)],
      ),
      warningGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC96F4A), Color(0xFF0D3A4A)],
      );

  /// Dark mode advanced tokens
  const OrbiAdvancedTokens.dark()
    : info = const Color(0xFF42E2CF),
      infoSoft = const Color(0x2042E2CF),
      infoStrong = const Color(0xFFF2FBFA),
      disabled = const Color(0x66102834),
      disabledText = const Color(0xFF66818A),
      disabledBorder = const Color(0x4025404A),
      hover = const Color(0xCC0F3A42),
      pressed = const Color(0xE0071923),
      focus = const Color(0xFF42E2CF),
      focusRing = const Color(0x3342E2CF),
      chatBubbleBot = const Color(0xCC0B2029),
      transactionPositive = const Color(0xFF6DE0A8),
      transactionNegative = const Color(0xFFFF6B62),
      transactionPending = const Color(0xFFF2FBFA),
      chartPositive = const Color(0xFF6DE0A8),
      chartNegative = const Color(0xFFFF6B62),
      chartNeutral = const Color(0xFF769098),
      premiumAccent = const Color(0xFF75D7E8),
      premiumGlow = const Color(0x1F75D7E8),
      shadowElevation1 = const Color(0x28000000),
      shadowElevation2 = const Color(0x3A000000),
      shadowElevation3 = const Color(0x52000000),
      elevatedGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF173640), Color(0xFF071923)],
      ),
      accentGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF42E2CF), Color(0xFF00A7C2)],
      ),
      warningGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF233A41), Color(0xFF071923)],
      );

  @override
  OrbiAdvancedTokens copyWith({
    Color? info,
    Color? infoSoft,
    Color? infoStrong,
    Color? disabled,
    Color? disabledText,
    Color? disabledBorder,
    Color? hover,
    Color? pressed,
    Color? focus,
    Color? focusRing,
    Color? chatBubbleBot,
    Color? transactionPositive,
    Color? transactionNegative,
    Color? transactionPending,
    Color? chartPositive,
    Color? chartNegative,
    Color? chartNeutral,
    Color? premiumAccent,
    Color? premiumGlow,
    Color? shadowElevation1,
    Color? shadowElevation2,
    Color? shadowElevation3,
    Gradient? elevatedGradient,
    Gradient? accentGradient,
    Gradient? warningGradient,
  }) {
    return OrbiAdvancedTokens(
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      infoStrong: infoStrong ?? this.infoStrong,
      disabled: disabled ?? this.disabled,
      disabledText: disabledText ?? this.disabledText,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      focus: focus ?? this.focus,
      focusRing: focusRing ?? this.focusRing,
      chatBubbleBot: chatBubbleBot ?? this.chatBubbleBot,
      transactionPositive: transactionPositive ?? this.transactionPositive,
      transactionNegative: transactionNegative ?? this.transactionNegative,
      transactionPending: transactionPending ?? this.transactionPending,
      chartPositive: chartPositive ?? this.chartPositive,
      chartNegative: chartNegative ?? this.chartNegative,
      chartNeutral: chartNeutral ?? this.chartNeutral,
      premiumAccent: premiumAccent ?? this.premiumAccent,
      premiumGlow: premiumGlow ?? this.premiumGlow,
      shadowElevation1: shadowElevation1 ?? this.shadowElevation1,
      shadowElevation2: shadowElevation2 ?? this.shadowElevation2,
      shadowElevation3: shadowElevation3 ?? this.shadowElevation3,
      elevatedGradient: elevatedGradient ?? this.elevatedGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      warningGradient: warningGradient ?? this.warningGradient,
    );
  }

  @override
  OrbiAdvancedTokens lerp(ThemeExtension<OrbiAdvancedTokens>? other, double t) {
    if (other is! OrbiAdvancedTokens) return this;
    return OrbiAdvancedTokens(
      info: Color.lerp(info, other.info, t) ?? info,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t) ?? infoSoft,
      infoStrong: Color.lerp(infoStrong, other.infoStrong, t) ?? infoStrong,
      disabled: Color.lerp(disabled, other.disabled, t) ?? disabled,
      disabledText:
          Color.lerp(disabledText, other.disabledText, t) ?? disabledText,
      disabledBorder:
          Color.lerp(disabledBorder, other.disabledBorder, t) ?? disabledBorder,
      hover: Color.lerp(hover, other.hover, t) ?? hover,
      pressed: Color.lerp(pressed, other.pressed, t) ?? pressed,
      focus: Color.lerp(focus, other.focus, t) ?? focus,
      focusRing: Color.lerp(focusRing, other.focusRing, t) ?? focusRing,
      chatBubbleBot:
          Color.lerp(chatBubbleBot, other.chatBubbleBot, t) ?? chatBubbleBot,
      transactionPositive:
          Color.lerp(transactionPositive, other.transactionPositive, t) ??
          transactionPositive,
      transactionNegative:
          Color.lerp(transactionNegative, other.transactionNegative, t) ??
          transactionNegative,
      transactionPending:
          Color.lerp(transactionPending, other.transactionPending, t) ??
          transactionPending,
      chartPositive:
          Color.lerp(chartPositive, other.chartPositive, t) ?? chartPositive,
      chartNegative:
          Color.lerp(chartNegative, other.chartNegative, t) ?? chartNegative,
      chartNeutral:
          Color.lerp(chartNeutral, other.chartNeutral, t) ?? chartNeutral,
      premiumAccent:
          Color.lerp(premiumAccent, other.premiumAccent, t) ?? premiumAccent,
      premiumGlow: Color.lerp(premiumGlow, other.premiumGlow, t) ?? premiumGlow,
      shadowElevation1:
          Color.lerp(shadowElevation1, other.shadowElevation1, t) ??
          shadowElevation1,
      shadowElevation2:
          Color.lerp(shadowElevation2, other.shadowElevation2, t) ??
          shadowElevation2,
      shadowElevation3:
          Color.lerp(shadowElevation3, other.shadowElevation3, t) ??
          shadowElevation3,
      elevatedGradient: elevatedGradient, // Gradients don't lerp
      accentGradient: accentGradient,
      warningGradient: warningGradient,
    );
  }
}
