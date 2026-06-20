import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/auth/biometric_auth_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_preferences_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/security_otp_dialog.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/state/profile_controller.dart';
import '../../services/presentation/paysafe_screen.dart';
import '../../services/presentation/service_access_screen.dart';
import 'about_orbi_screen.dart';
import 'widgets/settings_common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OtpAutoFillService _otpAutoFill = OtpAutoFillService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();

  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  bool _biometricToggleBusy = false;
  bool _pushEnabled = true;
  bool _emailAlertsEnabled = true;
  bool _marketingEnabled = false;
  bool _notifSecurity = true;
  bool _notifFinancial = true;
  bool _notifBudget = true;
  bool _notifMarketing = false;
  String _languageCode = 'en';
  bool _applyLanguageToApp = false;
  bool _applyLanguageToServices = true;
  bool _isSavingServicePrefs = false;
  bool _languageInitialized = false;
  bool _initializedFromProfile = false;
  bool _isDisposed = false;

  static const String _prefLanguageCode = 'settings_app_language_code';
  static const String _prefApplyLanguageApp = 'settings_app_language_apply';
  static const String _prefApplyLanguageServices =
      'settings_service_language_apply';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadAppPrefs();
    _loadLanguagePrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ProfileController>().loadProfile();
      if (mounted) {
        _hydrateFromProfile();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _otpAutoFill.stopListening();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final availability = await BiometricAuthService().getAvailability();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = availability.supported;
      _biometricEnrolled = availability.enrolled;
    });
  }

  Future<void> _loadAppPrefs() async {
    final snapshot = await NotificationPreferencesService.instance.load();
    if (!mounted) return;
    setState(() {
      _marketingEnabled = snapshot.marketingEnabled;
      _pushEnabled = snapshot.pushChannelEnabled;
      _emailAlertsEnabled = snapshot.emailChannelEnabled;
      _notifSecurity = snapshot.notifSecurity;
      _notifFinancial = snapshot.notifFinancial;
      _notifBudget = snapshot.notifBudget;
      _notifMarketing = snapshot.notifMarketing;
    });
  }

  Future<void> _savePrefs() async {
    await NotificationPreferencesService.instance.saveDevicePreferences(
      pushEnabled: _pushEnabled,
      emailAlertsEnabled: _emailAlertsEnabled,
      marketingEnabled: _marketingEnabled,
    );
  }

  Future<void> _loadLanguagePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = prefs.getString(_prefLanguageCode) ?? _languageCode;
      _applyLanguageToApp = prefs.getBool(_prefApplyLanguageApp) ?? false;
      _applyLanguageToServices =
          prefs.getBool(_prefApplyLanguageServices) ?? true;
    });
  }

  Future<void> _saveLanguagePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguageCode, _languageCode);
    await prefs.setBool(_prefApplyLanguageApp, _applyLanguageToApp);
    await prefs.setBool(_prefApplyLanguageServices, _applyLanguageToServices);
  }

  Map<String, dynamic> _mergedProfile() {
    final profile = context.read<ProfileController>().profile;
    final auth = context.read<AuthController>().session;
    final user = auth['user'] is Map
        ? Map<String, dynamic>.from(auth['user'])
        : <String, dynamic>{};
    return {...user, ...profile};
  }

  void _hydrateFromProfile() {
    if (_initializedFromProfile) return;
    final merged = _mergedProfile();
    _nameController.text =
        (merged['full_name'] ?? merged['fullName'] ?? merged['name'] ?? '')
            .toString();
    _phoneController.text = (merged['phone'] ?? '').toString();
    _addressController.text = (merged['address'] ?? '').toString();
    _currencyController.text =
        (merged['currency'] ?? merged['currency_code'] ?? '')
            .toString()
            .toUpperCase();
    if (!_languageInitialized) {
      final lang = (merged['language'] ?? '').toString().toLowerCase();
      if (lang == 'en' || lang == 'sw') {
        _languageCode = lang;
      }
      _languageInitialized = true;
    }
    final security = merged['notif_security'];
    final financial = merged['notif_financial'];
    final budget = merged['notif_budget'];
    final marketing = merged['notif_marketing'];
    final push = merged['notif_push'];
    final email = merged['notif_email'];
    if (push is bool) _pushEnabled = push;
    if (email is bool) _emailAlertsEnabled = email;
    if (security is bool) _notifSecurity = security;
    if (financial is bool) _notifFinancial = financial;
    if (budget is bool) _notifBudget = budget;
    if (marketing is bool) _notifMarketing = marketing;
    unawaited(
      NotificationPreferencesService.instance.saveServicePreferences(
        notifPush: _pushEnabled,
        notifEmail: _emailAlertsEnabled,
        notifSecurity: _notifSecurity,
        notifFinancial: _notifFinancial,
        notifBudget: _notifBudget,
        notifMarketing: _notifMarketing,
      ),
    );
    _initializedFromProfile = true;
  }

  Future<void> _applyAppLanguage() async {
    if (_isSavingServicePrefs) return;
    setState(() => _isSavingServicePrefs = true);

    final localizations = AppLocalizations.of(context)!;
    final languageLabel = _languageLabel(context, _languageCode);
    final profileController = context.read<ProfileController>();
    bool appSuccess = true;
    bool serviceSuccess = true;

    // Apply app language settings if toggle is enabled
    if (_applyLanguageToApp) {
      try {
        final settings = context.read<AppSettingsController>();
        await settings.setAppLanguage(
          languageCode: _languageCode,
          applyToApp: _applyLanguageToApp,
        );
      } catch (e) {
        appSuccess = false;
      }
    }

    // Apply service settings if toggle is enabled
    if (_applyLanguageToServices) {
      final payload = <String, dynamic>{'language': _languageCode};
      serviceSuccess = await profileController.updateProfile(payload);
    }

    // Always save language preferences
    await _saveLanguagePrefs();

    if (!mounted) return;
    setState(() => _isSavingServicePrefs = false);

    // Show appropriate feedback message
    String message;
    if (_applyLanguageToApp && _applyLanguageToServices) {
      // Both toggles enabled
      if (appSuccess && serviceSuccess) {
        message = localizations.settingsAllPreferencesUpdatedMessage;
      } else if (appSuccess) {
        message = localizations.settingsAppLanguageUpdatedServiceFailedMessage;
      } else if (serviceSuccess) {
        message = localizations.settingsServiceUpdatedAppFailedMessage;
      } else {
        message = localizations.settingsAllPreferencesUpdateFailedMessage;
      }
    } else if (_applyLanguageToApp) {
      // Only app language
      message = appSuccess
          ? localizations.appLanguageSetMessage(languageLabel)
          : localizations.settingsAppLanguageUpdateFailedMessage;
    } else if (_applyLanguageToServices) {
      // Only services
      message = serviceSuccess
          ? localizations.settingsServicePreferencesUpdatedMessage
          : localizations.settingsServicePreferencesUpdateFailedMessage;
    } else {
      // No toggles enabled
      message = localizations.settingsNoPreferencesSelectedMessage;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _applyAllSettings() async {
    if (_isSavingServicePrefs) return;
    setState(() => _isSavingServicePrefs = true);

    final localizations = AppLocalizations.of(context)!;
    final profileController = context.read<ProfileController>();
    bool serviceSuccess = true;

    // Apply service settings (notifications and backend language)
    final payload = <String, dynamic>{
      if (_applyLanguageToServices) 'language': _languageCode,
      'notif_push': _pushEnabled,
      'notif_email': _emailAlertsEnabled,
      'notif_security': _notifSecurity,
      'notif_financial': _notifFinancial,
      'notif_budget': _notifBudget,
      'notif_marketing': _notifMarketing,
    };
    serviceSuccess = await profileController.updateProfile(payload);
    if (serviceSuccess) {
      await _saveLanguagePrefs();
      await NotificationPreferencesService.instance.saveServicePreferences(
        notifPush: _pushEnabled,
        notifEmail: _emailAlertsEnabled,
        notifSecurity: _notifSecurity,
        notifFinancial: _notifFinancial,
        notifBudget: _notifBudget,
        notifMarketing: _notifMarketing,
      );
    }

    if (!mounted) return;
    setState(() => _isSavingServicePrefs = false);

    // Show feedback message
    final message = serviceSuccess
        ? localizations.settingsServicePreferencesUpdatedMessage
        : localizations.settingsServicePreferencesUpdateFailedMessage;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _languageLabel(BuildContext context, String code) {
    final localizations = AppLocalizations.of(context)!;
    switch (code) {
      case 'sw':
        return localizations.languageSwahili;
      case 'en':
      default:
        return localizations.languageEnglish;
    }
  }

  Future<String?> _promptOtpDialog() async {
    if (_isDisposed) return null;
    return showSecurityOtpDialog(
      context: context,
      title: AppLocalizations.of(context)!.loginSecurityVerificationTitle,
      helperText: AppLocalizations.of(
        context,
      )!.settingsSecurityVerificationHelper,
      startListening: (onCode) => _otpAutoFill.startListening(onCode: onCode),
      stopListening: _otpAutoFill.stopListening,
    );
  }

  Future<void> _handleBiometricToggle(bool val) async {
    final auth = context.read<AuthController>();
    if (_biometricToggleBusy) return;

    if (!val) {
      await auth.setBiometricEnabled(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsBiometricDisabledMessage,
          ),
        ),
      );
      return;
    }

    setState(() => _biometricToggleBusy = true);
    try {
      final profile = _mergedProfile();
      final email = (profile['email'] ?? '').toString();
      final success = await auth.registerPasskey(
        email: email.isNotEmpty ? email : null,
        requestOtp: _promptOtpDialog,
      );
      if (!mounted) return;

      if (success) {
        final storage = SecureStorageService();
        final hasPin = await storage.hasPin();
        if (!mounted) return;
        if (!hasPin) {
          final pinSet = await _promptPinSetup();
          if (!mounted) return;
          if (!pinSet) {
            await auth.setBiometricEnabled(false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  )!.settingsPinRequiredForBiometricMessage,
                ),
              ),
            );
            return;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.of(context)!.settingsBiometricEnabledMessage
                : (auth.error ??
                      AppLocalizations.of(
                        context,
                      )!.settingsBiometricEnableFailedMessage),
          ),
        ),
      );
      if (!success) {
        await auth.setBiometricEnabled(false);
      }
    } finally {
      if (mounted) {
        setState(() => _biometricToggleBusy = false);
      }
    }
  }

  Future<bool> _promptPinSetup() async {
    final auth = context.read<AuthController>();
    String pin = '';
    String confirm = '';
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsSetPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              onChanged: (value) => pin = value,
              decoration: InputDecoration(labelText: l10n.pinNewLabel),
            ),
            TextField(
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              onChanged: (value) => confirm = value,
              decoration: InputDecoration(labelText: l10n.pinConfirmNewLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    final trimmedPin = pin.trim();
    final trimmedConfirm = confirm.trim();
    if (trimmedPin.length != 4 || trimmedPin != trimmedConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsNewPinInvalidMessage)),
      );
      return false;
    }
    final enrolled = await auth.enrollSecurityPin(trimmedPin);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enrolled
              ? l10n.settingsPinUpdatedMessage
              : (auth.error ?? l10n.settingsBiometricEnableFailedMessage),
        ),
      ),
    );
    return enrolled;
  }

  Future<void> _changePin() async {
    final storage = SecureStorageService();
    final hasPin = await storage.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      await _promptPinSetup();
      return;
    }
    String current = '';
    String newPin = '';
    String confirm = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.settingsChangePinTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                onChanged: (value) => current = value,
                decoration: InputDecoration(labelText: l10n.pinCurrentLabel),
              ),
              TextField(
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                onChanged: (value) => newPin = value,
                decoration: InputDecoration(labelText: l10n.pinNewLabel),
              ),
              TextField(
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                onChanged: (value) => confirm = value,
                decoration: InputDecoration(labelText: l10n.pinConfirmNewLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.actionUpdate),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (ok == true) {
      final trimmedCurrent = current.trim();
      final trimmedNewPin = newPin.trim();
      final trimmedConfirm = confirm.trim();
      final validCurrent = await storage.verifyPin(trimmedCurrent);
      if (!mounted) return;
      if (!validCurrent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.settingsCurrentPinIncorrectMessage,
              ),
            ),
          );
        }
      } else if (trimmedNewPin.length < 4 ||
          trimmedNewPin.length > 6 ||
          trimmedNewPin != trimmedConfirm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.settingsNewPinInvalidMessage,
              ),
            ),
          );
        }
      } else {
        final auth = context.read<AuthController>();
        final verified = await auth.biometricLogin(
          requestOtp: _promptOtpDialog,
        );
        if (!mounted) return;
        if (!verified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                auth.error ??
                    AppLocalizations.of(
                      context,
                    )!.settingsBiometricEnableFailedMessage,
              ),
            ),
          );
          return;
        }
        final updated = await auth.updateSecurityPin(trimmedNewPin);
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updated
                    ? AppLocalizations.of(context)!.settingsPinUpdatedMessage
                    : (auth.error ??
                          AppLocalizations.of(
                            context,
                          )!.settingsBiometricEnableFailedMessage),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    final currency = _currencyController.text.trim().toUpperCase();
    if (currency.isEmpty) {
      final sw =
          Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sw
                ? 'Weka sarafu ya akaunti ili kuendelea.'
                : 'Enter an account currency to continue.',
          ),
        ),
      );
      return;
    }
    final payload = <String, dynamic>{
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'currency': currency,
    };
    final ok = await context.read<ProfileController>().updateProfile(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocalizations.of(context)!.settingsProfileUpdatedMessage
              : AppLocalizations.of(
                  context,
                )!.settingsProfileUpdateFailedMessage,
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsChangePasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.passwordNewLabel,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.passwordConfirmLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.actionUpdate),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.length < 8) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsPasswordMinMessage,
          ),
        ),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsPasswordsNoMatchMessage,
          ),
        ),
      );
      return;
    }

    final auth = context.read<AuthController>();
    final success = await auth.completePasswordReset(newPassword);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocalizations.of(context)!.settingsPasswordUpdatedMessage
              : (auth.error ??
                    AppLocalizations.of(
                      context,
                    )!.settingsPasswordUpdateFailedMessage),
        ),
      ),
    );
  }

  Future<void> _syncPushPreference(bool enabled) async {
    final profileController = context.read<ProfileController>();
    final firebaseService = FirebaseService();
    final token = await firebaseService.setPushEnabled(enabled);
    final ok = await profileController.updateProfile({
      'notif_push': enabled,
      'fcm_token': token,
    });
    if (!mounted || ok) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? '${l10n.settingsPushNotificationsTitle} enabled locally, but backend sync failed.'
              : '${l10n.settingsPushNotificationsTitle} disabled locally, but backend sync failed.',
        ),
      ),
    );
  }

  Future<void> _syncEmailPreference(bool enabled) async {
    final profileController = context.read<ProfileController>();
    final ok = await profileController.updateProfile({'notif_email': enabled});
    if (!mounted || ok) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.settingsEmailAlertsTitle} updated locally, but backend sync failed.',
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final profileCtrl = context.read<ProfileController>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: OrbiTheme.uiOf(context).card,
      builder: (ctx) {
        final ui = OrbiTheme.uiOf(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: ui.accent),
                title: Text(
                  AppLocalizations.of(context)!.settingsChooseFromGallery,
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: ui.accent),
                title: Text(AppLocalizations.of(context)!.settingsTakePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;

    final ok = await profileCtrl.uploadAvatar(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocalizations.of(context)!.settingsProfilePhotoUpdatedMessage
              : (profileCtrl.error ??
                    AppLocalizations.of(
                      context,
                    )!.settingsProfilePhotoFailedMessage),
        ),
      ),
    );
  }

  bool _isKycVerified(Map<String, dynamic> profile) {
    final kycStatus =
        (profile['kyc_status'] ??
                profile['kycStatus'] ??
                (profile['kyc'] is Map
                    ? (profile['kyc'] as Map)['status']
                    : null))
            ?.toString();
    final kycLevelRaw =
        profile['kyc_level'] ??
        profile['kycLevel'] ??
        (profile['kyc'] is Map ? (profile['kyc'] as Map)['level'] : null);
    final kycLevel = int.tryParse('$kycLevelRaw') ?? 0;
    return kycLevel > 0 || _isKycVerifiedStatus(kycStatus);
  }

  bool _isKycVerifiedStatus(String? rawStatus) {
    final normalized = rawStatus
        ?.trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized == null || normalized.isEmpty) return false;

    if (normalized.contains('unverified') ||
        normalized.contains('not_verified') ||
        normalized.contains('incomplete') ||
        normalized.contains('inactive') ||
        normalized.contains('reject') ||
        normalized.contains('declin') ||
        normalized.contains('fail')) {
      return false;
    }

    const exactVerified = {
      'verified',
      'approved',
      'complete',
      'completed',
      'active',
      'kyc_verified',
      'kyc_approved',
      'kyc_complete',
      'kyc_completed',
      'kyc_active',
    };
    if (exactVerified.contains(normalized)) return true;

    return normalized.endsWith('_verified') ||
        normalized.endsWith('_approved') ||
        normalized.endsWith('_complete') ||
        normalized.endsWith('_completed');
  }

  String _kycStatusText(Map<String, dynamic> profile) {
    return (profile['kyc_status'] ??
            profile['kycStatus'] ??
            (profile['kyc'] is Map
                ? (profile['kyc'] as Map)['status']
                : null) ??
            'unverified')
        .toString();
  }

  bool _isKycWaiting(String statusText) {
    final s = statusText.toLowerCase();
    return s.contains('pending') ||
        s.contains('review') ||
        s.contains('waiting') ||
        s.contains('submitted') ||
        s.contains('processing');
  }

  Color _kycStatusColor({required bool isVerified, required bool isWaiting}) {
    if (isVerified) return const Color(0xFF16C784); // green
    if (isWaiting) return const Color(0xFFF5C542); // yellow
    return const Color(0xFFE24A4A); // red (unverified)
  }

  String? _normalizeIdTypeKey(String? rawType) {
    if (rawType == null) return null;
    final normalized = rawType.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('passport')) return 'passport';
    if (normalized.contains('driver')) return 'driving_license';
    if (normalized.contains('voter')) return 'voter_id';
    if (normalized.contains('national') ||
        normalized == 'id' ||
        normalized == 'national_id') {
      return 'national_id';
    }
    return null;
  }

  void _showKycVerificationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final ui = OrbiTheme.uiOf(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ui.cardStrong, ui.card, ui.sheet],
              ),
              border: Border.all(color: ui.borderStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: ui.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: ui.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.settingsKycVerificationRequiredTitle,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isSwahili(context)
                      ? 'Pakia kitambulisho na uthibitishe akaunti.'
                      : 'Upload ID and verify your account.',
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _openKycUpdateForm();
                      });
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsUpdateKycInformation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openKycUpdateForm() async {
    final profileCtrl = context.read<ProfileController>();
    final merged = _mergedProfile();
    final registeredName =
        (merged['full_name'] ?? merged['fullName'] ?? merged['name'] ?? '')
            .toString()
            .trim();
    final fullNameController = TextEditingController(text: registeredName);
    final idNumberController = TextEditingController();
    final idTypes = <String, String>{
      'national_id': AppLocalizations.of(context)!.settingsIdTypeNationalId,
      'passport': AppLocalizations.of(context)!.settingsIdTypePassport,
      'driving_license': AppLocalizations.of(
        context,
      )!.settingsIdTypeDrivingLicense,
      'voter_id': AppLocalizations.of(context)!.settingsIdTypeVoterId,
    };
    String selectedIdType = 'national_id';
    String? imagePath;
    bool pickingImage = false;
    bool scanningKyc = false;
    bool submittingKyc = false;
    bool hasScanResponse = false;
    bool scanSucceeded = false;
    String? scanErrorText;
    String? scanMetaText;
    final picker = ImagePicker();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final ui = OrbiTheme.uiOf(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickFrom(ImageSource source) async {
              if (!mounted || !ctx.mounted) return;
              setModalState(() => pickingImage = true);
              try {
                final file = await picker.pickImage(
                  source: source,
                  imageQuality: 88,
                  maxWidth: 1800,
                );
                if (!mounted || !ctx.mounted) return;
                if (file != null) {
                  setModalState(() {
                    imagePath = file.path;
                    hasScanResponse = false;
                    scanSucceeded = false;
                    scanErrorText = null;
                    scanMetaText = null;
                  });
                }
              } finally {
                if (mounted && ctx.mounted) {
                  setModalState(() => pickingImage = false);
                }
              }
            }

            Future<void> scanAndPrefill() async {
              if (scanningKyc) return;
              if (imagePath == null || imagePath!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsUploadIdFirstMessage,
                    ),
                  ),
                );
                return;
              }
              setModalState(() => scanningKyc = true);
              try {
                final result = await profileCtrl.scanKycDocument(imagePath!);
                if (!mounted || !ctx.mounted) return;
                if (result == null || result.isEmpty) {
                  final message =
                      profileCtrl.error ??
                      AppLocalizations.of(
                        context,
                      )!.settingsScanCouldNotExtractMessage;
                  setModalState(() {
                    hasScanResponse = true;
                    scanSucceeded = false;
                    scanErrorText = message;
                    scanMetaText = null;
                  });
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                  return;
                }

                final extractedId = (result['id_number'] ?? '')
                    .toString()
                    .trim();
                final extractedType = _normalizeIdTypeKey(
                  result['id_type']?.toString(),
                );
                final extractedName = (result['full_name'] ?? '')
                    .toString()
                    .trim();
                final extractedDob = (result['dob'] ?? '').toString().trim();
                final extractedExpiry = (result['expiry_date'] ?? '')
                    .toString()
                    .trim();

                setModalState(() {
                  hasScanResponse = true;
                  scanSucceeded = true;
                  scanErrorText = null;
                  if (extractedId.isNotEmpty) {
                    idNumberController.text = extractedId;
                  }
                  if (extractedType != null &&
                      idTypes.containsKey(extractedType)) {
                    selectedIdType = extractedType;
                  }
                  if (extractedName.isNotEmpty &&
                      registeredName.isNotEmpty &&
                      extractedName.toLowerCase() !=
                          registeredName.toLowerCase()) {
                    scanMetaText = AppLocalizations.of(
                      context,
                    )!.settingsScanNameMismatchMessage;
                  } else {
                    scanMetaText = AppLocalizations.of(
                      context,
                    )!.settingsScanSuccessMessage;
                  }
                  if (extractedDob.isNotEmpty) {
                    scanMetaText =
                        '${scanMetaText ?? ''} ${AppLocalizations.of(context)!.settingsScanDobLabel}: $extractedDob'
                            .trim();
                  }
                  if (extractedExpiry.isNotEmpty) {
                    scanMetaText =
                        '${scanMetaText ?? ''} ${AppLocalizations.of(context)!.settingsScanExpiryLabel}: $extractedExpiry'
                            .trim();
                  }
                });
              } finally {
                if (ctx.mounted) {
                  setModalState(() => scanningKyc = false);
                }
              }
            }

            Future<void> submit() async {
              if (submittingKyc) return;
              final idNumber = idNumberController.text.trim();
              if (registeredName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsProfileNameMissingMessage,
                    ),
                  ),
                );
                return;
              }
              if (idNumber.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsEnterIdNumberMessage,
                    ),
                  ),
                );
                return;
              }
              if (imagePath == null || imagePath!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsUploadIdHoldingMessage,
                    ),
                  ),
                );
                return;
              }

              setModalState(() => submittingKyc = true);
              try {
                final ok = await profileCtrl.submitKyc(
                  fullName: registeredName,
                  idType: selectedIdType,
                  idNumber: idNumber,
                  imagePath: imagePath!,
                );
                if (!mounted || !ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.settingsKycSubmittedMessage,
                        ),
                      ),
                    );
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        profileCtrl.error ??
                            AppLocalizations.of(
                              context,
                            )!.settingsKycSubmitFailedMessage,
                      ),
                    ),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setModalState(() => submittingKyc = false);
                }
              }
            }

            final canSubmit =
                !submittingKyc &&
                !scanningKyc &&
                imagePath != null &&
                imagePath!.isNotEmpty &&
                hasScanResponse;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 18,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ui.borderStrong),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.settingsUpdateKycInformation,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSwahili(context)
                            ? 'Jina la akaunti'
                            : 'Account name',
                        style: TextStyle(color: ui.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fullNameController,
                        readOnly: true,
                        style: TextStyle(color: ui.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.settingsKycRegisteredFullNameLabel,
                          labelStyle: TextStyle(color: ui.textMuted),
                          filled: true,
                          fillColor: ui.cardMuted.withValues(alpha: 0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedIdType,
                        dropdownColor: ui.card,
                        style: TextStyle(color: ui.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.settingsKycIdTypeLabel,
                          labelStyle: TextStyle(color: ui.textMuted),
                          filled: true,
                          fillColor: ui.cardMuted.withValues(alpha: 0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                        ),
                        items: idTypes.entries
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => selectedIdType = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: idNumberController,
                        style: TextStyle(color: ui.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.settingsKycIdNumberLabel,
                          labelStyle: TextStyle(color: ui.textMuted),
                          filled: true,
                          fillColor: ui.cardMuted.withValues(alpha: 0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ui.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: pickingImage
                            ? null
                            : () => showModalBottomSheet<void>(
                                context: ctx,
                                backgroundColor: ui.card,
                                builder: (pickerCtx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          Icons.photo_library,
                                          color: ui.accent,
                                        ),
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.settingsChooseFromGallery,
                                        ),
                                        onTap: () {
                                          Navigator.pop(pickerCtx);
                                          pickFrom(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(
                                          Icons.camera_alt,
                                          color: ui.accent,
                                        ),
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.settingsTakePhoto,
                                        ),
                                        onTap: () {
                                          Navigator.pop(pickerCtx);
                                          pickFrom(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: ui.cardMuted.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ui.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: imagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.file(
                                    File(imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (pickingImage)
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )
                                    else ...[
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        color: ui.accent,
                                        size: 26,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isSwahili(context)
                                            ? 'Pakia kitambulisho'
                                            : 'Upload ID',
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: scanningKyc || submittingKyc
                              ? null
                              : scanAndPrefill,
                          icon: scanningKyc
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.document_scanner_outlined),
                          label: Text(
                            scanningKyc
                                ? AppLocalizations.of(
                                    context,
                                  )!.settingsScanningIdLabel
                                : AppLocalizations.of(
                                    context,
                                  )!.settingsAutoFillFromIdScanLabel,
                          ),
                        ),
                      ),
                      if (hasScanResponse && !scanSucceeded) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ui.dangerSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ui.danger.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            scanErrorText ??
                                AppLocalizations.of(
                                  context,
                                )!.settingsAutoScanVerifyFailedMessage,
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (!hasScanResponse) ...[
                        const SizedBox(height: 8),
                        Text(
                          _isSwahili(context)
                              ? 'Scan kitambulisho kwanza.'
                              : 'Scan ID first.',
                          style: TextStyle(color: ui.textMuted, fontSize: 11),
                        ),
                      ],
                      if (scanMetaText != null && scanMetaText!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          scanMetaText!,
                          style: TextStyle(color: ui.textMuted, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? submit : null,
                          icon: submittingKyc
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(
                            submittingKyc
                                ? AppLocalizations.of(
                                    context,
                                  )!.sendMoneySubmittingLabel
                                : AppLocalizations.of(
                                    context,
                                  )!.settingsSubmitKycLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    fullNameController.dispose();
    idNumberController.dispose();
  }

  Widget _sectionCard({required Widget child}) {
    final ui = OrbiTheme.uiOf(context);
    return SettingsSectionCard(ui: ui, child: child);
  }

  Widget _infoField(
    String label,
    TextEditingController controller, {
    TextInputType? type,
    bool enabled = true,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return SettingsInfoField(
      ui: ui,
      label: label,
      controller: controller,
      type: type,
      enabled: enabled,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    final ui = OrbiTheme.uiOf(context);
    return SettingsSectionTitle(
      ui: ui,
      title: title,
      subtitle: subtitle,
      icon: icon,
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return SettingsTile(
      ui: ui,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      iconColor: iconColor,
      trailing: trailing,
    );
  }

  Widget _settingsSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Color? iconColor,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return SettingsSwitchTile(
      ui: ui,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      iconColor: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = OrbiTheme.uiOf(context);
    final auth = context.watch<AuthController>();
    final profileCtrl = context.watch<ProfileController>();
    final localizations = AppLocalizations.of(context)!;
    final profile = _mergedProfile();
    if (!_initializedFromProfile && profile.isNotEmpty) {
      _hydrateFromProfile();
    }

    final userName =
        (profile['full_name'] ??
                profile['name'] ??
                localizations.settingsUserFallback)
            .toString();
    final userEmail =
        (profile['email'] ?? localizations.settingsNoEmailFallback).toString();
    final rawAvatarUrl = (profile['avatar_url'] ?? profile['avatarUrl'])
        ?.toString();
    final avatarUrl = rawAvatarUrl != null && rawAvatarUrl.isNotEmpty
        ? '$rawAvatarUrl${rawAvatarUrl.contains('?') ? '&' : '?'}v=${profileCtrl.avatarRefreshTick}'
        : null;
    final customerId =
        [
          profile['customer_id'],
          profile['customerId'],
          profile['customerID'],
          profile['fnx_id'],
          profile['fnxId'],
        ].firstWhere(
          (v) => v != null && v.toString().trim().isNotEmpty,
          orElse: () => null,
        );
    final customerIdText =
        customerId?.toString() ?? localizations.transactionsNotAvailable;
    final kyc = _kycStatusText(profile);
    final isKycVerified = _isKycVerified(profile);
    final isKycWaiting = _isKycWaiting(kyc);
    final kycColor = _kycStatusColor(
      isVerified: isKycVerified,
      isWaiting: isKycWaiting,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(localizations.settingsTitle),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: ui.textPrimary,
      ),
      body: OrbiBackground(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          child: OrbiResponsiveContent(
            padding: OrbiResponsive.pagePadding(context, top: 12, bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileOverviewCard(
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: ui.cardMuted,
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : localizations
                                                  .settingsUserInitialFallback,
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: GestureDetector(
                                  onTap: profileCtrl.isUploadingAvatar
                                      ? null
                                      : _pickAndUploadPhoto,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ui.accent,
                                    ),
                                    child: profileCtrl.isUploadingAvatar
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF0A0D0C),
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt_outlined,
                                            size: 16,
                                            color:
                                                theme.colorScheme.onSecondary,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.settingsAccountInformationTitle,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  userEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _settingsHeroMetric(
                              ui,
                              Icons.badge_outlined,
                              Localizations.localeOf(
                                        context,
                                      ).languageCode.toLowerCase() ==
                                      'sw'
                                  ? 'Namba ya mteja'
                                  : 'Customer ID',
                              customerIdText,
                              onTap: customerId == null
                                  ? null
                                  : () => _copyCustomerId(customerIdText),
                              trailingIcon: customerId == null
                                  ? null
                                  : Icons.copy_rounded,
                            ),
                            _settingsHeroMetric(
                              ui,
                              Icons.verified_user_outlined,
                              'KYC',
                              kyc,
                              valueColor: kycColor,
                            ),
                            _settingsHeroMetric(
                              ui,
                              Icons.language_outlined,
                              Localizations.localeOf(
                                        context,
                                      ).languageCode.toLowerCase() ==
                                      'sw'
                                  ? 'Lugha'
                                  : 'Language',
                              _languageLabel(context, _languageCode),
                            ),
                          ],
                        ),
                      ),
                      if (!isKycVerified) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _showKycVerificationSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ui.iconMuted.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ui.iconMuted.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: ui.iconMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    localizations.settingsVerifyNowMessage,
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: ui.iconMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        localizations.settingsAccountInformationTitle,
                        '',
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _infoField(
                        localizations.settingsFullNameLabel,
                        _nameController,
                      ),
                      _infoField(
                        localizations.settingsPhoneLabel,
                        _phoneController,
                        type: TextInputType.phone,
                      ),
                      _infoField(
                        localizations.settingsAddressLabel,
                        _addressController,
                      ),
                      _infoField(
                        localizations.settingsCurrencyLabel,
                        _currencyController,
                        enabled: false,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: profileCtrl.isUpdatingProfile
                              ? null
                              : _saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            profileCtrl.isUpdatingProfile
                                ? localizations.settingsSavingLabel
                                : localizations.settingsSaveProfileLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        localizations.settingsSecurityTitle,
                        '',
                        Icons.shield_outlined,
                      ),
                      const SizedBox(height: 8),
                      if (_biometricAvailable)
                        _settingsSwitchTile(
                          icon: Icons.fingerprint,
                          title: localizations.settingsUseBiometricsTitle,
                          subtitle: _biometricEnrolled
                              ? localizations.settingsUseBiometricsSubtitle
                              : localizations
                                    .settingsEnableDeviceBiometricsSubtitle,
                          value: auth.biometricEnabled,
                          onChanged: _biometricToggleBusy
                              ? null
                              : (val) => _handleBiometricToggle(val),
                        )
                      else
                        _settingsTile(
                          icon: Icons.fingerprint,
                          title:
                              localizations.settingsBiometricUnavailableTitle,
                          subtitle: localizations
                              .settingsBiometricUnavailableSubtitle,
                          iconColor: ui.iconMuted,
                        ),
                      if (auth.biometricEnabled)
                        _settingsTile(
                          icon: Icons.pin,
                          title: localizations.settingsChangePinTitle,
                          subtitle: localizations.settingsChangePinSubtitle,
                          onTap: _changePin,
                        ),
                      _settingsTile(
                        icon: Icons.lock_outline,
                        title: localizations.settingsChangePasswordTitle,
                        subtitle: localizations.settingsChangePasswordSubtitle,
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        localizations.languageTitle,
                        '',
                        Icons.language_outlined,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: ui.cardMuted.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ui.border),
                        ),
                        child: RadioGroup<String>(
                          groupValue: _languageCode,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _languageCode = value);
                          },
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                value: 'en',
                                activeColor: ui.accent,
                                selected: _languageCode == 'en',
                                title: Text(
                                  localizations.languageEnglish,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  localizations.languageEnglishSubtitle,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: ui.border),
                              RadioListTile<String>(
                                value: 'sw',
                                activeColor: ui.accent,
                                selected: _languageCode == 'sw',
                                title: Text(
                                  localizations.languageSwahili,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  localizations.languageSwahiliSubtitle,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _settingsSwitchTile(
                        icon: Icons.phone_iphone,
                        title: localizations.applyToAppLanguageTitle,
                        subtitle: localizations.applyToAppLanguageSubtitle,
                        value: _applyLanguageToApp,
                        onChanged: (v) async {
                          setState(() => _applyLanguageToApp = v);
                          await _saveLanguagePrefs();
                        },
                      ),
                      _settingsSwitchTile(
                        icon: Icons.forum_outlined,
                        title: localizations.applyToServicesTitle,
                        subtitle: localizations.applyToServicesSubtitle,
                        value: _applyLanguageToServices,
                        onChanged: (v) async {
                          setState(() => _applyLanguageToServices = v);
                          await _saveLanguagePrefs();
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyAppLanguage,
                          icon: const Icon(Icons.translate),
                          label: Text(
                            _isSavingServicePrefs
                                ? localizations.applyingButton
                                : localizations.applyButton,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        localizations.notificationsTitle,
                        '',
                        Icons.notifications_outlined,
                      ),
                      const SizedBox(height: 6),
                      _settingsSwitchTile(
                        icon: Icons.security_outlined,
                        title: localizations.securityAlertsTitle,
                        subtitle: localizations.securityAlertsSubtitle,
                        value: _notifSecurity,
                        onChanged: (v) => setState(() => _notifSecurity = v),
                      ),
                      _settingsSwitchTile(
                        icon: Icons.payments_outlined,
                        title: localizations.financialAlertsTitle,
                        subtitle: localizations.financialAlertsSubtitle,
                        value: _notifFinancial,
                        onChanged: (v) => setState(() => _notifFinancial = v),
                      ),
                      _settingsSwitchTile(
                        icon: Icons.pie_chart_outline,
                        title: localizations.budgetAlertsTitle,
                        subtitle: localizations.budgetAlertsSubtitle,
                        value: _notifBudget,
                        onChanged: (v) => setState(() => _notifBudget = v),
                      ),
                      _settingsSwitchTile(
                        icon: Icons.local_offer_outlined,
                        title: localizations.marketingUpdatesTitle,
                        subtitle: localizations.marketingUpdatesSubtitle,
                        value: _notifMarketing,
                        onChanged: (v) => setState(() => _notifMarketing = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSavingServicePrefs ||
                                  profileCtrl.isUpdatingProfile
                              ? null
                              : _applyAllSettings,
                          icon: const Icon(Icons.check_circle_outlined),
                          label: Text(
                            _isSavingServicePrefs
                                ? localizations.applyingButton
                                : localizations.applyToServicesButton,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        localizations.settingsDeviceNotificationsTitle,
                        '',
                        Icons.tune_rounded,
                      ),
                      const SizedBox(height: 8),
                      _settingsSwitchTile(
                        icon: Icons.notifications_active_outlined,
                        title: localizations.settingsPushNotificationsTitle,
                        subtitle:
                            localizations.settingsPushNotificationsSubtitle,
                        value: _pushEnabled,
                        onChanged: (v) async {
                          setState(() => _pushEnabled = v);
                          await _savePrefs();
                          await _syncPushPreference(v);
                        },
                      ),
                      _settingsSwitchTile(
                        icon: Icons.email_outlined,
                        title: localizations.settingsEmailAlertsTitle,
                        subtitle: localizations.settingsEmailAlertsSubtitle,
                        value: _emailAlertsEnabled,
                        onChanged: (v) async {
                          setState(() => _emailAlertsEnabled = v);
                          await _savePrefs();
                          await _syncEmailPreference(v);
                        },
                      ),
                      _settingsSwitchTile(
                        icon: Icons.local_offer_outlined,
                        title: localizations.marketingUpdatesTitle,
                        subtitle:
                            localizations.settingsMarketingUpdatesSubtitle,
                        value: _marketingEnabled,
                        onChanged: (v) async {
                          setState(() => _marketingEnabled = v);
                          await _savePrefs();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    children: [
                      _settingsTile(
                        icon: Icons.lock_clock_outlined,
                        title: _isSwahili(context)
                            ? 'Zana za ulinzi'
                            : 'Protection tools',
                        subtitle: _isSwahili(context)
                            ? 'Fungua PaySafe moja kwa moja.'
                            : 'Open PaySafe directly.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PaySafeScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(color: ui.border),
                      _settingsTile(
                        icon: Icons.verified_user_outlined,
                        title: _isSwahili(context)
                            ? 'Ruhusa ya huduma'
                            : 'Service access',
                        subtitle: _isSwahili(context)
                            ? 'Omba au kagua ruhusa za merchant na agent.'
                            : 'Request or review merchant and agent access.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ServiceAccessScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(color: ui.border),
                      _settingsTile(
                        icon: Icons.help_outline,
                        title: localizations.settingsHelpSupportTitle,
                        subtitle: _isSwahili(context)
                            ? 'Pata msaada'
                            : 'Get help',
                        onTap: _showHelpSupportDialog,
                      ),
                      Divider(color: ui.border),
                      _settingsTile(
                        icon: Icons.info_outline,
                        title: localizations.settingsAboutTitle,
                        subtitle: _isSwahili(context)
                            ? 'Dhamira, huduma na ulinzi wa ORBI'
                            : 'ORBI mission, services, and protection',
                        onTap: _openAboutOrbi,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ui.danger,
                      side: BorderSide(color: ui.danger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      AppLocalizations.of(context)!.settingsLogoutTitle,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            AppLocalizations.of(context)!.settingsLogoutTitle,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.settingsLogoutConfirmMessage,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                AppLocalizations.of(context)!.actionCancel,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                AppLocalizations.of(context)!.actionLogout,
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (_) => false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileOverviewCard({required Widget child}) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(ui.iconMuted, ui.card, 0.92) ?? ui.card,
            ui.cardStrong,
            ui.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.borderStrong),
      ),
      child: child,
    );
  }

  Widget _settingsHeroMetric(
    OrbiUiTokens ui,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    final content = Container(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ui.iconMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ui.textMuted, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, size: 14, color: ui.accent),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }

  Future<void> _copyCustomerId(String customerId) async {
    final value = customerId.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    final sw = _isSwahili(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sw ? 'Namba ya mteja imenakiliwa.' : 'Customer ID copied.',
        ),
      ),
    );
  }

  Future<void> _showHelpSupportDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsHelpSupportTitle),
        content: Text(
          sw
              ? 'Kwa changamoto za akaunti, malipo, au uthibitishaji, anza na arifa za ndani ya programu na zana za wasifu. Tatizo likiendelea, wasiliana na kituo cha usaidizi cha ORBI ukiambatanisha muda na hatua iliyoshindikana.'
              : 'For account, payment, or verification issues, use the in-app notifications and profile tools first. If the issue continues, contact your ORBI support channel with the exact time and action that failed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  bool _isSwahili(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  }

  Future<void> _openAboutOrbi() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutOrbiScreen()));
  }
}
