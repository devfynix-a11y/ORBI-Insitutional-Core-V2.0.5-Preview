import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../auth/state/auth_controller.dart';
import '../../notifications/state/notification_controller.dart';
import '../data/wallet_models.dart';
import '../data/wallet_service.dart';
import '../state/wallet_view_model.dart';
import 'link_external_wallet_screen.dart';
import 'widgets/transaction_bottom_sheet.dart';
import 'widgets/wallet_sections.dart';

class LinkedWalletsScreen extends StatefulWidget {
  const LinkedWalletsScreen({super.key});

  @override
  State<LinkedWalletsScreen> createState() => _LinkedWalletsScreenState();
}

class _LinkedWalletsScreenState extends State<LinkedWalletsScreen> {
  late final WalletViewModel _viewModel;
  StreamSubscription<Map<String, dynamic>>? _balanceUpdateSubscription;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthController>().session;
    _viewModel = WalletViewModel(
      walletService: WalletService(),
      session: session,
    );
    _viewModel.updateLanguageCode(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    _viewModel.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _balanceUpdateSubscription = context
          .read<NotificationController>()
          .balanceUpdates
          .listen(_viewModel.handleRealtimeEvent);
    });
  }

  @override
  void dispose() {
    _balanceUpdateSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _runAsyncAction(
    String message,
    Future<void> Function() action,
  ) async {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    if (mounted) {
      setState(() {
        _busy = true;
        _busyMessage = message;
        _statusMessage = null;
      });
    }
    try {
      await action();
    } catch (error) {
      _setStatus(
        sw
            ? 'Ombi halikukamilika. Tafadhali jaribu tena.'
            : 'The request could not be completed. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusTone = isError ? OrbiStatusTone.error : OrbiStatusTone.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    _viewModel.updateLanguageCode(Localizations.localeOf(context).languageCode);
    final l10n = AppLocalizations.of(context)!;

    return ChangeNotifierProvider<WalletViewModel>.value(
      value: _viewModel,
      child: Consumer<WalletViewModel>(
        builder: (context, viewModel, _) {
          final theme = Theme.of(context);
          final ui = OrbiTheme.uiOf(context);
          final hideBalances = context.select<AppSettingsController, bool>(
            (settings) => settings.hideBalances,
          );
          final sw =
              Localizations.localeOf(context).languageCode.toLowerCase() ==
              'sw';

          return Scaffold(
            appBar: AppBar(title: Text(l10n.dashboardLinkedCardsTitle)),
            body: OrbiLoadingOverlay(
              loading: _busy,
              message: _busyMessage ?? (sw ? 'Inaendelea...' : 'Working...'),
              statusMessage: _statusMessage,
              statusTone: _statusMessage == null ? null : _statusTone,
              onDismissStatus: () {
                if (!mounted) return;
                setState(() => _statusMessage = null);
              },
              child: OrbiBackground(
                padding: EdgeInsets.zero,
                child: RefreshIndicator(
                  onRefresh: viewModel.refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: OrbiResponsiveContent(
                      padding: OrbiResponsive.pagePadding(
                        context,
                        top: 16,
                        bottom: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sw
                                ? 'Simamia walleti zote zilizounganishwa moja kwa moja.'
                                : 'Manage all linked wallets directly.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: ui.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          WalletListSection(
                            theme: theme,
                            viewModel: viewModel,
                            hideBalances: hideBalances,
                            onWalletTap: (WalletRecord wallet) =>
                                WalletTransactionBottomSheet.show(
                                  context,
                                  wallet,
                                ),
                            onLinkWallet: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LinkExternalWalletScreen(
                                  sessionCurrency: viewModel.sessionCurrency,
                                  onWalletLinked: viewModel.refresh,
                                ),
                              ),
                            ),
                            runAsyncAction: _runAsyncAction,
                            onStatus: _setStatus,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
