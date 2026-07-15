import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:provider/provider.dart';
import '../auth/state/auth_controller.dart';

// Feature imports (Do NOT modify paths unless folder structure changes)
import '../dashboard/presentation/dashboard_screen.dart';
import '../payment/presentation/payment_screen.dart';
import '../notifications/presentation/notifications_prompt.dart';
import '../transactions/presentation/transactions_screen.dart';
import '../wallet/presentation/wallet_screen.dart';
import '../goals/presentation/goals_screen.dart';
import '../services/presentation/currency_exchange_screen.dart';
import '../services/presentation/agent_screen.dart';
import '../services/presentation/merchant_screen.dart';
import '../services/presentation/paysafe_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../chat/presentation/widgets/orbi_chatbot_overlay.dart';
import '../transfers/presentation/request_money_screen.dart';
import '../transfers/presentation/send_money_screen.dart';
import '../transfers/presentation/transfer_screen.dart';
import '../wallet/presentation/shared_pots_screen.dart';
import '../wallet/presentation/shared_budgets_screen.dart';
import '../wallet/presentation/bill_reserves_screen.dart';
import '../wallet/presentation/allocation_rules_screen.dart';
import '../wallet/presentation/link_external_wallet_launcher.dart';
import '../advanced_hub/presentation/advanced_hub_sheet.dart';
import 'package:orbi_mobileapp/features/notifications/state/notification_controller.dart';
import 'package:orbi_mobileapp/features/profile/state/profile_controller.dart';
import '../goals/state/goals_controller.dart';

// Custom AppBar
import '../../core/theme/orbi_theme.dart';
import '../../core/widgets/orbi_app_bar_new.dart';
import '../../core/widgets/orbi_loading_landing.dart';
import '../../core/widgets/orbi_state_card.dart';
import '../dashboard/state/dashboard_controller.dart';
import '../wallet/data/wallet_service.dart';

part 'app_shell_bootstrap.dart';
part 'app_shell_navigation.dart';
part 'app_shell_routes.dart';

/// =============================================================
/// AppShell
/// -------------------------------------------------------------
/// Main root screen after login.
/// Holds:
/// - AppBar
/// - Bottom navigation
/// - Floating Action Button
/// - IndexedStack for tab preservation
///
/// IMPORTANT:
/// This file controls ONLY UI navigation state.
/// No backend logic should be placed here.
/// =============================================================
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.screensOverride});

  final List<Widget>? screensOverride;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// -----------------------------------------------------------
  /// Current selected bottom navigation index
  /// 0 = Home
  /// 1 = Wealth
  /// 2 = Transactions
  /// 3 = Goals
  /// -----------------------------------------------------------
  int _currentIndex = 0;
  final Map<int, double> _navPressTurns = <int, double>{};
  bool _bootstrapInProgress = false;
  bool _bootstrapDone = false;
  bool _bootstrapScheduled = false;
  String? _bootstrapError;
  bool _startupBeepPlayed = false;

  StreamSubscription<Map<String, dynamic>>? _balanceUpdateSubscription;
  StreamSubscription<Map<String, dynamic>>? _serviceAccessEventSubscription;
  Timer? _dashboardRealtimeRefreshDebounce;
  Timer? _identityRefreshDebounce;

  AuthController? _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // grab auth controller for logout
    _auth ??= Provider.of<AuthController>(context, listen: false);
    _balanceUpdateSubscription ??= context
        .read<NotificationController>()
        .balanceUpdates
        .listen((_) => _scheduleRealtimeDashboardRefresh());
    _serviceAccessEventSubscription ??= context
        .read<NotificationController>()
        .serviceAccessEvents
        .listen((_) => _scheduleIdentityRefresh());
    _scheduleBootstrap();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot-reload/dev safety: ensure bootstrap can run again if needed.
    _scheduleBootstrap();
  }

  void _scheduleBootstrap() {
    if (_bootstrapDone || _bootstrapInProgress || _bootstrapScheduled) return;
    _bootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapScheduled = false;
      if (!mounted || _bootstrapDone || _bootstrapInProgress) return;
      _startBootstrap();
    });
  }

  Future<void> _startBootstrap() async {
    final l10n = AppLocalizations.of(context)!;
    final token = await _auth?.getValidAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _routeToPrimaryLogin(message: l10n.shellSessionExpiredMessage);
      return;
    }

    setState(() {
      _bootstrapInProgress = true;
      _bootstrapError = null;
      _startupBeepPlayed = false;
    });

    try {
      _ensureRealtimeNotifications(token);
      final dashboardController = context.read<DashboardController>();
      final profileController = context.read<ProfileController>();
      final notificationController = context.read<NotificationController>();
      final goalsController = context.read<GoalsController>();
      final walletService = WalletService();

      await Future.wait<void>([
        dashboardController.fetchDashboardData(token),
        profileController.loadProfile(),
        walletService.getWallets(forceRefresh: true).then((_) {}),
      ]);
      if (!mounted) return;

      setState(() {
        _bootstrapInProgress = false;
        _bootstrapDone = true;
        _bootstrapError = null;
      });
      if (!_startupBeepPlayed) {
        _startupBeepPlayed = true;
      }

      Future<void>(() async {
        try {
          await Future.wait<void>([
            notificationController.fetch(token),
            goalsController.loadAll(token, notify: false),
            walletService
                .getWalletTransactions(
                  '',
                  limit: 50,
                  offset: 0,
                  forceRefresh: true,
                )
                .then((_) {}),
          ]);
          await _auth?.refreshCurrentProfile();
        } catch (e) {
          debugPrint('⚠️ Deferred shell bootstrap sync failed: $e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      final sessionExpired =
          raw.contains('401') ||
          raw.contains('unauthorized') ||
          raw.contains('token expired') ||
          raw.contains('jwt') ||
          raw.contains('session expired') ||
          raw.contains('forbidden');
      if (sessionExpired) {
        _routeToPrimaryLogin(message: l10n.shellSessionExpiredMessage);
        return;
      }
      setState(() {
        _bootstrapInProgress = false;
        _bootstrapDone = false;
        _bootstrapError = _toUserFacingBootstrapError(e.toString());
      });
    }
  }

  String _toUserFacingBootstrapError(String raw) {
    final l10n = AppLocalizations.of(context)!;
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('timed out')) {
      return l10n.shellNoNetworkMessage;
    }
    return l10n.shellStartupFailedMessage;
  }

  void _routeToPrimaryLogin({String? message}) {
    if (!mounted) return;
    context.read<NotificationController>().stopRealtime();
    setState(() {
      _bootstrapInProgress = false;
      _bootstrapDone = false;
      _bootstrapError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dashboardRealtimeRefreshDebounce?.cancel();
    _identityRefreshDebounce?.cancel();
    _balanceUpdateSubscription?.cancel();
    _serviceAccessEventSubscription?.cancel();
    super.dispose();
  }

  void _ensureRealtimeNotifications(String token) {
    final userId = _resolveUserId(_auth?.session['user']);
    if (userId == null || userId.isEmpty) return;
    context.read<NotificationController>().startRealtime(token, userId);
  }

  void _scheduleRealtimeDashboardRefresh() {
    _dashboardRealtimeRefreshDebounce?.cancel();
    _dashboardRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        if (!mounted || _bootstrapInProgress) return;
        final dashboard = context.read<DashboardController>();
        final token = await _auth?.getValidAccessToken();
        if (!mounted) return;
        if (token == null || token.isEmpty) return;
        await dashboard.fetchDashboardData(token);
      },
    );
  }

  void _scheduleIdentityRefresh() {
    _identityRefreshDebounce?.cancel();
    _identityRefreshDebounce = Timer(
      const Duration(milliseconds: 700),
      () async {
        if (!mounted) return;
        final previousRole = _auth?.accountRole;
        final previousRegistryType = _auth?.registryType;
        try {
          await _auth?.refreshCurrentProfile();
          if (!mounted) return;
          final roleChanged =
              previousRole != _auth?.accountRole ||
              previousRegistryType != _auth?.registryType;
          if (roleChanged) {
            final resolvedRole = _auth?.accountRole ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your ORBI access has been updated to $resolvedRole.',
                ),
              ),
            );
          }
        } catch (_) {
          // Ignore transient refresh issues from realtime identity sync.
        }
      },
    );
  }

  Future<void> _restoreRealtimeNotifications() async {
    if (!mounted) return;
    final token = await _auth?.getValidAccessToken();
    if (!mounted || token == null || token.isEmpty) return;
    _ensureRealtimeNotifications(token);
    try {
      await context.read<NotificationController>().fetch(token);
    } catch (_) {
      // Ignore transient refresh errors while restoring foreground realtime.
    }
  }

  String? _resolveUserId(dynamic userObj) {
    if (userObj is Map) {
      final candidates = [
        userObj['id'],
        userObj['user_id'],
        userObj['userId'],
        userObj['uid'],
        userObj['customer_id'],
      ];
      for (final c in candidates) {
        if (c is String && c.isNotEmpty) return c;
        if (c is num) return c.toString();
      }
    }
    return null;
  }

  // capture interactions globally
  void _handleUserInteraction([_]) {
    _auth?.sessionManager.resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_auth?.isAuthenticated == true && _auth?.isReauthLocked != true) {
        unawaited(_restoreRealtimeNotifications());
        _scheduleIdentityRefresh();
      }
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      context.read<NotificationController>().stopRealtime();
    }
  }

  /// -----------------------------------------------------------
  /// Screens list
  /// IMPORTANT:
  /// Keep order aligned with bottom navigation items.
  ///
  /// We use const widgets for performance.
  /// IndexedStack preserves scroll and screen state.
  /// -----------------------------------------------------------
  List<Widget> _buildScreens() {
    final screensOverride = widget.screensOverride;
    if (screensOverride != null && screensOverride.isNotEmpty) {
      return screensOverride;
    }
    return [
      const DashboardScreen(), // Index 0: Home - Dashboard overview
      const WalletScreen(), // Index 1: Wealth - Manage accounts and balances
      const TransactionsScreen(), // Index 2: Transactions - Transaction history
      const GoalsScreen(), // Index 3: Goals - Financial goals tracker
    ];
  }

  /// -----------------------------------------------------------
  /// Handles bottom navigation taps
  ///
  /// Prevents unnecessary rebuild when tapping active tab.
  /// -----------------------------------------------------------
  void _onTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @visibleForTesting
  int get debugCurrentIndex => _currentIndex;

  @visibleForTesting
  void debugSelectTab(int index) => _onTap(index);

  Future<void> _animateNavPress(int index) async {
    final random = math.Random();
    final turn = (random.nextBool() ? 20 : -20) / 360;
    if (!mounted) return;
    setState(() => _navPressTurns[index] = turn);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _navPressTurns[index] = 0);
  }

  void _handleShellSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;
    _handleUserInteraction();
    final screens = _buildScreens();
    if (velocity < 0 && _currentIndex < screens.length - 1) {
      setState(() => _currentIndex += 1);
      return;
    }
    if (velocity > 0 && _currentIndex > 0) {
      setState(() => _currentIndex -= 1);
    }
  }

  /// -----------------------------------------------------------
  /// Handles Android system back button behavior
  ///
  /// UX Logic:
  /// - If not on Home → go to Home
  /// - If already on Home → allow app exit
  /// -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();
    final notificationCtrl = context.watch<NotificationController>();
    final screens = _buildScreens();
    final safeIndex = screens.isEmpty
        ? 0
        : _currentIndex.clamp(0, screens.length - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = safeIndex);
        }
      });
    }

    if (_bootstrapInProgress) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const _BootstrapLanding(),
      );
    }

    if (_bootstrapError != null) {
      final theme = Theme.of(context);
      final ui = OrbiTheme.uiOf(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: OrbiStateCard(
              icon: Icons.cloud_off_rounded,
              title: AppLocalizations.of(context)!.shellStartupUnavailableTitle,
              message: _bootstrapError!,
              accentColor: ui.danger,
              accentBackground: ui.dangerSoft,
              action: ElevatedButton.icon(
                onPressed: _startBootstrap,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.actionRetry),
              ),
            ),
          ),
        ),
      );
    }

    // listen for interactions anywhere
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: GestureDetector(
        key: const ValueKey<String>('shell-gesture-layer'),
        behavior: HitTestBehavior.translucent,
        onTap: _handleUserInteraction,
        onPanDown: _handleUserInteraction,
        onHorizontalDragEnd: _handleShellSwipe,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        OrbiTheme.surfacesOf(context).heroTop,
                        Color.lerp(
                              OrbiTheme.surfacesOf(context).heroTop,
                              OrbiTheme.surfacesOf(context).heroBottom,
                              0.55,
                            ) ??
                            OrbiTheme.surfacesOf(context).heroBottom,
                        OrbiTheme.surfacesOf(context).heroBottom,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Scaffold(
              extendBody: true,
              backgroundColor: Colors.transparent,

              /// -----------------------------------------------------
              /// Custom AppBar
              ///
              /// You may later pass:
              /// - notificationCount
              /// - user data
              /// - dynamic title
              /// -----------------------------------------------------
              appBar: OrbiAppBar(
                onProfilePressed: _openSettings,
                onNotificationPressed: _openNotifications,
                notificationCount: notificationCtrl.unreadCount,
              ),

              /// IndexedStack
              ///
              /// WHY IndexedStack?
              /// - Preserves scroll state
              /// - Prevents screen rebuild
              /// - Prevents API refetch (if any inside screen)
              /// -----------------------------------------------------
              body: _buildAnimatedShellBody(
                screens: screens,
                currentIndex: safeIndex,
              ),

              /// -----------------------------------------------------
              /// Floating Action Button (Center)
              ///
              /// Currently used for:
              /// - QR Payment
              /// - Quick Pay
              ///
              /// You may change icon or action later.
              /// -----------------------------------------------------
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom > 0 ? 2 : 6,
                ),
                child: FloatingActionButton(
                  onPressed: _openAdvancedHub,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  elevation: 0,
                  highlightElevation: 0,
                  shape: const CircleBorder(),
                  child: Builder(
                    builder: (context) {
                      final ui = OrbiTheme.uiOf(context);
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final fill = isDark ? ui.accent : const Color(0xFF2596BE);
                      return Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fill,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0D3A4A,
                              ).withValues(alpha: isDark ? 0.34 : 0.24),
                              blurRadius: 28,
                              spreadRadius: 1.2,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// FAB positioned inside bottom nav notch
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,

              /// -----------------------------------------------------
              /// Custom Glass Bottom Navigation
              ///
              /// Uses:
              /// - BackdropFilter (blur)
              /// - CircularNotchedRectangle (FAB notch)
              ///
              /// To modify:
              /// - Change height
              /// - Change blur intensity
              /// - Change color opacity
              /// -----------------------------------------------------
              bottomNavigationBar: _buildGlassBottomNav(
                currentIndex: safeIndex,
              ),
            ),
            OrbiChatbotOverlay(onInteraction: _handleUserInteraction),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedShellBody({
    required List<Widget> screens,
    required int currentIndex,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.padding.bottom;
    final compactNav = mediaQuery.size.width < 390;
    final shortNav = screenHeight < 760;
    final ultraCompactNav = mediaQuery.size.width < 350 || screenHeight < 700;
    final navHeight = ultraCompactNav
        ? 48.0
        : shortNav || compactNav
        ? 54.0
        : 58.0;
    final shellBottomClearance = navHeight + bottomInset;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final orderedIndexes = <int>[
      for (var i = 0; i < screens.length; i++)
        if (i != currentIndex) i,
      if (screens.isNotEmpty) currentIndex,
    ];

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final i in orderedIndexes)
            _ShellTabPane(
              key: ValueKey<String>('shell-pane-$i'),
              isActive: i == currentIndex,
              reduceMotion: reduceMotion,
              direction: i < currentIndex ? -1 : 1,
              bottomClearance: shellBottomClearance,
              child: screens[i],
            ),
        ],
      ),
    );
  }
}

class _ShellTabPane extends StatelessWidget {
  const _ShellTabPane({
    super.key,
    required this.isActive,
    required this.reduceMotion,
    required this.direction,
    required this.bottomClearance,
    required this.child,
  });

  final bool isActive;
  final bool reduceMotion;
  final int direction;
  final double bottomClearance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 380);
    final curve = isActive ? Curves.easeOutCubic : Curves.easeInCubic;

    return IgnorePointer(
      ignoring: !isActive,
      child: TickerMode(
        enabled: isActive,
        child: AnimatedOpacity(
          opacity: isActive ? 1 : 0,
          duration: duration,
          curve: curve,
          child: AnimatedSlide(
            offset: isActive ? Offset.zero : Offset(direction * 0.025, 0.012),
            duration: duration,
            curve: curve,
            child: AnimatedScale(
              scale: isActive ? 1 : 0.992,
              alignment: Alignment.center,
              duration: duration,
              curve: curve,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomClearance),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
