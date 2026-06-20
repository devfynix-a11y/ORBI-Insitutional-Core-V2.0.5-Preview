part of 'login_screen.dart';

typedef _LoginInputDecorationBuilder =
    InputDecoration Function({
      required BuildContext context,
      required String label,
      required IconData icon,
      Widget? suffixIcon,
    });

class _LoginPasswordView extends StatelessWidget {
  final AuthController auth;
  final AppLocalizations l10n;
  final dynamic ui;
  final Color warningTone;
  final bool biometricEnabled;
  final bool biometricLoginLoading;
  final bool hasInstantAccess;
  final bool hasPin;
  final bool biometricTemporarilyDisabled;
  final bool biometricIdentityMissing;
  final bool canSubmit;
  final bool obscurePassword;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? statusMessage;
  final OrbiStatusTone? statusTone;
  final Color headingColor;
  final VoidCallback onDismissStatus;
  final _LoginInputDecorationBuilder inputDecorationBuilder;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onBiometricTap;
  final Future<void> Function() onPinUnlock;
  final Future<void> Function() onSubmit;
  final VoidCallback onBackToPin;
  final Future<void> Function() onForgotPassword;
  final VoidCallback onGoToSignup;
  final Future<void> Function() onMandatoryBiometricSetup;

  const _LoginPasswordView({
    required this.auth,
    required this.l10n,
    required this.ui,
    required this.warningTone,
    required this.biometricEnabled,
    required this.biometricLoginLoading,
    required this.hasInstantAccess,
    required this.hasPin,
    required this.biometricTemporarilyDisabled,
    required this.biometricIdentityMissing,
    required this.canSubmit,
    required this.obscurePassword,
    required this.emailController,
    required this.passwordController,
    required this.statusMessage,
    required this.statusTone,
    required this.headingColor,
    required this.onDismissStatus,
    required this.inputDecorationBuilder,
    required this.onTogglePasswordVisibility,
    required this.onBiometricTap,
    required this.onPinUnlock,
    required this.onSubmit,
    required this.onBackToPin,
    required this.onForgotPassword,
    required this.onGoToSignup,
    required this.onMandatoryBiometricSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrbiLoadingOverlay(
        loading: auth.isLoading,
        message: l10n.loginAuthenticatingSecurely,
        statusMessage: statusMessage,
        statusTone: statusTone,
        onDismissStatus: onDismissStatus,
        child: OrbiBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: OrbiResponsive.pagePadding(context, top: 20, bottom: 20),
              child: OrbiMotionReveal(
                beginOffset: const Offset(0, 0.06),
                child: OrbiResponsiveContent(
                  maxWidth: 460,
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return OrbiMotionReveal(
                            delay: const Duration(milliseconds: 90),
                            beginOffset: const Offset(0, 0.05),
                            child: Card(
                              color: ui.card.withValues(alpha: 0.96),
                              elevation: 12,
                              shadowColor: Colors.black.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Center(child: OrbiLogoV2(width: 132)),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.loginOrbiTagline,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.michroma(
                                        fontSize: 10,
                                        color: ui.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      l10n.loginWelcomeTitle,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.michroma(
                                        fontSize: 18,
                                        color: headingColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.loginSecureSignInSubtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ui.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if ((statusMessage ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      _LoginStatusPanel(
                                        message: statusMessage!.trim(),
                                        tone: statusTone ?? OrbiStatusTone.info,
                                        ui: ui,
                                        onDismiss: onDismissStatus,
                                        onForgotPassword: onForgotPassword,
                                        l10n: l10n,
                                      ),
                                      const SizedBox(height: 18),
                                    ] else
                                      const SizedBox(height: 4),
                                    if (auth.biometricSetupRequired) ...[
                                      _LoginMandatoryBiometricCard(
                                        auth: auth,
                                        l10n: l10n,
                                        warningTone: warningTone,
                                        onSetupNow: onMandatoryBiometricSetup,
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                    if (biometricEnabled)
                                      _LoginBiometricActionStrip(
                                        l10n: l10n,
                                        ui: ui,
                                        biometricLoginLoading:
                                            biometricLoginLoading,
                                        onBiometricTap: onBiometricTap,
                                      )
                                    else if (biometricTemporarilyDisabled)
                                      _LoginInlineNotice(
                                        icon: Icons.lock_outline,
                                        iconColor: ui.warning,
                                        message: l10n
                                            .loginBiometricTemporarilyLocked,
                                        textColor: ui.warning,
                                        iconSize: 40,
                                      ),
                                    if (biometricIdentityMissing &&
                                        auth.biometricEnabled &&
                                        !biometricTemporarilyDisabled)
                                      _LoginInlineNotice(
                                        icon: Icons.info_outline,
                                        iconColor: ui.warning,
                                        message: l10n.loginBiometricMissing,
                                        textColor: ui.warning,
                                        iconSize: 36,
                                      ),
                                    if (auth.isReauthLocked && hasPin) ...[
                                      ElevatedButton.icon(
                                        onPressed: biometricLoginLoading
                                            ? null
                                            : onPinUnlock,
                                        icon: const Icon(Icons.pin),
                                        label: Text(
                                          l10n.loginUnlockWithPin,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    TextField(
                                      controller: emailController,
                                      enabled: true,
                                      style: TextStyle(color: ui.textPrimary),
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: inputDecorationBuilder(
                                        context: context,
                                        label: l10n.labelEmail,
                                        icon: Icons.alternate_email_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: passwordController,
                                      obscureText: obscurePassword,
                                      style: TextStyle(color: ui.textPrimary),
                                      decoration: inputDecorationBuilder(
                                        context: context,
                                        label: l10n.labelPassword,
                                        icon: Icons.lock_outline,
                                        suffixIcon: IconButton(
                                          onPressed: onTogglePasswordVisibility,
                                          icon: Icon(
                                            obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: ui.iconMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: auth.isLoading || !canSubmit
                                            ? null
                                            : onSubmit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ui.accent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.actionLogin,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (hasInstantAccess) ...[
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : onBackToPin,
                                        child: Text(
                                          Localizations.localeOf(context)
                                                      .languageCode
                                                      .toLowerCase() ==
                                                  'sw'
                                              ? 'Rudi kwenye PIN / biometriki'
                                              : 'Back to PIN',
                                          style: TextStyle(color: ui.accent),
                                        ),
                                      ),
                                    ],
                                    _LoginFooterActions(
                                      auth: auth,
                                      l10n: l10n,
                                      ui: ui,
                                      onForgotPassword: onForgotPassword,
                                      onGoToSignup: onGoToSignup,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

class _LoginStatusPanel extends StatelessWidget {
  final String message;
  final OrbiStatusTone tone;
  final dynamic ui;
  final VoidCallback onDismiss;
  final Future<void> Function() onForgotPassword;
  final AppLocalizations l10n;

  const _LoginStatusPanel({
    required this.message,
    required this.tone,
    required this.ui,
    required this.onDismiss,
    required this.onForgotPassword,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    final isError = tone == OrbiStatusTone.error;
    final isSuccess = tone == OrbiStatusTone.success;
    final showReset =
        isError &&
        (lower.contains('credential') ||
            lower.contains('password') ||
            lower.contains('invalid') ||
            lower.contains('wrong'));
    final color = isSuccess ? ui.success : (isError ? ui.danger : ui.accent);
    final icon = isSuccess
        ? Icons.check_circle_outline_rounded
        : (isError ? Icons.error_outline_rounded : Icons.info_outline_rounded);
    final title = isSuccess
        ? 'Sign-in updated'
        : (isError ? 'Sign-in needs attention' : 'Sign-in notice');

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Dismiss sign-in message',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    color: ui.iconMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (showReset) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onForgotPassword(),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: Text(l10n.loginForgotPassword),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoginMandatoryBiometricCard extends StatelessWidget {
  final AuthController auth;
  final AppLocalizations l10n;
  final Color warningTone;
  final Future<void> Function() onSetupNow;

  const _LoginMandatoryBiometricCard({
    required this.auth,
    required this.l10n,
    required this.warningTone,
    required this.onSetupNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningTone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningTone.withValues(alpha: 0.82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: warningTone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.loginBiometricSetupRequiredTitle,
                  style: TextStyle(
                    color: warningTone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.loginBiometricSetupRequiredBody,
            style: TextStyle(color: warningTone, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              if (compact) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: auth.biometricInFlight
                            ? null
                            : () => auth.logout(),
                        child: Text(l10n.actionLogout),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.biometricInFlight ? null : onSetupNow,
                        child: Text(
                          auth.biometricInFlight
                              ? l10n.loginAuthenticating
                              : l10n.actionSetUpNow,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: auth.biometricInFlight
                          ? null
                          : () => auth.logout(),
                      child: Text(l10n.actionLogout),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: auth.biometricInFlight ? null : onSetupNow,
                      child: Text(
                        auth.biometricInFlight
                            ? l10n.loginAuthenticating
                            : l10n.actionSetUpNow,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoginBiometricActionStrip extends StatelessWidget {
  final AppLocalizations l10n;
  final dynamic ui;
  final bool biometricLoginLoading;
  final VoidCallback onBiometricTap;

  const _LoginBiometricActionStrip({
    required this.l10n,
    required this.ui,
    required this.biometricLoginLoading,
    required this.onBiometricTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: biometricLoginLoading ? null : onBiometricTap,
          icon: biometricLoginLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.fingerprint),
          label: Text(
            biometricLoginLoading
                ? l10n.loginAuthenticating
                : l10n.loginUseFingerprintButton,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: ui.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: ui.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.loginOrUsePassword,
                style: TextStyle(color: ui.textMuted),
              ),
            ),
            Expanded(child: Divider(color: ui.border, thickness: 1)),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LoginInlineNotice extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final Color textColor;
  final double iconSize;

  const _LoginInlineNotice({
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.textColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: textColor),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _LoginFooterActions extends StatelessWidget {
  final AuthController auth;
  final AppLocalizations l10n;
  final dynamic ui;
  final Future<void> Function() onForgotPassword;
  final VoidCallback onGoToSignup;

  const _LoginFooterActions({
    required this.auth,
    required this.l10n,
    required this.ui,
    required this.onForgotPassword,
    required this.onGoToSignup,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, actionConstraints) {
        final compactActions = actionConstraints.maxWidth < 360;
        if (compactActions) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: auth.isLoading ? null : onForgotPassword,
                  child: Text(
                    l10n.loginForgotPassword,
                    style: TextStyle(color: ui.accent),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onGoToSignup,
                  child: Text(
                    l10n.loginNewUserCreateAccount,
                    style: TextStyle(color: ui.accent),
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onGoToSignup,
                  child: Text(
                    l10n.loginNewUserCreateAccount,
                    style: TextStyle(color: ui.accent),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: auth.isLoading ? null : onForgotPassword,
              child: Text(
                l10n.loginForgotPassword,
                style: TextStyle(color: ui.accent),
              ),
            ),
          ],
        );
      },
    );
  }
}
