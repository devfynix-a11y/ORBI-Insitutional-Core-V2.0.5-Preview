import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_section_card.dart';
import '../../auth/state/auth_controller.dart';
import '../../notifications/state/notification_controller.dart';
import '../state/enterprise_controller.dart';

class EnterpriseDashboardScreen extends StatefulWidget {
  const EnterpriseDashboardScreen({super.key});

  @override
  State<EnterpriseDashboardScreen> createState() =>
      _EnterpriseDashboardScreenState();
}

class _EnterpriseDashboardScreenState extends State<EnterpriseDashboardScreen> {
  StreamSubscription<Map<String, dynamic>>? _alertSubscription;

  String _moneyLabel(dynamic amount, String currency) {
    final numeric = double.tryParse(amount?.toString() ?? '') ?? 0;
    return formatAppBalanceAmount(numeric, currency);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapEnterprise();
      _subscribeToAlerts();
    });
  }

  void _subscribeToAlerts() {
    final enterprise = context.read<EnterpriseController>();
    _alertSubscription ??= context
        .read<NotificationController>()
        .enterpriseAlerts
        .listen((alert) {
          if (!mounted) return;
          enterprise.addBudgetAlert(alert);
        });
  }

  Future<void> _bootstrapEnterprise() async {
    final auth = context.read<AuthController>();
    final token = await auth.getValidAccessToken();
    if (!mounted) return;
    final orgId = auth.organizationId;
    if (token == null || token.isEmpty || orgId.isEmpty) return;
    final enterprise = context.read<EnterpriseController>();
    await Future.wait([
      enterprise.loadOrganization(token, orgId),
      enterprise.loadBudgetAlerts(token, orgId),
      enterprise.loadPendingApprovals(token, orgId),
    ]);
    if (!mounted) return;
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final auth = context.watch<AuthController>();
    final enterprise = context.watch<EnterpriseController>();
    final orgId = auth.organizationId;
    final token = auth.session['access_token'] as String?;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.enterpriseTitle),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: ui.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrapEnterprise,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          children: [
            _enterpriseHero(auth, enterprise, ui),
            const SizedBox(height: 16),
            if (wide)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: (width - 48) / 2,
                    child: _sectionBlock(
                      AppLocalizations.of(context)!.enterpriseOrganizationTitle,
                      orgId.isEmpty
                          ? _emptyState(
                              AppLocalizations.of(
                                context,
                              )!.enterpriseNoOrganizationTitle,
                              AppLocalizations.of(
                                context,
                              )!.enterpriseNoOrganizationMessage,
                            )
                          : _orgCard(enterprise.organization, auth.orgRole),
                    ),
                  ),
                  SizedBox(
                    width: (width - 48) / 2,
                    child: _sectionBlock(
                      AppLocalizations.of(context)!.enterpriseBudgetAlertsTitle,
                      _alertsCard(enterprise.budgetAlerts),
                    ),
                  ),
                  SizedBox(
                    width: (width - 48) / 2,
                    child: _sectionBlock(
                      AppLocalizations.of(
                        context,
                      )!.enterpriseTreasuryGoalsTitle,
                      _goalsCard(enterprise.goals, auth.orgRole, token),
                    ),
                  ),
                  SizedBox(
                    width: (width - 48) / 2,
                    child: _sectionBlock(
                      AppLocalizations.of(
                        context,
                      )!.enterprisePendingApprovalsTitle,
                      _approvalsCard(
                        enterprise.pendingApprovals,
                        auth.orgRole,
                        token,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _sectionBlock(
                AppLocalizations.of(context)!.enterpriseOrganizationTitle,
                orgId.isEmpty
                    ? _emptyState(
                        AppLocalizations.of(
                          context,
                        )!.enterpriseNoOrganizationTitle,
                        AppLocalizations.of(
                          context,
                        )!.enterpriseNoOrganizationMessage,
                      )
                    : _orgCard(enterprise.organization, auth.orgRole),
              ),
              const SizedBox(height: 16),
              _sectionBlock(
                AppLocalizations.of(context)!.enterpriseBudgetAlertsTitle,
                _alertsCard(enterprise.budgetAlerts),
              ),
              const SizedBox(height: 16),
              _sectionBlock(
                AppLocalizations.of(context)!.enterpriseTreasuryGoalsTitle,
                _goalsCard(enterprise.goals, auth.orgRole, token),
              ),
              const SizedBox(height: 16),
              _sectionBlock(
                AppLocalizations.of(context)!.enterprisePendingApprovalsTitle,
                _approvalsCard(
                  enterprise.pendingApprovals,
                  auth.orgRole,
                  token,
                ),
              ),
            ],
            if (enterprise.isLoading) ...[
              const SizedBox(height: 20),
              Center(child: CircularProgressIndicator(color: ui.accent)),
            ],
            if (enterprise.error != null) ...[
              const SizedBox(height: 20),
              Text(enterprise.error!, style: TextStyle(color: ui.danger)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _enterpriseHero(
    AuthController auth,
    EnterpriseController enterprise,
    OrbiUiTokens ui,
  ) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(ui.accent, ui.card, 0.84) ?? ui.card,
            ui.cardStrong,
            ui.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ui.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.business_outlined, color: ui.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.enterpriseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sw
                          ? 'Hazina, tahadhari, na idhini za taasisi.'
                          : 'Treasury, alerts, and approvals.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ui.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                ui,
                Icons.business_outlined,
                sw ? 'Wajibu' : 'Role',
                auth.orgRole.toUpperCase(),
              ),
              _heroChip(
                ui,
                Icons.warning_amber_rounded,
                sw ? 'Tahadhari' : 'Alerts',
                '${enterprise.budgetAlerts.length}',
              ),
              _heroChip(
                ui,
                Icons.flag_outlined,
                sw ? 'Malengo ya hazina' : 'Treasury goals',
                '${enterprise.goals.length}',
              ),
              _heroChip(
                ui,
                Icons.fact_check_outlined,
                sw ? 'Maidhinisho' : 'Approvals',
                '${enterprise.pendingApprovals.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(OrbiUiTokens ui, IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ui.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ui.textMuted, fontSize: 10.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionBlock(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_sectionTitle(title), child],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: OrbiTheme.uiOf(context).textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _orgCard(Map<String, dynamic>? org, String role) {
    final ui = OrbiTheme.uiOf(context);
    if (org == null || org.isEmpty) {
      return _emptyState(
        AppLocalizations.of(context)!.enterpriseLoadingTitle,
        AppLocalizations.of(context)!.enterpriseFetchingOrganizationMessage,
      );
    }
    final name =
        (org['name'] ??
                AppLocalizations.of(context)!.enterpriseOrganizationFallback)
            .toString();
    final currency = (org['base_currency'] ?? org['baseCurrency'] ?? '')
        .toString();
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(
              context,
            )!.enterpriseRoleLabel(role.toUpperCase()),
            style: TextStyle(color: ui.textMuted, fontSize: 12),
          ),
          if (currency.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(
                context,
              )!.enterpriseBaseCurrencyLabel(currency),
              style: TextStyle(color: ui.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _goalsCard(List<dynamic> goals, String role, String? token) {
    final ui = OrbiTheme.uiOf(context);
    final canConfigure =
        role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'FINANCE';
    if (goals.isEmpty) {
      return _emptyState(
        AppLocalizations.of(context)!.enterpriseNoTreasuryGoalsTitle,
        AppLocalizations.of(context)!.enterpriseNoTreasuryGoalsMessage,
      );
    }
    return OrbiSectionCard(
      child: Column(
        children: goals.take(6).map((goal) {
          final map = goal is Map ? Map<String, dynamic>.from(goal) : {};
          final name =
              (map['name'] ??
                      map['title'] ??
                      AppLocalizations.of(
                        context,
                      )!.enterpriseTreasuryGoalFallback)
                  .toString();
          final id = map['id']?.toString() ?? '';
          final currency = map['currency']?.toString() ?? '';
          final balance = map['balance']?.toString() ?? '';
          final meta = map['metadata'] is Map
              ? Map<String, dynamic>.from(map['metadata'] as Map)
              : <String, dynamic>{};
          final sweepEnabled = meta['auto_sweep'] == true;
          final threshold = meta['sweep_threshold']?.toString() ?? '';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              name,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              sweepEnabled
                  ? AppLocalizations.of(
                      context,
                    )!.enterpriseAutoSweepEnabledStatus(
                      threshold.isEmpty
                          ? ''
                          : AppLocalizations.of(
                              context,
                            )!.enterpriseThresholdSuffix(threshold),
                    )
                  : AppLocalizations.of(
                      context,
                    )!.enterpriseAutoSweepDisabledStatus,
              style: TextStyle(color: ui.textMuted, fontSize: 11),
            ),
            trailing: balance.isEmpty
                ? null
                : Text(
                    '$currency $balance',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            enabled:
                canConfigure &&
                id.isNotEmpty &&
                token != null &&
                token.isNotEmpty,
            onTap: !canConfigure || id.isEmpty || token == null || token.isEmpty
                ? null
                : () => _openAutoSweepDialog(
                    token: token,
                    goalId: id,
                    goalName: name,
                    currency: currency,
                    currentEnabled: sweepEnabled,
                    currentThreshold: threshold,
                  ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openAutoSweepDialog({
    required String token,
    required String goalId,
    required String goalName,
    required String currency,
    required bool currentEnabled,
    required String currentThreshold,
  }) async {
    final controller = context.read<EnterpriseController>();
    final thresholdController = TextEditingController(text: currentThreshold);
    var enabled = currentEnabled;
    final ui = OrbiTheme.uiOf(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.enterpriseAutoSweepConfigurationTitle,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goalName,
                    style: TextStyle(color: ui.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: enabled,
                    onChanged: (value) => setSheetState(() => enabled = value),
                    title: Text(
                      AppLocalizations.of(
                        context,
                      )!.enterpriseEnableAutoSweepTitle,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        )!.enterpriseOperatingVaultThreshold(currency),
                        prefixText: resolveCurrencyDisplaySymbol(currency),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            AppLocalizations.of(context)!.actionCancel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final l10n = AppLocalizations.of(context)!;
                            final navigator = Navigator.of(sheetContext);
                            final messenger = ScaffoldMessenger.of(context);
                            final threshold =
                                double.tryParse(thresholdController.text) ?? 0;
                            await controller.configureAutoSweep(token, {
                              'goalId': goalId,
                              'enabled': enabled,
                              'threshold': threshold,
                            });
                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.enterpriseAutoSweepUpdatedMessage,
                                ),
                              ),
                            );
                          },
                          child: Text(AppLocalizations.of(context)!.actionSave),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _alertsCard(List<dynamic> alerts) {
    final ui = OrbiTheme.uiOf(context);
    if (alerts.isEmpty) {
      return _emptyState(
        AppLocalizations.of(context)!.enterpriseAllClearTitle,
        AppLocalizations.of(context)!.enterpriseNoBudgetAlertsMessage,
      );
    }
    return OrbiSectionCard(
      child: Column(
        children: alerts.take(6).map((alert) {
          final map = alert is Map ? Map<String, dynamic>.from(alert) : {};
          final type = (map['alert_type'] ?? map['type'] ?? '').toString();
          final message =
              (map['message'] ??
                      map['body'] ??
                      AppLocalizations.of(
                        context,
                      )!.enterpriseBudgetAlertFallback)
                  .toString();
          final amount = map['amount']?.toString() ?? '';
          final currency = map['currency']?.toString() ?? '';
          final alertType = type.toUpperCase();
          final color = alertType.contains('BLOCK')
              ? ui.danger
              : alertType.contains('EXCEEDED')
              ? ui.warning
              : ui.accent;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              type.isEmpty
                  ? AppLocalizations.of(context)!.enterpriseBudgetAlertUpper
                  : type,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              message,
              style: TextStyle(color: ui.textMuted, fontSize: 12),
            ),
            trailing: amount.isEmpty
                ? null
                : Text(
                    _moneyLabel(amount, currency),
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _approvalsCard(List<dynamic> approvals, String role, String? token) {
    final ui = OrbiTheme.uiOf(context);
    final canApprove =
        role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'FINANCE';
    final currentUserId = context.read<AuthController>().userId;
    if (approvals.isEmpty) {
      return _emptyState(
        AppLocalizations.of(context)!.enterpriseNoApprovalsTitle,
        AppLocalizations.of(context)!.enterpriseNothingPendingMessage,
      );
    }
    return OrbiSectionCard(
      child: Column(
        children: approvals.take(6).map((approval) {
          final map = approval is Map
              ? Map<String, dynamic>.from(approval)
              : {};
          final reason = (map['reason'] ?? map['metadata']?['reason'] ?? '')
              .toString();
          final amount = map['amount']?.toString() ?? '';
          final currency = map['currency']?.toString() ?? '';
          final id = map['id']?.toString() ?? '';
          final requesterId =
              (map['user_id'] ??
                      map['userId'] ??
                      map['requested_by'] ??
                      map['maker_id'] ??
                      map['metadata']?['user_id'])
                  ?.toString();
          final isSelf =
              requesterId != null &&
              requesterId.isNotEmpty &&
              requesterId == currentUserId;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              reason.isEmpty
                  ? AppLocalizations.of(
                      context,
                    )!.enterpriseTreasuryApprovalFallback
                  : reason,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              id.isEmpty
                  ? ''
                  : AppLocalizations.of(context)!.enterpriseIdLabel(id),
              style: TextStyle(color: ui.textMuted, fontSize: 11),
            ),
            trailing: amount.isEmpty
                ? null
                : Text(
                    _moneyLabel(amount, currency),
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            enabled: canApprove && !isSelf,
            onTap: !canApprove || isSelf
                ? null
                : () async {
                    if (token == null || token.isEmpty) return;
                    if (id.isEmpty) return;
                    final controller = context.read<EnterpriseController>();
                    final messenger = ScaffoldMessenger.of(context);
                    await controller.approveWithdrawal(token, {'txId': id});
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.enterpriseApprovalSubmittedMessage,
                        ),
                      ),
                    );
                  },
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState(String title, String message) {
    final ui = OrbiTheme.uiOf(context);
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: ui.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
