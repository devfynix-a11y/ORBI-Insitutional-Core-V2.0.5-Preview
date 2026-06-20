part of 'login_screen.dart';

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    required this.biometricIcon,
  });

  static const double _buttonSize = 65;
  static const double _gap = 14;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;

  @override
  Widget build(BuildContext context) {
    final keys = <Map<String, String>>[
      {'digit': '1', 'letters': ''},
      {'digit': '2', 'letters': 'ABC'},
      {'digit': '3', 'letters': 'DEF'},
      {'digit': '4', 'letters': 'GHI'},
      {'digit': '5', 'letters': 'JKL'},
      {'digit': '6', 'letters': 'MNO'},
      {'digit': '7', 'letters': 'PQRS'},
      {'digit': '8', 'letters': 'TUV'},
      {'digit': '9', 'letters': 'WXYZ'},
    ];
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: _gap),
                  SizedBox.square(
                    dimension: _buttonSize,
                    child: _PinKeyButton(
                      label: keys[(row * 3) + col]['digit']!,
                      letters: keys[(row * 3) + col]['letters']!,
                      onTap: () => onDigit(keys[(row * 3) + col]['digit']!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: _buttonSize,
              child: _PinIconButton(
                icon: biometricIcon,
                onTap: onBiometric,
                enabled: onBiometric != null,
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox.square(
              dimension: _buttonSize,
              child: _PinKeyButton(
                label: '0',
                letters: '+',
                onTap: () => onDigit('0'),
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox.square(
              dimension: _buttonSize,
              child: _PinIconButton(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                enabled: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  const _PinKeyButton({
    required this.label,
    required this.letters,
    required this.onTap,
  });

  final String label;
  final String letters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.transparent
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? ui.border.withValues(alpha: 0.9) : const Color(0xFFC5CCD6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (letters.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  letters,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PinIconButton extends StatelessWidget {
  const _PinIconButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDelete = icon == Icons.backspace_outlined;
    final isBiometric = icon == Icons.fingerprint_rounded;
    final foreground = !enabled
        ? ui.textSoft
        : isDelete
            ? (isDark ? const Color(0xFFF4BE63) : const Color(0xFFB86A15))
            : isBiometric
                ? (isDark ? const Color(0xFFE9FFF3) : const Color(0xFF58B889))
                : ui.accent;
    final numberBorder = isDark ? ui.border.withValues(alpha: 0.9) : const Color(0xFFC5CCD6);
    final border = !enabled
        ? ui.border.withValues(alpha: 0.7)
        : isDelete
            ? foreground.withValues(alpha: 0.45)
            : isBiometric
                ? foreground.withValues(alpha: 0.55)
                : numberBorder;
    final background = !enabled
        ? ui.cardMuted.withValues(alpha: 0.48)
        : isDelete
            ? foreground.withValues(alpha: isDark ? 0.14 : 0.12)
            : isBiometric
                ? (isDark
                    ? const Color(0xFF18392C).withValues(alpha: 0.78)
                    : const Color(0xFFE8F8F0).withValues(alpha: 0.92))
                : (isDark
                    ? Colors.transparent
                    : Colors.transparent);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap?.call();
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: isDelete
                ? background
                : isBiometric
                    ? background
                    : (isDark
                        ? Colors.transparent
                        : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: isBiometric
                    ? foreground.withValues(alpha: isDark ? 0.28 : 0.18)
                    : Colors.black.withValues(alpha: enabled ? (isDark ? 0.10 : 0.04) : 0.02),
                blurRadius: isBiometric ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: isBiometric
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      foreground.withValues(alpha: isDark ? 0.20 : 0.14),
                      background,
                    ],
                  )
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              color: foreground,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
