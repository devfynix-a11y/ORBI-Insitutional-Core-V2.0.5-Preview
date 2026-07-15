import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/security/behavior_telemetry_service.dart';
import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_logo.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/security_otp_dialog.dart';
import '../state/auth_controller.dart';
import 'auth_flow_content.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _addressController = TextEditingController();
  final OtpAutoFillService _otpAutoFill = OtpAutoFillService();

  late CountryProfile _selectedCountry;
  late String _currency;
  late String _languageLabel;

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  bool _emailErrorShown = false;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  static const int _stepCount = 3;

  @override
  void initState() {
    super.initState();
    _selectedCountry = kOrbiCountryProfiles.firstWhere(
      (country) => country.code == 'TZ',
      orElse: () => kOrbiCountryProfiles.first,
    );
    _currency = _selectedCountry.currency;
    _languageLabel = _selectedCountry.languageLabel;
    _nationalityController.text = _selectedCountry.nationality;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppSettingsController>().setAppLanguage(
        languageCode: _selectedCountry.languageCode,
        applyToApp: true,
      );
    });

    final telemetry = BehaviorTelemetryService.instance;
    telemetry.trackTextController(_fullNameController);
    telemetry.trackTextController(_phoneController);
    telemetry.trackTextController(_emailController);
    telemetry.trackTextController(_passwordController);
    telemetry.trackTextController(_confirmPasswordController);
    telemetry.trackTextController(_nationalityController);
    telemetry.trackTextController(_addressController);
  }

  @override
  void dispose() {
    final telemetry = BehaviorTelemetryService.instance;
    telemetry.untrackTextController(_fullNameController);
    telemetry.untrackTextController(_phoneController);
    telemetry.untrackTextController(_emailController);
    telemetry.untrackTextController(_passwordController);
    telemetry.untrackTextController(_confirmPasswordController);
    telemetry.untrackTextController(_nationalityController);
    telemetry.untrackTextController(_addressController);
    _otpAutoFill.stopListening();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String get _dialCode => _selectedCountry.dialCode;

  double get _progressValue => (_currentStep + 1) / _stepCount;

  String _stepTitle(int step) {
    final l10n = AppLocalizations.of(context)!;
    switch (step) {
      case 0:
        return l10n.signupStepPersonalInfo;
      case 1:
        return l10n.signupStepContactDetails;
      case 2:
        return l10n.signupStepVerification;
      default:
        return '';
    }
  }

  String _stepShortTitle(int step) {
    final l10n = AppLocalizations.of(context)!;
    switch (step) {
      case 0:
        return l10n.signupStepShortInfo;
      case 1:
        return l10n.signupStepShortCountry;
      case 2:
        return l10n.signupStepShortVerify;
      default:
        return '';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final raw = message.toLowerCase();
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: Localizations.localeOf(context).languageCode.toLowerCase() == 'sw',
        fallback: message,
      );
      _statusTone =
          raw.contains('error') ||
              raw.contains('required') ||
              raw.contains('invalid') ||
              raw.contains('failed')
          ? OrbiStatusTone.error
          : OrbiStatusTone.info;
    });
  }

  void _applyCountryDefaults(
    CountryProfile country, {
    required bool syncLocale,
  }) {
    final normalizedPhone = _sanitizeLocalPhone(_phoneController.text);
    setState(() {
      _selectedCountry = country;
      _currency = country.currency;
      _languageLabel = country.languageLabel;
      _nationalityController.text = country.nationality;
      _phoneController.text = normalizedPhone;
    });

    if (syncLocale) {
      context.read<AppSettingsController>().setAppLanguage(
        languageCode: country.languageCode,
        applyToApp: true,
      );
    }
  }

  String _sanitizeLocalPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final dialDigits = _dialCode.replaceAll('+', '');
    if (digits.startsWith(dialDigits)) {
      return digits.substring(dialDigits.length);
    }
    return digits;
  }

  bool _validateCurrentStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        final fullName = _fullNameController.text.trim();
        if (fullName.isEmpty) {
          _showMessage(l10n.signupFullNameRequired);
          return false;
        }
        if (fullName.length < 3) {
          _showMessage(l10n.signupFullNameInvalid);
          return false;
        }
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          _showMessage(l10n.signupEmailRequired);
          return false;
        }
        if (!RegExp(
          r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
        ).hasMatch(email)) {
          if (!_emailErrorShown) {
            _showMessage(l10n.signupEmailInvalid);
            _emailErrorShown = true;
          }
          return false;
        } else {
          _emailErrorShown = false;
        }
        return true;
      case 1:
        final phone = _sanitizeLocalPhone(_phoneController.text);
        if (phone.isEmpty) {
          _showMessage(l10n.signupPhoneRequired);
          return false;
        }
        if (phone.length < 8) {
          _showMessage(l10n.signupPhoneInvalid);
          return false;
        }
        return true;
      case 2:
        final password = _passwordController.text;
        if (password.isEmpty) {
          _showMessage(l10n.signupPasswordRequired);
          return false;
        }
        final passwordError = _passwordPolicyError(password, l10n);
        if (passwordError != null) {
          _showMessage(passwordError);
          return false;
        }
        if (_confirmPasswordController.text != password) {
          _showMessage(l10n.signupPasswordsMismatch);
          return false;
        }
        if (!_agreeToTerms) {
          _showMessage(l10n.signupAcceptTermsMessage);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _copy(String en, String sw) => _isSw ? sw : en;

  String? _passwordPolicyError(String password, AppLocalizations l10n) {
    if (password.length < 8) return l10n.signupPasswordMin;
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return _copy(
        'Password must include a lowercase letter.',
        'Nywila lazima iwe na herufi ndogo.',
      );
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return _copy(
        'Password must include an uppercase letter.',
        'Nywila lazima iwe na herufi kubwa.',
      );
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return _copy(
        'Password must include a number.',
        'Nywila lazima iwe na namba.',
      );
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return _copy(
        'Password must include a special character, for example @, #, or !.',
        'Nywila lazima iwe na alama maalum, mfano @, #, au !.',
      );
    }
    return null;
  }

  void _goNext(AppLocalizations l10n) {
    if (!_validateCurrentStep(l10n)) return;
    if (_currentStep >= _stepCount - 1) return;
    setState(() => _currentStep += 1);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_validateCurrentStep(l10n)) return;
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.signup(
      fullName: _fullNameController.text.trim(),
      phone: '$_dialCode${_sanitizeLocalPhone(_phoneController.text)}',
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nationality: _nationalityController.text.trim().isNotEmpty
          ? _nationalityController.text.trim()
          : null,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      currency: _currency,
      languageCode: _selectedCountry.languageCode,
      countryCode: _selectedCountry.code,
      countryName: _selectedCountry.name,
      dialCode: _selectedCountry.dialCode,
      requestOtp: _promptOtpDialog,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(
        context,
        '/account-activation',
        arguments:
            auth.pendingActivationIdentifier ?? _emailController.text.trim(),
      );
      return;
    }
    if (auth.accountActivationRequired) {
      Navigator.pushReplacementNamed(
        context,
        '/account-activation',
        arguments: auth.pendingActivationIdentifier?.trim().isNotEmpty == true
            ? auth.pendingActivationIdentifier
            : _emailController.text.trim(),
      );
      return;
    }
    _showMessage(
      auth.error ??
          _copy(
            'Unable to complete signup right now. Please try again.',
            'Hatukuweza kukamilisha usajili sasa. Tafadhali jaribu tena.',
          ),
    );
  }

  Future<String?> _promptOtpDialog() async {
    final l10n = AppLocalizations.of(context)!;
    return showSecurityOtpDialog(
      context: context,
      title: l10n.signupSecurityVerificationTitle,
      helperText: l10n.signupSecurityVerificationHelper,
      startListening: (onCode) => _otpAutoFill.startListening(onCode: onCode),
      stopListening: _otpAutoFill.stopListening,
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
    String? prefixText,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixText: prefixText,
      labelStyle: TextStyle(color: ui.textMuted),
      helperStyle: TextStyle(color: ui.textSoft),
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

  Color _headingColor(BuildContext context, dynamic ui) {
    return Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
  }

  ThemeData _signupTheme(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness != Brightness.dark) return theme;

    final ui = OrbiTheme.uiOf(context);
    final surface = OrbiTheme.surfacesOf(context);
    final advanced = OrbiTheme.advancedOf(context);

    final signupUi = ui.copyWith(
      card: const Color(0xFF071923),
      cardMuted: const Color(0xFF102B34),
      cardStrong: const Color(0xFF173640),
      border: const Color(0xFF25404A),
      borderStrong: const Color(0xFF54717A),
      textPrimary: const Color(0xFFF2FBFA),
      textMuted: const Color(0xFFA9BDC2),
      textSoft: const Color(0xFF769098),
      iconMuted: const Color(0xFF42E2CF),
      accent: const Color(0xFF42E2CF),
      accentSoft: const Color(0x2442E2CF),
      sheet: const Color(0xFF071923),
      appBarStart: const Color(0xFF08222B),
      appBarMid: const Color(0xFF071923),
      appBarEnd: const Color(0xFF031018),
    );
    final signupSurface = surface.copyWith(
      heroTop: const Color(0xFF08222B),
      heroBottom: const Color(0xFF031018),
      shellStart: const Color(0xFF071923),
      shellEnd: const Color(0xFF031018),
      shellAccent: const Color(0xFF0E4E55),
      overlay: const Color(0xD0031018),
      glass: const Color(0xE60B2029),
      glassBorder: const Color(0x2842E2CF),
      subduedText: const Color(0xFFA9BDC2),
    );

    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        secondary: signupUi.accent,
        secondaryContainer: signupUi.cardStrong,
        tertiary: signupUi.accent,
        tertiaryContainer: signupUi.cardStrong,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: signupUi.cardStrong,
          foregroundColor: signupUi.textPrimary,
          disabledBackgroundColor: signupUi.cardMuted,
          disabledForegroundColor: signupUi.textSoft,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: signupUi.borderStrong),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: signupUi.textPrimary,
          side: BorderSide(color: signupUi.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(
        color: signupUi.accent,
        linearTrackColor: signupUi.border,
      ),
      extensions: <ThemeExtension<dynamic>>[signupUi, signupSurface, advanced],
    );
  }

  Widget _buildStepContent({
    required BuildContext context,
    required AppLocalizations l10n,
    required dynamic ui,
  }) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionIntro(
              icon: Icons.badge_outlined,
              title: l10n.signupAboutYouTitle,
              subtitle: l10n.signupAboutYouSubtitle,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelFullName,
                icon: Icons.person_outline,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return l10n.signupFullNameRequired;
                if (text.length < 3) return l10n.signupFullNameInvalid;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelEmailAddress,
                icon: Icons.alternate_email_outlined,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return l10n.signupEmailRequired;
                if (!RegExp(
                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                ).hasMatch(text)) {
                  return l10n.signupEmailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelAddress,
                icon: Icons.home_outlined,
                helperText: l10n.signupAddressHelper,
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionIntro(
              icon: Icons.public_outlined,
              title: l10n.signupChooseCountryTitle,
              subtitle: l10n.signupChooseCountrySubtitle,
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelCountry,
                icon: Icons.flag_outlined,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CountryProfile>(
                  value: _selectedCountry,
                  dropdownColor: ui.card,
                  iconEnabledColor: ui.iconMuted,
                  isExpanded: true,
                  items: kOrbiCountryProfiles
                      .map(
                        (country) => DropdownMenuItem(
                          value: country,
                          child: Row(
                            children: [
                              Text(
                                country.flag,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${country.name} (${country.dialCode})',
                                  style: TextStyle(color: ui.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _applyCountryDefaults(value, syncLocale: true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ReadOnlyInfoTile(
                    icon: Icons.language_rounded,
                    label: l10n.signupLanguageLabel,
                    value: _languageLabel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReadOnlyInfoTile(
                    icon: Icons.payments_outlined,
                    label: l10n.signupCurrencyLabel,
                    value: _currency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelPhoneNumber,
                icon: Icons.phone_outlined,
                prefixText: '$_dialCode ',
                helperText: l10n.signupPhoneHelper,
              ),
              onChanged: (value) {
                final normalized = _sanitizeLocalPhone(value);
                if (normalized == value) return;
                _phoneController.value = TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: normalized.length),
                );
              },
              validator: (value) {
                final text = _sanitizeLocalPhone(value ?? '');
                if (text.isEmpty) return l10n.signupPhoneRequired;
                if (text.length < 8) return l10n.signupPhoneInvalid;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nationalityController,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelNationality,
                icon: Icons.public_outlined,
                helperText: l10n.signupNationalityHelper,
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionIntro(
              icon: Icons.lock_outline_rounded,
              title: l10n.signupSecureAccountTitle,
              subtitle: l10n.signupSecureAccountSubtitle,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelPassword,
                icon: Icons.lock_outline,
                helperText: _copy(
                  'Use uppercase, lowercase, number, and special character.',
                  'Tumia herufi kubwa, ndogo, namba, na alama maalum.',
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: ui.iconMuted,
                  ),
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return l10n.signupPasswordRequired;
                return _passwordPolicyError(text, l10n);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: ui.textPrimary),
              decoration: _inputDecoration(
                context: context,
                label: l10n.labelConfirmPassword,
                icon: Icons.verified_user_outlined,
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  }),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: ui.iconMuted,
                  ),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return l10n.signupPasswordsMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _ReviewCard(
              country: _selectedCountry,
              languageLabel: _languageLabel,
              currency: _currency,
              phoneNumber:
                  '$_dialCode${_sanitizeLocalPhone(_phoneController.text)}',
              email: _emailController.text.trim(),
              fullName: _fullNameController.text.trim(),
              title: l10n.signupReviewTitle,
              nameFallback: l10n.signupReviewNameFallback,
              emailFallback: l10n.signupReviewEmailFallback,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreeToTerms,
              activeColor: ui.accent,
              checkColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              onChanged: (value) {
                setState(() => _agreeToTerms = value ?? false);
              },
              title: Text(
                l10n.signupAgreeTermsTitle,
                style: TextStyle(color: ui.textMuted, fontSize: 13),
              ),
              subtitle: Text(l10n.signupAgreeTermsSubtitle),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSignupScaffold(BuildContext context) {
    final auth = context.watch<AuthController>();
    final ui = OrbiTheme.uiOf(context);
    final surface = OrbiTheme.surfacesOf(context);
    final l10n = AppLocalizations.of(context)!;
    final isSw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    return Scaffold(
      body: OrbiLoadingOverlay(
        loading: auth.isLoading,
        message: isSw ? 'Inaunda akaunti...' : 'Creating your account...',
        statusMessage:
            _statusMessage ??
            (auth.error != null
                ? mapBackendStatusMessage(
                    auth.error!,
                    sw: isSw,
                    fallback: auth.error!,
                  )
                : null),
        statusTone: _statusMessage != null
            ? _statusTone
            : (auth.error != null ? OrbiStatusTone.error : null),
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        child: OrbiBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: OrbiResponsive.pagePadding(context, top: 20, bottom: 20),
              child: OrbiResponsiveContent(
                maxWidth: 1120,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 920;
                    final formCard = Card(
                      color: ui.card.withValues(alpha: 0.97),
                      elevation: 14,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 28 : 22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!wide) ...[
                                const Center(child: OrbiLogoV2(width: 124)),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.signupCreateAccountTitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.michroma(
                                    fontSize: 22,
                                    color: _headingColor(context, ui),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.signupHeroSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      ui.cardStrong,
                                      surface.heroBottom.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: ui.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _HeaderBadge(
                                          icon: Icons.auto_awesome_rounded,
                                          label: l10n.signupEasyOnboardingBadge,
                                        ),
                                        _HeaderBadge(
                                          icon: Icons.language_rounded,
                                          label: l10n.signupPersonalizedBadge,
                                        ),
                                        _HeaderBadge(
                                          icon: Icons.verified_user_rounded,
                                          label: l10n.signupSafeSecureBadge,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (wide) ...[
                                      Text(
                                        l10n.signupCreateAccountTitle,
                                        style: GoogleFonts.michroma(
                                          fontSize: 22,
                                          color: _headingColor(context, ui),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        l10n.signupHeroSubtitle,
                                        style: TextStyle(
                                          color: ui.textMuted,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: _progressValue,
                                        minHeight: 8,
                                        backgroundColor: ui.border,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              ui.accent,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.signupStepCounter(
                                        '${_currentStep + 1}',
                                        '$_stepCount',
                                        _stepTitle(_currentStep),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: List.generate(
                                  _stepCount,
                                  (index) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: index == _stepCount - 1 ? 0 : 8,
                                      ),
                                      child: _StepPill(
                                        title: _stepShortTitle(index),
                                        isActive: _currentStep == index,
                                        isComplete: _currentStep > index,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildStepContent(
                                context: context,
                                l10n: l10n,
                                ui: ui,
                              ),
                              const SizedBox(height: 20),
                              _buildSignupActions(context, auth, l10n),
                            ],
                          ),
                        ),
                      ),
                    );

                    final heroPanel = Container(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ui.card.withValues(alpha: 0.72),
                            ui.cardStrong.withValues(alpha: 0.88),
                            ui.card.withValues(alpha: 0.94),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: ui.borderStrong),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OrbiLogoV2(width: 150),
                          const SizedBox(height: 20),
                          Text(
                            l10n.loginOrbiTagline,
                            style: GoogleFonts.michroma(
                              fontSize: 11,
                              color: ui.textMuted,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.signupHeroSubtitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: _headingColor(context, ui),
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSw
                                ? 'Fungua akaunti yako kwa hatua chache zilizo wazi, salama, na zinazolingana na mapendeleo yako.'
                                : 'Open your account through a guided setup that keeps your preferences, security, and onboarding clear from the start.',
                            style: TextStyle(
                              color: ui.textMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _HeaderBadge(
                                icon: Icons.person_add_alt_rounded,
                                label: isSw
                                    ? 'Usajili ulioongozwa'
                                    : 'Guided account setup',
                              ),
                              _HeaderBadge(
                                icon: Icons.public_rounded,
                                label: isSw
                                    ? 'Lugha na nchi'
                                    : 'Locale and country',
                              ),
                              _HeaderBadge(
                                icon: Icons.verified_user_outlined,
                                label: isSw
                                    ? 'Uthibitishaji salama'
                                    : 'Secure verification',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    if (!wide) return formCard;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: heroPanel),
                          const SizedBox(width: 22),
                          Expanded(child: formCard),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupActions(
    BuildContext context,
    AuthController auth,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, actionConstraints) {
        final stackActions = actionConstraints.maxWidth < 420;
        final backButton = OutlinedButton.icon(
          onPressed: auth.isLoading || _currentStep == 0
              ? null
              : () => setState(() => _currentStep -= 1),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(l10n.signupBackButton),
        );
        final nextButton = SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: auth.isLoading
                ? null
                : _currentStep == _stepCount - 1
                ? _submit
                : () => _goNext(l10n),
            icon: Icon(
              _currentStep == _stepCount - 1
                  ? Icons.task_alt_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              _currentStep == _stepCount - 1
                  ? l10n.actionCreateAccount
                  : l10n.signupNextButton,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );

        final loginLink = TextButton(
          onPressed: auth.isLoading
              ? null
              : () => Navigator.pushReplacementNamed(context, '/login'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(l10n.signupAlreadyHaveAccount),
        );

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep > 0) ...[
                SizedBox(width: double.infinity, child: backButton),
                const SizedBox(height: 12),
              ],
              SizedBox(width: double.infinity, child: nextButton),
              const SizedBox(height: 10),
              Center(child: loginLink),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(child: backButton),
                  const SizedBox(width: 12),
                ],
                Expanded(child: nextButton),
              ],
            ),
            const SizedBox(height: 10),
            loginLink,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _signupTheme(context);
    return Theme(
      data: theme,
      child: Builder(builder: (context) => _buildSignupScaffold(context)),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.title,
    required this.isActive,
    required this.isComplete,
  });

  final String title;
  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? ui.accentSoft
            : isComplete
            ? ui.successSoft
            : ui.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? ui.accent
              : isComplete
              ? ui.success
              : ui.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isComplete
                ? Icons.check_circle_rounded
                : isActive
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isActive
                ? ui.accent
                : isComplete
                ? ui.success
                : ui.textSoft,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive
                    ? ui.textPrimary
                    : isComplete
                    ? ui.success
                    : ui.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final headingColor = Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: ui.accentSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: ui.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: headingColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final headingColor = Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ui.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: headingColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyInfoTile extends StatelessWidget {
  const _ReadOnlyInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ui.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: ui.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w700,
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.country,
    required this.languageLabel,
    required this.currency,
    required this.phoneNumber,
    required this.email,
    required this.fullName,
    required this.title,
    required this.nameFallback,
    required this.emailFallback,
  });

  final CountryProfile country;
  final String languageLabel;
  final String currency;
  final String phoneNumber;
  final String email;
  final String fullName;
  final String title;
  final String nameFallback;
  final String emailFallback;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final headingColor = Theme.of(context).brightness == Brightness.dark
        ? ui.accent
        : ui.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: ui.accent),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: headingColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReviewChip(label: fullName.isEmpty ? nameFallback : fullName),
              _ReviewChip(label: email.isEmpty ? emailFallback : email),
              _ReviewChip(label: '${country.flag} ${country.name}'),
              _ReviewChip(label: phoneNumber),
              _ReviewChip(label: currency),
              _ReviewChip(label: languageLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  const _ReviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
