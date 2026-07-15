import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/state/app_settings_controller.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../auth/state/auth_controller.dart';
import '../../goals/data/goals_service.dart';
import '../../goals/presentation/goals_form_sheets.dart';
import '../../notifications/state/notification_controller.dart';
import '../../payment/presentation/payment_screen.dart';
import '../../services/presentation/paysafe_screen.dart';
import '../../transfers/presentation/send_money_screen.dart';
import '../../transfers/presentation/withdraw_screen.dart';
import 'deposit_funds_screen.dart';
import '../data/wallet_models.dart';
import '../data/wallet_service.dart';
import '../data/wealth_service.dart';
import '../state/wallet_view_model.dart';
import 'widgets/transaction_bottom_sheet.dart';
import 'widgets/wealth_foundation_sections.dart';
import 'widgets/wealth_tabs.dart';
import 'widgets/wallet_shell_widgets.dart';
import 'widgets/wallet_tab_content.dart';

class WalletScreen extends StatefulWidget {
  final bool standalone;

  const WalletScreen({super.key, this.standalone = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final WalletViewModel _viewModel;
  StreamSubscription<Map<String, dynamic>>? _balanceUpdateSubscription;

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

  @override
  Widget build(BuildContext context) {
    _viewModel.updateLanguageCode(Localizations.localeOf(context).languageCode);
    final body = ChangeNotifierProvider<WalletViewModel>.value(
      value: _viewModel,
      child: Consumer<WalletViewModel>(
        builder: (context, viewModel, _) => _WalletScreenBody(
          standalone: widget.standalone,
          viewModel: viewModel,
          onWalletTap: (wallet) =>
              WalletTransactionBottomSheet.show(context, wallet),
        ),
      ),
    );

    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.walletTitle)),
        body: body,
      );
    }
    return body;
  }
}

class _WalletScreenBody extends StatefulWidget {
  const _WalletScreenBody({
    required this.standalone,
    required this.viewModel,
    required this.onWalletTap,
  });

  final bool standalone;
  final WalletViewModel viewModel;
  final ValueChanged<WalletRecord> onWalletTap;

  @override
  State<_WalletScreenBody> createState() => _WalletScreenBodyState();
}

class _WalletScreenBodyState extends State<_WalletScreenBody> {
  final GoalsService _goalsService = GoalsService();
  final WealthService _wealthService = WealthService();

  WealthScreenTab _activeTab = WealthScreenTab.home;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  bool _wealthLoading = true;
  String? _wealthError;
  List<Map<String, dynamic>> _goals = const [];
  List<Map<String, dynamic>> _categories = const [];
  WealthSnapshotData? _wealthSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshWealthSnapshot());
    });
  }

  Future<void> _runWalletAction(
    String message,
    Future<void> Function() action,
  ) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _busyMessage = message;
      });
    }
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      widget.viewModel.refresh(forceRefresh: true),
      _refreshWealthSnapshot(),
    ]);
  }

  Future<void> _refreshWealthSnapshot() async {
    if (mounted) {
      setState(() {
        _wealthLoading = true;
        _wealthError = null;
      });
    }

    try {
      final token = await context.read<AuthController>().getValidAccessToken(
        expireSessionIfMissing: false,
      );
      if (token == null || token.trim().isEmpty) {
        throw Exception('We could not confirm your session right now.');
      }
      try {
        final summary = await _wealthService.getSummary();
        final invitationResults = await Future.wait([
          _safeWealthList(_wealthService.listMySharedPotInvitations),
          _safeWealthList(_wealthService.listMySharedBudgetInvitations),
        ]);
        final potInvitations = invitationResults[0];
        final budgetInvitations = invitationResults[1];
        final summaryCurrency =
            (summary['currency'] ?? widget.viewModel.sessionCurrency)
                .toString();
        final goalsCount = _asInt(summary['goal_count']);
        final budgetsCount = _asInt(summary['budget_count']);
        final linkedCount = _asInt(summary['linked_wallet_count']);
        final linkedBalance = _asDouble(
          summary['linked_wallets_balance'] ??
              summary['linked_wallet_balance'] ??
              summary['total_linked_balance'] ??
              summary['linked_total'] ??
              summary['linkedBalance'],
        );
        if (!mounted) return;
        setState(() {
          _wealthSnapshot = WealthSnapshotData(
            currency: summaryCurrency,
            operatingBalance: _asDouble(summary['operating_balance']),
            plannedAmount: _asDouble(summary['planned_balance']),
            protectedAmount: _asDouble(summary['protected_balance']),
            growingAmount: _asDouble(summary['growing_balance']),
            linkedWalletBalance: linkedBalance,
            goalCount: goalsCount,
            budgetCount: budgetsCount,
            linkedWalletCount: linkedCount,
            sharedPotInvitationCount: _countPendingInvitations(potInvitations),
            sharedBudgetInvitationCount: _countPendingInvitations(
              budgetInvitations,
            ),
          );
        });
      } catch (_) {
        final results = await Future.wait([
          _goalsService.fetchGoals(token),
          _goalsService.fetchCategories(token),
          _safeWealthList(_wealthService.listMySharedPotInvitations),
          _safeWealthList(_wealthService.listMySharedBudgetInvitations),
        ]);
        if (!mounted) return;
        setState(() {
          _goals = List<Map<String, dynamic>>.from(results[0]);
          _categories = List<Map<String, dynamic>>.from(results[1]);
          final potInvitations = List<Map<String, dynamic>>.from(results[2]);
          final budgetInvitations = List<Map<String, dynamic>>.from(results[3]);
          final primaryVault = widget.viewModel.primaryInternalVault;
          final primaryCurrency = primaryVault?.currency.isNotEmpty == true
              ? primaryVault!.currency
              : widget.viewModel.sessionCurrency;
          final protectedBalance = widget.viewModel.wallets
              .where((wallet) => wallet.isEscrow)
              .fold<double>(0, (sum, wallet) => sum + wallet.balance);
          final linkedWalletCount = widget.viewModel.wallets
              .where((wallet) => wallet.isLinked)
              .length;
          final linkedWalletBalance = widget.viewModel.wallets
              .where((wallet) => wallet.isLinked)
              .fold<double>(0, (sum, wallet) => sum + wallet.balance);
          final growingAmount = _sumByKeys(_goals, const [
            'current',
            'saved_amount',
            'balance',
          ]);
          final plannedAmount = _sumByKeys(_categories, const [
            'budget',
            'amount',
            'limit',
          ]);
          _wealthSnapshot = WealthSnapshotData(
            currency: primaryCurrency,
            operatingBalance: primaryVault?.balance ?? 0,
            plannedAmount: plannedAmount,
            protectedAmount: protectedBalance,
            growingAmount: growingAmount,
            linkedWalletBalance: linkedWalletBalance,
            goalCount: _goals.length,
            budgetCount: _categories.length,
            linkedWalletCount: linkedWalletCount,
            sharedPotInvitationCount: _countPendingInvitations(potInvitations),
            sharedBudgetInvitationCount: _countPendingInvitations(
              budgetInvitations,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _wealthError = _normalizeWealthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _wealthLoading = false;
        });
      }
    }
  }

  Future<void> _openGoalComposerShortcut() async {
    final l10n = AppLocalizations.of(context)!;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final currencyCode = widget.viewModel.sessionCurrency.isNotEmpty
        ? widget.viewModel.sessionCurrency
        : 'TZS';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return GoalComposerSheet(
          initialData: const GoalFormData(
            name: '',
            target: null,
            fundingStrategy: 'manual',
            autoAllocationEnabled: false,
            linkedIncomePercentage: null,
            monthlyTarget: null,
            deadline: null,
          ),
          currencyCode: currencyCode,
          languageCode: sw ? 'sw' : 'en',
          isEditing: false,
          isSwahili: sw,
          onSubmit: (data) async {
            final token = await context
                .read<AuthController>()
                .getValidAccessToken();
            if (token == null || token.isEmpty) {
              throw Exception(
                sw
                    ? 'Kikao chako hakikuthibitishwa. Jaribu tena.'
                    : 'Your session could not be confirmed. Try again.',
              );
            }

            final payload = <String, dynamic>{
              'name': data.name,
              'target': data.target,
              'fundingStrategy': data.fundingStrategy,
              'autoAllocationEnabled': data.autoAllocationEnabled,
              if (data.fundingStrategy == 'percentage' &&
                  data.linkedIncomePercentage != null)
                'linkedIncomePercentage': data.linkedIncomePercentage,
              if (data.fundingStrategy == 'fixed' && data.monthlyTarget != null)
                'monthlyTarget': data.monthlyTarget,
              if (data.deadline != null)
                'deadline': data.deadline!.toUtc().toIso8601String(),
              'color': 'emerald',
              'icon': 'target',
            };

            try {
              await _runWalletAction(
                sw ? 'Inaunda lengo...' : 'Creating goal...',
                () async {
                  await _goalsService.createGoal(token, payload);
                  await _refreshWealthSnapshot();
                },
              );
              if (!mounted) return;
              _setStatus(l10n.goalsGoalCreatedMessage, isError: false);
            } catch (error) {
              throw Exception(
                mapBackendStatusMessage(
                  error.toString(),
                  sw: sw,
                  fallback: sw
                      ? 'Imeshindikana kuhifadhi lengo.'
                      : 'Unable to save the goal.',
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _safeWealthList(
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  String _normalizeWealthError(Object error) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final mapped = mapBackendStatusMessage(
      error.toString(),
      sw: sw,
      fallback: error.toString(),
    );
    final raw = error.toString().toLowerCase();
    final mappedLower = mapped.toLowerCase();

    if (error is DioException &&
        error.response?.statusCode == 400 &&
        (mappedLower.contains('dioexception') ||
            mappedLower.contains('requestoptions.validatestatus'))) {
      return sw
          ? 'Utajiri haukupatikana kwa sasa. Tafadhali jaribu tena.'
          : 'Wealth could not load right now. Please try again.';
    }

    if (raw.contains('dioexception') &&
        raw.contains('400') &&
        raw.contains('validatestatus')) {
      return sw
          ? 'Utajiri haukupatikana kwa sasa. Tafadhali jaribu tena.'
          : 'Wealth could not load right now. Please try again.';
    }

    return mapBackendStatusMessage(
      error.toString(),
      sw: sw,
      fallback: sw
          ? 'Utajiri haukupatikana kwa sasa. Tafadhali jaribu tena.'
          : 'Wealth could not load right now. Please try again.',
    );
  }

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
      _statusTone = isError ? OrbiStatusTone.error : OrbiStatusTone.success;
    });
  }

  double _sumByKeys(Iterable<Map<String, dynamic>> items, List<String> keys) {
    double total = 0;
    for (final item in items) {
      total += _readNumber(item, keys);
    }
    return total;
  }

  double _readNumber(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', ''));
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
  }

  int _countPendingInvitations(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final status = (item['status'] ?? '').toString().trim().toUpperCase();
      return status == 'PENDING' || status == 'UNDER_REVIEW';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = OrbiTheme.uiOf(context);
    final hideBalances = context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );
    final viewModel = widget.viewModel;
    final primaryVault = viewModel.primaryInternalVault;
    final primaryCurrency = primaryVault?.currency.isNotEmpty == true
        ? primaryVault!.currency
        : viewModel.sessionCurrency;
    final primaryBalanceText = hideBalances
        ? AppSettingsController.hiddenBalanceText
        : formatDisplayMoney(
            primaryVault?.balance ?? 0,
            primaryCurrency,
            hideBalances: hideBalances,
          );
    final auth = context.read<AuthController>();
    final wealthSnapshot = _wealthSnapshot;

    return OrbiLoadingOverlay(
      loading: _busy,
      message: _busyMessage,
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      child: OrbiBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: ui.success,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: OrbiResponsive.pagePadding(context, top: 14, bottom: 20),
            children: [
              OrbiResponsiveContent(
                child: OrbiMotionCascade(
                  children: [
                    if (viewModel.isInitialLoading) ...[
                      const InitialWalletLoadingCard(),
                    ] else ...[
                      WealthTabSelector(
                        currentTab: _activeTab,
                        onChanged: (tab) => setState(() => _activeTab = tab),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 620),
                        reverseDuration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutExpo,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0.045, 0.025),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<WealthScreenTab>(_activeTab),
                          child: WalletTabContent(
                            activeTab: _activeTab,
                            snapshot: wealthSnapshot,
                            wealthLoading: _wealthLoading,
                            wealthError: _wealthError,
                            hideBalances: hideBalances,
                            theme: theme,
                            primaryVault: primaryVault,
                            primaryBalanceText: primaryBalanceText,
                            mainWalletCardNumber: _cardNumberSource(
                              primaryVault?.linkedCustomerId.isEmpty ?? true
                                  ? viewModel.customerId
                                  : primaryVault?.linkedCustomerId,
                            ),
                            viewModel: viewModel,
                            onWalletTap: widget.onWalletTap,
                            onSetActiveTab: (tab) =>
                                setState(() => _activeTab = tab),
                            onRetryWealth: _refreshWealthSnapshot,
                            onToggleBalanceVisibility: () {
                              context
                                  .read<AppSettingsController>()
                                  .toggleHideBalances();
                            },
                            onDeposit: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DepositFundsScreen(),
                              ),
                            ),
                            onWithdraw: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WithdrawScreen(),
                              ),
                            ),
                            onSend: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SendMoneyScreen(),
                              ),
                            ),
                            onScan: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PaymentScreen(),
                              ),
                            ),
                            onOpenGoals: _openGoalComposerShortcut,
                            onOpenPaySafe: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PaySafeScreen(),
                              ),
                            ),
                            runAsyncAction: _runWalletAction,
                            onStatus: _setStatus,
                            isMerchant: auth.isMerchant,
                            isAgent: auth.isAgent,
                            isEnterprise:
                                auth.organizationId.trim().isNotEmpty ||
                                auth.orgRole.toUpperCase() != 'EMPLOYEE',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cardNumberSource(String? rawValue) {
    final raw = (rawValue ?? '').trim();
    if (raw.isEmpty) return '0000';
    return raw;
  }
}
