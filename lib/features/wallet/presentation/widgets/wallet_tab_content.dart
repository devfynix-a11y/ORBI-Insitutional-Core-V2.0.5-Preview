import 'package:flutter/material.dart';
import '../../data/wallet_models.dart';
import '../../state/wallet_view_model.dart';
import '../allocation_rules_screen.dart';
import '../bill_reserves_screen.dart';
import '../link_external_wallet_screen.dart';
import '../shared_budgets_screen.dart';
import '../shared_pots_screen.dart';
import 'wallet_sections.dart';
import 'wallet_shell_widgets.dart';
import 'wealth_foundation_sections.dart';
import 'wealth_tabs.dart';

class WalletTabContent extends StatelessWidget {
  const WalletTabContent({
    super.key,
    required this.activeTab,
    required this.snapshot,
    required this.wealthLoading,
    required this.wealthError,
    required this.hideBalances,
    required this.theme,
    required this.primaryVault,
    required this.primaryBalanceText,
    required this.mainWalletCardNumber,
    required this.viewModel,
    required this.onWalletTap,
    required this.onSetActiveTab,
    required this.onRetryWealth,
    required this.onToggleBalanceVisibility,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSend,
    required this.onScan,
    required this.onOpenGoals,
    required this.onOpenPaySafe,
    required this.runAsyncAction,
    required this.onStatus,
    required this.isMerchant,
    required this.isAgent,
    required this.isEnterprise,
  });

  final WealthScreenTab activeTab;
  final WealthSnapshotData? snapshot;
  final bool wealthLoading;
  final String? wealthError;
  final bool hideBalances;
  final ThemeData theme;
  final WalletRecord? primaryVault;
  final String primaryBalanceText;
  final String mainWalletCardNumber;
  final WalletViewModel viewModel;
  final ValueChanged<WalletRecord> onWalletTap;
  final ValueChanged<WealthScreenTab> onSetActiveTab;
  final VoidCallback onRetryWealth;
  final VoidCallback onToggleBalanceVisibility;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSend;
  final VoidCallback onScan;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenPaySafe;
  final Future<void> Function(String message, Future<void> Function() action)
  runAsyncAction;
  final void Function(String message, {required bool isError}) onStatus;
  final bool isMerchant;
  final bool isAgent;
  final bool isEnterprise;

  @override
  Widget build(BuildContext context) {
    switch (activeTab) {
      case WealthScreenTab.home:
        return Column(
          children: [
            WealthHomeTab(
              snapshot: snapshot,
              loading: wealthLoading,
              errorMessage: wealthError,
              onRetry: onRetryWealth,
              onOpenGoals: onOpenGoals,
              onOpenPlans: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SharedBudgetsScreen()),
              ),
              onOpenProtection: onOpenPaySafe,
              isMerchant: isMerchant,
              isAgent: isAgent,
              isEnterprise: isEnterprise,
            ),
            if (viewModel.isProvisioningState) ...[
              const SizedBox(height: 14),
              ProvisioningBanner(viewModel: viewModel),
            ],
            const SizedBox(height: 18),
            WalletListSection(
              theme: theme,
              viewModel: viewModel,
              hideBalances: hideBalances,
              onWalletTap: onWalletTap,
              onLinkWallet: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LinkExternalWalletScreen(
                    sessionCurrency: viewModel.sessionCurrency,
                    onWalletLinked: viewModel.refresh,
                  ),
                ),
              ),
              runAsyncAction: runAsyncAction,
              onStatus: onStatus,
            ),
          ],
        );
      case WealthScreenTab.plans:
        return WealthPlansTab(
          snapshot: snapshot,
          onOpenBillReserve: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BillReservesScreen())),
          onOpenAllocationRules: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AllocationRulesScreen()),
          ),
          onOpenSharedBudget: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SharedBudgetsScreen()),
          ),
          isMerchant: isMerchant,
          isAgent: isAgent,
          isEnterprise: isEnterprise,
        );
      case WealthScreenTab.growth:
        return WealthGrowthTab(
          snapshot: snapshot,
          onOpenGoals: onOpenGoals,
          onOpenSharedPot: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SharedPotsScreen())),
          onOpenSharedBudget: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SharedBudgetsScreen()),
          ),
          isMerchant: isMerchant,
          isAgent: isAgent,
          isEnterprise: isEnterprise,
        );
      case WealthScreenTab.protection:
        return WealthProtectionTab(
          snapshot: snapshot,
          onOpenPaySafe: onOpenPaySafe,
          onOpenLinkWallet: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LinkExternalWalletScreen(
                sessionCurrency: viewModel.sessionCurrency,
                onWalletLinked: viewModel.refresh,
              ),
            ),
          ),
          isMerchant: isMerchant,
          isAgent: isAgent,
          isEnterprise: isEnterprise,
        );
    }
  }
}
