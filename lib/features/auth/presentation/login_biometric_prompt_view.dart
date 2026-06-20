part of 'login_screen.dart';

class _LoginBiometricPromptView extends StatelessWidget {
  final AuthController auth;
  final bool hasPin;
  final bool biometricLoginLoading;
  final String? statusMessage;
  final OrbiStatusTone? statusTone;
  final VoidCallback onDismissStatus;
  final VoidCallback onUsePassword;
  final Future<void> Function() onUsePin;
  final Color headingColor;

  const _LoginBiometricPromptView({
    required this.auth,
    required this.hasPin,
    required this.biometricLoginLoading,
    required this.statusMessage,
    required this.statusTone,
    required this.onDismissStatus,
    required this.onUsePassword,
    required this.onUsePin,
    required this.headingColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: OrbiLoadingOverlay(
        loading: biometricLoginLoading || auth.biometricInFlight,
        message: l10n.loginAuthenticatingSecurely,
        statusMessage: statusMessage,
        statusTone: statusTone,
        onDismissStatus: onDismissStatus,
        child: OrbiBackground(
          child: SafeArea(
            child: OrbiResponsiveContent(
              maxWidth: 360,
              alignment: Alignment.center,
              padding: OrbiResponsive.pagePadding(
                context,
                top: 20,
                bottom: 20,
              ),
              child: Card(
                color: ui.card,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.loginOrbiLoginTitle,
                        style: GoogleFonts.michroma(
                          fontSize: 18,
                          color: headingColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: ui.cardMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ui.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_moon_outlined,
                              color: ui.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.loginSecureDeviceAttached,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Icon(Icons.fingerprint, size: 56, color: ui.accent),
                      const SizedBox(height: 12),
                      Text(
                        l10n.loginAuthenticateWithBiometric,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.loginBiometricFallbackHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: ui.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: biometricLoginLoading ? null : onUsePassword,
                        child: Text(
                          l10n.loginUsePasswordInstead,
                          style: TextStyle(color: ui.accent),
                        ),
                      ),
                      if (auth.isReauthLocked && hasPin) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: biometricLoginLoading ? null : onUsePin,
                          child: Text(
                            l10n.loginUsePinInstead,
                            style: TextStyle(color: ui.accent),
                          ),
                        ),
                      ],
                    ],
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
