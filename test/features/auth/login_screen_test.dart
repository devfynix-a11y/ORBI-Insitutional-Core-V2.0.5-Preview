import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/core/theme/orbi_advanced_tokens.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/features/auth/presentation/login_screen.dart';
import 'package:orbi_mobileapp/features/auth/state/auth_controller.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final storage = <String, String>{};

  Future<dynamic> secureStorageHandler(MethodCall call) async {
    final arguments = Map<String, dynamic>.from(call.arguments as Map);
    final key = arguments['key'] as String?;
    switch (call.method) {
      case 'read':
        return key == null ? null : storage[key];
      case 'write':
        if (key != null) {
          storage[key] = (arguments['value'] ?? '').toString();
        }
        return null;
      case 'delete':
        if (key != null) {
          storage.remove(key);
        }
        return null;
      case 'deleteAll':
        storage.clear();
        return null;
      case 'containsKey':
        return key != null && storage.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(storage);
      default:
        return null;
    }
  }

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Theme(
            data: ThemeData.light().copyWith(
              extensions: const <ThemeExtension<dynamic>>[
                OrbiUiTokens.light(),
                OrbiSurfaceTokens.light(),
                OrbiAdvancedTokens.light(),
              ],
            ),
            child: const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    storage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('shows instant access view when a saved PIN exists', (
    WidgetTester tester,
  ) async {
    storage['remembered_user_profile'] = jsonEncode({
      'full_name': 'Jane Doe',
      'email': 'jane@example.com',
    });
    storage['pin_hash'] = 'hash';
    storage['pin_salt'] = 'salt';

    await pumpLoginScreen(tester);

    expect(find.text('Welcome back, Jane'), findsOneWidget);
    expect(find.text('Use PIN or biometrics.'), findsOneWidget);
    expect(find.text('Use password'), findsOneWidget);
  });

  testWidgets('can switch from instant access to password login form', (
    WidgetTester tester,
  ) async {
    storage['remembered_user_profile'] = jsonEncode({
      'full_name': 'Jane Doe',
      'email': 'jane@example.com',
    });
    storage['pin_hash'] = 'hash';
    storage['pin_salt'] = 'salt';

    await pumpLoginScreen(tester);
    final usePassword = find.text('Use password');
    await tester.ensureVisible(usePassword);
    await tester.tap(usePassword, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('shows password form by default when no instant access exists', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.text('Welcome to ORBI'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.text('Use password'), findsNothing);
  });
}




