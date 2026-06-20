import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:orbi_mobileapp/l10n/wealth_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_activity_card.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../../auth/state/auth_controller.dart';
import '../../goals/data/goals_service.dart';
import '../data/wealth_service.dart';

const Color _allocationRulesAccent = Color(0xFF2596BE);

class AllocationRulesScreen extends StatefulWidget {
  const AllocationRulesScreen({super.key});

  @override
  State<AllocationRulesScreen> createState() => _AllocationRulesScreenState();
}

class _AllocationRulesScreenState extends State<AllocationRulesScreen> {
  final WealthService _wealthService = WealthService();
  final GoalsService _goalsService = GoalsService();

  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  String? _error;
  List<Map<String, dynamic>> _rules = const [];
  List<Map<String, dynamic>> _goals = const [];
  List<Map<String, dynamic>> _billReserves = const [];
  List<Map<String, dynamic>> _sharedPots = const [];
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await context.read<AuthController>().getValidAccessToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception(
          _l10n.pick(
            en: 'Your session could not be confirmed.',
            swText: 'Kikao chako hakikuthibitishwa.',
          ),
        );
      }
      final rules = await _wealthService.listAllocationRules();
      final goals = await _goalsService.fetchGoals(token);
      final reserves = await _wealthService.listBillReserves();
      final pots = await _wealthService.listSharedPots();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _goals = goals;
        _billReserves = reserves;
        _sharedPots = pots;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapBackendStatusMessage(
          e.toString(),
          sw: _l10n.isSw,
          fallback: _l10n.pick(
            en: 'Unable to load allocation rules.',
            swText: 'Imeshindikana kupakia allocation rules.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
    });
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

  Future<void> _toggleRule(Map<String, dynamic> rule) async {
    final active = rule['is_active'] == true;
    await _runBusy(
      _l10n.pick(en: 'Updating rule...', swText: 'Inasasisha rule...'),
      () => _wealthService.updateAllocationRule((rule['id'] ?? '').toString(), {
        'is_active': !active,
      }),
    );
    await _load();
    if (!mounted) return;
    setState(() {
      _statusMessage = active
          ? (_l10n.pick(en: 'Rule paused.', swText: 'Rule imezimwa.'))
          : (_l10n.pick(en: 'Rule activated.', swText: 'Rule imewashwa.'));
      _statusTone = OrbiStatusTone.success;
    });
  }

  Future<void> _showCreateRuleSheet() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String triggerType = 'DEPOSIT';
    String targetType = 'GOAL';
    String mode = 'PERCENT';
    String? selectedTargetId;
    String? formError;
    bool submitting = false;

    List<Map<String, dynamic>> targetsFor(String type) {
      switch (type) {
        case 'GOAL':
          return _goals;
        case 'BILL_RESERVE':
          return _billReserves;
        case 'SHARED_POT':
          return _sharedPots;
        default:
          return const [];
      }
    }

    String labelFor(Map<String, dynamic> item) {
      return (item['name'] ??
              item['provider_name'] ??
              item['bill_type'] ??
              'Target')
          .toString();
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final targets = targetsFor(targetType);
            selectedTargetId ??= targets.isNotEmpty
                ? (targets.first['id'] ?? '').toString()
                : null;
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ui.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _l10n.pick(
                          en: 'New allocation rule',
                          swText: 'Allocation rule mpya',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _l10n.pick(
                          en: 'Move money automatically to the right place.',
                          swText:
                              'Hamisha fedha moja kwa moja kwenda sehemu sahihi.',
                        ),
                        style: TextStyle(color: ui.textMuted, height: 1.35),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          formError!,
                          style: TextStyle(
                            color: ui.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: _l10n.pick(
                            en: 'Rule name',
                            swText: 'Jina la rule',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackFields = constraints.maxWidth < 380;
                          final triggerField = DropdownButtonFormField<String>(
                            initialValue: triggerType,
                            items: const [
                              DropdownMenuItem(
                                value: 'DEPOSIT',
                                child: Text('Deposit'),
                              ),
                              DropdownMenuItem(
                                value: 'SALARY',
                                child: Text('Salary'),
                              ),
                              DropdownMenuItem(
                                value: 'ROUNDUP',
                                child: Text('Round-up'),
                              ),
                            ],
                            onChanged: submitting
                                ? null
                                : (value) => setSheetState(
                                    () => triggerType = value ?? triggerType,
                                  ),
                            decoration: InputDecoration(
                              labelText: _l10n.pick(
                                en: 'Trigger',
                                swText: 'Trigger',
                              ),
                              isDense: true,
                            ),
                          );
                          final modeField = DropdownButtonFormField<String>(
                            initialValue: mode,
                            items: const [
                              DropdownMenuItem(
                                value: 'PERCENT',
                                child: Text('Percent'),
                              ),
                              DropdownMenuItem(
                                value: 'FIXED',
                                child: Text('Fixed'),
                              ),
                            ],
                            onChanged: submitting
                                ? null
                                : (value) =>
                                      setSheetState(() => mode = value ?? mode),
                            decoration: InputDecoration(
                              labelText: _l10n.pick(en: 'Mode', swText: 'Mode'),
                              isDense: true,
                            ),
                          );
                          if (stackFields) {
                            return Column(
                              children: [
                                triggerField,
                                const SizedBox(height: 10),
                                modeField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: triggerField),
                              const SizedBox(width: 10),
                              Expanded(child: modeField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: targetType,
                        items: const [
                          DropdownMenuItem(value: 'GOAL', child: Text('Goal')),
                          DropdownMenuItem(
                            value: 'BILL_RESERVE',
                            child: Text('Bill reserve'),
                          ),
                          DropdownMenuItem(
                            value: 'SHARED_POT',
                            child: Text('Shared pot'),
                          ),
                        ],
                        onChanged: submitting
                            ? null
                            : (value) => setSheetState(() {
                                targetType = value ?? targetType;
                                final targets = targetsFor(targetType);
                                selectedTargetId = targets.isNotEmpty
                                    ? (targets.first['id'] ?? '').toString()
                                    : null;
                              }),
                        decoration: InputDecoration(
                          labelText: _l10n.pick(
                            en: 'Target type',
                            swText: 'Target type',
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTargetId,
                        items: targets
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: (item['id'] ?? '').toString(),
                                child: Text(labelFor(item)),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) =>
                                  setSheetState(() => selectedTargetId = value),
                        decoration: InputDecoration(
                          labelText: _l10n.pick(
                            en: 'Destination',
                            swText: 'Destination',
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OrbiAmountField(
                        controller: amountController,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [AmountInputFormatter()],
                        label: mode == 'PERCENT'
                            ? (_l10n.pick(en: 'Percentage', swText: 'Asilimia'))
                            : (_l10n.pick(en: 'Amount', swText: 'Kiasi')),
                        currency: mode == 'PERCENT' ? '%' : 'TZS',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final name = nameController.text.trim();
                                  final amount = AmountInputFormatter.tryParse(
                                    amountController.text,
                                  );
                                  if (name.isEmpty ||
                                      amount == null ||
                                      amount <= 0 ||
                                      selectedTargetId == null) {
                                    setSheetState(() {
                                      formError = _l10n.pick(
                                        en: 'Enter a rule name, destination, and valid amount.',
                                        swText:
                                            'Jaza jina, destination, na kiasi sahihi.',
                                      );
                                    });
                                    return;
                                  }
                                  setSheetState(() {
                                    submitting = true;
                                    formError = null;
                                  });
                                  try {
                                    await _wealthService.createAllocationRule({
                                      'name': name,
                                      'trigger_type': triggerType,
                                      'target_type': targetType,
                                      'target_id': selectedTargetId,
                                      'mode': mode,
                                      if (mode == 'PERCENT')
                                        'percentage': amount,
                                      if (mode == 'FIXED')
                                        'fixed_amount': amount,
                                    });
                                    if (!sheetContext.mounted) return;
                                    Navigator.of(sheetContext).pop(true);
                                  } catch (e) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {
                                      formError = mapBackendStatusMessage(
                                        e.toString(),
                                        sw: _l10n.isSw,
                                        fallback: _l10n.pick(
                                          en: 'Unable to create the allocation rule.',
                                          swText:
                                              'Imeshindikana kuunda allocation rule.',
                                        ),
                                      );
                                      submitting = false;
                                    });
                                  }
                                },
                          child: submitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _l10n.pick(
                                        en: 'Saving...',
                                        swText: 'Inahifadhi...',
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _l10n.pick(
                                    en: 'Save rule',
                                    swText: 'Hifadhi rule',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();

    if (created == true) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = _l10n.pick(
          en: 'Allocation rule created.',
          swText: 'Allocation rule imeundwa.',
        );
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _l10n.pick(en: 'Allocation Rules', swText: 'Allocation Rules'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRuleSheet,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(_l10n.pick(en: 'New rule', swText: 'Rule mpya')),
      ),
      body: OrbiLoadingOverlay(
        loading: _busy,
        message: _busyMessage,
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () => setState(() => _statusMessage = null),
        child: OrbiBackground(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OrbiActivityCard(
                  accent: _allocationRulesAccent,
                  hero: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l10n.pick(
                          en: 'Let money move to the right place automatically',
                          swText: 'Fedha ziende mahali sahihi zenyewe',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _l10n.pick(
                          en: 'Use rules to move money automatically into goals, bill reserves, or shared pots.',
                          swText:
                              'Tumia rules kupeleka fedha moja kwa moja kwenye malengo, bili, au shared pots.',
                        ),
                        style: TextStyle(color: ui.textMuted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  OrbiStateCard(
                    icon: Icons.sync_problem_rounded,
                    title: _l10n.pick(
                      en: 'Allocation rules could not be loaded',
                      swText: 'Allocation rules hazikupatikana',
                    ),
                    message: _error,
                    accentColor: ui.warning,
                    accentBackground: ui.warningSoft,
                    action: TextButton(
                      onPressed: _load,
                      child: Text(
                        _l10n.pick(en: 'Try again', swText: 'Jaribu tena'),
                      ),
                    ),
                  )
                else if (_rules.isEmpty)
                  OrbiStateCard(
                    icon: Icons.route_rounded,
                    title: _l10n.pick(
                      en: 'No allocation rule yet',
                      swText: 'Hakuna allocation rule bado',
                    ),
                    message: _l10n.pick(
                      en: 'Create a rule so money moves automatically without manual work each time.',
                      swText:
                          'Unda rule ili fedha ziende zenyewe bila kufanya kila kitu kwa mkono.',
                    ),
                    accentColor: ui.accent,
                    accentBackground: ui.accent.withValues(alpha: 0.14),
                    action: TextButton(
                      onPressed: _showCreateRuleSheet,
                      child: Text(
                        _l10n.pick(en: 'Create rule', swText: 'Unda rule'),
                      ),
                    ),
                  )
                else
                  ..._rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrbiActivityCard(
                        accent: _allocationRulesAccent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (rule['name'] ?? 'Rule').toString(),
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${rule['trigger_type'] ?? 'DEPOSIT'} • ${rule['target_type'] ?? 'TARGET'}',
                                    style: TextStyle(color: ui.textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    rule['mode'] == 'FIXED'
                                        ? '${rule['fixed_amount'] ?? 0}'
                                        : '${rule['percentage'] ?? 0}%',
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: rule['is_active'] == true,
                              onChanged: (_) => _toggleRule(rule),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
