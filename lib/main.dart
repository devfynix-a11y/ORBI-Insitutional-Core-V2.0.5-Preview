library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/account_activation_screen.dart';
import 'features/auth/presentation/auth_onboarding_screen.dart';
import 'features/auth/presentation/password_reset_screen.dart';
import 'features/auth/presentation/secure_account_setup_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/profile/state/profile_controller.dart';
import 'features/dashboard/presentation/dashboard_screen.dart'
    show DashboardScreen;
import 'features/dashboard/state/dashboard_controller.dart'
    show DashboardController;
import 'features/shell/app_shell.dart';
import 'core/theme/orbi_theme.dart';
import 'core/security/device_fingerprint.dart';
import 'core/security/device_integrity_service.dart';
import 'core/security/tls_pinning.dart';
import 'core/widgets/activity_listener_wrapper.dart';
import 'core/widgets/location_readiness_gate.dart';
import 'core/widgets/orbi_loading_landing.dart';
import 'features/notifications/state/notification_controller.dart';
import 'features/goals/state/goals_controller.dart';
import 'core/config/app_config.dart';
import 'core/state/app_settings_controller.dart';
import 'core/services/firebase_service.dart';
import 'core/services/app_permission_service.dart';
import 'core/utils/otp_autofill.dart';
import 'globals.dart';

// Crash reporting
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// lib/main.dart
/// Application entry point.
/// Initializes ORBI Mobile and routes to Login screen.

Future<void> _safeStartupStep(
  String name,
  Future<void> Function() step, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final sw = Stopwatch()..start();
  try {
    await step().timeout(timeout);
    debugPrint('[STARTUP] $name completed in ${sw.elapsedMilliseconds}ms');
  } catch (e) {
    debugPrint(
      '[STARTUP] $name failed/timeout after ${sw.elapsedMilliseconds}ms: $e',
    );
  }
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // Initialize Firebase & Crashlytics early so crashes are reported in prod.
  try {
    await Firebase.initializeApp();
    // Enable collection only in non-debug builds.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  } catch (e, st) {
    // If Firebase isn't available in this environment, continue and let
    // FirebaseService.initialize try later. Do not throw here.
    debugPrint('❌ [CRASHLYTICS] Firebase init failed: $e\n$st');
  }

  // Route Flutter framework errors to Crashlytics in production, otherwise
  // fall back to console logging for dev.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
      if (details.stack != null) debugPrint(details.stack.toString());
    } else {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) {
      debugPrint('[WIDGET_BUILD_ERROR] ${details.exceptionAsString()}');
      if (details.stack != null) debugPrint(details.stack.toString());
    } else {
      // Capture a non-fatal message so we can triage widget build issues in prod
      FirebaseCrashlytics.instance
          .log('WIDGET_BUILD_ERROR: ${details.exceptionAsString()}');
    }
    return const _SafeFlutterErrorView();
  };

  binding.platformDispatcher.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[UNHANDLED] $error');
      debugPrint(stack.toString());
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
  await _safeStartupStep(
    'DeviceFingerprint.init',
    () => DeviceFingerprint.init(),
    timeout: const Duration(seconds: 4),
  );
  await _safeStartupStep(
    'DeviceIntegrityService.init',
    () => DeviceIntegrityService.init(),
    timeout: const Duration(seconds: 6),
  );
  TlsPinningInstaller.install();

  // Keep visual startup fast; notification infrastructure can warm in the background.
  unawaited(
    _safeStartupStep(
      'FirebaseService.initialize',
      () => FirebaseService().initialize(),
      timeout: const Duration(seconds: 10),
    ),
  );
  unawaited(
    _safeStartupStep(
      'AppPermissionService.requestStartupPermissions',
      () => AppPermissionService.instance.requestStartupPermissions(),
      timeout: const Duration(seconds: 12),
    ),
  );

  // Log the Android SMS Retriever hash once at startup so backend setup is easy.
  if (defaultTargetPlatform == TargetPlatform.android) {
    unawaited(
      _safeStartupStep('OtpAutoFillService.getAndroidHash', () async {
        try {
          final hash = await OtpAutoFillService().getAndroidHash();
          debugPrint(
            '[OTP] Android SMS Retriever hash (startup) result: $hash',
          );
          if (hash == null) {
            debugPrint('[OTP][ERROR] getAndroidHash returned null');
          } else if (hash.isEmpty) {
            debugPrint('[OTP][ERROR] getAndroidHash returned empty string');
          } else {
            debugPrint('[OTP] Android SMS Retriever hash (startup): $hash');
          }
        } catch (e, st) {
          debugPrint('[OTP][ERROR] Exception during getAndroidHash: $e');
          debugPrint('[OTP][ERROR] Stack trace: $st');
        }
      }, timeout: const Duration(seconds: 3)),
    );
  }

  debugPrint(
    '🔐 [PASSKEY] config rpId=${AppConfig.passkeyRpId} '
    'origin=${AppConfig.passkeyOrigin} '
    'assetLinksSha256=${AppConfig.androidAssetLinksSha256Fingerprint}',
  );

  // Protect async unhandled errors in zones so Crashlytics catches them.
  runZonedGuarded(() {
    runApp(const OrbiApp());
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('🧨 Unhandled async error: $error\n$stack');
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}


class _SafeFlutterErrorView extends StatelessWidget {
  const _SafeFlutterErrorView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFF9FBFE),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F6C7A).withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Color(0xFF0F6C7A), size: 30),
                SizedBox(height: 12),
                Text(
                  'This screen could not finish loading.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1E2F3A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Please go back, refresh, and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5E727E),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrbiApp extends StatelessWidget {
  const OrbiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => NotificationController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => GoalsController()),
        ChangeNotifierProvider(create: (_) => AppSettingsController()..load()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            navigatorKey: globalNavigatorKey,
            title: 'ORBI',
            debugShowCheckedModeBanner: false,
            theme: OrbiTheme.light(),
            darkTheme: OrbiTheme.dark(),
            themeMode: ThemeMode.system,
            locale: context.watch<AppSettingsController>().appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (locale, supportedLocales) {
              final languageCode = locale?.languageCode.toLowerCase();
              for (final supported in supportedLocales) {
                if (supported.languageCode.toLowerCase() == languageCode) {
                  return supported;
                }
              }
              return const Locale('en');
            },
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return ActivityListenerWrapper(
                child: LocationReadinessGate(child: child),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const _AppWithAutoLogout(),
              '/shell': (context) => const AppShell(),
              '/dashboard': (context) => const DashboardScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/secure-account-setup': (context) =>
                  const SecureAccountSetupScreen(),
              '/account-activation': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return AccountActivationScreen(
                  initialIdentifier: args is String ? args : null,
                );
              },
              '/password-reset': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return PasswordResetScreen(
                  initialIdentifier: args is String ? args : null,
                );
              },
            },
          );
        },
      ),
    );
  }
}

/// Wrapper to set up auto-logout callback when session expires
class _AppWithAutoLogout extends StatefulWidget {
  const _AppWithAutoLogout();

  @override
  State<_AppWithAutoLogout> createState() => _AppWithAutoLogoutState();
}

class _AppWithAutoLogoutState extends State<_AppWithAutoLogout>
    with WidgetsBindingObserver {
  final ValueNotifier<int> _inactivityWarningSeconds = ValueNotifier<int>(60);
  bool _warningDialogOpen = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();

      // Set the auto-lock callback
      auth.setAutoLogoutCallback(() {
        debugPrint('🚨 Session lock triggered - navigating to login');
        if (mounted) {
          _dismissInactivityWarning();
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
      });

      auth.sessionManager.setOnInactivityWarning((remaining) {
        if (!mounted) return;

        // In case session state changed while warning countdown was active.
        if (!auth.isAuthenticated || auth.isReauthLocked) {
          _dismissInactivityWarning();
          return;
        }

        _inactivityWarningSeconds.value = remaining;

        if (_warningDialogOpen) return;
        _showInactivityWarning();
      });

      auth.sessionManager.setOnInactivityWarningCleared(() {
        if (!mounted) return;
        _dismissInactivityWarning();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissInactivityWarning();
    _inactivityWarningSeconds.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        _wasBackgrounded = true;
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _wasBackgrounded = true;
        unawaited(context.read<AuthController>().markAppBackgrounded());
        break;
      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          _wasBackgrounded = false;
          unawaited(_revalidateSessionAfterResume());
        }
        break;
    }
  }

  Future<void> _revalidateSessionAfterResume() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();

    await auth.sessionManager.handleAppResumed();
    if (!mounted) return;

    if (auth.isReauthLocked) {
      _dismissInactivityWarning();
      return;
    }

    await auth.clearAppBackgroundMarker();

    final hasSessionContext =
        auth.isAuthenticated ||
        auth.isReauthLocked ||
        auth.currentSession != null;
    if (!hasSessionContext) return;

    final token = await auth.getValidAccessToken(expireSessionIfMissing: true);
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _dismissInactivityWarning();
    }
  }

  void _dismissInactivityWarning() {
    if (!_warningDialogOpen) return;
    _warningDialogOpen = false;

    final navigator = globalNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      try {
        navigator.pop();
      } catch (_) {
        // If pop fails for any reason (route already removed), ignore.
      }
    }
  }

  Future<void> _showInactivityWarning() async {
    if (_warningDialogOpen) return;
    _warningDialogOpen = true;

    final navigator = globalNavigatorKey.currentState;
    final overlayContext = globalNavigatorKey.currentContext;
    if (navigator == null || overlayContext == null) {
      _warningDialogOpen = false;
      return;
    }
    final auth = context.read<AuthController>();
    final l10n = AppLocalizations.of(overlayContext)!;
    final ui = OrbiTheme.uiOf(overlayContext);

    await showDialog<void>(
      context: overlayContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? ui.cardStrong.withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.96),
                    isDark
                        ? ui.card.withValues(alpha: 0.92)
                        : ui.cardMuted.withValues(alpha: 0.92),
                    ui.warningSoft.withValues(alpha: isDark ? 0.10 : 0.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ui.warning.withValues(alpha: 0.20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: ui.warning.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _inactivityWarningSeconds,
                builder: (context, remaining, _) {
                  final progress =
                      (remaining /
                              auth.sessionManager.warningLeadTime.inSeconds)
                          .clamp(0.0, 1.0);
                  final angle = (1 - progress) * math.pi * 2;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ui.warningSoft.withValues(alpha: 0.92),
                              ui.warning.withValues(alpha: 0.12),
                            ],
                          ),
                          border: Border.all(
                            color: ui.warning.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: ui.warning.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ui.warning,
                                ),
                              ),
                            ),
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: ui.card.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Transform.rotate(
                              angle: angle,
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 2.4,
                                      height: 20,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: ui.warning,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        size: 14,
                                        color: ui.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '$remaining',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.inactivityWarningTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.inactivityWarningMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ui.textMuted, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ui.cardMuted.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: ui.border.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Text(
                          l10n.inactivityWarningCountdown(remaining),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            auth.sessionManager.resetInactivityTimer();
                          },
                          icon: const Icon(Icons.touch_app_rounded),
                          label: Text(l10n.inactivityWarningStayButton),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    _warningDialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final settings = context.watch<AppSettingsController>();
    final l10n = AppLocalizations.of(context)!;
    if (auth.isInitializing) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: OrbiLoadingLanding(
          subtitle: l10n.shellBootstrapSubtitle,
          status: l10n.appLoadingStatus,
          detail: l10n.appLoadingDetail,
        ),
      );
    }
    if (!settings.isLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: OrbiLoadingLanding(
          subtitle: l10n.shellBootstrapSubtitle,
          status: l10n.preferencesLoadingStatus,
          detail: l10n.preferencesLoadingDetail,
        ),
      );
    }
    if (auth.isAuthenticated) {
      return const AppShell();
    }
    if (auth.biometricSetupRequired) {
      return const ActivityListenerWrapper(child: SecureAccountSetupScreen());
    }
    if (auth.isReauthLocked) {
      return const ActivityListenerWrapper(child: LoginScreen());
    }
    if (!settings.welcomeFlowCompleted) {
      return const ActivityListenerWrapper(child: AuthOnboardingScreen());
    }
    return const ActivityListenerWrapper(child: LoginScreen());
  }
}
