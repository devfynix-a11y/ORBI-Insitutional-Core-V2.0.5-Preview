import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/core/theme/orbi_advanced_tokens.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/features/auth/auth_models.dart';
import 'package:orbi_mobileapp/features/auth/state/auth_controller.dart';
import 'package:orbi_mobileapp/features/dashboard/state/dashboard_controller.dart';
import 'package:orbi_mobileapp/features/goals/state/goals_controller.dart';
import 'package:orbi_mobileapp/features/notifications/state/notification_controller.dart';
import 'package:orbi_mobileapp/features/profile/state/profile_controller.dart';
import 'package:orbi_mobileapp/features/shell/app_shell.dart';
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

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => _FakeAuthController(),
          ),
          ChangeNotifierProvider<NotificationController>(
            create: (_) => _FakeNotificationController(),
          ),
          ChangeNotifierProvider<DashboardController>(
            create: (_) => _FakeDashboardController(),
          ),
          ChangeNotifierProvider<ProfileController>(
            create: (_) => _FakeProfileController(),
          ),
          ChangeNotifierProvider<GoalsController>(
            create: (_) => _FakeGoalsController(),
          ),
        ],
        child: MaterialApp(
          routes: {
            '/login': (_) => const Scaffold(body: Text('Login Route')),
          },
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
            child: AppShell(
              screensOverride: const [
                Center(child: Text('Home Pane')),
                Center(child: Text('Wallet Pane')),
                Center(child: Text('Transactions Pane')),
                Center(child: Text('Goals Pane')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> settleShellMotion(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool paneIsActive(WidgetTester tester, int index) {
    final dynamic pane = tester.widget(
      find.byKey(ValueKey<String>('shell-pane-$index')),
    );
    return pane.isActive as bool;
  }

  dynamic shellState(WidgetTester tester) => tester.state(find.byType(AppShell));

  testWidgets('selecting a tab activates its pane', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    expect(paneIsActive(tester, 0), isTrue);
    expect(paneIsActive(tester, 1), isFalse);

    shellState(tester).debugSelectTab(1);
    await settleShellMotion(tester);

    expect(shellState(tester).debugCurrentIndex, 1);
    expect(paneIsActive(tester, 0), isFalse);
    expect(paneIsActive(tester, 1), isTrue);
  });

  testWidgets('system back returns to the home pane from a secondary tab', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    shellState(tester).debugSelectTab(2);
    await settleShellMotion(tester);
    expect(shellState(tester).debugCurrentIndex, 2);
    expect(paneIsActive(tester, 2), isTrue);

    await tester.binding.handlePopRoute();
    await settleShellMotion(tester);

    expect(shellState(tester).debugCurrentIndex, 0);
    expect(paneIsActive(tester, 0), isTrue);
    expect(paneIsActive(tester, 2), isFalse);
  });

  testWidgets('horizontal swipes move between shell panes', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    final gestureLayer = find.byKey(
      const ValueKey<String>('shell-gesture-layer'),
    );

    await tester.fling(gestureLayer, const Offset(-500, 0), 1200);
    await settleShellMotion(tester);
    expect(paneIsActive(tester, 1), isTrue);

    await tester.fling(gestureLayer, const Offset(500, 0), 1200);
    await settleShellMotion(tester);
    expect(paneIsActive(tester, 0), isTrue);
  });
}

class _FakeAuthController extends AuthController {
  _FakeAuthController() : super() {
    currentSession = SessionModel(
      accessToken: 'test-token',
      user: UserModel.fromJson({
        'id': 'user-123',
        'email': 'jane@example.com',
        'full_name': 'Jane Doe',
        'role': 'USER',
        'registry_type': 'CONSUMER',
      }),
    );
  }

  @override
  Future<String?> getValidAccessToken({bool expireSessionIfMissing = true}) async {
    return 'test-token';
  }

  @override
  Future<void> refreshCurrentProfile() async {}
}

class _FakeNotificationController extends NotificationController {
  final StreamController<Map<String, dynamic>> _balanceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _serviceAccessController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  int get unreadCount => 0;

  @override
  Stream<Map<String, dynamic>> get balanceUpdates => _balanceController.stream;

  @override
  Stream<Map<String, dynamic>> get serviceAccessEvents =>
      _serviceAccessController.stream;

  @override
  Future<void> fetch(String token, {int limit = 50, int offset = 0}) async {}

  @override
  Future<void> startRealtime(String token, String userId) async {}

  @override
  void stopRealtime() {}

  @override
  void dispose() {
    _balanceController.close();
    _serviceAccessController.close();
    super.dispose();
  }
}

class _FakeDashboardController extends DashboardController {
  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchDashboardData(String token) async {}
}

class _FakeProfileController extends ProfileController {
  @override
  Future<void> loadProfile() async {}
}

class _FakeGoalsController extends GoalsController {
  _FakeGoalsController() : super();

  @override
  Future<void> loadAll(String token, {bool notify = true}) async {}
}
