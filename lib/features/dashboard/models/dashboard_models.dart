import 'package:flutter/material.dart';

enum FinancialHealthStatus { excellent, good, needsAttention }

enum GuardianInsightType {
  spendingAlert,
  savingSuggestion,
  goalPrediction,
  budgetWarning,
  securityWarning,
}

enum SmartCarouselCardType {
  goalProgress,
  budgetStatus,
  upcomingBill,
  sharedPot,
  offlineTransaction,
  merchantRecommendation,
}

class DashboardHomeSnapshot {
  const DashboardHomeSnapshot({
    required this.financialHealth,
    required this.netWorth,
    required this.carouselCards,
    required this.aiFeed,
    required this.journey,
    required this.recentActivity,
    required this.online,
    required this.deviceSecurity,
    required this.lastUpdatedAt,
  });

  const DashboardHomeSnapshot.empty()
    : financialHealth = const FinancialHealthSnapshot.empty(),
      netWorth = const NetWorthSnapshot.empty(),
      carouselCards = const <SmartCarouselCardData>[],
      aiFeed = const <GuardianInsightData>[],
      journey = const FinancialJourneySnapshot.empty(),
      recentActivity = const <RecentActivityItem>[],
      online = false,
      deviceSecurity = const DeviceSecuritySnapshot.empty(),
      lastUpdatedAt = null;

  final FinancialHealthSnapshot financialHealth;
  final NetWorthSnapshot netWorth;
  final List<SmartCarouselCardData> carouselCards;
  final List<GuardianInsightData> aiFeed;
  final FinancialJourneySnapshot journey;
  final List<RecentActivityItem> recentActivity;
  final bool online;
  final DeviceSecuritySnapshot deviceSecurity;
  final DateTime? lastUpdatedAt;

  bool get hasData =>
      netWorth.hasData ||
      carouselCards.isNotEmpty ||
      aiFeed.isNotEmpty ||
      recentActivity.isNotEmpty ||
      journey.totalItems > 0;
}

class FinancialHealthSnapshot {
  const FinancialHealthSnapshot({
    required this.score,
    required this.status,
    required this.budgetDiscipline,
    required this.savingsProgress,
    required this.goalProgress,
    required this.securityStatus,
  });

  const FinancialHealthSnapshot.empty()
    : score = 0,
      status = FinancialHealthStatus.needsAttention,
      budgetDiscipline = 0,
      savingsProgress = 0,
      goalProgress = 0,
      securityStatus = 0;

  final int score;
  final FinancialHealthStatus status;
  final int budgetDiscipline;
  final int savingsProgress;
  final int goalProgress;
  final int securityStatus;

  String get statusLabel {
    switch (status) {
      case FinancialHealthStatus.excellent:
        return 'Excellent';
      case FinancialHealthStatus.good:
        return 'Good';
      case FinancialHealthStatus.needsAttention:
        return 'Needs Attention';
    }
  }
}

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.assets,
    required this.liabilities,
    required this.netWorth,
    required this.monthlyChangePercent,
    required this.monthlyChangeAmount,
    required this.liabilitiesBackedByApi,
  });

  const NetWorthSnapshot.empty()
    : assets = 0,
      liabilities = 0,
      netWorth = 0,
      monthlyChangePercent = 0,
      monthlyChangeAmount = 0,
      liabilitiesBackedByApi = false;

  final double assets;
  final double liabilities;
  final double netWorth;
  final double monthlyChangePercent;
  final double monthlyChangeAmount;
  final bool liabilitiesBackedByApi;

  bool get hasData =>
      assets.abs() > 0.009 ||
      liabilities.abs() > 0.009 ||
      netWorth.abs() > 0.009;
}

class DeviceSecuritySnapshot {
  const DeviceSecuritySnapshot({
    required this.label,
    required this.detail,
    required this.isSecure,
  });

  const DeviceSecuritySnapshot.empty()
    : label = 'Protected',
      detail = 'Monitoring active',
      isSecure = true;

  final String label;
  final String detail;
  final bool isSecure;
}

class SmartCarouselCardData {
  const SmartCarouselCardData({
    required this.type,
    required this.title,
    required this.headline,
    required this.supportingText,
    required this.amountLabel,
    required this.statusLabel,
    required this.progress,
    required this.icon,
  });

  final SmartCarouselCardType type;
  final String title;
  final String headline;
  final String supportingText;
  final String amountLabel;
  final String statusLabel;
  final double progress;
  final IconData icon;
}

class GuardianInsightData {
  const GuardianInsightData({
    required this.type,
    required this.title,
    required this.message,
    required this.severityLabel,
  });

  final GuardianInsightType type;
  final String title;
  final String message;
  final String severityLabel;
}

class FinancialJourneySnapshot {
  const FinancialJourneySnapshot({
    required this.activeGoals,
    required this.activeBudgets,
    required this.sharedPots,
    required this.upcomingCommitments,
    required this.goalItems,
    required this.budgetItems,
    required this.potItems,
    required this.commitmentItems,
  });

  const FinancialJourneySnapshot.empty()
    : activeGoals = 0,
      activeBudgets = 0,
      sharedPots = 0,
      upcomingCommitments = 0,
      goalItems = const <JourneyItem>[],
      budgetItems = const <JourneyItem>[],
      potItems = const <JourneyItem>[],
      commitmentItems = const <JourneyItem>[];

  final int activeGoals;
  final int activeBudgets;
  final int sharedPots;
  final int upcomingCommitments;
  final List<JourneyItem> goalItems;
  final List<JourneyItem> budgetItems;
  final List<JourneyItem> potItems;
  final List<JourneyItem> commitmentItems;

  int get totalItems =>
      activeGoals + activeBudgets + sharedPots + upcomingCommitments;
}

class JourneyItem {
  const JourneyItem({
    required this.title,
    required this.detail,
    required this.progress,
  });

  final String title;
  final String detail;
  final double progress;
}

class RecentActivityItem {
  const RecentActivityItem({
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.status,
    required this.time,
    required this.provider,
    required this.channel,
    required this.icon,
  });

  final String title;
  final double amount;
  final bool isCredit;
  final String status;
  final DateTime time;
  final String provider;
  final String channel;
  final IconData icon;
}
