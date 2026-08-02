import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_card_styles.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/orbi_activity_card.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/orbi_wealth_ring.dart';
import '../../advanced_hub/presentation/advanced_hub_sheet.dart';
import '../../auth/state/auth_controller.dart';
import '../../payment/presentation/payment_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../services/presentation/agent_screen.dart';
import '../../services/presentation/currency_exchange_screen.dart';
import '../../services/presentation/merchant_screen.dart';
import '../../services/presentation/paysafe_screen.dart';
import '../../transfers/presentation/request_money_screen.dart';
import '../../transfers/presentation/send_money_screen.dart';
import '../../transfers/presentation/transfer_screen.dart';
import '../../wallet/presentation/allocation_rules_screen.dart';
import '../../wallet/presentation/bill_reserves_screen.dart';
import '../../wallet/presentation/link_external_wallet_launcher.dart';
import '../../wallet/presentation/shared_budgets_screen.dart';
import '../../wallet/presentation/shared_pots_screen.dart';
import '../models/dashboard_models.dart';
import '../state/dashboard_controller.dart';

part 'dashboard_sections.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ── Layout constants (enterprise spacing scale) ──────────────────────────
  static const double _bottomNavReservedSpace = 104.0;
  static const double _minScrollBottomPadding = 32.0;
  static const double _horizontalGutter = 20.0;
  static const double _topContentGap = 12.0;
  static const Duration _statusAutoDismiss = Duration(seconds: 5);

  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  Timer? _statusTimer;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;

    final isSwahili =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: isSwahili,
        fallback: message,
      );
      _statusTone = isError ? OrbiStatusTone.error : OrbiStatusTone.info;
    });

    _statusTimer?.cancel();
    _statusTimer = Timer(_statusAutoDismiss, _clearStatus);
  }

  void _clearStatus() {
    if (!mounted || _statusMessage == null) return;
    setState(() => _statusMessage = null);
  }

  Future<void> _reloadDashboardData({bool showErrorStatus = false}) async {
    final auth = context.read<AuthController>();
    final dashboard = context.read<DashboardController>();

    final token = await auth.getValidAccessToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      if (showErrorStatus) {
        _setStatus('Session expired. Please sign in again.', isError: true);
      }
      return;
    }

    await dashboard.fetchDashboardData(token, forceRefresh: true);

    if (!mounted || !showErrorStatus) return;

    final error = dashboard.error;
    if (error != null && error.isNotEmpty) {
      _setStatus(error, isError: true);
    }
  }

  void _navigateAfterSheet(BuildContext sheetContext, Widget screen) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Future<void> _openMoreHub() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) {
        return AdvancedHubSheet(
          onSend: () => _navigateAfterSheet(sheetContext, const SendMoneyScreen()),
          onTransfer: () => _navigateAfterSheet(sheetContext, const TransferScreen()),
          onRequest: () => _navigateAfterSheet(sheetContext, const RequestMoneyScreen()),
          onScanPay: () => _navigateAfterSheet(sheetContext, const PaymentScreen()),
          onPaySafe: () => _navigateAfterSheet(sheetContext, const PaySafeScreen()),
          onSharedPot: () => _navigateAfterSheet(sheetContext, const SharedPotsScreen()),
          onSharedBudget: () => _navigateAfterSheet(sheetContext, const SharedBudgetsScreen()),
          onBillReserve: () => _navigateAfterSheet(sheetContext, const BillReservesScreen()),
          onAllocationRules: () => _navigateAfterSheet(sheetContext, const AllocationRulesScreen()),
          onLinkExternalWallet: () => _navigateAfterSheet(sheetContext, const LinkExternalWalletLauncher()),
          onCurrencyExchange: () => _navigateAfterSheet(sheetContext, const CurrencyExchangeScreen()),
          onAgentDesk: () => _navigateAfterSheet(sheetContext, const AgentScreen()),
          onMerchantDesk: () => _navigateAfterSheet(sheetContext, const MerchantScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardController>();

    // Rebuild only when hide-balances preference changes
    context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final topSafe = media.padding.top;
    final bottomSafe = media.padding.bottom;

    final scrollBottomPadding = math.max(
      _minScrollBottomPadding,
      bottomSafe + _bottomNavReservedSpace,
    );

    final showBusyOverlay = dashboard.isLoading && dashboard.hasData;
    final showOfflineBanner = dashboard.error != null && dashboard.hasData;

    // Keep responsive padding available for the content layer
    final contentPadding = OrbiResponsive.pagePadding(context, top: 0);

    return OrbiLoadingOverlay(
      loading: showBusyOverlay,
      message: 'Synchronising command centre…',
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: _clearStatus,
      child: OrbiBackground(
        padding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main content ──────────────────────────────────────────────
              RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                displacement: 52,
                strokeWidth: 2.5,
                edgeOffset: topSafe + 8,
                onRefresh: () => _reloadDashboardData(showErrorStatus: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Top safe-area + consistent breathing room
                    SliverToBoxAdapter(
                      child: SizedBox(height: topSafe + _topContentGap),
                    ),

                    // Primary dashboard body – horizontally aligned
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: math.max(_horizontalGutter, contentPadding.left),
                        right: math.max(_horizontalGutter, contentPadding.right),
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _HomeDashboardContent(
                          snapshot: dashboard.homeSnapshot,
                          isLoading: dashboard.isLoading,
                          error: dashboard.error,
                          onRetry: _reloadDashboardData,
                          onOpenMore: _openMoreHub,
                        ),
                      ),
                    ),

                    // Bottom clearance for floating navigation
                    SliverToBoxAdapter(
                      child: SizedBox(height: scrollBottomPadding),
                    ),
                  ],
                ),
              ),

              // ── Offline banner (perfectly aligned, floating) ──────────────
              if (showOfflineBanner)
                Positioned(
                  top: topSafe + 10,
                  left: _horizontalGutter,
                  right: _horizontalGutter,
                  child: const _EnterpriseOfflineBanner(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm, high-trust offline indicator used by enterprise banking surfaces.
class _EnterpriseOfflineBanner extends StatelessWidget {
  const _EnterpriseOfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: bg,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status dot
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Message
            Expanded(
              child: Text(
                'Working offline  ·  Showing last synchronised data',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.15,
                  height: 1.25,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(width: 10),
            Icon(Icons.cloud_off_rounded, size: 17, color: iconColor),
          ],
        ),
      ),
    );
  }
}
