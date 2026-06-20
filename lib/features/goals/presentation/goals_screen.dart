import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/state/app_settings_controller.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/pin_prompt.dart';
import '../../../core/widgets/security_otp_dialog.dart';
import '../../auth/state/auth_controller.dart';
import '../../wallet/data/wallet_service.dart';
import 'budget.dart';
import 'goals_form_sheets.dart';
import 'goal.dart';
import 'goals_overview_widgets.dart';
import 'goals_section_widgets.dart';
import 'goals_shared_widgets.dart';
import '../state/goals_controller.dart';
import 'task.dart';

enum _GoalsView { goals, budget, tasks }

class _DynamicCardSpec {
  const _DynamicCardSpec({
    required this.accent,
    required this.glow,
    required this.progress,
    required this.icon,
    required this.visualToken,
    this.eyebrow,
    this.subtitle,
    this.badge,
  });

  final Color accent;
  final Color glow;
  final Color progress;
  final IconData icon;
  final int visualToken;
  final String? eyebrow;
  final String? subtitle;
  final String? badge;
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final int _visualSessionSalt = math.Random.secure().nextInt(0x7fffffff);
  final WalletService _walletService = WalletService();
  final PageController _goalsPageController = PageController(
    viewportFraction: 0.94,
  );
  final PageController _budgetsPageController = PageController(
    viewportFraction: 0.94,
  );
  final PageController _tasksPageController = PageController(
    viewportFraction: 0.94,
  );

  bool _didRequestLoad = false;
  _GoalsView _view = _GoalsView.goals;
  bool _isBusy = false;
  bool _openingComposer = false;
  String? _busyMessage;
  String? _statusMessage;
  bool _statusIsError = false;
  Timer? _goalsTimer;
  Timer? _budgetsTimer;
  Timer? _tasksTimer;
  int _goalsIndex = 0;
  int _budgetsIndex = 0;
  int _tasksIndex = 0;
  int _goalsCount = 0;
  int _budgetsCount = 0;
  int _tasksCount = 0;
  int _viewDirection = 1;
  bool _goalsAutoScrollPaused = false;
  bool _budgetsAutoScrollPaused = false;
  bool _tasksAutoScrollPaused = false;

  @override
  void dispose() {
    _goalsTimer?.cancel();
    _budgetsTimer?.cancel();
    _tasksTimer?.cancel();
    _goalsPageController.dispose();
    _budgetsPageController.dispose();
    _tasksPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestLoad) return;
    final token = _token;
    if (token == null) return;
    _didRequestLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || !mounted) return;
    await _runBusy(
      _isSwahili ? 'Inapakia malengo...' : 'Loading goals...',
      () => context.read<GoalsController>().loadAll(token),
      keepStatus: true,
    );
    if (!mounted) return;
    final error = context.read<GoalsController>().error;
    if (error != null && error.isNotEmpty) {
      _setStatus(error, isError: true);
    }
  }

  String? get _token {
    final token = context.read<AuthController>().session['access_token'];
    if (token is String && token.isNotEmpty) return token;
    return null;
  }

  String get _languageCode {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code == 'sw' ? 'sw' : 'en';
  }

  String get _currencyCode {
    final raw = context.read<AuthController>().session;
    return resolveCurrencyCode([
      raw['currency'],
      raw['currency_code'],
      raw['user']?['currency'],
      raw['user']?['currency_code'],
      raw['user']?['preferred_currency'],
    ]);
  }

  Future<String?> _promptSecurityPin() async {
    final l10n = AppLocalizations.of(context)!;
    return showSecurityCodeDialog(
      context: context,
      title: l10n.loginEnterPinTitle,
      helperText: l10n.loginUsePinInstead,
      fieldLabel: l10n.loginPinLabel,
      confirmLabel: l10n.actionUnlock,
      cancelLabel: l10n.actionCancel,
      maxLength: 6,
      minLength: 4,
      obscureText: true,
      digitsOnly: true,
      keyboardType: TextInputType.number,
    );
  }

  Future<String?> _promptSecurityOtp() async {
    final l10n = AppLocalizations.of(context)!;
    return showSecurityOtpDialog(
      context: context,
      title: l10n.loginSecurityVerificationTitle,
      helperText: l10n.settingsSecurityVerificationHelper,
    );
  }

  Future<Map<String, dynamic>?> _buildGoalWithdrawalVerification() async {
    final auth = context.read<AuthController>();
    final invalidPinMessage = AppLocalizations.of(
      context,
    )!.loginInvalidPinMessage;
    var pinVerified = false;

    if (await auth.hasSecurityPinConfigured()) {
      final pin = await _promptSecurityPin();
      if (pin == null || pin.trim().isEmpty) {
        return null;
      }
      final ok = await auth.verifySecurityPin(pin);
      if (!ok) {
        throw Exception(invalidPinMessage);
      }
      pinVerified = true;
    }

    final challenge = await auth.startSensitiveActionChallenge(
      action: 'GOAL_WITHDRAWAL',
    );
    final otp = await _promptSecurityOtp();
    if (otp == null || otp.trim().isEmpty) {
      return null;
    }

    return {
      'otpRequestId': challenge['requestId'],
      'otpCode': otp.trim(),
      'verifiedVia': pinVerified ? 'pin+otp' : 'otp',
      'pinVerified': pinVerified,
      'deliveryType': challenge['type'],
    };
  }

  String get _localeTag {
    final locale = Localizations.localeOf(context);
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }

  String _formatMoney(double value) {
    if (context.read<AppSettingsController>().hideBalances) {
      return AppSettingsController.hiddenBalanceText;
    }
    return formatCurrencyAmount(
      value,
      _currencyCode,
      locale: _localeTag,
      decimalDigits: 2,
    );
  }

  String _formatCompactMoneyLabel(
    double value, {
    double compactFrom = kCompactMoneyThreshold,
  }) {
    if (compactFrom == kLargeCardCompactThreshold) {
      return formatLargeCardMoney(
        value,
        _currencyCode,
        locale: _localeTag,
        hideBalances: context.read<AppSettingsController>().hideBalances,
      );
    }
    return formatDisplayMoney(
      value,
      _currencyCode,
      locale: _localeTag,
      hideBalances: context.read<AppSettingsController>().hideBalances,
    );
  }

  bool get _isSwahili =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  Future<T> _runBusy<T>(
    String message,
    Future<T> Function() action, {
    bool keepStatus = false,
  }) async {
    if (mounted) {
      setState(() {
        _isBusy = true;
        _busyMessage = message;
        if (!keepStatus) {
          _statusMessage = null;
        }
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: _isSwahili,
        fallback: message,
      );
      _statusIsError = isError;
    });
  }

  void _setView(_GoalsView view) {
    if (!mounted || _view == view) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _viewDirection = view.index >= _view.index ? 1 : -1;
      _view = view;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GoalsController>();
    final authToken = context.select<AuthController, String?>((auth) {
      final token = auth.session['access_token'];
      return token is String && token.isNotEmpty ? token : null;
    });
    if (!_didRequestLoad && authToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didRequestLoad) return;
        _didRequestLoad = true;
        _load();
      });
    }

    final l10n = AppLocalizations.of(context)!;
    final width = OrbiResponsive.contentMaxWidth(context);
    final wide = width >= 900;
    _ensureAutoScrollCounts(
      goalsCount: controller.goals.length,
      budgetsCount: controller.categories.length,
      tasksCount: controller.tasks.length,
    );

    return OrbiLoadingOverlay(
      loading: _isBusy,
      message: _busyMessage ?? (_isSwahili ? 'Inaendelea...' : 'Working...'),
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null
          ? null
          : (_statusIsError ? OrbiStatusTone.error : OrbiStatusTone.success),
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      child: OrbiBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: OrbiResponsiveContent(
              padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _overviewCard(controller),
                  const SizedBox(height: 22),
                  _viewSwitcher(),
                  const SizedBox(height: 16),
                  _sectionHeader(width: width, wide: wide, l10n: l10n),
                  const SizedBox(height: 16),
                  if (controller.isLoading &&
                      controller.goals.isEmpty &&
                      controller.categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (controller.error != null &&
                      controller.goals.isEmpty &&
                      controller.categories.isEmpty)
                    _errorCard(controller.error!)
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            currentChild,
                          ].whereType<Widget>().toList(),
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        );
                        final offsetAnimation = Tween<Offset>(
                          begin: Offset(0.08 * _viewDirection, 0),
                          end: Offset.zero,
                        ).animate(curved);
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_view),
                        child: _sectionContent(controller),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _createButton(AppLocalizations l10n) {
    final ui = OrbiTheme.uiOf(context);
    final label = _view == _GoalsView.goals
        ? l10n.goalsNewGoal
        : _view == _GoalsView.budget
        ? l10n.goalsNewBudget
        : l10n.goalsNewTask;
    return FilledButton.icon(
      onPressed: _openingComposer
          ? null
          : () async {
              setState(() => _openingComposer = true);
              try {
                if (_view == _GoalsView.goals) {
                  await _openGoalComposer();
                } else if (_view == _GoalsView.budget) {
                  await _openCategoryComposer();
                } else {
                  await _openTaskComposer();
                }
              } finally {
                if (mounted) {
                  setState(() => _openingComposer = false);
                }
              }
            },
      icon: Icon(
        _openingComposer ? Icons.hourglass_top_rounded : Icons.add_rounded,
      ),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: ui.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _sectionHeader({
    required double width,
    required bool wide,
    required AppLocalizations l10n,
  }) {
    final eyebrow = _view == _GoalsView.goals
        ? (_isSwahili ? 'Muhtasari wa malengo' : 'Goal overview')
        : _view == _GoalsView.budget
        ? (_isSwahili ? 'Muhtasari wa bajeti' : 'Budget overview')
        : (_isSwahili ? 'Muhtasari wa kazi' : 'Task overview');
    final helper = _view == _GoalsView.goals
        ? (_isSwahili
              ? 'Fuatilia akiba, ongeza fedha, au toa kiasi kwenye lengo lako.'
              : 'Track savings, add funds, or withdraw from your goals.')
        : _view == _GoalsView.budget
        ? (_isSwahili
              ? 'Simamia mipaka ya matumizi na uwashe ulinzi wa bajeti ukihitaji.'
              : 'Manage spending limits and enable budget protection when needed.')
        : (_isSwahili
              ? 'Kamilisha kazi za fedha na fuatilia hatua zinazofuata.'
              : 'Complete money tasks and keep track of your next steps.');
    return GoalsSectionHeader(
      width: width,
      wide: wide,
      eyebrow: eyebrow,
      helper: helper,
      createButton: _createButton(l10n),
    );
  }

  Widget _sectionContent(GoalsController controller) {
    return _view == _GoalsView.goals
        ? _goalsList(controller.goals)
        : _view == _GoalsView.budget
        ? _categoriesList(controller.categories)
        : _tasksList(controller.tasks, controller.goals);
  }

  Widget _overviewCard(GoalsController controller) {
    final l10n = AppLocalizations.of(context)!;
    final hideBalances = context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );
    final goals = controller.goals;
    final categories = controller.categories;
    final targetTotal = goals.fold<double>(
      0,
      (sum, item) => sum + doubleFrom(item['target']),
    );
    final currentTotal = goals.fold<double>(
      0,
      (sum, item) => sum + doubleFrom(item['current']),
    );
    final budgetTotal = categories.fold<double>(
      0,
      (sum, item) => sum + doubleFrom(item['budget']),
    );
    final remainingTotal = math.max(targetTotal - currentTotal, 0).toDouble();
    final completion = targetTotal <= 0
        ? 0.0
        : (currentTotal / targetTotal).clamp(0.0, 1.0);
    final activeTasks = controller.tasks
        .where((task) => !boolFrom(task['completed']))
        .length;
    final insightMessage = targetTotal <= 0
        ? (_isSwahili
              ? 'Anza kwa kuweka lengo lako la kwanza la akiba.'
              : 'Start by creating your first savings goal.')
        : remainingTotal <= 0
        ? (_isSwahili
              ? 'Malengo yote yamefadhiliwa. Unaweza sasa kuhamisha au kupanga upya.'
              : 'All goals are fully funded. You can now rebalance or withdraw.')
        : activeTasks > 0
        ? (_isSwahili
              ? 'Bado unahitaji ${_formatMoney(remainingTotal)} kufikia malengo, na kazi $activeTasks ziko wazi.'
              : 'You still need ${_formatMoney(remainingTotal)} to reach your goals, with $activeTasks active tasks left.')
        : (_isSwahili
              ? 'Bado unahitaji ${_formatMoney(remainingTotal)} kufikia malengo yako.'
              : 'You still need ${_formatMoney(remainingTotal)} to reach your goals.');
    final budgetLockEnabled = context
        .watch<AppSettingsController>()
        .budgetLockEnabled;
    final ui = OrbiTheme.uiOf(context);
    return GoalsOverviewCard(
      title: l10n.goalsTitle,
      description: _isSwahili
          ? 'Panga fedha zako, fuatilia maendeleo, na jua hatua inayofuata.'
          : 'Plan your money, track progress, and know what needs attention next.',
      hideBalances: hideBalances,
      onToggleHideBalances: () {
        context.read<AppSettingsController>().toggleHideBalances();
      },
      hideBalancesTooltip: l10n.walletHideBalances,
      showBalancesTooltip: l10n.walletShowBalances,
      planningTitle: l10n.goalsPlanningTitle,
      planningAmount: _formatCompactMoneyLabel(currentTotal + budgetTotal),
      progressLabel: _isSwahili
          ? '${(completion * 100).toStringAsFixed(0)}% imefikiwa'
          : '${(completion * 100).toStringAsFixed(0)}% funded',
      tasksLabel: _isSwahili
          ? '$activeTasks kazi wazi'
          : '$activeTasks active tasks',
      insightMessage: insightMessage,
      completion: completion,
      metrics: [
        GoalsMetricItem(
          label: l10n.goalsMetricGoals,
          value: '${goals.length}',
          icon: Icons.flag_outlined,
        ),
        GoalsMetricItem(
          label: l10n.goalsMetricSaved,
          value: _formatCompactMoneyLabel(currentTotal),
          icon: Icons.savings_outlined,
        ),
        GoalsMetricItem(
          label: _isSwahili ? 'Bado' : 'Left',
          value: _formatCompactMoneyLabel(remainingTotal),
          icon: Icons.track_changes_outlined,
        ),
        GoalsMetricItem(
          label: _isSwahili ? 'Kazi wazi' : 'Open tasks',
          value: '$activeTasks',
          icon: Icons.pending_actions_outlined,
        ),
      ],
      budgetLockTitle: _isSwahili
          ? 'Funga matumizi kwa bajeti'
          : 'Lock spending to budgets',
      budgetLockSubtitle: _isSwahili
          ? 'Matumizi yote yatatakiwa kutumia bajeti iliyochaguliwa.'
          : 'All spending will require a budget category and stay within its limit.',
      budgetLockStatusLabel: budgetLockEnabled
          ? (_isSwahili ? 'Ulinzi umewashwa' : 'Protection on')
          : (_isSwahili ? 'Ulinzi umezimwa' : 'Protection off'),
      budgetLockEnabled: budgetLockEnabled,
      budgetLockIcon: budgetLockEnabled
          ? Icons.lock_rounded
          : Icons.lock_open_rounded,
      budgetLockAccent: budgetLockEnabled ? ui.danger : ui.textMuted,
      onBudgetLockChanged: (value) async {
        final auth = context.read<AuthController>();
        if (await auth.hasSecurityPinConfigured()) {
          if (!mounted) return;
          final pin = await promptCurrentPin(context);
          if (pin == null || pin.trim().isEmpty) return;
          final ok = await auth.verifySecurityPin(pin);
          if (!ok) {
            showSnack(l10n.loginInvalidPinMessage);
            return;
          }
        } else {
          if (!mounted) return;
          final configured = await promptPinSetup(context);
          if (!configured) {
            showSnack(
              _isSwahili
                  ? 'Weka PIN kwanza kabla ya kufunga matumizi ya bajeti.'
                  : 'Set up your PIN first before locking budget spending.',
            );
            return;
          }
        }

        await _runBusy(
          value
              ? (_isSwahili
                    ? 'Inafunga matumizi kwa bajeti...'
                    : 'Locking spending to budgets...')
              : (_isSwahili
                    ? 'Inafungua matumizi ya bajeti...'
                    : 'Unlocking budget spending...'),
          () =>
              context.read<AppSettingsController>().setBudgetLockEnabled(value),
        );
        showSnack(
          value
              ? (_isSwahili
                    ? 'Bajeti zimefungwa kwa matumizi.'
                    : 'Budget lock enabled.')
              : (_isSwahili
                    ? 'Bajeti zimefunguliwa.'
                    : 'Budget lock disabled.'),
        );
      },
    );
  }

  void _syncAutoScroll({
    required int count,
    required int currentCount,
    required PageController controller,
    required Timer? timer,
    required void Function(Timer?) setTimer,
    required void Function(int) setIndex,
    required bool Function() isPaused,
  }) {
    if (count == currentCount) return;
    timer?.cancel();
    if (count <= 1) {
      setTimer(null);
      setIndex(0);
      if (controller.hasClients) {
        controller.jumpToPage(0);
      }
      return;
    }
    setTimer(
      Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !controller.hasClients || isPaused()) return;
        final next = (currentIndexGetter(controller) + 1) % count;
        controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }),
    );
  }

  int currentIndexGetter(PageController controller) {
    if (identical(controller, _goalsPageController)) return _goalsIndex;
    if (identical(controller, _budgetsPageController)) return _budgetsIndex;
    return _tasksIndex;
  }

  void _setCarouselPaused(PageController controller, bool value) {
    if (identical(controller, _goalsPageController)) {
      if (_goalsAutoScrollPaused != value && mounted) {
        setState(() => _goalsAutoScrollPaused = value);
      }
      return;
    }
    if (identical(controller, _budgetsPageController)) {
      if (_budgetsAutoScrollPaused != value && mounted) {
        setState(() => _budgetsAutoScrollPaused = value);
      }
      return;
    }
    if (_tasksAutoScrollPaused != value && mounted) {
      setState(() => _tasksAutoScrollPaused = value);
    }
  }

  void _ensureAutoScrollCounts({
    required int goalsCount,
    required int budgetsCount,
    required int tasksCount,
  }) {
    if (goalsCount != _goalsCount) {
      _syncAutoScroll(
        count: goalsCount,
        currentCount: _goalsCount,
        controller: _goalsPageController,
        timer: _goalsTimer,
        setTimer: (value) => _goalsTimer = value,
        setIndex: (value) => _goalsIndex = value,
        isPaused: () => _goalsAutoScrollPaused,
      );
      _goalsCount = goalsCount;
    }
    if (budgetsCount != _budgetsCount) {
      _syncAutoScroll(
        count: budgetsCount,
        currentCount: _budgetsCount,
        controller: _budgetsPageController,
        timer: _budgetsTimer,
        setTimer: (value) => _budgetsTimer = value,
        setIndex: (value) => _budgetsIndex = value,
        isPaused: () => _budgetsAutoScrollPaused,
      );
      _budgetsCount = budgetsCount;
    }
    if (tasksCount != _tasksCount) {
      _syncAutoScroll(
        count: tasksCount,
        currentCount: _tasksCount,
        controller: _tasksPageController,
        timer: _tasksTimer,
        setTimer: (value) => _tasksTimer = value,
        setIndex: (value) => _tasksIndex = value,
        isPaused: () => _tasksAutoScrollPaused,
      );
      _tasksCount = tasksCount;
    }
  }

  Widget _goalsList(List<Map<String, dynamic>> goals) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return GoalsCarouselSection(
      items: List.generate(
        goals.length,
        (index) => _goalCard(goals[index], cardIndex: index),
      ),
      controller: _goalsPageController,
      activeIndex: _goalsIndex,
      onPageChanged: (index) => setState(() => _goalsIndex = index),
      onPauseChanged: (value) =>
          _setCarouselPaused(_goalsPageController, value),
      emptyIcon: Icons.flag_outlined,
      emptyTitle: l10n.goalsEmptyTitle,
      emptySubtitle: l10n.goalsEmptyMessage,
      height: width < 360 ? 344 : (width < 390 ? 356 : 368),
    );
  }

  Widget _categoriesList(List<Map<String, dynamic>> categories) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return GoalsCarouselSection(
      items: List.generate(
        categories.length,
        (index) => _categoryCard(categories[index], cardIndex: index),
      ),
      controller: _budgetsPageController,
      activeIndex: _budgetsIndex,
      onPageChanged: (index) => setState(() => _budgetsIndex = index),
      onPauseChanged: (value) =>
          _setCarouselPaused(_budgetsPageController, value),
      emptyIcon: Icons.dashboard_customize_outlined,
      emptyTitle: l10n.goalsBudgetEmptyTitle,
      emptySubtitle: l10n.goalsBudgetEmptyMessage,
      height: width < 360 ? 316 : (width < 390 ? 328 : 338),
    );
  }

  Widget _tasksList(
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> goals,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return GoalsCarouselSection(
      items: List.generate(
        tasks.length,
        (index) => _taskCard(tasks[index], goals, cardIndex: index),
      ),
      controller: _tasksPageController,
      activeIndex: _tasksIndex,
      onPageChanged: (index) => setState(() => _tasksIndex = index),
      onPauseChanged: (value) =>
          _setCarouselPaused(_tasksPageController, value),
      emptyIcon: Icons.checklist_rounded,
      emptyTitle: l10n.goalsTasksEmptyTitle,
      emptySubtitle: l10n.goalsTasksEmptyMessage,
      height: width < 360 ? 320 : (width < 390 ? 332 : 344),
    );
  }

  Widget _viewSwitcher() {
    final l10n = AppLocalizations.of(context)!;
    return GoalsViewSwitcher(
      items: [
        GoalsSwitchItem(
          title: l10n.goalsTabGoals,
          subtitle: _isSwahili ? 'Akiba na malengo' : 'Savings and targets',
        ),
        GoalsSwitchItem(
          title: l10n.goalsTabBudget,
          subtitle: _isSwahili ? 'Mipaka ya matumizi' : 'Spending limits',
        ),
        GoalsSwitchItem(
          title: l10n.goalsTabTasks,
          subtitle: _isSwahili ? 'Hatua za kufuatilia' : 'Progress checklist',
        ),
      ],
      selectedIndex: _view.index,
      onSelectedIndex: (index) => _setView(_GoalsView.values[index]),
    );
  }

  Widget _goalCard(Map<String, dynamic> goal, {required int cardIndex}) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final spec = goalSpec(goal, cardIndex: cardIndex);
    final name = readString(goal, [
      'name',
    ], fallback: l10n.goalsDefaultGoalName);
    final current = doubleFrom(goal['current']);
    final target = doubleFrom(goal['target']);
    final percent = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final remaining = math.max(target - current, 0).toDouble();
    final deadline = formatDate(goal['deadline']);
    final fundingStrategyLabel = _goalFundingStrategyLabel(goal);
    final fundingStrategyColor = _goalFundingStrategyColor(ui, goal);
    final autoAllocationEnabled = boolFrom(
      lookupDynamicValue(goal, [
        'autoAllocationEnabled',
        'auto_allocation_enabled',
      ]),
    );
    final monthlyTarget = doubleFrom(
      lookupDynamicValue(goal, ['monthlyTarget', 'monthly_target']),
    );
    final goalStatusLabel = (spec.badge?.trim().isNotEmpty ?? false)
        ? spec.badge!
        : (_isSwahili ? 'Hai' : 'Active');
    return GoalCard(
      title: name,
      accent: spec.accent,
      glow: spec.glow,
      visualToken: spec.visualToken,
      progressColor: spec.progress,
      icon: spec.icon,
      amountLabel: _formatCompactMoneyLabel(current),
      progressLabel:
          '${(percent * 100).toStringAsFixed(0)}% ${_isSwahili ? 'imefikiwa' : 'reached'}',
      strategyBadge: StatusBadgeData(
        label: fundingStrategyLabel,
        icon: autoAllocationEnabled
            ? Icons.auto_graph_rounded
            : Icons.touch_app_rounded,
        accent: fundingStrategyColor,
      ),
      statusBadge: StatusBadgeData(
        label: goalStatusLabel,
        icon: Icons.verified_rounded,
        accent: ui.success,
      ),
      analyticsTitle: _isSwahili ? 'Uchanganuzi wa lengo' : 'Goal analysis',
      analyticsSubtitle: _isSwahili
          ? 'Grafu inaonesha kiasi kilichofadhiliwa, pengo lililobaki, na lengo.'
          : 'Chart compares funded amount, remaining gap, and target level.',
      savedValue: _formatCompactMoneyLabel(current),
      remainingValue: _formatCompactMoneyLabel(remaining),
      targetValue: _formatCompactMoneyLabel(target),
      deadlineLabel: deadline,
      monthlyPaceLabel: monthlyTarget > 0
          ? _formatCompactMoneyLabel(monthlyTarget)
          : null,
      chartValueFormatter: _compactChartCurrency,
      goalBars: [
        GoalBarData(
          label: _isSwahili ? 'Fedha' : 'Funded',
          value: current,
          color: ui.success,
        ),
        GoalBarData(
          label: _isSwahili ? 'Pengo' : 'Gap',
          value: remaining,
          color: ui.warning,
        ),
        GoalBarData(
          label: _isSwahili ? 'Lengo' : 'Target',
          value: target,
          color: spec.accent,
        ),
      ],
      onMenuSelected: (value) {
        if (value == 'edit') {
          _openGoalComposer(existing: goal);
          return;
        }
        _deleteGoal(goal);
      },
      onAllocate: () => _openAllocateSheet(goal),
      onWithdraw: () => _openWithdrawSheet(goal),
      onEdit: () => _openGoalComposer(existing: goal),
      onDelete: () => _deleteGoal(goal),
      isSwahili: _isSwahili,
      l10n: l10n,
    );
  }

  Widget _categoryCard(
    Map<String, dynamic> category, {
    required int cardIndex,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final spec = categorySpec(category, cardIndex: cardIndex);
    final name = readString(category, [
      'name',
    ], fallback: l10n.goalsDefaultBudgetName);
    final budget = doubleFrom(category['budget']);
    final used = doubleFrom(
      lookupDynamicValue(category, [
        'spent',
        'used',
        'current',
        'spent_amount',
        'usage',
        'amount_used',
      ]),
    );
    final period = formatBudgetPeriod(category);
    final expectedUsage = expectedBudgetUsage(category, budget);
    final hardLimit = boolFrom(
      lookupDynamicValue(category, ['hard_limit', 'hardLimit']),
    );
    final usageStatusBadge = _budgetUsageStatusBadge(
      used: used,
      expected: expectedUsage,
      budget: budget,
    );
    final budgetSignal = budget <= 0
        ? 1
        : budget < 100
        ? 1
        : budget < 1000
        ? 2
        : budget < 10000
        ? 3
        : 4;
    return BudgetCard(
      title: name,
      accent: spec.accent,
      glow: spec.glow,
      visualToken: spec.visualToken,
      icon: spec.icon,
      eyebrow: spec.eyebrow,
      subtitle: spec.subtitle,
      amountLabel: _formatCompactMoneyLabel(budget),
      periodLabel: period.toUpperCase(),
      limitBadge: StatusBadgeData(
        label: hardLimit ? l10n.goalsHardLimit : l10n.goalsSoftLimit,
        icon: hardLimit ? Icons.gpp_good_outlined : Icons.tune_rounded,
        accent: hardLimit ? ui.danger : ui.warning,
      ),
      statusBadge: usageStatusBadge,
      analyticsTitle: _isSwahili ? 'Matumizi ya bajeti' : 'Budget usage',
      analyticsSubtitle: _isSwahili
          ? 'Inaonesha matumizi yaliyotarajiwa hadi sasa, yaliyotumika, na uwezo wa bajeti.'
          : 'Shows expected usage so far, actual used amount, and full budget capacity.',
      analyticsValues: [expectedUsage, used, budget],
      analyticsLabels: [
        _isSwahili ? 'Tarajiwa' : 'Expected',
        _isSwahili ? 'Imetumika' : 'Used',
        _isSwahili ? 'Uwezo' : 'Capacity',
      ],
      analyticsColors: [
        ui.accent,
        hardLimit ? ui.danger : ui.warning,
        Color.lerp(ui.success, spec.accent, 0.2)!,
      ],
      analyticsValueFormatter: _compactChartCurrency,
      activeCount: budgetSignal,
      onMenuSelected: (value) {
        if (value == 'edit') {
          _openCategoryComposer(existing: category);
          return;
        }
        _deleteCategory(category);
      },
    );
  }

  Widget _taskCard(
    Map<String, dynamic> task,
    List<Map<String, dynamic>> goals, {
    required int cardIndex,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final text = readString(task, ['text'], fallback: l10n.goalsTaskFallback);
    final completed = boolFrom(task['completed']);
    final dueDate = formatDate(
      lookupDynamicValue(task, ['dueDate', 'due_date']),
    );
    final bounty = doubleFrom(lookupDynamicValue(task, ['bounty']));
    final linkedGoalId = readString(task, ['linkedGoalId', 'linked_goal_id']);
    final linkedGoalName = goals
        .where((goal) => readString(goal, ['id']) == linkedGoalId)
        .map((goal) => readString(goal, ['name']))
        .cast<String?>()
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => '',
        )
        .toString();
    final taskPalette = seededPalette(
      task,
      fallback: const [
        Color(0xFF0F8B8D),
        Color(0xFF6C5CE7),
        Color(0xFFD97706),
        Color(0xFF2B6CB0),
        Color(0xFFB83280),
        Color(0xFF2F855A),
        Color(0xFFC05621),
        Color(0xFF7A5AF8),
      ],
      namespace: 'task',
      discriminator: cardIndex,
    );
    final taskAccent = completed
        ? mixColor(taskPalette.$1, ui.success, 0.48)
        : taskPalette.$1;
    final taskGlow = mixColor(taskAccent, taskPalette.$2, 0.62);
    final taskSummary = completed
        ? (_isSwahili
              ? 'Imekamilika na imehifadhiwa kwenye mpango wako.'
              : 'Completed and safely tracked in your plan.')
        : linkedGoalName.isNotEmpty
        ? (_isSwahili
              ? 'Imeunganishwa na lengo la $linkedGoalName.'
              : 'Linked to $linkedGoalName for follow-through.')
        : (_isSwahili
              ? 'Iko tayari kwa hatua yako inayofuata ya fedha.'
              : 'Ready for your next money move.');
    return TaskCard(
      title: text,
      accent: taskAccent,
      glow: taskGlow,
      visualToken: _visualToken(
        task,
        namespace: 'task',
        discriminator: cardIndex,
      ),
      completed: completed,
      dueLabel: dueDate,
      linkedGoalName: linkedGoalName,
      bountyLabel: bounty > 0 ? _formatCompactMoneyLabel(bounty) : null,
      summary: taskSummary,
      analyticsValues: [
        completed ? 1 : 0.45,
        linkedGoalName.isNotEmpty ? 0.82 : 0.34,
        bounty > 0 ? 0.68 : 0.24,
      ],
      analyticsLabels: [
        _isSwahili ? 'Mwendo' : 'Progress',
        _isSwahili ? 'Imeunganishwa' : 'Linked',
        _isSwahili ? 'Zawadi' : 'Reward',
      ],
      analyticsColors: [ui.success, ui.accent, ui.warning],
      analyticsValueFormatter: _compactChartNumber,
      statusBadge: StatusBadgeData(
        label: completed ? l10n.goalsTaskCompleted : l10n.goalsTaskPending,
        icon: completed
            ? Icons.task_alt_rounded
            : Icons.pending_actions_outlined,
        accent: completed ? ui.success : ui.warning,
      ),
      onToggle: () => _toggleTask(task),
      onEdit: () => _openTaskComposer(existing: task, goals: goals),
      onDelete: () => _deleteTask(task),
      onMenuSelected: (value) {
        if (value == 'edit') {
          _openTaskComposer(existing: task, goals: goals);
          return;
        }
        _deleteTask(task);
      },
      l10n: l10n,
    );
  }

  String _compactChartNumber(double value) {
    final absolute = value.abs();
    final suffix = absolute >= 1000000000000
        ? 'T'
        : absolute >= 1000000000
        ? 'B'
        : absolute >= 1000000
        ? 'M'
        : absolute >= 1000
        ? 'K'
        : '';
    final scaled = suffix == 'T'
        ? value / 1000000000000
        : suffix == 'B'
        ? value / 1000000000
        : suffix == 'M'
        ? value / 1000000
        : suffix == 'K'
        ? value / 1000
        : value;
    final digits = scaled.abs() >= 100 || scaled == scaled.roundToDouble()
        ? 0
        : 1;
    return '${scaled.toStringAsFixed(digits)}$suffix';
  }

  String _compactChartCurrency(double value) {
    return formatDisplayMoney(
      value,
      _currencyCode,
      locale: _localeTag,
      hideBalances: context.read<AppSettingsController>().hideBalances,
    );
  }

  Widget _errorCard(String error) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: ui.danger),
            const SizedBox(height: 10),
            Text(
              l10n.goalsLoadFailedTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoalComposer({Map<String, dynamic>? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return GoalComposerSheet(
          initialData: GoalFormData(
            name: existing == null ? '' : readString(existing, ['name']),
            target: existing == null ? null : doubleFrom(existing['target']),
            fundingStrategy: _goalFundingStrategy(existing),
            autoAllocationEnabled: _goalAutoAllocationEnabled(existing),
            linkedIncomePercentage: existing == null
                ? null
                : doubleFrom(
                    lookupDynamicValue(existing, [
                      'linkedIncomePercentage',
                      'linked_income_percentage',
                    ]),
                  ),
            monthlyTarget: existing == null
                ? null
                : doubleFrom(
                    lookupDynamicValue(existing, [
                      'monthlyTarget',
                      'monthly_target',
                    ]),
                  ),
            deadline: DateTime.tryParse(
              existing == null ? '' : readString(existing, ['deadline']),
            ),
          ),
          currencyCode: _currencyCode,
          languageCode: _languageCode,
          isEditing: existing != null,
          isSwahili: _isSwahili,
          onSubmit: (data) async {
            final token = await this.context
                .read<AuthController>()
                .getValidAccessToken();
            if (!context.mounted) return;
            if (token == null || token.isEmpty) {
              throw Exception(
                _isSwahili
                    ? 'Kikao chako hakikuthibitishwa. Jaribu tena.'
                    : 'Your session could not be confirmed. Try again.',
              );
            }
            final draftStyle = draftGoalStyle(data.name);
            final payload = {
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
              'color': readString(existing ?? const {}, [
                'color',
              ], fallback: draftStyle.$1),
              'icon': readString(existing ?? const {}, [
                'icon',
              ], fallback: draftStyle.$2),
            };
            try {
              await _runBusy(
                existing == null
                    ? (_isSwahili ? 'Inaunda lengo...' : 'Creating goal...')
                    : (_isSwahili ? 'Inasasisha lengo...' : 'Updating goal...'),
                () async {
                  if (existing == null) {
                    await this.context.read<GoalsController>().createGoal(
                      token,
                      payload,
                    );
                  } else {
                    await this.context.read<GoalsController>().updateGoal(
                      token,
                      readString(existing, ['id']),
                      payload,
                    );
                  }
                },
              );
              if (!context.mounted) return;
              showSnack(
                existing == null
                    ? l10n.goalsGoalCreatedMessage
                    : l10n.goalsGoalUpdatedMessage,
              );
            } catch (e) {
              throw Exception(
                mapBackendStatusMessage(
                  e.toString(),
                  sw: _isSwahili,
                  fallback: _isSwahili
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

  String _goalFundingStrategy(Map<String, dynamic>? goal) {
    final raw = lookupDynamicValue(goal ?? const {}, [
      'fundingStrategy',
      'funding_strategy',
    ]);
    final value = raw?.toString().trim().toLowerCase();
    if (value == 'percentage' || value == 'fixed') return value!;
    return 'manual';
  }

  String _goalFundingStrategyLabel(Map<String, dynamic> goal) {
    final strategy = _goalFundingStrategy(goal);
    final autoEnabled = _goalAutoAllocationEnabled(goal);
    if (strategy == 'percentage') {
      final percentage = doubleFrom(
        lookupDynamicValue(goal, [
          'linkedIncomePercentage',
          'linked_income_percentage',
        ]),
      );
      if (autoEnabled && percentage > 0) {
        final formatted = percentage % 1 == 0
            ? percentage.toStringAsFixed(0)
            : percentage.toStringAsFixed(2);
        return _isSwahili ? 'Auto ($formatted%)' : 'Auto ($formatted%)';
      }
      return _isSwahili ? 'Auto' : 'Auto';
    }
    if (strategy == 'fixed') {
      return _isSwahili ? 'Fixed' : 'Fixed';
    }
    return _isSwahili ? 'Manual' : 'Manual';
  }

  Color _goalFundingStrategyColor(OrbiUiTokens ui, Map<String, dynamic> goal) {
    final strategy = _goalFundingStrategy(goal);
    if (strategy == 'percentage') return ui.accent;
    if (strategy == 'fixed') return ui.iconMuted;
    return ui.textMuted;
  }

  bool _goalAutoAllocationEnabled(Map<String, dynamic>? goal) {
    return boolFrom(
      lookupDynamicValue(goal ?? const {}, [
        'autoAllocationEnabled',
        'auto_allocation_enabled',
      ]),
    );
  }

  Future<void> _openCategoryComposer({Map<String, dynamic>? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return BudgetComposerSheet(
          initialData: BudgetFormData(
            name: existing == null ? '' : readString(existing, ['name']),
            budget: existing == null ? null : doubleFrom(existing['budget']),
            interval: existing == null ? 1 : budgetInterval(existing),
            period: existing == null
                ? 'month'
                : normalizeBudgetPeriod(
                    readString(existing, ['budget_period', 'period', 'window']),
                  ),
          ),
          currencyCode: _currencyCode,
          isEditing: existing != null,
          isSwahili: _isSwahili,
          onSubmit: (data) async {
            final token = await this.context
                .read<AuthController>()
                .getValidAccessToken();
            if (!context.mounted) return;
            if (token == null || token.isEmpty) {
              throw Exception(
                _isSwahili
                    ? 'Kikao chako hakikuthibitishwa. Jaribu tena.'
                    : 'Your session could not be confirmed. Try again.',
              );
            }
            final draftStyle = draftBudgetStyle(data.name);
            final payload = {
              'name': data.name,
              'budget': data.budget,
              'color': draftStyle.$1,
              'icon': draftStyle.$2,
              'budget_period': data.period,
              'budget_interval': data.interval,
              'period': data.period,
            };
            try {
              await _runBusy(
                existing == null
                    ? (_isSwahili ? 'Inaunda bajeti...' : 'Creating budget...')
                    : (_isSwahili
                          ? 'Inasasisha bajeti...'
                          : 'Updating budget...'),
                () async {
                  if (existing == null) {
                    await this.context.read<GoalsController>().createCategory(
                      token,
                      payload,
                    );
                  } else {
                    await this.context.read<GoalsController>().updateCategory(
                      token,
                      readString(existing, ['id']),
                      payload,
                    );
                  }
                },
              );
              if (!context.mounted) return;
              showSnack(
                existing == null
                    ? l10n.goalsBudgetCreatedMessage
                    : l10n.goalsBudgetUpdatedMessage,
              );
            } catch (e) {
              throw Exception(
                mapBackendStatusMessage(
                  e.toString(),
                  sw: _isSwahili,
                  fallback: _isSwahili
                      ? 'Imeshindikana kuhifadhi bajeti.'
                      : 'Unable to save the budget.',
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _openTaskComposer({
    Map<String, dynamic>? existing,
    List<Map<String, dynamic>>? goals,
  }) async {
    final availableGoals = goals ?? context.read<GoalsController>().goals;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return TaskComposerSheet(
          initialData: TaskFormData(
            text: existing == null ? '' : readString(existing, ['text']),
            linkedGoalId: () {
              final id = readString(existing ?? const {}, [
                'linkedGoalId',
                'linked_goal_id',
              ]);
              return id.isEmpty ? null : id;
            }(),
            bounty: existing == null
                ? null
                : doubleFrom(lookupDynamicValue(existing, ['bounty'])),
            dueDate: DateTime.tryParse(
              readString(existing ?? const {}, ['dueDate', 'due_date']),
            ),
            completed: boolFrom(existing?['completed']),
          ),
          availableGoals: availableGoals,
          currencyCode: _currencyCode,
          languageCode: _languageCode,
          isEditing: existing != null,
          isSwahili: _isSwahili,
          onSubmit: (data) async {
            final token = await this.context
                .read<AuthController>()
                .getValidAccessToken();
            if (!context.mounted) return;
            if (token == null || token.isEmpty) {
              throw Exception(
                _isSwahili
                    ? 'Kikao chako hakikuthibitishwa. Jaribu tena.'
                    : 'Your session could not be confirmed. Try again.',
              );
            }
            final linkedGoalPayload = data.linkedGoalId == null
                ? const <String, dynamic>{}
                : <String, dynamic>{'linkedGoalId': data.linkedGoalId};
            final payload = {
              'text': data.text,
              'completed': data.completed,
              ...linkedGoalPayload,
              if (data.bounty case final double taskBounty when taskBounty > 0)
                'bounty': taskBounty,
              if (data.dueDate case final selectedDueDate?)
                'dueDate': selectedDueDate.toUtc().toIso8601String(),
            };
            try {
              await _runBusy(
                existing == null
                    ? (_isSwahili ? 'Inaunda kazi...' : 'Creating task...')
                    : (_isSwahili ? 'Inasasisha kazi...' : 'Updating task...'),
                () async {
                  if (existing == null) {
                    await this.context.read<GoalsController>().createTask(
                      token,
                      payload,
                    );
                  } else {
                    await this.context.read<GoalsController>().updateTask(
                      token,
                      readString(existing, ['id']),
                      payload,
                    );
                  }
                },
              );
              if (!context.mounted) return;
              showSnack(
                existing == null
                    ? l10n.goalsTaskCreatedMessage
                    : l10n.goalsTaskUpdatedMessage,
              );
            } catch (e) {
              throw Exception(
                mapBackendStatusMessage(
                  e.toString(),
                  sw: _isSwahili,
                  fallback: _isSwahili
                      ? 'Imeshindikana kuhifadhi kazi.'
                      : 'Unable to save the task.',
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final nextCompleted = !boolFrom(task['completed']);
    try {
      await _runBusy(
        nextCompleted
            ? (_isSwahili ? 'Inakamilisha kazi...' : 'Completing task...')
            : (_isSwahili ? 'Inafungua tena kazi...' : 'Reopening task...'),
        () => context.read<GoalsController>().updateTask(
          token,
          readString(task, ['id']),
          {
            'text': readString(task, ['text']),
            'completed': nextCompleted,
            if (readString(task, ['linkedGoalId', 'linked_goal_id']).isNotEmpty)
              'linkedGoalId': readString(task, [
                'linkedGoalId',
                'linked_goal_id',
              ]),
            if (doubleFrom(lookupDynamicValue(task, ['bounty'])) > 0)
              'bounty': doubleFrom(lookupDynamicValue(task, ['bounty'])),
            if (readString(task, ['dueDate', 'due_date']).isNotEmpty)
              'dueDate': readString(task, ['dueDate', 'due_date']),
          },
        ),
      );
      showSnack(
        nextCompleted
            ? l10n.goalsTaskCompletedMessage
            : l10n.goalsTaskReopenedMessage,
      );
    } catch (e) {
      showSnack(e.toString());
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      l10n.goalsDeleteTaskTitle,
      l10n.goalsDeleteTaskMessage,
    );
    if (!confirmed) return;
    if (!mounted) return;

    try {
      await _runBusy(
        _isSwahili ? 'Inafuta kazi...' : 'Deleting task...',
        () => context.read<GoalsController>().deleteTask(
          token,
          readString(task, ['id']),
        ),
      );
      if (!mounted) return;
      showSnack(l10n.goalsTaskDeletedMessage);
    } catch (e) {
      if (!mounted) return;
      showSnack(e.toString());
    }
  }

  Future<void> _openAllocateSheet(Map<String, dynamic> goal) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final controller = context.read<GoalsController>();
    final amountController = TextEditingController();
    List<Map<String, dynamic>> wallets = const [];
    String? selectedWalletId;
    String? availableUnallocatedLabel;

    try {
      await _runBusy(
        _isSwahili
            ? 'Inatafuta walleti ya uendeshaji...'
            : 'Checking your operating wallet...',
        () async {
          wallets = await _walletService.getWallets();
          if (wallets.where((wallet) => isOperatingWallet(wallet)).isEmpty) {
            final sovereignWallets = await _walletService.getSovereignWallets(
              includeEscrow: false,
            );
            wallets = [...wallets, ...sovereignWallets];
          }
        },
      );
      wallets = wallets.where((wallet) => isOperatingWallet(wallet)).toList();
      if (wallets.isEmpty) {
        _setStatus(l10n.goalsNoSourceWalletsMessage, isError: true);
      }
      if (wallets.isNotEmpty) {
        final selectedWallet = wallets.first;
        selectedWalletId = walletId(selectedWallet);

        final allocatedTotal =
            controller.goals.fold<double>(
              0,
              (sum, item) => sum + doubleFrom(item['current']),
            ) +
            controller.categories.fold<double>(
              0,
              (sum, item) => sum + doubleFrom(item['budget']),
            );
        final walletAmount = doubleFrom(
          selectedWallet['available_balance'] ??
              selectedWallet['balance'] ??
              selectedWallet['ledger_balance'],
        );
        final unallocated = (walletAmount - allocatedTotal)
            .clamp(0, double.infinity)
            .toDouble();
        final currency = readString(selectedWallet, [
          'currency',
          'currency_code',
        ], fallback: '');
        availableUnallocatedLabel = formatCurrencyAmount(
          unallocated,
          currency,
          locale: _localeTag,
          decimalDigits: 2,
        );
      }
    } catch (e) {
      _setStatus(e.toString(), isError: true);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.goalsAllocateSheetTitle(
                      readString(goal, [
                        'name',
                      ], fallback: l10n.goalsAllocateFallbackName),
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (wallets.isEmpty)
                    Text(l10n.goalsNoSourceWalletsMessage)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.goalsSourceWalletLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSwahili
                              ? 'Chagua walleti utakayotumia kufadhili lengo hili.'
                              : 'Choose the wallet you want to use to fund this goal.',
                          style: TextStyle(
                            color: OrbiTheme.uiOf(context).textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < wallets.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == wallets.length - 1 ? 0 : 10,
                            ),
                            child: _goalWalletChoiceCard(
                              wallets[i],
                              selected:
                                  walletId(wallets[i]) == selectedWalletId,
                              onTap: () {
                                final selectedWallet = wallets[i];
                                setSheetState(() {
                                  selectedWalletId = walletId(selectedWallet);
                                  final currency = readString(selectedWallet, [
                                    'currency',
                                    'currency_code',
                                  ], fallback: _currencyCode);
                                  availableUnallocatedLabel =
                                      formatCurrencyAmount(
                                        availableOperatingBalance(
                                          selectedWallet,
                                        ),
                                        currency,
                                        locale: _localeTag,
                                        decimalDigits: 2,
                                      );
                                });
                              },
                            ),
                          ),
                        if (availableUnallocatedLabel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _isSwahili
                                ? 'Baki haijatengwa: $availableUnallocatedLabel'
                                : 'Unallocated available: $availableUnallocatedLabel',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 12),
                  OrbiAmountField(
                    controller: amountController,
                    inputFormatters: [AmountInputFormatter()],
                    label: l10n.goalsAmountLabel,
                    currency: resolveCurrencyDisplaySymbol(_currencyCode),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: wallets.isEmpty
                          ? null
                          : () async {
                              final amount = AmountInputFormatter.tryParse(
                                amountController.text,
                              );
                              if (amount == null ||
                                  amount <= 0 ||
                                  selectedWalletId == null) {
                                showSnack(l10n.goalsAllocateValidationMessage);
                                return;
                              }
                              Navigator.pop(context);
                              try {
                                await _runBusy(
                                  _isSwahili
                                      ? 'Inahamisha fedha kwenda lengo...'
                                      : 'Allocating funds to goal...',
                                  () => this.context
                                      .read<GoalsController>()
                                      .allocateGoal(
                                        token,
                                        readString(goal, [
                                          'id',
                                          'goalId',
                                          'goal_id',
                                        ]),
                                        {
                                          'amount': amount,
                                          'sourceWalletId': selectedWalletId,
                                          'source_wallet_id': selectedWalletId,
                                          'walletId': selectedWalletId,
                                        },
                                      ),
                                );
                                showSnack(l10n.goalsAllocatedMessage);
                              } catch (e) {
                                final message = e.toString();
                                if (message.contains(
                                  'INTERNAL_BALANCE_MISMATCH',
                                )) {
                                  showSnack(
                                    _isSwahili
                                        ? 'Hitilafu ya ndani ya salio. Tafadhali wasiliana na huduma kwa wateja ikiwa itaendelea.'
                                        : 'Internal balance error. Please contact support if this persists.',
                                  );
                                } else {
                                  showSnack(message);
                                }
                              }
                            },
                      child: Text(l10n.goalsAllocateFundsButton),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openWithdrawSheet(Map<String, dynamic> goal) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    List<Map<String, dynamic>> wallets = const [];
    String? selectedWalletId;

    try {
      await _runBusy(
        _isSwahili
            ? 'Inatafuta walleti ya uendeshaji...'
            : 'Checking your operating wallet...',
        () async {
          wallets = await _walletService.getWallets();
          if (wallets.where((wallet) => isOperatingWallet(wallet)).isEmpty) {
            final sovereignWallets = await _walletService.getSovereignWallets(
              includeEscrow: false,
            );
            wallets = [...wallets, ...sovereignWallets];
          }
        },
      );
      wallets = wallets.where((wallet) => isOperatingWallet(wallet)).toList();
      if (wallets.isEmpty) {
        _setStatus(l10n.goalsNoDestinationWalletsMessage, isError: true);
      }
      if (wallets.isNotEmpty) {
        final selectedWallet = wallets.first;
        selectedWalletId = walletId(selectedWallet);
      }
    } catch (e) {
      _setStatus(e.toString(), isError: true);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.goalsWithdrawSheetTitle(
                      readString(goal, [
                        'name',
                      ], fallback: l10n.goalsAllocateFallbackName),
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.goalsWithdrawLockedHint,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (wallets.isEmpty)
                    Text(l10n.goalsNoDestinationWalletsMessage)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.goalsDestinationWalletLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSwahili
                              ? 'Fedha zitarejea kwenye walleti yako ya uendeshaji.'
                              : 'Funds will return to your operating wallet.',
                          style: TextStyle(
                            color: OrbiTheme.uiOf(context).textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < wallets.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == wallets.length - 1 ? 0 : 10,
                            ),
                            child: _goalWalletChoiceCard(
                              wallets[i],
                              selected:
                                  walletId(wallets[i]) == selectedWalletId,
                              onTap: () {
                                final selectedWallet = wallets[i];
                                setSheetState(() {
                                  selectedWalletId = walletId(selectedWallet);
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  OrbiAmountField(
                    controller: amountController,
                    inputFormatters: [AmountInputFormatter()],
                    label: l10n.goalsAmountLabel,
                    currency: resolveCurrencyDisplaySymbol(_currencyCode),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: wallets.isEmpty
                          ? null
                          : () async {
                              final amount = AmountInputFormatter.tryParse(
                                amountController.text,
                              );
                              if (amount == null ||
                                  amount <= 0 ||
                                  selectedWalletId == null) {
                                showSnack(l10n.goalsWithdrawValidationMessage);
                                return;
                              }
                              Navigator.pop(context);
                              try {
                                final verification =
                                    await _buildGoalWithdrawalVerification();
                                if (!mounted) return;
                                if (verification == null) {
                                  showSnack(
                                    l10n.settingsSecurityVerificationHelper,
                                  );
                                  return;
                                }
                                await _runBusy(
                                  _isSwahili
                                      ? 'Inarejesha fedha kutoka lengo...'
                                      : 'Returning funds from goal...',
                                  () => this.context
                                      .read<GoalsController>()
                                      .withdrawGoal(
                                        token,
                                        readString(goal, ['id']),
                                        {
                                          'amount': amount,
                                          'destinationWalletId':
                                              selectedWalletId,
                                          'verification': verification,
                                        },
                                      ),
                                );
                                showSnack(l10n.goalsWithdrawnMessage);
                              } catch (e) {
                                final message = e.toString();
                                if (message.contains(
                                  'INTERNAL_BALANCE_MISMATCH',
                                )) {
                                  showSnack(
                                    _isSwahili
                                        ? 'Hitilafu ya ndani ya salio. Tafadhali wasiliana na huduma kwa wateja ikiwa itaendelea.'
                                        : 'Internal balance error. Please contact support if this persists.',
                                  );
                                } else {
                                  showSnack(message);
                                }
                              }
                            },
                      child: Text(l10n.goalsWithdrawFundsButton),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final goalsController = context.read<GoalsController>();
    final confirmed = await _confirm(
      l10n.goalsDeleteGoalTitle,
      l10n.goalsDeleteGoalMessage,
    );
    if (!confirmed) return;

    try {
      await _runBusy(
        _isSwahili ? 'Inafuta lengo...' : 'Deleting goal...',
        () => goalsController.deleteGoal(token, readString(goal, ['id'])),
      );
      showSnack(l10n.goalsDeletedMessage);
    } catch (e) {
      showSnack(e.toString());
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context)!;
    final goalsController = context.read<GoalsController>();
    final confirmed = await _confirm(
      l10n.goalsDeleteBudgetTitle,
      l10n.goalsDeleteBudgetMessage,
    );
    if (!confirmed) return;

    try {
      await _runBusy(
        _isSwahili ? 'Inafuta bajeti...' : 'Deleting budget...',
        () =>
            goalsController.deleteCategory(token, readString(category, ['id'])),
      );
      showSnack(l10n.goalsBudgetDeletedMessage);
    } catch (e) {
      showSnack(e.toString());
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.goalsContinueAction),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void showSnack(String message) {
    final raw = message.toLowerCase();
    final isError =
        raw.contains('error') ||
        raw.contains('exception') ||
        raw.contains('failed') ||
        raw.contains('invalid') ||
        raw.contains('required') ||
        raw.contains('not found') ||
        raw.contains('denied') ||
        raw.contains('insufficient') ||
        raw.contains('locked');
    _setStatus(message, isError: isError);
  }

  String formatDate(dynamic raw) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return l10n.goalsFlexibleDate;
    return DateFormat('dd MMM yyyy', _languageCode).format(parsed.toLocal());
  }

  String formatBudgetPeriod(Map<String, dynamic> category) {
    final raw = readString(category, ['period', 'budget_period', 'window']);
    final normalized = normalizeBudgetPeriod(raw);
    final interval = budgetInterval(category);
    if (_isSwahili) {
      final unit = swBudgetUnit(normalized);
      if (interval <= 1) return 'Kila $unit';
      return 'Kila $unit $interval';
    }
    final unit = enBudgetUnit(normalized);
    if (interval <= 1) {
      return enBudgetLabel(normalized);
    }
    final plural = interval == 1 ? unit : '${unit}s';
    return 'Every $interval $plural';
  }

  String normalizeBudgetPeriod(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('day')) return 'day';
    if (value.contains('week')) return 'week';
    if (value.contains('year') || value.contains('annual')) return 'year';
    return 'month';
  }

  int budgetInterval(Map<String, dynamic> category) {
    final raw = lookupDynamicValue(category, [
      'budget_interval',
      'interval',
      'period_interval',
      'cadence',
    ]);
    if (raw is int) return raw <= 0 ? 1 : raw;
    if (raw is num) return raw <= 0 ? 1 : raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  String enBudgetUnit(String period) {
    switch (period) {
      case 'day':
        return 'day';
      case 'week':
        return 'week';
      case 'year':
        return 'year';
      case 'month':
      default:
        return 'month';
    }
  }

  String enBudgetLabel(String period) {
    switch (period) {
      case 'day':
        return 'Daily';
      case 'week':
        return 'Weekly';
      case 'year':
        return 'Yearly';
      case 'month':
      default:
        return 'Monthly';
    }
  }

  String swBudgetUnit(String period) {
    switch (period) {
      case 'day':
        return 'siku';
      case 'week':
        return 'wiki';
      case 'year':
        return 'mwaka';
      case 'month':
      default:
        return 'mwezi';
    }
  }

  String readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return fallback;
  }

  dynamic lookupDynamicValue(Map<String, dynamic> source, List<String> keys) {
    final metadata = metadata0(source);
    for (final key in keys) {
      final direct = source[key];
      if (direct != null) return direct;
      final nested = metadata[key];
      if (nested != null) return nested;
    }
    return null;
  }

  Map<String, dynamic> metadata0(Map<String, dynamic> source) {
    final raw =
        source['metadata'] ??
        source['meta'] ??
        source['ui'] ??
        source['appearance'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  _DynamicCardSpec goalSpec(
    Map<String, dynamic> goal, {
    required int cardIndex,
  }) {
    final seeded = seededPalette(
      goal,
      fallback: const [
        Color(0xFF1B8A5A),
        Color(0xFF2E7D8F),
        Color(0xFF7A5AF8),
        Color(0xFFC76B29),
        Color(0xFFB54749),
        Color(0xFF356AE6),
        Color(0xFF6F9A37),
        Color(0xFF9D4EDD),
      ],
      namespace: 'goal',
      discriminator: cardIndex,
    );
    final accent =
        parseBackendColor(
          lookupDynamicValue(goal, [
            'color',
            'accent_color',
            'accentColor',
            'theme_color',
            'themeColor',
          ]),
        ) ??
        seeded.$1;
    final subtitle = stringFromDynamic(goal, [
      'description',
      'subtitle',
      'note',
      'notes',
      'summary',
      'tagline',
    ]);
    final badge = stringFromDynamic(goal, [
      'status',
      'stage',
      'progress_label',
      'progressLabel',
    ]);
    return _DynamicCardSpec(
      accent: accent,
      glow: mixColor(accent, seeded.$2, 0.58),
      progress: mixColor(accent, seeded.$3, 0.72),
      icon: dynamicIcon(goal, fallback: Icons.flag_outlined),
      visualToken: _visualToken(
        goal,
        namespace: 'goal',
        discriminator: cardIndex,
      ),
      eyebrow: stringFromDynamic(goal, [
        'goal_type',
        'type',
        'category',
        'label',
      ]),
      subtitle: subtitle,
      badge: badge,
    );
  }

  _DynamicCardSpec categorySpec(
    Map<String, dynamic> category, {
    required int cardIndex,
  }) {
    final seeded = seededPalette(
      category,
      fallback: const [
        Color(0xFFD97706),
        Color(0xFF0F8B8D),
        Color(0xFF8E44AD),
        Color(0xFF2B6CB0),
        Color(0xFF2F855A),
        Color(0xFFC05621),
        Color(0xFFB83280),
        Color(0xFF4C51BF),
      ],
      namespace: 'budget',
      discriminator: cardIndex,
    );
    final accent =
        parseBackendColor(
          lookupDynamicValue(category, [
            'color',
            'accent_color',
            'accentColor',
            'theme_color',
            'themeColor',
          ]),
        ) ??
        seeded.$1;
    return _DynamicCardSpec(
      accent: accent,
      glow: mixColor(accent, seeded.$2, 0.62),
      progress: mixColor(accent, seeded.$3, 0.68),
      icon: dynamicIcon(category, fallback: Icons.pie_chart_outline_rounded),
      visualToken: _visualToken(
        category,
        namespace: 'budget',
        discriminator: cardIndex,
      ),
      eyebrow: stringFromDynamic(category, [
        'category_type',
        'type',
        'segment',
        'label',
      ]),
      subtitle: stringFromDynamic(category, [
        'description',
        'subtitle',
        'note',
        'notes',
        'summary',
      ]),
      badge: stringFromDynamic(category, [
        'currency',
        'currency_code',
        'currencyCode',
      ]),
    );
  }

  Widget dynamicIconTile(_DynamicCardSpec spec) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.accent.withValues(alpha: 0.12),
            spec.glow.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: spec.accent.withValues(alpha: 0.18)),
      ),
      child: Icon(spec.icon, color: spec.accent),
    );
  }

  String? stringFromDynamic(Map<String, dynamic> source, List<String> keys) {
    final value = lookupDynamicValue(source, keys);
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool boolFrom(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'hard';
  }

  Color? parseBackendColor(dynamic rawColor) {
    final value = (rawColor ?? '').toString().trim();
    if (value.isEmpty) return null;

    var hex = value;
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  (Color, Color, Color) seededPalette(
    Map<String, dynamic> source, {
    required List<Color> fallback,
    String namespace = 'card',
    int discriminator = 0,
  }) {
    final hash = _visualToken(
      source,
      namespace: namespace,
      discriminator: discriminator,
    );
    final safe = hash.abs();
    return (
      fallback[safe % fallback.length],
      fallback[(safe + 3) % fallback.length],
      fallback[(safe + 5) % fallback.length],
    );
  }

  int _visualToken(
    Map<String, dynamic> source, {
    required String namespace,
    int discriminator = 0,
  }) {
    final identity =
        stringFromDynamic(source, [
          'id',
          'goalId',
          'categoryId',
          'taskId',
          'reference_id',
          'referenceId',
          'name',
          'title',
          'text',
        ]) ??
        'orbi-dynamic-card';
    final seed = '$namespace:$discriminator:$identity:$_visualSessionSalt';
    return seed.runes.fold<int>(
      17,
      (value, rune) => 0x7fffffff & ((value * 37) + rune),
    );
  }

  Color mixColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  (String, String) draftGoalStyle(String seed) {
    final palette = const [
      ('1B8A5A', 'flag'),
      ('2E7D8F', 'target'),
      ('7A5AF8', 'star'),
      ('C76B29', 'travel'),
      ('356AE6', 'wallet'),
      ('B54749', 'shield'),
      ('6F9A37', 'savings'),
      ('9D4EDD', 'gift'),
    ];
    final lowered = seed.toLowerCase();
    if (lowered.contains('travel') || lowered.contains('trip')) {
      return ('C76B29', 'travel');
    }
    if (lowered.contains('home') || lowered.contains('house')) {
      return ('356AE6', 'home');
    }
    if (lowered.contains('car') || lowered.contains('auto')) {
      return ('B54749', 'car');
    }
    if (lowered.contains('school') || lowered.contains('fees')) {
      return ('7A5AF8', 'school');
    }
    if (lowered.contains('health') || lowered.contains('medical')) {
      return ('2E7D8F', 'health');
    }
    if (lowered.contains('gift') || lowered.contains('wedding')) {
      return ('9D4EDD', 'gift');
    }
    return seedDraftStyle(seed, palette);
  }

  (String, String) draftBudgetStyle(String seed) {
    final palette = const [
      ('D97706', 'pie-chart'),
      ('0F8B8D', 'food'),
      ('8E44AD', 'school'),
      ('2B6CB0', 'home'),
      ('2F855A', 'wallet'),
      ('C05621', 'car'),
      ('B83280', 'shop'),
      ('4C51BF', 'chart'),
    ];
    final lowered = seed.toLowerCase();
    if (lowered.contains('food') || lowered.contains('grocery')) {
      return ('0F8B8D', 'food');
    }
    if (lowered.contains('rent') || lowered.contains('home')) {
      return ('2B6CB0', 'home');
    }
    if (lowered.contains('transport') || lowered.contains('fuel')) {
      return ('C05621', 'car');
    }
    if (lowered.contains('school') || lowered.contains('education')) {
      return ('8E44AD', 'school');
    }
    if (lowered.contains('shopping') || lowered.contains('shop')) {
      return ('B83280', 'shop');
    }
    return seedDraftStyle(seed, palette);
  }

  (String, String) seedDraftStyle(String seed, List<(String, String)> palette) {
    final hash = seed.runes.fold<int>(0, (value, rune) => value * 31 + rune);
    return palette[hash.abs() % palette.length];
  }

  IconData dynamicIcon(
    Map<String, dynamic> source, {
    required IconData fallback,
  }) {
    final raw = stringFromDynamic(source, [
      'icon',
      'icon_name',
      'iconName',
      'symbol',
      'glyph',
    ]);
    if (raw == null) return fallback;

    final iconRaw = raw.toLowerCase();
    if (iconRaw.contains('flag') || iconRaw.contains('goal')) {
      return Icons.flag_outlined;
    }
    if (iconRaw.contains('save') || iconRaw.contains('savings')) {
      return Icons.savings_outlined;
    }
    if (iconRaw.contains('target') || iconRaw.contains('bullseye')) {
      return Icons.gps_fixed_rounded;
    }
    if (iconRaw.contains('travel') || iconRaw.contains('flight')) {
      return Icons.flight_takeoff_rounded;
    }
    if (iconRaw.contains('home') || iconRaw.contains('house')) {
      return Icons.home_work_outlined;
    }
    if (iconRaw.contains('car') || iconRaw.contains('auto')) {
      return Icons.directions_car_filled_outlined;
    }
    if (iconRaw.contains('shop') || iconRaw.contains('cart')) {
      return Icons.shopping_bag_outlined;
    }
    if (iconRaw.contains('food') || iconRaw.contains('meal')) {
      return Icons.restaurant_outlined;
    }
    if (iconRaw.contains('health') || iconRaw.contains('medical')) {
      return Icons.health_and_safety_outlined;
    }
    if (iconRaw.contains('school') || iconRaw.contains('education')) {
      return Icons.school_outlined;
    }
    if (iconRaw.contains('gift')) {
      return Icons.card_giftcard_outlined;
    }
    if (iconRaw.contains('pie') || iconRaw.contains('budget')) {
      return Icons.pie_chart_outline_rounded;
    }
    if (iconRaw.contains('chart') || iconRaw.contains('analytics')) {
      return Icons.query_stats_rounded;
    }
    if (iconRaw.contains('wallet') || iconRaw.contains('money')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (iconRaw.contains('shield') || iconRaw.contains('protect')) {
      return Icons.shield_outlined;
    }
    if (iconRaw.contains('star')) {
      return Icons.auto_awesome_outlined;
    }
    return fallback;
  }

  double doubleFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String walletId(Map<String, dynamic> wallet) {
    return readString(wallet, ['wallet_id', 'id']);
  }

  String walletName(Map<String, dynamic> wallet) {
    return readString(wallet, [
      'name',
      'wallet_name',
      'title',
    ], fallback: 'Wallet');
  }

  String walletBalance(Map<String, dynamic> wallet) {
    final amount = doubleFrom(
      wallet['available_balance'] ??
          wallet['balance'] ??
          wallet['ledger_balance'],
    );
    final currency = readString(wallet, [
      'currency',
      'currency_code',
    ], fallback: '');
    return formatCurrencyAmount(
      amount,
      currency,
      locale: _localeTag,
      decimalDigits: 2,
    );
  }

  double availableOperatingBalance(Map<String, dynamic> wallet) {
    return doubleFrom(
      wallet['available_balance'] ??
          wallet['balance'] ??
          wallet['ledger_balance'] ??
          wallet['amount'],
    );
  }

  IconData _goalWalletIcon(Map<String, dynamic> wallet) {
    final composite =
        '${readString(wallet, ['wallet_type', 'type', 'management_tier', 'vault_role', 'role'])} ${walletName(wallet)}'
            .toLowerCase();
    if (composite.contains('bank')) return Icons.account_balance_rounded;
    if (composite.contains('card')) return Icons.credit_card_rounded;
    if (composite.contains('mobile') || composite.contains('phone')) {
      return Icons.phone_android_rounded;
    }
    if (composite.contains('goal') || composite.contains('save')) {
      return Icons.flag_circle_rounded;
    }
    return Icons.account_balance_wallet_rounded;
  }

  Widget _goalWalletChoiceCard(
    Map<String, dynamic> wallet, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  ui.accentSoft.withValues(alpha: isDark ? 0.40 : 0.20),
                  ui.cardStrong.withValues(alpha: isDark ? 0.92 : 0.95),
                ]
              : [
                  ui.card.withValues(alpha: isDark ? 0.92 : 0.97),
                  ui.cardMuted.withValues(alpha: isDark ? 0.86 : 0.92),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? ui.accent.withValues(alpha: 0.76)
              : ui.borderStrong.withValues(alpha: isDark ? 0.56 : 0.72),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (selected ? ui.accent : Colors.black).withValues(
              alpha: selected ? (isDark ? 0.14 : 0.10) : (isDark ? 0.10 : 0.04),
            ),
            blurRadius: selected ? 16 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ui.cardStrong.withValues(alpha: isDark ? 0.94 : 0.98),
                        ui.iconMuted.withValues(alpha: isDark ? 0.16 : 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ui.border.withValues(alpha: isDark ? 0.50 : 0.72),
                    ),
                  ),
                  child: Icon(
                    _goalWalletIcon(wallet),
                    size: 20,
                    color: selected ? ui.accent : ui.iconMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walletName(wallet),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        walletBalance(wallet),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? ui.accent
                        : ui.cardStrong.withValues(alpha: isDark ? 0.88 : 0.96),
                    border: Border.all(
                      color: selected
                          ? ui.accent
                          : ui.border.withValues(alpha: isDark ? 0.5 : 0.7),
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: selected ? Colors.white : ui.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isOperatingWallet(Map<String, dynamic> wallet) {
    final type = readString(wallet, [
      'wallet_type',
      'type',
      'management_tier',
      'vault_role',
      'role',
    ]).toLowerCase();
    final name = walletName(wallet).toLowerCase();
    final status = readString(wallet, ['status', 'state']).toLowerCase();
    final isPrimary =
        wallet['is_primary'] == true || wallet['isPrimary'] == true;
    if (status.contains('lock') ||
        status.contains('freeze') ||
        status.contains('block') ||
        status.contains('suspend')) {
      return false;
    }
    if (name.contains('paysafe') || type.contains('internal_transfer')) {
      return false;
    }
    return isPrimary ||
        type.contains('operating') ||
        type.contains('internal_main') ||
        type.contains('internal') ||
        type.contains('vault') ||
        type.contains('sovereign') ||
        name.contains('operating') ||
        name.contains('main default') ||
        name.contains('internal vault') ||
        name.contains('dilpesa');
  }

  double expectedBudgetUsage(Map<String, dynamic> category, double budget) {
    if (budget <= 0) return 0;
    final now = DateTime.now();
    final anchor = DateTime.tryParse(
      readString(category, [
        'period_start',
        'periodStart',
        'window_start',
        'windowStart',
        'start_date',
        'startDate',
        'created_at',
        'createdAt',
      ]),
    );
    final normalizedPeriod = normalizeBudgetPeriod(
      readString(category, ['period', 'budget_period', 'window']),
    );
    final interval = budgetInterval(category);
    final cycleStart = currentBudgetCycleStart(
      now: now,
      anchor: anchor,
      period: normalizedPeriod,
      interval: interval,
    );
    final cycleEnd = addBudgetPeriod(cycleStart, normalizedPeriod, interval);
    final totalMs = cycleEnd.difference(cycleStart).inMilliseconds;
    if (totalMs <= 0) return 0;
    final elapsedMs = now
        .difference(cycleStart)
        .inMilliseconds
        .clamp(0, totalMs);
    final progress = elapsedMs / totalMs;
    return budget * progress.clamp(0.0, 1.0);
  }

  StatusBadgeData? _budgetUsageStatusBadge({
    required double used,
    required double expected,
    required double budget,
  }) {
    final ui = OrbiTheme.uiOf(context);
    if (budget <= 0) {
      return StatusBadgeData(
        label: _isSwahili ? 'Hakuna kikomo' : 'No limit set',
        icon: Icons.remove_circle_outline_rounded,
        accent: ui.textMuted,
      );
    }

    if (used <= 0 && expected <= 0) {
      return StatusBadgeData(
        label: _isSwahili ? 'Imeanza sasa' : 'Just started',
        icon: Icons.hourglass_bottom_rounded,
        accent: ui.accent,
      );
    }

    if (used > budget) {
      return StatusBadgeData(
        label: _isSwahili ? 'Umezidi bajeti' : 'Over budget',
        icon: Icons.error_outline_rounded,
        accent: ui.danger,
      );
    }

    if (expected <= 0) {
      return StatusBadgeData(
        label: _isSwahili ? 'Matumizi yameanza' : 'Spending started',
        icon: Icons.play_arrow_rounded,
        accent: ui.accent,
      );
    }

    final ratio = used / expected;
    if (ratio >= 1.1) {
      return StatusBadgeData(
        label: _isSwahili ? 'Juu ya tarajiwa' : 'Over expected',
        icon: Icons.warning_amber_rounded,
        accent: ui.danger,
      );
    }
    if (ratio <= 0.9) {
      return StatusBadgeData(
        label: _isSwahili ? 'Chini ya tarajiwa' : 'Under expected',
        icon: Icons.trending_down_rounded,
        accent: ui.success,
      );
    }
    return StatusBadgeData(
      label: _isSwahili ? 'Inaendana na mpango' : 'On track',
      icon: Icons.track_changes_rounded,
      accent: ui.warning,
    );
  }

  DateTime currentBudgetCycleStart({
    required DateTime now,
    required DateTime? anchor,
    required String period,
    required int interval,
  }) {
    final safeInterval = interval <= 0 ? 1 : interval;
    final normalizedAnchor = anchor ?? defaultBudgetAnchor(now, period);
    if (normalizedAnchor.isAfter(now)) {
      return normalizedAnchor;
    }
    var start = normalizedAnchor;
    while (true) {
      final next = addBudgetPeriod(start, period, safeInterval);
      if (next.isAfter(now)) return start;
      start = next;
    }
  }

  DateTime defaultBudgetAnchor(DateTime now, String period) {
    switch (period) {
      case 'day':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        final daysFromMonday = now.weekday - DateTime.monday;
        final start = now.subtract(Duration(days: daysFromMonday));
        return DateTime(start.year, start.month, start.day);
      case 'year':
        return DateTime(now.year);
      case 'month':
      default:
        return DateTime(now.year, now.month);
    }
  }

  DateTime addBudgetPeriod(DateTime date, String period, int interval) {
    final safeInterval = interval <= 0 ? 1 : interval;
    switch (period) {
      case 'day':
        return date.add(Duration(days: safeInterval));
      case 'week':
        return date.add(Duration(days: 7 * safeInterval));
      case 'year':
        return DateTime(date.year + safeInterval, date.month, date.day);
      case 'month':
      default:
        return DateTime(date.year, date.month + safeInterval, date.day);
    }
  }
}
