part of 'app_shell.dart';

extension on _AppShellState {
  void _pushShellRoute(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openPayment() {
    _pushShellRoute(const PaymentScreen());
  }

  Future<void> _openAdvancedHub() async {
    final auth = context.read<AuthController>();

    unawaited(
      (() async {
        try {
          await auth.refreshCurrentProfile();
        } catch (_) {
          // Keep advanced hub responsive even during transient profile refresh issues.
        }
      })(),
    );

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<AuthController>(
          builder: (context, auth, _) {
            return AdvancedHubSheet(
              onSend: () => _launchAdvancedHubAction(
                sheetContext,
                const SendMoneyScreen(),
              ),
              onRequest: () => _launchAdvancedHubAction(
                sheetContext,
                const RequestMoneyScreen(),
              ),
              onTransfer: () => _launchAdvancedHubAction(
                sheetContext,
                const TransferScreen(),
              ),
              onScanPay: () {
                Navigator.pop(sheetContext);
                _openPayment();
              },
              onPaySafe: () =>
                  _launchAdvancedHubAction(sheetContext, const PaySafeScreen()),
              onSharedPot: () => _launchAdvancedHubAction(
                sheetContext,
                const SharedPotsScreen(),
              ),
              onSharedBudget: () => _launchAdvancedHubAction(
                sheetContext,
                const SharedBudgetsScreen(),
              ),
              onBillReserve: () => _launchAdvancedHubAction(
                sheetContext,
                const BillReservesScreen(),
              ),
              onAllocationRules: () => _launchAdvancedHubAction(
                sheetContext,
                const AllocationRulesScreen(),
              ),
              onLinkExternalWallet: () => _launchAdvancedHubAction(
                sheetContext,
                const LinkExternalWalletLauncher(),
              ),
              onCurrencyExchange: () => _launchAdvancedHubAction(
                sheetContext,
                const CurrencyExchangeScreen(),
              ),
              onAgentDesk: auth.isAgent
                  ? () => _launchAdvancedHubAction(
                      sheetContext,
                      const AgentScreen(),
                    )
                  : null,
              onMerchantDesk: auth.isMerchant
                  ? () => _launchAdvancedHubAction(
                      sheetContext,
                      const MerchantScreen(),
                    )
                  : null,
              onBusinessDesk: auth.organizationId.trim().isNotEmpty
                  ? () => _launchAdvancedHubAction(
                      sheetContext,
                      const EnterpriseDashboardScreen(),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  void _launchAdvancedHubAction(BuildContext sheetContext, Widget screen) {
    Navigator.pop(sheetContext);
    _pushShellRoute(screen);
  }

  void _openSettings() {
    _pushShellRoute(const SettingsScreen());
  }

  void _openNotifications() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const NotificationsPrompt();
      },
      transitionBuilder: (context, a1, a2, widget) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOut);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: a1, child: widget),
        );
      },
    );
  }
}
