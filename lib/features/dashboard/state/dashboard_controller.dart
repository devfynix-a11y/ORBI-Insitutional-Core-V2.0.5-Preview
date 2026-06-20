import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/device_fingerprint.dart';
import '../../../core/utils/user_facing_error.dart';
import '../data/dashboard_home_service.dart';
import '../data/financial_insights.dart';
import '../data/insights_service.dart';
import '../models/dashboard_models.dart';

class DashboardController extends ChangeNotifier {
  DashboardController();

  final InsightsService _insightsService = InsightsService();
  final DashboardHomeService _homeService = DashboardHomeService();
  final String _fingerprint = DeviceFingerprint.generate();

  final String baseUrl = AppConfig.baseUrl;

  double _netWorth = 0.0;
  double _changePercent = 0.0;
  double _allocatedAmount = 0.0;
  double _unallocatedAmount = 0.0;
  double _budgetedAmount = 0.0;
  double _savedAmount = 0.0;
  double _lockedAmount = 0.0;
  double _spentAmount = 0.0;
  double _assets = 0.0;
  double _liabilities = 0.0;
  bool _liabilitiesBackedByApi = false;
  double? _linkedWalletsTotalFromApi;
  double? _internalVaultTotalFromApi;
  List<PortfolioItem> _portfolioItems = const <PortfolioItem>[];
  List<PortfolioItem> _linkedWallets = const <PortfolioItem>[];
  List<PortfolioItem> _sovereignWallets = const <PortfolioItem>[];
  List<Map<String, dynamic>> _sovereignWalletRecords =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _goals = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _budgets = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _sharedPots = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _sharedBudgets = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _billReserves = const <Map<String, dynamic>>[];
  List<TransactionActivity> _transactions = const <TransactionActivity>[];
  FinancialInsights _insights = const FinancialInsights.empty();
  DashboardHomeSnapshot _homeSnapshot = const DashboardHomeSnapshot.empty();
  List<String> _messages = const <String>[];
  bool _isLoading = true;
  String? _error;
  String _currencyCode = '';
  DateTime? _lastUpdatedAt;

  double get netWorth => _netWorth;
  double get changePercent => _changePercent;
  double get allocatedAmount => _allocatedAmount;
  double get unallocatedAmount => _unallocatedAmount;
  double get budgetedAmount => _budgetedAmount;
  double get savedAmount => _savedAmount;
  double get lockedAmount => _lockedAmount;
  double get spentAmount => _spentAmount;
  List<PortfolioItem> get portfolioItems => _portfolioItems;
  List<PortfolioItem> get linkedWallets => _linkedWallets;
  List<PortfolioItem> get sovereignWallets => _sovereignWallets;
  List<Map<String, dynamic>> get sovereignWalletRecords =>
      _sovereignWalletRecords;
  double get _computedLinkedBalance =>
      _linkedWallets.fold<double>(0, (sum, item) => sum + item.value);
  double get _computedInternalVaultBalance =>
      _sovereignWallets.fold<double>(0, (sum, item) => sum + item.value);
  double get totalLinkedBalance => _linkedWallets.isNotEmpty
      ? _computedLinkedBalance
      : (_linkedWalletsTotalFromApi ?? 0.0);
  double get totalInternalVaultBalance => _sovereignWallets.isNotEmpty
      ? _computedInternalVaultBalance
      : (_internalVaultTotalFromApi ?? 0.0);
  FinancialInsights get insights => _insights;
  DashboardHomeSnapshot get homeSnapshot => _homeSnapshot;
  List<TransactionActivity> get transactions => _transactions;
  List<Map<String, dynamic>> get goals => _goals;
  List<Map<String, dynamic>> get budgets => _budgets;
  List<Map<String, dynamic>> get sharedPots => _sharedPots;
  List<Map<String, dynamic>> get sharedBudgets => _sharedBudgets;
  List<Map<String, dynamic>> get billReserves => _billReserves;
  List<String> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currencyCode => _currencyCode;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get hasData => _homeSnapshot.hasData;

  Map<String, String> _headers(String token) {
    return OrbiRequestHeaders.build(
      token: token,
      fingerprint: _fingerprint,
      trace: const Uuid().v4(),
    );
  }

  Future<void> fetchDashboardData(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _fetchDashboardPayload(token);
      final rawTransactions = _extractListFromPayload(
        data['transactions'],
        const ['transactions', 'items', 'results', 'rows', 'history'],
      );
      final dashboardWallets = _extractListFromPayload(data['wallets'], const [
        'wallets',
        'items',
        'results',
      ]);
      final wallets = await _fetchWallets(token, dashboardWallets);

      _applyWallets(wallets);

      _goals = _extractListFromPayload(
        data['financialGoals'] ?? data['goals'],
        const ['financialGoals', 'goals', 'items', 'results'],
      );
      _budgets = _extractListFromPayload(
        data['categories'] ?? data['budgets'],
        const ['categories', 'budgets', 'items', 'results'],
      );

      _allocateGoalAndBudgetBalances();

      final supplementResults = await Future.wait<dynamic>([
        _homeService.fetchSharedPots(token),
        _homeService.fetchSharedBudgets(token),
        _homeService.fetchUpcomingBills(token),
        rawTransactions.isNotEmpty
            ? Future<List<Map<String, dynamic>>>.value(rawTransactions)
            : _homeService.fetchRecentTransactions(token),
        _homeService.fetchMerchantRecommendations(token),
        _homeService.fetchNetWorthSummary(token),
      ]);

      _sharedPots = List<Map<String, dynamic>>.from(
        supplementResults[0] as List,
      );
      _sharedBudgets = List<Map<String, dynamic>>.from(
        supplementResults[1] as List,
      );
      _billReserves = List<Map<String, dynamic>>.from(
        supplementResults[2] as List,
      );
      _transactions =
          List<Map<String, dynamic>>.from(
              supplementResults[3] as List,
            ).map((item) => TransactionActivity.fromJson(item)).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final merchantRecommendations = List<Map<String, dynamic>>.from(
        supplementResults[4] as List,
      );
      final netWorthSummary = Map<String, dynamic>.from(
        supplementResults[5] as Map,
      );

      _insights = await _insightsService.fetch(token);
      _changePercent =
          _firstNonNullDouble([
            netWorthSummary['monthly_change_percent'],
            netWorthSummary['monthlyChangePercent'],
          ]) ??
          _resolveMonthlyPerformancePercent(
            data,
            List<Map<String, dynamic>>.from(supplementResults[3] as List),
          );
      _messages = _extractMessages(data);
      _currencyCode = _resolveCurrencyCode(data, wallets);
      _liabilitiesBackedByApi =
          netWorthSummary.containsKey('liabilities') ||
          netWorthSummary.containsKey('liabilities_source');
      _liabilities =
          _firstNonNullDouble([
            netWorthSummary['liabilities'],
            data['liabilities'],
            data['total_liabilities'],
            data['totalLiabilities'],
            data['debt'],
            data['total_debt'],
            (data['summary'] is Map ? data['summary']['liabilities'] : null),
            (data['summary'] is Map
                ? data['summary']['total_liabilities']
                : null),
            (data['balances'] is Map ? data['balances']['liabilities'] : null),
          ]) ??
          0.0;
      _assets =
          _firstNonNullDouble([
            netWorthSummary['assets'],
            data['assets'],
            data['total_assets'],
            data['totalAssets'],
            (data['summary'] is Map ? data['summary']['assets'] : null),
            (data['summary'] is Map ? data['summary']['total_assets'] : null),
          ]) ??
          wallets.fold<double>(0, (sum, wallet) {
            final balance = _toDouble(
              wallet['balance'] ??
                  wallet['available_balance'] ??
                  wallet['wallet_balance'] ??
                  wallet['current_balance'],
            );
            return sum + math.max(0, balance);
          });
      _netWorth =
          _firstNonNullDouble([
            netWorthSummary['net_worth'],
            netWorthSummary['netWorth'],
            data['net_worth'],
            data['netWorth'],
            (data['summary'] is Map ? data['summary']['net_worth'] : null),
            (data['summary'] is Map ? data['summary']['netWorth'] : null),
          ]) ??
          (_assets - _liabilities);
      _lastUpdatedAt = DateTime.now();
      _homeSnapshot = _buildHomeSnapshot(
        data: data,
        merchantRecommendations: merchantRecommendations,
      );
    } catch (error) {
      _error = UserFacingError.from(
        error,
        fallback: 'Unable to load dashboard data right now. Please try again.',
      );
      if (!_homeSnapshot.hasData) {
        _homeSnapshot = const DashboardHomeSnapshot.empty();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _fetchDashboardPayload(String token) async {
    final endpoints = [
      Uri.parse('$baseUrl/api/v1/dashboard'),
      Uri.parse('$baseUrl/api/v1/user/dashboard'),
      Uri.parse('$baseUrl/v1/dashboard'),
    ];
    final failures = <String>[];
    for (final endpoint in endpoints) {
      try {
        final response = await http.get(endpoint, headers: _headers(token));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body);
          final data = body is Map<String, dynamic>
              ? body['data'] ?? body
              : body;
          if (data is Map) {
            return _normalizeMap(Map<dynamic, dynamic>.from(data));
          }
        } else {
          failures.add('${endpoint.path}: ${response.statusCode}');
        }
      } catch (error) {
        failures.add('${endpoint.path}: $error');
      }
    }
    throw Exception(
      failures.isEmpty
          ? 'No dashboard endpoint responded.'
          : 'Dashboard endpoints failed. ${failures.join(' | ')}',
    );
  }

  void _applyWallets(List<Map<String, dynamic>> wallets) {
    final items = <PortfolioItem>[];
    final linked = <PortfolioItem>[];
    final sovereign = <PortfolioItem>[];

    for (final wallet in wallets) {
      final tier =
          (wallet['management_tier'] ??
                  wallet['managementTier'] ??
                  wallet['tier'] ??
                  wallet['wallet_type'] ??
                  wallet['walletType'] ??
                  wallet['type'] ??
                  '')
              .toString();
      final balance = _toDouble(
        wallet['balance'] ??
            wallet['available_balance'] ??
            wallet['wallet_balance'] ??
            wallet['current_balance'] ??
            wallet['ledger_balance'] ??
            wallet['actualBalance'] ??
            wallet['actual_balance'],
      );
      final item = PortfolioItem(
        title: (wallet['name'] ?? wallet['alias'] ?? 'Wallet').toString(),
        value: balance,
        icon: _iconForTier(tier),
        color: _colorForTier(tier),
        tier: tier,
        rawData: wallet,
      );
      items.add(item);
      if (_isLinkedWallet(wallet)) linked.add(item);
      if (_isInternalWallet(wallet)) sovereign.add(item);
    }

    _portfolioItems = items.take(8).toList();
    _linkedWallets = linked;
    _sovereignWallets = sovereign;
    _sovereignWalletRecords = sovereign.map((item) => item.rawData).toList();

    final aggregates = wallets.fold<_WalletAggregate>(
      const _WalletAggregate.zero(),
      (state, wallet) {
        final balance = _toDouble(
          wallet['balance'] ??
              wallet['available_balance'] ??
              wallet['wallet_balance'] ??
              wallet['current_balance'] ??
              wallet['ledger_balance'],
        );
        return _WalletAggregate(
          spendable:
              state.spendable +
              (_isInternalWallet(wallet) ? math.max(0, balance) : 0),
          protected:
              state.protected +
              (_looksProtected(wallet) ? math.max(0, balance) : 0),
          total: state.total + math.max(0, balance),
        );
      },
    );

    _linkedWalletsTotalFromApi = linked.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );
    _internalVaultTotalFromApi = sovereign.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );
    _unallocatedAmount = aggregates.spendable;
    _savedAmount = aggregates.protected;
    _lockedAmount = aggregates.protected;
  }

  void _allocateGoalAndBudgetBalances() {
    final allocatedToGoals = _goals.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['current'] ?? item['saved_amount']),
    );
    final allocatedToBudgets = _budgets.fold<double>(
      0,
      (sum, item) =>
          sum +
          _toDouble(item['budget'] ?? item['budget_limit'] ?? item['limit']),
    );
    final spentFromBudgets = _budgets.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['spent'] ?? item['spent_amount']),
    );

    _allocatedAmount = allocatedToGoals + allocatedToBudgets;
    _budgetedAmount = allocatedToBudgets;
    _savedAmount = math.max(_savedAmount, allocatedToGoals);
    _lockedAmount = math.max(_lockedAmount, allocatedToGoals);
    _spentAmount = spentFromBudgets;
  }

  DashboardHomeSnapshot _buildHomeSnapshot({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> merchantRecommendations,
  }) {
    final health = _buildFinancialHealthSnapshot(data);
    final changeAmount =
        _firstNonNullDouble([
          data['monthly_change_amount'],
          data['monthlyChangeAmount'],
          (data['summary'] is Map
              ? data['summary']['monthly_change_amount']
              : null),
          (data['summary'] is Map
              ? data['summary']['monthlyChangeAmount']
              : null),
        ]) ??
        (_netWorth * (_changePercent / 100));
    final netWorth = NetWorthSnapshot(
      assets: _assets,
      liabilities: _liabilities,
      netWorth: _netWorth,
      monthlyChangePercent: _changePercent,
      monthlyChangeAmount: changeAmount,
      liabilitiesBackedByApi: _liabilitiesBackedByApi,
    );
    final deviceSecurity = _buildDeviceSecuritySnapshot(data);
    final carousel = _buildCarouselCards(
      merchantRecommendations: merchantRecommendations,
    );
    final aiFeed = _buildAiFeed(deviceSecurity);
    final journey = _buildJourneySnapshot();
    final recentActivity = _transactions
        .take(8)
        .map(_toRecentActivityItem)
        .toList();

    return DashboardHomeSnapshot(
      financialHealth: health,
      netWorth: netWorth,
      carouselCards: carousel,
      aiFeed: aiFeed,
      journey: journey,
      recentActivity: recentActivity,
      online: _error == null,
      deviceSecurity: deviceSecurity,
      lastUpdatedAt: _lastUpdatedAt ?? DateTime.now(),
    );
  }

  FinancialHealthSnapshot _buildFinancialHealthSnapshot(
    Map<String, dynamic> data,
  ) {
    final budgetBase = _budgetedAmount <= 0 ? 1.0 : _budgetedAmount;
    final budgetDiscipline = ((_budgetedAmount - _spentAmount) / budgetBase)
        .clamp(0.0, 1.0);
    final totalGoalTarget = _goals.fold<double>(
      0,
      (sum, item) =>
          sum +
          _toDouble(
            item['target'] ?? item['target_amount'] ?? item['goal_amount'],
          ),
    );
    final totalGoalCurrent = _goals.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['current'] ?? item['saved_amount']),
    );
    final goalProgress = totalGoalTarget <= 0
        ? (_savedAmount > 0 ? 0.62 : 0.0)
        : (totalGoalCurrent / totalGoalTarget).clamp(0.0, 1.0);
    final savingsDenominator = math.max(_assets, _netWorth.abs());
    final savingsProgress = savingsDenominator <= 0
        ? (_savedAmount > 0 ? 0.58 : 0.0)
        : (_savedAmount / savingsDenominator).clamp(0.0, 1.0);
    final securityRaw = _firstNonNullDouble([
      data['security_score'],
      data['securityScore'],
      (data['security'] is Map ? data['security']['score'] : null),
      (data['device'] is Map ? data['device']['security_score'] : null),
    ]);
    final securityStatus =
        ((securityRaw ??
                    (_buildDeviceSecuritySnapshot(data).isSecure ? 92 : 60)) /
                100)
            .clamp(0.0, 1.0);
    final score =
        ((budgetDiscipline * 0.30) +
            (savingsProgress * 0.20) +
            (goalProgress * 0.25) +
            (securityStatus * 0.25)) *
        100;
    final rounded = score.round().clamp(0, 100);
    final status = rounded >= 85
        ? FinancialHealthStatus.excellent
        : rounded >= 70
        ? FinancialHealthStatus.good
        : FinancialHealthStatus.needsAttention;

    return FinancialHealthSnapshot(
      score: rounded,
      status: status,
      budgetDiscipline: (budgetDiscipline * 100).round(),
      savingsProgress: (savingsProgress * 100).round(),
      goalProgress: (goalProgress * 100).round(),
      securityStatus: (securityStatus * 100).round(),
    );
  }

  DeviceSecuritySnapshot _buildDeviceSecuritySnapshot(
    Map<String, dynamic> data,
  ) {
    final security = data['security'] is Map
        ? _normalizeMap(Map<dynamic, dynamic>.from(data['security'] as Map))
        : const <String, dynamic>{};
    final device = data['device'] is Map
        ? _normalizeMap(Map<dynamic, dynamic>.from(data['device'] as Map))
        : const <String, dynamic>{};
    final label = _firstNonEmpty([
      security['status_label']?.toString(),
      security['status']?.toString(),
      device['badge']?.toString(),
      device['status']?.toString(),
    ]);
    final detail = _firstNonEmpty([
      security['detail']?.toString(),
      security['message']?.toString(),
      device['detail']?.toString(),
    ]);
    final secureValue = _firstNonEmpty([
      security['risk']?.toString(),
      security['level']?.toString(),
      device['risk']?.toString(),
    ]).toLowerCase();
    final isSecure =
        !(secureValue.contains('high') ||
            secureValue.contains('warning') ||
            secureValue.contains('risk'));
    return DeviceSecuritySnapshot(
      label: label.isEmpty ? (isSecure ? 'Protected' : 'Review Needed') : label,
      detail: detail.isEmpty
          ? (isSecure ? 'Trusted device' : 'Check device safety')
          : detail,
      isSecure: isSecure,
    );
  }

  List<SmartCarouselCardData> _buildCarouselCards({
    required List<Map<String, dynamic>> merchantRecommendations,
  }) {
    final cards = <SmartCarouselCardData>[];

    final topGoal = _goals.isEmpty ? null : _goals.first;
    if (topGoal != null) {
      final current = _toDouble(topGoal['current'] ?? topGoal['saved_amount']);
      final target = _toDouble(
        topGoal['target'] ?? topGoal['target_amount'] ?? topGoal['goal_amount'],
      );
      final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
      cards.add(
        SmartCarouselCardData(
          type: SmartCarouselCardType.goalProgress,
          title: 'Goal Progress',
          headline: (topGoal['name'] ?? 'Savings goal').toString(),
          supportingText: '${(progress * 100).round()}% funded',
          amountLabel: current > 0 ? current.toStringAsFixed(0) : '',
          statusLabel: 'On track',
          progress: progress,
          icon: Icons.flag_rounded,
        ),
      );
    }

    final topBudget = _budgets.isEmpty ? null : _budgets.first;
    if (topBudget != null) {
      final spent = _toDouble(topBudget['spent'] ?? topBudget['spent_amount']);
      final limit = _toDouble(
        topBudget['budget'] ?? topBudget['budget_limit'] ?? topBudget['limit'],
      );
      final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
      cards.add(
        SmartCarouselCardData(
          type: SmartCarouselCardType.budgetStatus,
          title: 'Budget Status',
          headline: (topBudget['name'] ?? topBudget['category'] ?? 'Budget')
              .toString(),
          supportingText: '${(progress * 100).round()}% used',
          amountLabel: limit > 0 ? limit.toStringAsFixed(0) : '',
          statusLabel: progress >= 0.9 ? 'At risk' : 'Healthy',
          progress: progress,
          icon: Icons.pie_chart_rounded,
        ),
      );
    }

    final upcomingBill = _billReserves.isEmpty ? null : _billReserves.first;
    if (upcomingBill != null) {
      final dueText = _firstNonEmpty([
        upcomingBill['due_at']?.toString(),
        upcomingBill['due_date']?.toString(),
        upcomingBill['dueDate']?.toString(),
        upcomingBill['next_due']?.toString(),
        'Upcoming',
      ]);
      cards.add(
        SmartCarouselCardData(
          type: SmartCarouselCardType.upcomingBill,
          title: 'Upcoming Bill',
          headline:
              (upcomingBill['name'] ??
                      upcomingBill['title'] ??
                      upcomingBill['provider'] ??
                      upcomingBill['bill_type'] ??
                      'Bill reserve')
                  .toString(),
          supportingText: dueText,
          amountLabel: _toDouble(
            upcomingBill['amount'] ??
                upcomingBill['locked_balance'] ??
                upcomingBill['target_amount'] ??
                upcomingBill['reserved_amount'],
          ).toStringAsFixed(0),
          statusLabel: 'Watch',
          progress: 0.55,
          icon: Icons.receipt_long_rounded,
        ),
      );
    }

    final sharedPot = _sharedPots.isEmpty ? null : _sharedPots.first;
    if (sharedPot != null) {
      final current = _toDouble(
        sharedPot['current_amount'] ??
            sharedPot['balance'] ??
            sharedPot['amount'],
      );
      final target = _toDouble(
        sharedPot['target_amount'] ??
            sharedPot['goal_amount'] ??
            sharedPot['limit'],
      );
      cards.add(
        SmartCarouselCardData(
          type: SmartCarouselCardType.sharedPot,
          title: 'Shared Pot',
          headline: (sharedPot['name'] ?? 'Shared pot').toString(),
          supportingText: target > 0
              ? '${((current / target).clamp(0.0, 1.0) * 100).round()}% funded'
              : 'Active balance',
          amountLabel: current.toStringAsFixed(0),
          statusLabel: 'Collaborative',
          progress: target <= 0 ? 0.45 : (current / target).clamp(0.0, 1.0),
          icon: Icons.groups_rounded,
        ),
      );
    }

    final pendingTransactions = _transactions
        .where(
          (item) =>
              item.status.toLowerCase().contains('pending') ||
              item.status.toLowerCase().contains('failed'),
        )
        .toList();
    if (pendingTransactions.isNotEmpty) {
      final item = pendingTransactions.first;
      cards.add(
        SmartCarouselCardData(
          type: SmartCarouselCardType.offlineTransaction,
          title: 'Offline Transaction Status',
          headline: item.title,
          supportingText: item.status,
          amountLabel: item.amount.toStringAsFixed(0),
          statusLabel: item.status,
          progress: item.status.toLowerCase().contains('pending') ? 0.6 : 0.2,
          icon: Icons.sync_problem_rounded,
        ),
      );
    }

    final merchant = merchantRecommendations.isNotEmpty
        ? merchantRecommendations.first
        : null;
    cards.add(
      SmartCarouselCardData(
        type: SmartCarouselCardType.merchantRecommendation,
        title: 'Merchant Recommendation',
        headline:
            (merchant?['name'] ??
                    merchant?['merchant_name'] ??
                    'Trusted merchants')
                .toString(),
        supportingText: merchant == null
            ? 'No personalized recommendation is ready yet.'
            : (merchant['category'] ?? merchant['reason'] ?? 'Recommended now')
                  .toString(),
        amountLabel: '',
        statusLabel: 'Discover',
        progress: 0.5,
        icon: Icons.storefront_rounded,
      ),
    );

    return cards.take(6).toList();
  }

  List<GuardianInsightData> _buildAiFeed(
    DeviceSecuritySnapshot deviceSecurity,
  ) {
    final feed = <GuardianInsightData>[];
    final seen = <String>{};

    void addInsight(GuardianInsightData insight) {
      final normalizedMessage = insight.message.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final semanticKey = '${insight.type.name}:$normalizedMessage';
      if (normalizedMessage.isEmpty || !seen.add(semanticKey)) return;
      feed.add(insight);
    }

    for (final item in _insights.spendingAlerts.take(2)) {
      addInsight(
        GuardianInsightData(
          type: GuardianInsightType.spendingAlert,
          title: 'Guardian AI',
          message: item,
          severityLabel: 'Spending alert',
        ),
      );
    }
    for (final item in _insights.budgetSuggestions.take(2)) {
      addInsight(
        GuardianInsightData(
          type: GuardianInsightType.savingSuggestion,
          title: 'Guardian AI',
          message: item,
          severityLabel: 'Saving suggestion',
        ),
      );
    }
    for (final item in _insights.financialAdvice.take(2)) {
      addInsight(
        GuardianInsightData(
          type: GuardianInsightType.goalPrediction,
          title: 'Guardian AI',
          message: item,
          severityLabel: 'Goal prediction',
        ),
      );
    }

    if (_insights.isEmpty) {
      if (_spentAmount > _budgetedAmount && _budgetedAmount > 0) {
        addInsight(
          GuardianInsightData(
            type: GuardianInsightType.budgetWarning,
            title: 'Guardian AI',
            message:
                'Spending is running ahead of your active budgets. Tighten one category this week.',
            severityLabel: 'Budget warning',
          ),
        );
      }
      if (_savedAmount > 0 && _goals.isNotEmpty) {
        addInsight(
          GuardianInsightData(
            type: GuardianInsightType.goalPrediction,
            title: 'Guardian AI',
            message:
                'Your strongest goal is gaining momentum. Keep the same weekly saving pace.',
            severityLabel: 'Goal prediction',
          ),
        );
      }
      if (_savedAmount <= 0 && _unallocatedAmount > 0) {
        addInsight(
          GuardianInsightData(
            type: GuardianInsightType.savingSuggestion,
            title: 'Guardian AI',
            message:
                'You can redirect part of available cash into savings without slowing everyday spending.',
            severityLabel: 'Saving suggestion',
          ),
        );
      }
    }

    if (!deviceSecurity.isSecure) {
      addInsight(
        GuardianInsightData(
          type: GuardianInsightType.securityWarning,
          title: 'Guardian AI',
          message: deviceSecurity.detail,
          severityLabel: 'Security warning',
        ),
      );
    }

    feed.sort((a, b) {
      int priority(GuardianInsightType type) {
        return switch (type) {
          GuardianInsightType.securityWarning => 0,
          GuardianInsightType.spendingAlert => 1,
          GuardianInsightType.budgetWarning => 2,
          GuardianInsightType.savingSuggestion => 3,
          GuardianInsightType.goalPrediction => 4,
        };
      }

      return priority(a.type).compareTo(priority(b.type));
    });
    return feed.take(3).toList();
  }

  FinancialJourneySnapshot _buildJourneySnapshot() {
    return FinancialJourneySnapshot(
      activeGoals: _goals.length,
      activeBudgets: _budgets.length,
      sharedPots: _sharedPots.length,
      upcomingCommitments: _billReserves.length,
      goalItems: _goals.take(3).map((goal) {
        final current = _toDouble(goal['current'] ?? goal['saved_amount']);
        final target = _toDouble(
          goal['target'] ?? goal['target_amount'] ?? goal['goal_amount'],
        );
        return JourneyItem(
          title: (goal['name'] ?? 'Goal').toString(),
          detail: target > 0
              ? '${((current / target).clamp(0.0, 1.0) * 100).round()}% funded'
              : 'Active',
          progress: target <= 0 ? 0.35 : (current / target).clamp(0.0, 1.0),
        );
      }).toList(),
      budgetItems: _budgets.take(3).map((budget) {
        final spent = _toDouble(budget['spent'] ?? budget['spent_amount']);
        final limit = _toDouble(
          budget['budget'] ?? budget['budget_limit'] ?? budget['limit'],
        );
        return JourneyItem(
          title: (budget['name'] ?? budget['category'] ?? 'Budget').toString(),
          detail: limit > 0
              ? '${((spent / limit).clamp(0.0, 1.0) * 100).round()}% used'
              : 'Active',
          progress: limit <= 0 ? 0.4 : (spent / limit).clamp(0.0, 1.0),
        );
      }).toList(),
      potItems: _sharedPots.take(3).map((pot) {
        final amount = _toDouble(
          pot['current_amount'] ?? pot['balance'] ?? pot['amount'],
        );
        final target = _toDouble(
          pot['target_amount'] ?? pot['goal_amount'] ?? pot['limit'],
        );
        return JourneyItem(
          title: (pot['name'] ?? 'Shared pot').toString(),
          detail: amount > 0 ? 'Balance in motion' : 'Ready to fund',
          progress: target <= 0 ? 0.45 : (amount / target).clamp(0.0, 1.0),
        );
      }).toList(),
      commitmentItems: _billReserves.take(3).map((reserve) {
        return JourneyItem(
          title:
              (reserve['name'] ??
                      reserve['title'] ??
                      reserve['provider'] ??
                      reserve['bill_type'] ??
                      'Commitment')
                  .toString(),
          detail: _firstNonEmpty([
            reserve['due_at']?.toString(),
            reserve['due_date']?.toString(),
            reserve['dueDate']?.toString(),
            reserve['next_due']?.toString(),
            'Upcoming',
          ]),
          progress: 0.5,
        );
      }).toList(),
    );
  }

  RecentActivityItem _toRecentActivityItem(TransactionActivity activity) {
    return RecentActivityItem(
      title: activity.title,
      amount: activity.amount,
      isCredit: activity.isCredit,
      status: activity.status,
      time: activity.timestamp,
      provider: activity.provider,
      channel: activity.channel,
      icon: activity.icon,
    );
  }

  List<String> _extractMessages(Map<String, dynamic> data) {
    final raw = data['messages'];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => (item['title'] ?? item['message'] ?? '').toString().trim(),
        )
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _resolveCurrencyCode(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> wallets,
  ) {
    final profile = data['userProfile'] is Map
        ? _normalizeMap(Map<dynamic, dynamic>.from(data['userProfile'] as Map))
        : data['user'] is Map
        ? _normalizeMap(Map<dynamic, dynamic>.from(data['user'] as Map))
        : const <String, dynamic>{};
    final profileCurrency = _firstNonEmpty([
      profile['currency']?.toString(),
      profile['currency_code']?.toString(),
      profile['preferred_currency']?.toString(),
    ]);
    if (profileCurrency.isNotEmpty) return profileCurrency.toUpperCase();
    for (final wallet in wallets) {
      final currency = (wallet['currency'] ?? '').toString().trim();
      if (currency.isNotEmpty) return currency.toUpperCase();
    }
    return '';
  }

  double _resolveMonthlyPerformancePercent(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> rawTransactions,
  ) {
    final directPercent = _firstNonNullDouble([
      data['month_over_month_percent'],
      data['monthOverMonthPercent'],
      data['monthly_change_percent'],
      data['monthlyChangePercent'],
      data['net_worth_change_percent'],
      data['netWorthChangePercent'],
      (data['summary'] is Map
          ? data['summary']['month_over_month_percent']
          : null),
      (data['summary'] is Map
          ? data['summary']['monthly_change_percent']
          : null),
    ]);
    if (directPercent != null) {
      return directPercent;
    }

    final activities = rawTransactions
        .map((item) => TransactionActivity.fromJson(item))
        .toList();
    if (activities.isEmpty) return 0;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final previousMonthStart = DateTime(now.year, now.month - 1);

    double currentMonthNet = 0;
    double previousMonthNet = 0;
    for (final transaction in activities) {
      final signed = transaction.isCredit
          ? transaction.amount
          : -transaction.amount;
      if (!transaction.timestamp.isBefore(currentMonthStart) &&
          transaction.timestamp.isBefore(nextMonthStart)) {
        currentMonthNet += signed;
      } else if (!transaction.timestamp.isBefore(previousMonthStart) &&
          transaction.timestamp.isBefore(currentMonthStart)) {
        previousMonthNet += signed;
      }
    }

    if (previousMonthNet.abs() > 0.009) {
      return ((currentMonthNet - previousMonthNet) / previousMonthNet.abs()) *
          100;
    }
    if (_netWorth.abs() > 0.009) {
      return (currentMonthNet / _netWorth) * 100;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> _fetchWallets(
    String token,
    List<Map<String, dynamic>> fallback,
  ) async {
    final endpoints = [
      Uri.parse('$baseUrl/api/v1/wallets'),
      Uri.parse('$baseUrl/v1/wallets'),
    ];
    for (final endpoint in endpoints) {
      try {
        final response = await http.get(endpoint, headers: _headers(token));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final body = jsonDecode(response.body);
        final wallets = _extractListFromPayload(body, const [
          'wallets',
          'items',
          'results',
          'accounts',
          'linked_wallets',
          'sovereign_wallets',
        ]);
        if (wallets.isNotEmpty) return wallets;
      } catch (_) {
        continue;
      }
    }
    return fallback;
  }

  List<Map<String, dynamic>> _extractListFromPayload(
    dynamic payload,
    List<String> candidateKeys,
  ) {
    if (payload is List) {
      return payload.whereType<Map>().map(_normalizeMap).toList();
    }
    if (payload is Map && payload['data'] != null) {
      return _extractListFromPayload(payload['data'], candidateKeys);
    }
    if (payload is! Map) return const <Map<String, dynamic>>[];
    final mapNode = _normalizeMap(Map<dynamic, dynamic>.from(payload));
    for (final key in candidateKeys) {
      final value = mapNode[key];
      if (value is List) {
        return value.whereType<Map>().map(_normalizeMap).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  bool _looksProtected(Map<String, dynamic> wallet) {
    final descriptor = _walletDescriptor(wallet);
    return descriptor.contains('goal') ||
        descriptor.contains('saving') ||
        descriptor.contains('lock') ||
        descriptor.contains('reserve') ||
        descriptor.contains('protected');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  double? _tryToDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim());
    }
    return null;
  }

  double? _firstNonNullDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _tryToDouble(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  bool _isLinkedTier(String tier) {
    final value = tier.trim().toLowerCase();
    return value.contains('linked') ||
        value.contains('external') ||
        value.contains('bank') ||
        value.contains('card') ||
        value.contains('mobile_money') ||
        value.contains('momo');
  }

  bool _isInternalTier(String tier) {
    final value = tier.trim().toLowerCase();
    return value.contains('sovereign') ||
        value.contains('internal') ||
        value.contains('system') ||
        value.contains('vault') ||
        value.contains('orbi') ||
        value.contains('operating') ||
        value.contains('main') ||
        value.contains('primary');
  }

  String _walletDescriptor(Map<dynamic, dynamic> wallet) {
    final fields = [
      wallet['management_tier'],
      wallet['managementTier'],
      wallet['tier'],
      wallet['wallet_type'],
      wallet['walletType'],
      wallet['type'],
      wallet['vault_role'],
      wallet['vaultRole'],
      wallet['role'],
      wallet['name'],
      wallet['alias'],
      wallet['title'],
    ];
    return fields
        .where((entry) => entry != null)
        .map((entry) => entry.toString().toLowerCase().trim())
        .where((entry) => entry.isNotEmpty)
        .join(' ');
  }

  bool _isLinkedWallet(Map<dynamic, dynamic> wallet) {
    return _isLinkedTier(_walletDescriptor(wallet));
  }

  bool _isInternalWallet(Map<dynamic, dynamic> wallet) {
    return _isInternalTier(_walletDescriptor(wallet));
  }

  IconData _iconForTier(String tier) {
    if (_isLinkedTier(tier)) return Icons.link_rounded;
    if (_isInternalTier(tier)) return Icons.account_balance_wallet_rounded;
    return Icons.savings_rounded;
  }

  Color _colorForTier(String tier) {
    if (_isLinkedTier(tier)) return const Color(0xFF3B82F6);
    if (_isInternalTier(tier)) return const Color(0xFF14B8A6);
    return const Color(0xFFF59E0B);
  }
}

class _WalletAggregate {
  const _WalletAggregate({
    required this.spendable,
    required this.protected,
    required this.total,
  });

  const _WalletAggregate.zero() : spendable = 0, protected = 0, total = 0;

  final double spendable;
  final double protected;
  final double total;
}

class PortfolioItem {
  const PortfolioItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.tier,
    this.rawData = const <String, dynamic>{},
  });

  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final String tier;
  final Map<String, dynamic> rawData;
}

class TransactionActivity {
  const TransactionActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.isInternalTransfer,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.provider,
    required this.channel,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final bool isInternalTransfer;
  final DateTime timestamp;
  final String status;
  final String type;
  final String provider;
  final String channel;
  final IconData icon;

  factory TransactionActivity.fromJson(Map<String, dynamic> json) {
    final amount = _numFromDynamic(
      json['amount'] ??
          json['value'] ??
          json['transaction_amount'] ??
          json['total'] ??
          json['total_amount'] ??
          json['amount_total'] ??
          json['net_amount'] ??
          json['gross_amount'] ??
          json['debit_amount'] ??
          json['credit_amount'] ??
          json['debit'] ??
          json['credit'],
    );
    final type =
        (json['type'] ??
                json['transaction_type'] ??
                json['category'] ??
                json['kind'] ??
                '')
            .toString()
            .toLowerCase();
    final direction = (json['direction'] ?? json['flow'] ?? '')
        .toString()
        .toLowerCase();
    final rawStatus = (json['status'] ?? json['state'] ?? 'completed')
        .toString()
        .toLowerCase();

    final title = _pickString([
      json['title'],
      json['counterparty_name'],
      json['merchant_name'],
      json['provider'],
      json['description'],
    ]);
    final provider = _pickString([
      json['provider'],
      json['provider_name'],
      json['merchant_name'],
      json['channel'],
      json['rail'],
    ]);
    final channel = _pickString([
      json['channel'],
      json['rail'],
      json['method'],
      json['provider_channel'],
    ]);
    final isInternal =
        type.contains('internal') ||
        type.contains('peer') ||
        type.contains('p2p') ||
        type.contains('user_transfer');
    final isCredit =
        direction == 'in' ||
        direction == 'credit' ||
        direction == 'incoming' ||
        (amount >= 0 &&
            (type.contains('deposit') ||
                type.contains('refund') ||
                type.contains('salary') ||
                type.contains('income')));

    return TransactionActivity(
      id: (json['id'] ?? json['transaction_id'] ?? '').toString(),
      title: title.isEmpty
          ? (isInternal ? 'ORBI Transfer' : 'Transaction')
          : title,
      subtitle: _pickString([
        json['description'],
        json['narration'],
        json['reference'],
        _prettyStatus(rawStatus),
      ]),
      amount: amount.abs(),
      isCredit: isCredit,
      isInternalTransfer: isInternal,
      timestamp: _dateFromDynamic(
        json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            json['date'],
      ),
      status: _prettyStatus(rawStatus),
      type: type,
      provider: provider.isEmpty ? 'ORBI' : provider,
      channel: channel.isEmpty ? 'Wallet' : channel,
      icon: _iconForTransaction(type: type, isCredit: isCredit),
    );
  }
}

double _numFromDynamic(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
  }
  return 0.0;
}

DateTime _dateFromDynamic(dynamic value) {
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

String _pickString(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _prettyStatus(String raw) {
  if (raw.isEmpty) return 'Completed';
  return raw[0].toUpperCase() + raw.substring(1);
}

IconData _iconForTransaction({required String type, required bool isCredit}) {
  if (type.contains('bill')) return Icons.receipt_long_rounded;
  if (type.contains('merchant') || type.contains('payment')) {
    return Icons.storefront_rounded;
  }
  if (type.contains('request')) return Icons.call_received_rounded;
  if (type.contains('goal') || type.contains('saving')) {
    return Icons.flag_rounded;
  }
  return isCredit ? Icons.south_west_rounded : Icons.north_east_rounded;
}
