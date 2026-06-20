import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import '../state/auth_controller.dart';
import '../../../core/security/behavior_telemetry_service.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/orbi_logo.dart';
import '../../../core/widgets/security_otp_dialog.dart';

part 'login_instant_access_view.dart';
part 'login_pin_keypad.dart';
part 'login_biometric_prompt_view.dart';
part 'login_password_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _maxPinAttempts = 3;
  static const int _maxPasswordAttempts = 3;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final OtpAutoFillService _otpAutoFill = OtpAutoFillService();
  bool _biometricTemporarilyDisabled = false;
  bool _hasBiometricCredentials = false;
  bool _showBiometricPrompt = false;
  bool _biometricIdentityMissing = false;
  bool _obscurePassword = true;
  bool _hasPin = false;
  bool _showPasswordLogin = false;
  bool _otpDialogOpen = false;
  bool _pinDialogOpen = false;
  bool _biometricLoginLoading = false;
  int _pinFailures = 0;
  int _passwordFailures = 0;
  String _pinEntry = '';
  String _storedDisplayName = '';
  String _storedEmail = '';
  String? _storedAvatarUrl;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final telemetry = BehaviorTelemetryService.instance;
    telemetry.trackTextController(_emailController);
    telemetry.trackTextController(_passwordController);
    _emailController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
    _initializeLogin();
  }

  @override
  void dispose() {
    final telemetry = BehaviorTelemetryService.instance;
    telemetry.untrackTextController(_emailController);
    telemetry.untrackTextController(_passwordController);
    _emailController.removeListener(_handleInputChanged);
    _passwordController.removeListener(_handleInputChanged);
    _otpAutoFill.stopListening();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeLogin() async {
    final storage = SecureStorageService();
    final auth = context.read<AuthController>();

    final tempDisabled = await storage.isBiometricTemporarilyDisabled();
    final identity = await storage.getBiometricIdentity();
    final profile =
        await storage.getUserProfile() ??
        await storage.getRememberedUserProfile();
    final hasPin = await storage.hasPin();
    if (!mounted) return;
    final settingEnabled = auth.biometricEnabled;
    final name =
        ((profile?['full_name'] ??
                    profile?['fullName'] ??
                    profile?['name'] ??
                    '')
                .toString())
            .trim();
    final avatar =
        ((profile?['avatar_url'] ??
                    profile?['avatarUrl'] ??
                    profile?['profile_photo_url'] ??
                    profile?['photo_url'] ??
                    '')
                .toString())
            .trim();
    final email = ((profile?['email'] ?? profile?['mail'] ?? '').toString())
        .trim();
    setState(() {
      _biometricTemporarilyDisabled = tempDisabled;
      _hasBiometricCredentials = settingEnabled;
      _biometricIdentityMissing = identity == null || identity.isEmpty;
      _hasPin = hasPin;
      _storedDisplayName = name;
      _storedEmail = email;
      _storedAvatarUrl = avatar.isEmpty ? null : avatar;
      _showPasswordLogin = !_hasInstantAccess;
    });
    if (_emailController.text.trim().isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  Future<void> _checkBiometricStatus() async {
    final storage = SecureStorageService();
    final tempDisabled = await storage.isBiometricTemporarilyDisabled();
    final identity = await storage.getBiometricIdentity();
    final profile =
        await storage.getUserProfile() ??
        await storage.getRememberedUserProfile();
    final hasPin = await storage.hasPin();
    final name =
        ((profile?['full_name'] ??
                    profile?['fullName'] ??
                    profile?['name'] ??
                    '')
                .toString())
            .trim();
    final avatar =
        ((profile?['avatar_url'] ??
                    profile?['avatarUrl'] ??
                    profile?['profile_photo_url'] ??
                    profile?['photo_url'] ??
                    '')
                .toString())
            .trim();
    final email = ((profile?['email'] ?? profile?['mail'] ?? '').toString())
        .trim();
    setState(() {
      _biometricTemporarilyDisabled = tempDisabled;
      _hasBiometricCredentials = context
          .read<AuthController>()
          .biometricEnabled;
      _biometricIdentityMissing = identity == null || identity.isEmpty;
      _hasPin = hasPin;
      _storedDisplayName = name;
      _storedEmail = email;
      _storedAvatarUrl = avatar.isEmpty ? null : avatar;
    });
    if (_emailController.text.trim().isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  bool get _hasInstantAccess =>
      _hasPin || (_hasBiometricCredentials && !_biometricIdentityMissing);

  Color _headingColor(BuildContext context, dynamic ui) {
    return Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
  }

  void _returnToAuthRouter() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      final l10n = AppLocalizations.of(context)!;
      _setStatus(l10n.loginEnterEmailPasswordMessage, OrbiStatusTone.error);
      return;
    }

    final auth = context.read<AuthController>();

    // Normal password login
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      requestOtp: _promptOtpDialog,
    );

    if (success && mounted) {
      _passwordFailures = 0;
      if (auth.biometricSetupRequired) {
        Navigator.pushReplacementNamed(context, '/secure-account-setup');
      } else {
        _setStatus('Signed in successfully.', OrbiStatusTone.success);
        _returnToAuthRouter();
      }
    } else if (mounted && auth.accountActivationRequired) {
      Navigator.pushNamed(
        context,
        '/account-activation',
        arguments:
            auth.pendingActivationIdentifier ?? _emailController.text.trim(),
      );
    } else if (mounted && (auth.error ?? '').trim().isNotEmpty) {
      _passwordFailures += 1;
      if (_passwordFailures >= _maxPasswordAttempts) {
        _passwordController.clear();
        _setStatus(
          'Too many password attempts. Use password.',
          OrbiStatusTone.error,
        );
      } else {
        _setStatus(auth.error!, OrbiStatusTone.error);
      }
    }
  }

  Future<void> _attemptBiometricLogin() async {
    final auth = context.read<AuthController>();
    if (_biometricLoginLoading || auth.biometricInFlight) return;
    setState(() => _biometricLoginLoading = true);
    String? localError;
    bool success;
    try {
      success = await auth.biometricLogin(requestOtp: _promptOtpDialog);
    } catch (e) {
      success = false;
      debugPrint('⚠️ biometric login threw: $e');
      localError = UserFacingError.from(
        e,
        fallback: 'Biometric sign in failed. Try again.',
      );
    }

    if (success) {
      if (mounted) _returnToAuthRouter();
    } else {
      final errorMsg = (localError ?? auth.error ?? '').trim();
      await _checkBiometricStatus();
      setState(() {
        _showBiometricPrompt = false;
      });

      if (mounted && errorMsg.isNotEmpty) {
        _setStatus(errorMsg, OrbiStatusTone.error);
      }
    }
    if (mounted) {
      setState(() => _biometricLoginLoading = false);
    }
  }

  Future<void> _attemptPinUnlock() async {
    final auth = context.read<AuthController>();
    final pin = await _promptPinDialog();
    if (pin == null || pin.trim().isEmpty) return;
    final success = await auth.unlockWithPin(pin.trim());
    if (success && mounted) {
      _pinFailures = 0;
      _returnToAuthRouter();
      return;
    }
    if (mounted) {
      _pinFailures += 1;
      final exhausted = _pinFailures >= _maxPinAttempts;
      _setStatus(
        exhausted
            ? 'Too many PIN attempts. Use password.'
            : auth.error ??
                  AppLocalizations.of(context)!.loginInvalidPinMessage,
        OrbiStatusTone.error,
      );
      if (exhausted) {
        setState(() {
          _pinEntry = '';
          _showPasswordLogin = true;
        });
      }
    }
  }

  Future<void> _submitInstantPin() async {
    if (_pinEntry.length < 4) return;
    final auth = context.read<AuthController>();
    final canUseBiometric =
        _hasBiometricCredentials &&
        !_biometricTemporarilyDisabled &&
        !_biometricIdentityMissing &&
        !auth.biometricSetupRequired;
    setState(() => _biometricLoginLoading = true);
    try {
      final loginEmail = _storedEmail.isNotEmpty
          ? _storedEmail
          : _emailController.text.trim();
      final success = auth.isReauthLocked
          ? await auth.unlockWithPin(_pinEntry)
          : (loginEmail.isEmpty
                ? false
                : await auth.pinLogin(
                    loginEmail,
                    _pinEntry,
                    requestOtp: _promptOtpDialog,
                  ));
      if (!mounted) return;
      if (success) {
        _pinFailures = 0;
        if (auth.biometricSetupRequired) {
          Navigator.pushReplacementNamed(context, '/secure-account-setup');
          return;
        }
        _returnToAuthRouter();
        return;
      }
      _pinFailures += 1;
      final exhausted = _pinFailures >= _maxPinAttempts;
      final normalizedError = (auth.error ?? '').trim();
      final lowerError = normalizedError.toLowerCase();
      final sessionExpired = lowerError.contains('session expired');
      final pinLockedForBiometric =
          lowerError.contains('pin_locked_use_biometric') ||
          lowerError.contains('use biometric');
      final deviceBindingProblem =
          lowerError.contains('device_not_trusted') ||
          lowerError.contains('device_binding_required');
      final pinNotEnrolled = lowerError.contains('pin_not_enrolled');
      final identityMismatch = lowerError.contains('identity_mismatch');
      _setStatus(
        pinLockedForBiometric
            ? 'PIN is locked. Use biometrics.'
            : deviceBindingProblem
            ? 'This device is not trusted. Use biometrics or password.'
            : identityMismatch
            ? 'Use the saved phone or email for this fingerprint.'
            : pinNotEnrolled
            ? 'PIN is not ready yet. Use biometrics or password.'
            : exhausted
            ? (canUseBiometric
                  ? 'Too many PIN attempts. Use biometrics.'
                  : 'Too many PIN attempts. Use password.')
            : (loginEmail.isEmpty && !auth.isReauthLocked
                  ? 'No saved email found. Use password.'
                  : auth.error ??
                        AppLocalizations.of(context)!.loginInvalidPinMessage),
        OrbiStatusTone.error,
      );
      setState(() {
        _pinEntry = '';
        if (pinLockedForBiometric) {
          _showBiometricPrompt = canUseBiometric;
          _showPasswordLogin = !canUseBiometric;
        } else if (deviceBindingProblem || pinNotEnrolled || identityMismatch) {
          _showPasswordLogin = true;
        } else if (exhausted) {
          _showBiometricPrompt = canUseBiometric;
          _showPasswordLogin = !canUseBiometric;
        } else if (sessionExpired && canUseBiometric) {
          _showBiometricPrompt = true;
        }
      });
      if ((sessionExpired || exhausted || pinLockedForBiometric) &&
          canUseBiometric) {
        Future.delayed(
          const Duration(milliseconds: 120),
          _attemptBiometricLogin,
        );
      }
    } finally {
      if (mounted) setState(() => _biometricLoginLoading = false);
    }
  }

  void _appendPinDigit(String digit) {
    if (_pinEntry.length >= 4 || _biometricLoginLoading) return;
    final nextPin = '$_pinEntry$digit';
    setState(() => _pinEntry = nextPin);
    if (nextPin.length == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _biometricLoginLoading || _pinEntry.length != 4) return;
        _submitInstantPin();
      });
    }
  }

  void _removePinDigit() {
    if (_pinEntry.isEmpty || _biometricLoginLoading) return;
    setState(() => _pinEntry = _pinEntry.substring(0, _pinEntry.length - 1));
  }

  void _setStatus(String message, OrbiStatusTone tone) {
    if (!mounted) return;
    void applyStatus() {
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

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => applyStatus());
      return;
    }

    applyStatus();
  }

  Future<String?> _promptPinDialog() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pinDialogOpen || !mounted) return null;
    _pinDialogOpen = true;
    try {
      return await showSecurityCodeDialog(
        context: context,
        title: l10n.loginEnterPinTitle,
        helperText: l10n.loginUsePinInstead,
        fieldLabel: l10n.loginPinLabel,
        confirmLabel: l10n.actionUnlock,
        cancelLabel: l10n.actionCancel,
        maxLength: 4,
        minLength: 4,
        obscureText: true,
        digitsOnly: true,
        keyboardType: TextInputType.number,
      );
    } finally {
      _pinDialogOpen = false;
    }
  }

  Future<String?> _promptOtpDialog() async {
    if (_otpDialogOpen || !mounted) return null;
    final l10n = AppLocalizations.of(context)!;
    _otpDialogOpen = true;
    try {
      return await showSecurityOtpDialog(
        context: context,
        title: l10n.loginSecurityVerificationTitle,
        helperText: l10n.loginBiometricFallbackHint,
        startListening: (onCode) => _otpAutoFill.startListening(onCode: onCode),
        stopListening: _otpAutoFill.stopListening,
      );
    } finally {
      _otpDialogOpen = false;
    }
  }

  Future<void> _handleMandatoryBiometricSetup() async {
    final auth = context.read<AuthController>();
    if (!auth.biometricSetupRequired) return;

    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final ui = OrbiTheme.uiOf(ctx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.loginBiometricSetupRequiredTitle),
            content: Text(l10n.loginBiometricSetupRequiredBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.actionLogout,
                  style: TextStyle(color: ui.danger),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.actionSetUpNow),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;

    if (shouldContinue != true) {
      await auth.logout();
      return;
    }

    final ok = await auth.completeMandatoryBiometricSetup(
      requestOtp: _promptOtpDialog,
    );
    if (!mounted) return;

    if (ok) {
      _returnToAuthRouter();
      return;
    }

    _setStatus(
      auth.error ??
          AppLocalizations.of(context)!.loginBiometricSetupFailedMessage,
      OrbiStatusTone.error,
    );
    await _checkBiometricStatus();
    if (mounted) {
      setState(() => _showBiometricPrompt = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    await Navigator.pushNamed(
      context,
      '/password-reset',
      arguments: _emailController.text.trim(),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ui.textMuted),
      floatingLabelStyle: TextStyle(color: ui.accent),
      prefixIcon: Icon(icon, color: ui.iconMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ui.cardMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final warningTone = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF0A34A)
        : const Color(0xFFB86A15);
    final biometricEnabled =
        auth.biometricEnabled &&
        _hasBiometricCredentials &&
        !_biometricTemporarilyDisabled &&
        !_biometricIdentityMissing &&
        !auth.biometricSetupRequired;

    if (!_showPasswordLogin &&
        _hasInstantAccess &&
        !auth.biometricSetupRequired) {
      return _LoginInstantAccessView(
        loading:
            auth.isLoading || _biometricLoginLoading || auth.biometricInFlight,
        statusMessage: _statusMessage,
        statusTone: _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        hasBiometricCredentials: _hasBiometricCredentials,
        biometricTemporarilyDisabled: _biometricTemporarilyDisabled,
        biometricIdentityMissing: _biometricIdentityMissing,
        biometricSetupRequired: auth.biometricSetupRequired,
        hasPin: _hasPin,
        pinEntry: _pinEntry,
        storedDisplayName: _storedDisplayName,
        storedAvatarUrl: _storedAvatarUrl,
        onDigit: _appendPinDigit,
        onBackspace: _removePinDigit,
        onBiometric: _attemptBiometricLogin,
        onShowPasswordLogin: () {
          if (!mounted) return;
          setState(() => _showPasswordLogin = true);
        },
        l10n: l10n,
      );
    }

    if (_showBiometricPrompt) {
      return _LoginBiometricPromptView(
        auth: auth,
        hasPin: _hasPin,
        biometricLoginLoading: _biometricLoginLoading,
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        onUsePassword: () {
          if (!mounted) return;
          setState(() => _showBiometricPrompt = false);
        },
        onUsePin: _attemptPinUnlock,
        headingColor: _headingColor(context, ui),
      );
    }

    return _LoginPasswordView(
      auth: auth,
      l10n: l10n,
      ui: ui,
      warningTone: warningTone,
      biometricEnabled: biometricEnabled,
      biometricLoginLoading: _biometricLoginLoading,
      hasInstantAccess: _hasInstantAccess,
      hasPin: _hasPin,
      biometricTemporarilyDisabled: _biometricTemporarilyDisabled,
      biometricIdentityMissing: _biometricIdentityMissing,
      canSubmit: _canSubmit,
      obscurePassword: _obscurePassword,
      emailController: _emailController,
      passwordController: _passwordController,
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      headingColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : _headingColor(context, ui),
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      inputDecorationBuilder:
          ({
            required BuildContext context,
            required String label,
            required IconData icon,
            Widget? suffixIcon,
          }) => _inputDecoration(
            context: context,
            label: label,
            icon: icon,
            suffixIcon: suffixIcon,
          ),
      onTogglePasswordVisibility: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
      onBiometricTap: () {
        setState(() => _showBiometricPrompt = true);
        Future.delayed(
          const Duration(milliseconds: 100),
          _attemptBiometricLogin,
        );
      },
      onPinUnlock: _attemptPinUnlock,
      onSubmit: _submit,
      onBackToPin: () {
        setState(() => _showPasswordLogin = false);
      },
      onForgotPassword: _showForgotPasswordDialog,
      onGoToSignup: () {
        Navigator.pushReplacementNamed(context, '/signup');
      },
      onMandatoryBiometricSetup: _handleMandatoryBiometricSetup,
    );
  }
}
