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
import '../../goals/presentation/goals_screen.dart';
import '../../payment/presentation/payment_screen.dart';
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

class _DashboardScreenState extends State<DashboardScreen> {
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: sw,
        fallback: message,
      );
      _statusTone = isError ? OrbiStatusTone.error : OrbiStatusTone.info;
    });
  }

  Future<void> _reloadDashboardData({bool showErrorStatus = false}) async {
    final auth = context.read<AuthController>();
    final dashboard = context.read<DashboardController>();
    final token = await auth.getValidAccessToken();
    if (!mounted || token == null || token.isEmpty) return;

    await dashboard.fetchDashboardData(token, forceRefresh: true);
    if (!showErrorStatus || !mounted) return;
    final error = dashboard.error;
    if (error != null && error.isNotEmpty) {
      _setStatus(error, isError: true);
    }
  }

  Future<void> _openMoreHub() async {
    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AdvancedHubSheet(
          onSend: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const SendMoneyScreen()),
            );
          },
          onTransfer: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const TransferScreen()),
            );
          },
          onRequest: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const RequestMoneyScreen()),
            );
          },
          onScanPay: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const PaymentScreen()),
            );
          },
          onPaySafe: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const PaySafeScreen()),
            );
          },
          onSharedPot: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const SharedPotsScreen()),
            );
          },
          onSharedBudget: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const SharedBudgetsScreen()),
            );
          },
          onBillReserve: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const BillReservesScreen()),
            );
          },
          onAllocationRules: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const AllocationRulesScreen()),
            );
          },
          onLinkExternalWallet: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const LinkExternalWalletLauncher(),
              ),
            );
          },
          onCurrencyExchange: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const CurrencyExchangeScreen()),
            );
          },
          onAgentDesk: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const AgentScreen()),
            );
          },
          onMerchantDesk: () {
            Navigator.of(context).pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const MerchantScreen()),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardController>();
    context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final scrollBottomPadding = math.max(32.0, bottomInset + 104);
    final showBusyOverlay = dashboard.isLoading && dashboard.hasData;

    return OrbiLoadingOverlay(
      loading: showBusyOverlay,
      message: 'Loading command center...',
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      child: OrbiBackground(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _reloadDashboardData(showErrorStatus: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: scrollBottomPadding),
                child: OrbiResponsiveContent(
                  padding: OrbiResponsive.pagePadding(context, top: 12),
                  child: _HomeDashboardContent(
                    snapshot: dashboard.homeSnapshot,
                    isLoading: dashboard.isLoading,
                    error: dashboard.error,
                    onRetry: _reloadDashboardData,
                    onOpenMore: _openMoreHub,
                  ),
                ),
              ),
            ),
            if (dashboard.error != null && dashboard.hasData)
              const _OfflineBanner(),
          ],
        ),
      ),
    );
  }
}
