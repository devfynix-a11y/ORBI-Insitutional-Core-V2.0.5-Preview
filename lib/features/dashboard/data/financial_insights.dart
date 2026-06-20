class FinancialInsights {
  final List<String> spendingAlerts;
  final List<String> budgetSuggestions;
  final List<String> financialAdvice;

  const FinancialInsights({
    required this.spendingAlerts,
    required this.budgetSuggestions,
    required this.financialAdvice,
  });

  const FinancialInsights.empty()
    : spendingAlerts = const [],
      budgetSuggestions = const [],
      financialAdvice = const [];

  bool get isEmpty =>
      spendingAlerts.isEmpty &&
      budgetSuggestions.isEmpty &&
      financialAdvice.isEmpty;
}
