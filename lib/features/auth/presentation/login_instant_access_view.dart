part of 'login_screen.dart';

class _LoginInstantAccessView extends StatelessWidget {
  const _LoginInstantAccessView({
    required this.loading,
    required this.statusMessage,
    required this.statusTone,
    required this.onDismissStatus,
    required this.hasBiometricCredentials,
    required this.biometricTemporarilyDisabled,
    required this.biometricIdentityMissing,
    required this.biometricSetupRequired,
    required this.hasPin,
    required this.pinEntry,
    required this.storedDisplayName,
    required this.storedAvatarUrl,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    required this.onShowPasswordLogin,
    required this.l10n,
  });

  final bool loading;
  final String? statusMessage;
  final OrbiStatusTone statusTone;
  final VoidCallback onDismissStatus;
  final bool hasBiometricCredentials;
  final bool biometricTemporarilyDisabled;
  final bool biometricIdentityMissing;
  final bool biometricSetupRequired;
  final bool hasPin;
  final String pinEntry;
  final String storedDisplayName;
  final String? storedAvatarUrl;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final VoidCallback onShowPasswordLogin;
  final AppLocalizations l10n;

  bool get _canUseBiometric =>
      hasBiometricCredentials &&
      !biometricTemporarilyDisabled &&
      !biometricIdentityMissing &&
      !biometricSetupRequired;

  Color _headingColor(BuildContext context, dynamic ui) {
    return Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
  }

  String _welcomeName() {
    final trimmed = storedDisplayName.trim();
    if (trimmed.isEmpty) return 'Welcome back';
    final first = trimmed.split(RegExp(r'\s+')).first.trim();
    return 'Welcome back, $first';
  }

  String _initials() {
    final trimmed = storedDisplayName.trim();
    if (trimmed.isEmpty) return 'OR';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'OR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final firstName = storedDisplayName.trim().isEmpty
        ? ''
        : storedDisplayName.trim().split(RegExp(r'\s+')).first;
    final welcomeText = sw
        ? (firstName.isEmpty ? 'Karibu tena' : 'Karibu tena, $firstName')
        : _welcomeName();

    return Scaffold(
      body: OrbiLoadingOverlay(
        loading: loading,
        message: l10n.loginAuthenticatingSecurely,
        statusMessage: statusMessage,
        statusTone: statusMessage == null ? null : statusTone,
        onDismissStatus: onDismissStatus,
        child: OrbiBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    ui.cardMuted,
                                    ui.cardStrong.withValues(alpha: 0.96),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: ui.borderStrong),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipOval(
                                    child: storedAvatarUrl != null
                                        ? Image.network(
                                            storedAvatarUrl!,
                                            width: 66,
                                            height: 66,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Center(
                                              child: Text(
                                                _initials(),
                                                style: TextStyle(
                                                  color: ui.textPrimary,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              _initials(),
                                              style: TextStyle(
                                                color: ui.textPrimary,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: ui.card,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: ui.borderStrong),
                                      ),
                                      child: Icon(
                                        Icons.waving_hand_rounded,
                                        color: ui.accent,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              welcomeText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.michroma(
                                fontSize: 16,
                                color: _headingColor(context, ui),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sw ? 'Tumia PIN au biometriki.' : 'Use PIN or biometrics.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ui.textSoft,
                                fontSize: 10.5,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const slotGap = 6.0;
                                final slotWidth = ((constraints.maxWidth - (slotGap * 3)) / 4)
                                    .clamp(30.0, 48.0);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(4, (index) {
                                    final filled = index < pinEntry.length;
                                    final digit = filled ? '•' : '';
                                    return Container(
                                      width: slotWidth,
                                      height: 42,
                                      margin: EdgeInsets.only(
                                        right: index == 3 ? 0 : slotGap,
                                      ),
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? ui.accent.withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: filled
                                              ? ui.accent.withValues(alpha: 0.35)
                                              : ui.border.withValues(alpha: 0.72),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        digit,
                                        style: TextStyle(
                                          color: filled ? ui.textPrimary : ui.textSoft,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pinEntry.isEmpty
                                  ? (hasPin
                                      ? (sw ? 'Weka PIN yako' : 'Enter your PIN')
                                      : (sw
                                          ? 'PIN haijawekwa kwenye kifaa hiki'
                                          : 'PIN is not set on this device'))
                                  : (sw ? 'PIN tayari' : 'PIN ready'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: pinEntry.isEmpty ? ui.textSoft : ui.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PinKeypad(
                              onDigit: hasPin ? onDigit : (_) {},
                              onBackspace: hasPin ? onBackspace : () {},
                              onBiometric: _canUseBiometric ? onBiometric : null,
                              biometricIcon: Icons.fingerprint_rounded,
                            ),
                            const SizedBox(height: 8),
                            if (!hasPin)
                              Text(
                                sw ? 'Tumia biometriki au nenosiri.' : 'Use biometrics or password.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: onShowPasswordLogin,
                              style: TextButton.styleFrom(foregroundColor: ui.textMuted),
                              child: Text(
                                sw ? 'Tumia nenosiri' : 'Use password',
                                style: TextStyle(
                                  color: ui.textSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
