import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'orbi_advanced_tokens.dart';

class OrbiTheme {
  static const Color _orbiNavy = Color(0xFF1E2F3A);
  static const Color _orbiNavyDeep = Color(0xFF1E2F3A);
  static const Color _orbiTealRefined = Color(0xFF0F6C7A);
  static const Color _orbiTealBright = Color(0xFF44A5B5);
  static const Color _orbiAmber = Color(0xFFE57C3C);
  static const Color _orbiMint = Color(0xFFE6F2F5);
  static const Color _orbiFrost = Color(0xFFF9FBFE);
  static const Color _orbiRed = Color(0xFFD32F2F);
  static const Color _lightPrimary = _orbiTealRefined;
  static const Color _lightPrimaryDeep = Color(0xFF0A5C63);
  static const Color _lightSecondary = _orbiAmber;
  static const Color _lightTertiary = _orbiNavy;
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightMuted = Color(0xFF5E727E);
  static const Color _lightInk = _orbiNavyDeep;
  static const Color _lightOutline = Color(0xFFDCE4EC);
  static const Color _lightDanger = _orbiRed;
  static const Color _darkPrimary = Color(0xFF2596BE);
  static const Color _darkSecondary = Color(0xFF15232E);
  static const Color _darkTertiary = Color(0xFF4AC5F2);
  static const Color _darkBase = Color(0xFF0B131A);
  static const Color _darkSurface = Color(0xFF0B131A);
  static const Color _darkCard = Color(0xF015232E);
  static const Color _darkOutline = Color(0xFF274150);
  static const Color _darkText = Color(0xFFF2FBFA);
  static const Color _darkTextMuted = Color(0xFFA9BDC2);
  static const Color _darkDanger = Color(0xFFFF6B62);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _lightPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _lightPrimary,
          onPrimary: Colors.white,
          primaryContainer: _orbiMint,
          onPrimaryContainer: _lightPrimaryDeep,
          secondary: _lightSecondary,
          onSecondary: const Color(0xFF1C1B1F),
          secondaryContainer: const Color(0xFFF6E1D3),
          onSecondaryContainer: const Color(0xFF5C2E11),
          tertiary: _lightTertiary,
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFE8F0F4),
          onTertiaryContainer: _lightPrimaryDeep,
          surface: _lightCard,
          onSurface: _lightInk,
          error: _lightDanger,
          onError: Colors.white,
          outline: _lightOutline,
          outlineVariant: const Color(0xFFF2F5F9),
        );

    return _buildTheme(
      scheme,
      scaffold: _orbiFrost,
      card: _lightCard,
      muted: _lightMuted,
      divider: _lightOutline,
      focus: _orbiTealBright,
      shadow: const Color(0x14000000),
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _darkPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkPrimary,
          onPrimary: _darkBase,
          primaryContainer: const Color(0xFF123D51),
          onPrimaryContainer: _darkText,
          secondary: _darkSecondary,
          onSecondary: _darkText,
          secondaryContainer: const Color(0xFF15232E),
          onSecondaryContainer: _darkText,
          tertiary: _darkTertiary,
          onTertiary: _darkBase,
          tertiaryContainer: const Color(0xFF123D51),
          onTertiaryContainer: _darkText,
          surface: _darkSurface,
          onSurface: _darkText,
          error: _darkDanger,
          onError: _darkBase,
          outline: _darkOutline,
          outlineVariant: const Color(0xFF122A34),
        );

    return _buildTheme(
      scheme,
      scaffold: _darkBase,
      card: _darkCard,
      muted: _darkTextMuted,
      divider: _darkOutline,
      focus: _darkTertiary,
      shadow: const Color(0x52000000),
    );
  }

  static ThemeData _buildTheme(
    ColorScheme scheme, {
    required Color scaffold,
    required Color card,
    required Color muted,
    required Color divider,
    required Color focus,
    required Color shadow,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final ui = isDark ? const OrbiUiTokens.dark() : const OrbiUiTokens.light();
    final surfaces = isDark
        ? const OrbiSurfaceTokens.dark()
        : const OrbiSurfaceTokens.light();
    final advanced = isDark
        ? const OrbiAdvancedTokens.dark()
        : const OrbiAdvancedTokens.light();
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      dividerColor: divider,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _OrbiSharedAxisPageTransitionsBuilder(),
          TargetPlatform.iOS: _OrbiLiftPageTransitionsBuilder(),
          TargetPlatform.macOS: _OrbiLiftPageTransitionsBuilder(),
          TargetPlatform.linux: _OrbiSharedAxisPageTransitionsBuilder(),
          TargetPlatform.windows: _OrbiSharedAxisPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _OrbiSharedAxisPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );

    return base
        .copyWith(
          appBarTheme: AppBarTheme(
            backgroundColor: isDark
                ? Colors.transparent
                : ui.appBarMid.withValues(alpha: 0.99),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: scheme.onSurface,
            centerTitle: false,
            iconTheme: IconThemeData(color: ui.iconMuted),
            actionsIconTheme: IconThemeData(color: ui.iconMuted),
          ),
          iconTheme: IconThemeData(color: ui.iconMuted),
          primaryIconTheme: IconThemeData(color: ui.iconMuted),
          cardTheme: CardThemeData(
            color: card,
            elevation: 0,
            shadowColor: shadow,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: isDark
                    ? ui.border.withValues(alpha: 0.54)
                    : Colors.transparent,
              ),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: isDark
                ? ui.cardStrong.withValues(alpha: 0.98)
                : ui.card.withValues(alpha: 0.99),
            contentTextStyle: TextStyle(
              color: isDark ? Colors.white : ui.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            behavior: SnackBarBehavior.floating,
            elevation: 0,
            showCloseIcon: true,
            closeIconColor: isDark ? ui.textMuted : ui.iconMuted,
            actionTextColor: isDark ? scheme.primary : ui.iconMuted,
            disabledActionTextColor: muted.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isDark
                    ? ui.borderStrong.withValues(alpha: 0.72)
                    : ui.borderStrong.withValues(alpha: 0.62),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: isDark
                ? ui.cardMuted.withValues(alpha: 0.9)
                : ui.card.withValues(alpha: 0.98),
            labelStyle: GoogleFonts.robotoMono(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
            floatingLabelStyle: GoogleFonts.robotoMono(
              color: isDark ? ui.accent : ui.iconMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            hintStyle: GoogleFonts.robotoMono(
              color: muted.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
            prefixStyle: GoogleFonts.robotoMono(
              color: isDark ? ui.accent : ui.iconMuted,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            suffixStyle: GoogleFonts.robotoMono(
              color: muted,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark
                    ? ui.border.withValues(alpha: 0.88)
                    : divider.withValues(alpha: 0.94),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark ? ui.accent : ui.iconMuted,
                width: 1.55,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: ui.danger.withValues(alpha: 0.72)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: ui.danger, width: 1.55),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark
                    ? ui.border.withValues(alpha: 0.88)
                    : divider.withValues(alpha: 0.94),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? scheme.secondary : ui.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isDark
                    ? BorderSide(color: ui.borderStrong)
                    : BorderSide.none,
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? ui.textPrimary : ui.textPrimary,
              backgroundColor: isDark
                  ? ui.cardStrong.withValues(alpha: 0.84)
                  : ui.card.withValues(alpha: 0.94),
              side: BorderSide(color: isDark ? ui.borderStrong : divider),
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? ui.iconMuted : ui.textPrimary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: isDark ? ui.iconMuted : ui.iconMuted,
              backgroundColor: isDark
                  ? ui.cardStrong.withValues(alpha: 0.96)
                  : ui.cardMuted,
              surfaceTintColor: Colors.transparent,
              disabledForegroundColor: isDark
                  ? ui.textSoft.withValues(alpha: 0.72)
                  : null,
              disabledBackgroundColor: isDark
                  ? ui.cardStrong.withValues(alpha: 0.6)
                  : null,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: isDark ? scheme.primary : ui.accent,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          progressIndicatorTheme: ProgressIndicatorThemeData(
            color: isDark ? scheme.primary : scheme.secondary,
            linearTrackColor: isDark ? ui.border : null,
          ),
          chipTheme: base.chipTheme.copyWith(
            backgroundColor: isDark ? ui.cardMuted : ui.cardMuted,
            selectedColor: isDark ? scheme.primaryContainer : ui.accentSoft,
            disabledColor: divider.withValues(alpha: 0.5),
            side: BorderSide(color: divider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            labelStyle: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!isDark) return null;
                if (states.contains(WidgetState.selected)) {
                  return ui.accentSoft;
                }
                return ui.cardMuted;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (!isDark) return null;
                return states.contains(WidgetState.selected)
                    ? ui.accent
                    : ui.textMuted;
              }),
              side: WidgetStatePropertyAll(
                BorderSide(color: isDark ? ui.borderStrong : divider),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: ui.sheet,
            shadowColor: shadow,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              color: ui.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            contentTextStyle: textTheme.bodyMedium?.copyWith(
              color: ui.textMuted,
              height: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: ui.borderStrong.withValues(alpha: isDark ? 0.82 : 0.58),
              ),
            ),
          ),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: ui.sheet,
            modalBackgroundColor: ui.sheet,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: isDark
                ? const Color(0xF20B131A)
                : const Color(0xFFF5F8FC),
            surfaceTintColor: Colors.transparent,
            indicatorColor: isDark
                ? ui.accent.withValues(alpha: 0.22)
                : const Color(0x140F6C7A),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.selected)
                  ? (isDark ? scheme.primary : _orbiNavy)
                  : muted;
              return TextStyle(
                color: color,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.selected)
                  ? (isDark ? scheme.primary : _orbiNavy)
                  : ui.iconMuted;
              return IconThemeData(color: color);
            }),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: isDark
                ? const Color(0xF20B131A)
                : const Color(0xFFF5F8FC),
            selectedItemColor: isDark ? scheme.primary : _orbiNavy,
            unselectedItemColor: isDark
                ? const Color(0xFFB5BBC3)
                : ui.iconMuted,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            type: BottomNavigationBarType.fixed,
          ),
          tabBarTheme: TabBarThemeData(
            dividerColor: divider,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: isDark ? scheme.primary : scheme.secondary,
                width: 2.4,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            labelColor: isDark ? scheme.primary : _orbiNavy,
            unselectedLabelColor: muted,
          ),
          listTileTheme: ListTileThemeData(
            iconColor: ui.iconMuted,
            textColor: scheme.onSurface,
            tileColor: Colors.transparent,
            selectedColor: isDark ? scheme.primary : _orbiNavy,
          ),
          textTheme: textTheme.copyWith(
            displayLarge: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.displayLarge,
              color: isDark ? scheme.primary : textTheme.displayLarge?.color,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
            ),
            displayMedium: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.displayMedium,
              color: isDark ? scheme.primary : textTheme.displayMedium?.color,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
            headlineMedium: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.headlineMedium,
              color: isDark ? scheme.primary : textTheme.headlineMedium?.color,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
            headlineSmall: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.headlineSmall,
              color: isDark ? scheme.primary : textTheme.headlineSmall?.color,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
            titleLarge: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.titleLarge,
              color: isDark ? scheme.primary : textTheme.titleLarge?.color,
              fontWeight: FontWeight.w800,
            ),
            titleMedium: GoogleFonts.spaceGrotesk(
              textStyle: textTheme.titleMedium,
              color: isDark ? scheme.primary : textTheme.titleMedium?.color,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
          extensions: <ThemeExtension<dynamic>>[ui, surfaces, advanced],
        )
        .copyWith();
  }

  static OrbiSurfaceTokens surfacesOf(BuildContext context) {
    return Theme.of(context).extension<OrbiSurfaceTokens>()!;
  }

  static OrbiUiTokens uiOf(BuildContext context) {
    return Theme.of(context).extension<OrbiUiTokens>()!;
  }

  static OrbiAdvancedTokens advancedOf(BuildContext context) {
    return Theme.of(context).extension<OrbiAdvancedTokens>()!;
  }
}

class _OrbiSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const _OrbiSharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final forwardCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInOutQuart,
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(forwardCurve);
    final slide = Tween<Offset>(
      begin: const Offset(0.055, 0.018),
      end: Offset.zero,
    ).animate(forwardCurve);
    final scale = Tween<double>(begin: 0.985, end: 1.0).animate(forwardCurve);
    final outgoing =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-0.025, 0)).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutExpo,
            reverseCurve: Curves.easeInOutQuart,
          ),
        );
    return SlideTransition(
      position: outgoing,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      ),
    );
  }
}

class _OrbiLiftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _OrbiLiftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final forwardCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInOutQuart,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(forwardCurve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.065),
          end: Offset.zero,
        ).animate(forwardCurve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.992, end: 1.0).animate(forwardCurve),
          child: child,
        ),
      ),
    );
  }
}

@immutable
class OrbiSurfaceTokens extends ThemeExtension<OrbiSurfaceTokens> {
  final Color heroTop;
  final Color heroBottom;
  final Color shellStart;
  final Color shellEnd;
  final Color shellAccent;
  final Color overlay;
  final Color glass;
  final Color glassBorder;
  final Color subduedText;

  const OrbiSurfaceTokens({
    required this.heroTop,
    required this.heroBottom,
    required this.shellStart,
    required this.shellEnd,
    required this.shellAccent,
    required this.overlay,
    required this.glass,
    required this.glassBorder,
    required this.subduedText,
  });

  const OrbiSurfaceTokens.light()
    : heroTop = const Color(0xFFFFFFFF),
      heroBottom = const Color(0xFFF2F5F9),
      shellStart = const Color(0xFFF9FBFE),
      shellEnd = const Color(0xFFF2F5F9),
      shellAccent = const Color(0xFF0F6C7A),
      overlay = const Color(0x1A0A5C63),
      glass = const Color(0xFFFFFFFF),
      glassBorder = const Color(0x220F6C7A),
      subduedText = const Color(0xFF5E727E);

  const OrbiSurfaceTokens.dark()
    : heroTop = const Color(0xFF15232E),
      heroBottom = const Color(0xFF0B131A),
      shellStart = const Color(0xFF0B131A),
      shellEnd = const Color(0xFF0B131A),
      shellAccent = const Color(0xFF2596BE),
      overlay = const Color(0xD90B131A),
      glass = const Color(0xF015232E),
      glassBorder = const Color(0x334AC5F2),
      subduedText = const Color(0xFFA9BDC2);

  @override
  OrbiSurfaceTokens copyWith({
    Color? heroTop,
    Color? heroBottom,
    Color? shellStart,
    Color? shellEnd,
    Color? shellAccent,
    Color? overlay,
    Color? glass,
    Color? glassBorder,
    Color? subduedText,
  }) {
    return OrbiSurfaceTokens(
      heroTop: heroTop ?? this.heroTop,
      heroBottom: heroBottom ?? this.heroBottom,
      shellStart: shellStart ?? this.shellStart,
      shellEnd: shellEnd ?? this.shellEnd,
      shellAccent: shellAccent ?? this.shellAccent,
      overlay: overlay ?? this.overlay,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      subduedText: subduedText ?? this.subduedText,
    );
  }

  @override
  OrbiSurfaceTokens lerp(ThemeExtension<OrbiSurfaceTokens>? other, double t) {
    if (other is! OrbiSurfaceTokens) return this;
    return OrbiSurfaceTokens(
      heroTop: Color.lerp(heroTop, other.heroTop, t) ?? heroTop,
      heroBottom: Color.lerp(heroBottom, other.heroBottom, t) ?? heroBottom,
      shellStart: Color.lerp(shellStart, other.shellStart, t) ?? shellStart,
      shellEnd: Color.lerp(shellEnd, other.shellEnd, t) ?? shellEnd,
      shellAccent: Color.lerp(shellAccent, other.shellAccent, t) ?? shellAccent,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
      glass: Color.lerp(glass, other.glass, t) ?? glass,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      subduedText: Color.lerp(subduedText, other.subduedText, t) ?? subduedText,
    );
  }
}

@immutable
class OrbiUiTokens extends ThemeExtension<OrbiUiTokens> {
  final Color card;
  final Color cardMuted;
  final Color cardStrong;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textMuted;
  final Color textSoft;
  final Color iconMuted;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color sheet;
  final Color appBarStart;
  final Color appBarMid;
  final Color appBarEnd;

  const OrbiUiTokens({
    required this.card,
    required this.cardMuted,
    required this.cardStrong,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.textSoft,
    required this.iconMuted,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.sheet,
    required this.appBarStart,
    required this.appBarMid,
    required this.appBarEnd,
  });

  const OrbiUiTokens.light()
    : card = const Color(0xFFFFFFFF),
      cardMuted = const Color(0xFFF5F8FC),
      cardStrong = const Color(0xFFF2F5F9),
      border = const Color(0xFFDCE4EC),
      borderStrong = const Color(0xFFC9D5DF),
      textPrimary = const Color(0xFF1E2F3A),
      textMuted = const Color(0xFF5E727E),
      textSoft = const Color(0xFF8AA2AE),
      iconMuted = const Color(0xFF0A5C63),
      accent = const Color(0xFF0F6C7A),
      accentSoft = const Color(0x220F6C7A),
      success = const Color(0xFF2D8C5A),
      successSoft = const Color(0x242D8C5A),
      warning = const Color(0xFFE57C3C),
      warningSoft = const Color(0x24E57C3C),
      danger = const Color(0xFFD32F2F),
      dangerSoft = const Color(0x20D32F2F),
      sheet = const Color(0xFFF9FBFE),
      appBarStart = const Color(0xFFF9FBFE),
      appBarMid = const Color(0xFFF7FAFD),
      appBarEnd = const Color(0xFFF2F5F9);

  const OrbiUiTokens.dark()
    : card = const Color(0xF015232E),
      cardMuted = const Color(0xF00F1A22),
      cardStrong = const Color(0xF015232E),
      border = const Color(0xFF274150),
      borderStrong = const Color(0xFF3C6174),
      textPrimary = const Color(0xFFF2FBFA),
      textMuted = const Color(0xFFA9BDC2),
      textSoft = const Color(0xFF769098),
      iconMuted = const Color(0xFF4AC5F2),
      accent = const Color(0xFF2596BE),
      accentSoft = const Color(0x2B2596BE),
      success = const Color(0xFF6DE0A8),
      successSoft = const Color(0x246DE0A8),
      warning = const Color(0xFFFFB44D),
      warningSoft = const Color(0x24FFB44D),
      danger = const Color(0xFFFF6B62),
      dangerSoft = const Color(0x30FF6B62),
      sheet = const Color(0xFF0B131A),
      appBarStart = const Color(0xFF15232E),
      appBarMid = const Color(0xFF101A23),
      appBarEnd = const Color(0xFF0B131A);

  @override
  OrbiUiTokens copyWith({
    Color? card,
    Color? cardMuted,
    Color? cardStrong,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textMuted,
    Color? textSoft,
    Color? iconMuted,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? sheet,
    Color? appBarStart,
    Color? appBarMid,
    Color? appBarEnd,
  }) {
    return OrbiUiTokens(
      card: card ?? this.card,
      cardMuted: cardMuted ?? this.cardMuted,
      cardStrong: cardStrong ?? this.cardStrong,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textSoft: textSoft ?? this.textSoft,
      iconMuted: iconMuted ?? this.iconMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      sheet: sheet ?? this.sheet,
      appBarStart: appBarStart ?? this.appBarStart,
      appBarMid: appBarMid ?? this.appBarMid,
      appBarEnd: appBarEnd ?? this.appBarEnd,
    );
  }

  @override
  OrbiUiTokens lerp(ThemeExtension<OrbiUiTokens>? other, double t) {
    if (other is! OrbiUiTokens) return this;
    return OrbiUiTokens(
      card: Color.lerp(card, other.card, t) ?? card,
      cardMuted: Color.lerp(cardMuted, other.cardMuted, t) ?? cardMuted,
      cardStrong: Color.lerp(cardStrong, other.cardStrong, t) ?? cardStrong,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textSoft: Color.lerp(textSoft, other.textSoft, t) ?? textSoft,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t) ?? iconMuted,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      success: Color.lerp(success, other.success, t) ?? success,
      successSoft: Color.lerp(successSoft, other.successSoft, t) ?? successSoft,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t) ?? warningSoft,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t) ?? dangerSoft,
      sheet: Color.lerp(sheet, other.sheet, t) ?? sheet,
      appBarStart: Color.lerp(appBarStart, other.appBarStart, t) ?? appBarStart,
      appBarMid: Color.lerp(appBarMid, other.appBarMid, t) ?? appBarMid,
      appBarEnd: Color.lerp(appBarEnd, other.appBarEnd, t) ?? appBarEnd,
    );
  }
}
