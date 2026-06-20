import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/security_otp_dialog.dart';
import '../state/auth_controller.dart';

class SecureAccountSetupScreen extends StatefulWidget {
  const SecureAccountSetupScreen({super.key});

  @override
  State<SecureAccountSetupScreen> createState() =>
      _SecureAccountSetupScreenState();
}

class _SecureAccountSetupScreenState extends State<SecureAccountSetupScreen> {
  final OtpAutoFillService _otpAutoFill = OtpAutoFillService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _pinReady = false;
  bool _biometricReady = false;
  bool _busy = false;
  bool _otpDialogOpen = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  @override
  void dispose() {
    _otpAutoFill.stopListening();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _setStatus(String message, OrbiStatusTone tone) {
    if (!mounted) return;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: sw,
        fallback: message,
      );
      _statusTone = tone;
    });
  }

  Future<String?> _promptOtpDialog() async {
    if (_otpDialogOpen || !mounted) return null;
    final l10n = AppLocalizations.of(context)!;
    _otpDialogOpen = true;
    try {
      return await showSecurityOtpDialog(
        context: context,
        title: l10n.signupSecurityVerificationTitle,
        helperText: l10n.signupSecurityVerificationHelper,
        startListening: (onCode) => _otpAutoFill.startListening(onCode: onCode),
        stopListening: _otpAutoFill.stopListening,
      );
    } finally {
      _otpDialogOpen = false;
    }
  }

  Future<void> _setupPin() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_biometricReady) {
      _setStatus(
        l10n.secureAccountSetupRegisterFingerprintFirst,
        OrbiStatusTone.error,
      );
      return;
    }
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    if (pin.length != 4 || pin != confirm) {
      _setStatus(l10n.secureAccountSetupPinMismatch, OrbiStatusTone.error);
      return;
    }
    setState(() => _busy = true);
    final ok = await context.read<AuthController>().enrollSecurityPin(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pinReady = ok;
    });
    if (ok) {
      _setStatus(l10n.secureAccountSetupSuccess, OrbiStatusTone.success);
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      return;
    }
    _setStatus(
      context.read<AuthController>().error ??
          l10n.secureAccountSetupPinEnrollFailed,
      OrbiStatusTone.error,
    );
  }

  Future<void> _setupBiometric() async {
    if (_busy) return;
    final auth = context.read<AuthController>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final ok = await auth.completeMandatoryBiometricSetup(
      requestOtp: _promptOtpDialog,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _biometricReady = ok;
    });
    if (ok) {
      _setStatus(l10n.secureAccountSetupBiometricReady, OrbiStatusTone.success);
      return;
    }
    _setStatus(
      auth.error ??
          AppLocalizations.of(context)!.loginBiometricSetupFailedMessage,
      OrbiStatusTone.error,
    );
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: OrbiLoadingOverlay(
          loading: _busy,
          message: l10n.secureAccountSetupLoading,
          statusMessage: _statusMessage,
          statusTone: _statusMessage == null ? null : _statusTone,
          onDismissStatus: () => setState(() => _statusMessage = null),
          child: OrbiBackground(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).brightness == Brightness.dark
                        ? ui.sheet.withValues(alpha: 0.96)
                        : const Color(0xFFF7F8FB),
                    Theme.of(context).brightness == Brightness.dark
                        ? ui.card.withValues(alpha: 0.94)
                        : const Color(0xFFF1F3F7),
                  ],
                ),
              ),
              child: SafeArea(
                child: OrbiResponsiveContent(
                  maxWidth: 460,
                  padding: OrbiResponsive.pagePadding(
                    context,
                    top: 28,
                    bottom: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                          child: Icon(
                            Icons.verified_user_rounded,
                            color: ui.textPrimary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.secureAccountSetupTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.michroma(
                            fontSize: 18,
                            color: ui.textPrimary,
                            letterSpacing: 0.24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.secureAccountSetupSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SecurityStepCard(
                          index: 1,
                          title: l10n.secureAccountStepFingerprintTitle,
                          message: l10n.secureAccountStepFingerprintMessage,
                          ready: _biometricReady,
                          actionLabel: _biometricReady
                              ? l10n.commonDone
                              : l10n.actionRegisterNow,
                          onTap: _biometricReady ? null : _setupBiometric,
                        ),
                        const SizedBox(height: 14),
                        _SecurityStepCard(
                          index: 2,
                          title: l10n.secureAccountStepPinTitle,
                          message: l10n.secureAccountStepPinMessage,
                          ready: _pinReady,
                          actionLabel: _pinReady
                              ? l10n.commonReady
                              : l10n.settingsSetPinTitle,
                          onTap: _biometricReady && !_pinReady
                              ? _setupPin
                              : null,
                          child: !_biometricReady || _pinReady
                              ? null
                              : Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _pinController,
                                      keyboardType: TextInputType.number,
                                      obscureText: _obscurePin,
                                      maxLength: 4,
                                      decoration: InputDecoration(
                                        labelText: l10n.pinNewLabel,
                                        counterText: '',
                                        filled: true,
                                        fillColor: ui.card.withValues(
                                          alpha: 0.88,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.accent,
                                            width: 1.4,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePin = !_obscurePin,
                                          ),
                                          icon: Icon(
                                            _obscurePin
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _confirmPinController,
                                      keyboardType: TextInputType.number,
                                      obscureText: _obscureConfirmPin,
                                      maxLength: 4,
                                      decoration: InputDecoration(
                                        labelText: l10n.pinConfirmLabel,
                                        counterText: '',
                                        filled: true,
                                        fillColor: ui.card.withValues(
                                          alpha: 0.88,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: ui.accent,
                                            width: 1.4,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscureConfirmPin =
                                                !_obscureConfirmPin,
                                          ),
                                          icon: Icon(
                                            _obscureConfirmPin
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: _busy ? null : _logout,
                          child: Text(l10n.secureAccountSignOutInstead),
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
    );
  }
}

class _SecurityStepCard extends StatelessWidget {
  const _SecurityStepCard({
    required this.index,
    required this.title,
    required this.message,
    required this.ready,
    required this.actionLabel,
    required this.onTap,
    this.child,
  });

  final int index;
  final String title;
  final String message;
  final bool ready;
  final String actionLabel;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ready ? ui.accent : ui.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ready ? ui.accent.withValues(alpha: 0.16) : ui.card,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ready
                ? Icon(Icons.check_rounded, color: ui.accent)
                : Text(
                    '$index',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                ...?(child == null ? null : <Widget>[child!]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
