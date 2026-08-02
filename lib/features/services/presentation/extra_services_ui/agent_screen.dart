import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/provider_asset_resolver.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/utils/backend_status_message.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/orbi_amount_field.dart';
import '../../../../core/widgets/orbi_background.dart';
import '../../../../core/widgets/orbi_orbit_loader.dart';
import '../../../../core/widgets/orbi_responsive.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../../core/widgets/orbi_state_card.dart';
import '../../../../core/widgets/provider_logo_image.dart';
import '../../../auth/state/auth_controller.dart';
import '../../data/service_actor_service.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final ServiceActorService _service = ServiceActorService();
  static const List<String> _externalAgentProviders = [
    'Vodacom Agent',
    'Airtel Agent',
    'Mix By Yas Agent',
    'Halotel Agent',
  ];

  bool _loading = true;
  bool _savingCustomer = false;
  String? _error;
  List<Map<String, dynamic>> _wallets = const [];
  List<Map<String, dynamic>> _transactions = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _commissions = const [];
  Map<String, dynamic>? _lastOperationPreview;
  String _transactionFilter = 'ALL';
  String _commissionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_transactionFilter == 'ALL') return _transactions;
    return _transactions.where((tx) {
      final serviceType = _pickString([
        tx['service_type'],
        tx['type'],
      ]).toLowerCase();
      if (_transactionFilter == 'DEPOSIT') {
        return serviceType.contains('deposit');
      }
      return serviceType.contains('withdraw');
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCommissions {
    if (_commissionFilter == 'ALL') return _commissions;
    return _commissions.where((commission) {
      final status = _pickString([commission['status']]).toUpperCase();
      return status == _commissionFilter;
    }).toList();
  }

  double _sumAmounts(List<Map<String, dynamic>> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + _pickDouble([item['amount']]),
    );
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _friendlyError(Object error) => mapBackendStatusMessage(
    error.toString(),
    sw: _isSw,
    fallback: _isSw
        ? 'Huduma ya wakala haikuweza kupakiwa. Tafadhali jaribu tena.'
        : 'Agent service could not be loaded. Please try again.',
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.listAgentWallets(),
        _service.listAgentTransactions(),
        _service.listAgentCustomers(),
        _service.listAgentCommissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallets = List<Map<String, dynamic>>.from(results[0] as List);
        _transactions = List<Map<String, dynamic>>.from(results[1] as List);
        _customers = List<Map<String, dynamic>>.from(results[2] as List);
        _commissions = List<Map<String, dynamic>>.from(results[3] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openCustomerRegistration() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final ui = OrbiTheme.uiOf(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer full name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Temporary password',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _savingCustomer
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    passwordController.text.trim().length < 8 ||
                                    (emailController.text.trim().isEmpty &&
                                        phoneController.text.trim().isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter name, password, and email or phone.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => _savingCustomer = true);
                                try {
                                  await _service.registerCustomerForActor(
                                    actorRole: 'AGENT',
                                    payload: {
                                      'full_name': nameController.text.trim(),
                                      'password': passwordController.text
                                          .trim(),
                                      if (emailController.text
                                          .trim()
                                          .isNotEmpty)
                                        'email': emailController.text.trim(),
                                      if (phoneController.text
                                          .trim()
                                          .isNotEmpty)
                                        'phone': phoneController.text.trim(),
                                    },
                                  );
                                  if (!mounted || !sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Customer registered.'),
                                    ),
                                  );
                                  await _load();
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(
                                      () => _savingCustomer = false,
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(
                          _savingCustomer ? 'Submitting...' : 'Add customer',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCashOperationFlow(String direction) async {
    if (_wallets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No agent wallet.')));
      return;
    }
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedWalletId = _pickString([
      _wallets.first['id'],
      _wallets.first['wallet_id'],
      _wallets.first['base_wallet_id'],
    ]);
    String currency = _pickString([_wallets.first['currency'], 'TZS']);
    Map<String, dynamic>? preview;
    final ui = OrbiTheme.uiOf(context);
    final isDeposit = direction == 'deposit';
    String selectedAgentProvider = _externalAgentProviders.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> previewOperation() async {
              final amount = AmountInputFormatter.tryParse(
                amountController.text,
              );
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid amount.')),
                );
                return;
              }
              setSheetState(() => busy = true);
              try {
                final payload = {
                  'sourceWalletId': selectedWalletId,
                  'amount': amount,
                  'currency': currency,
                  'description': descriptionController.text.trim().isEmpty
                      ? (isDeposit
                            ? 'Agent cash deposit'
                            : 'Agent cash withdrawal')
                      : descriptionController.text.trim(),
                  'type': isDeposit ? 'DEPOSIT' : 'WITHDRAWAL',
                  'metadata': {
                    if (!isDeposit) ...{
                      'counterparty_type': 'EXTERNAL_AGENT',
                      'provider_input': selectedAgentProvider,
                      'transaction_type': 'AGENT_CASH_WITHDRAWAL',
                    },
                  },
                };
                preview = isDeposit
                    ? await _service.previewAgentDeposit(payload)
                    : await _service.previewAgentWithdrawal(payload);
                if (mounted) {
                  setState(() => _lastOperationPreview = preview);
                }
              } finally {
                if (sheetContext.mounted) setSheetState(() => busy = false);
              }
            }

            Future<void> settleOperation() async {
              final amount = AmountInputFormatter.tryParse(
                amountController.text,
              );
              if (amount == null || amount <= 0) return;
              setSheetState(() => busy = true);
              try {
                final payload = {
                  'sourceWalletId': selectedWalletId,
                  'amount': amount,
                  'currency': currency,
                  'description': descriptionController.text.trim().isEmpty
                      ? (isDeposit
                            ? 'Agent cash deposit'
                            : 'Agent cash withdrawal')
                      : descriptionController.text.trim(),
                  'type': isDeposit ? 'DEPOSIT' : 'WITHDRAWAL',
                  'metadata': {
                    if (!isDeposit) ...{
                      'counterparty_type': 'EXTERNAL_AGENT',
                      'provider_input': selectedAgentProvider,
                      'transaction_type': 'AGENT_CASH_WITHDRAWAL',
                    },
                  },
                };
                if (isDeposit) {
                  await _service.settleAgentDeposit(payload);
                } else {
                  await _service.settleAgentWithdrawal(payload);
                }
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isDeposit
                          ? 'Deposit submitted.'
                          : 'Withdrawal submitted.',
                    ),
                  ),
                );
                await _load();
              } finally {
                if (sheetContext.mounted) setSheetState(() => busy = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ui.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ui.borderStrong.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (isDeposit ? ui.success : ui.accentSoft)
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isDeposit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: isDeposit ? ui.success : ui.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDeposit
                                      ? 'Cash deposit'
                                      : 'Cash withdrawal',
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isDeposit
                                      ? 'Receive cash.'
                                      : 'Choose agent network.',
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isDeposit) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ui.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ui.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agent network',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose network.',
                              style: TextStyle(
                                color: ui.textMuted,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _externalAgentProviders
                                  .map(
                                    (provider) => _agentProviderChoiceCard(
                                      provider: provider,
                                      selected:
                                          provider == selectedAgentProvider,
                                      onTap: () => setSheetState(
                                        () => selectedAgentProvider = provider,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ui.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ui.border),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedWalletId,
                            decoration: const InputDecoration(
                              labelText: 'Wallet',
                              border: OutlineInputBorder(),
                            ),
                            items: _wallets
                                .map(
                                  (wallet) => DropdownMenuItem<String>(
                                    value: _pickString([
                                      wallet['id'],
                                      wallet['wallet_id'],
                                      wallet['base_wallet_id'],
                                    ]),
                                    child: Text(
                                      '${_pickString([wallet['name'], 'Wallet'])} • ${_pickString([wallet['currency'], 'TZS'])}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final wallet = _wallets.firstWhere(
                                (item) =>
                                    _pickString([
                                      item['id'],
                                      item['wallet_id'],
                                      item['base_wallet_id'],
                                    ]) ==
                                    value,
                              );
                              setSheetState(() {
                                selectedWalletId = value;
                                currency = _pickString([
                                  wallet['currency'],
                                  'TZS',
                                ]);
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          OrbiAmountField(
                            controller: amountController,
                            inputFormatters: [AmountInputFormatter()],
                            label: 'Amount',
                            currency: resolveCurrencyDisplaySymbol(currency),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ui.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ui.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preview.toString(),
                              style: TextStyle(
                                color: ui.textMuted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : previewOperation,
                            icon: const Icon(Icons.visibility_outlined),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ui.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ui.borderStrong),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            label: Text(busy ? 'Working...' : 'Review'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy ? null : settleOperation,
                            icon: Icon(
                              isDeposit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: ui.iconMuted,
                              foregroundColor: const Color(0xFF151617),
                              disabledBackgroundColor: ui.cardStrong,
                              disabledForegroundColor: ui.textSoft,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            label: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Agent')),
      body: OrbiBackground(
        child: OrbiResponsiveContent(
          child: _loading
              ? const OrbiOrbitLoadingPane(
                  label: 'Loading agent desk',
                  centerIcon: Icons.storefront_outlined,
                )
              : _error != null
              ? Center(
                  child: OrbiStateCard(
                    icon: Icons.sync_problem_outlined,
                    title: 'Could not load Agent',
                    message: _error!,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
                    children: [
                      OrbiSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agent',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cash service, wallets, customers, and commissions.',
                              style: TextStyle(
                                color: ui.textMuted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _metric(ui, 'Start here', 'Register customer'),
                                _metric(
                                  ui,
                                  'Cash service',
                                  'Deposit or withdraw',
                                ),
                                _metric(
                                  ui,
                                  'Review',
                                  'Customers & commissions',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _metric(
                                  ui,
                                  'Float wallets',
                                  '${_wallets.length}',
                                ),
                                _metric(
                                  ui,
                                  'Cash activity',
                                  '${_transactions.length}',
                                ),
                                _metric(
                                  ui,
                                  'Customers',
                                  '${_customers.length}',
                                ),
                                _metric(
                                  ui,
                                  'Commissions',
                                  '${_commissions.length}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _metric(
                                  ui,
                                  'Deposit total',
                                  formatFinancialMoney(
                                    _sumAmounts(
                                      _transactions.where((tx) {
                                        final type = _pickString([
                                          tx['service_type'],
                                          tx['type'],
                                        ]).toLowerCase();
                                        return type.contains('deposit');
                                      }).toList(),
                                    ),
                                    'TZS',
                                    locale: 'en_US',
                                  ),
                                ),
                                _metric(
                                  ui,
                                  'Withdraw total',
                                  formatFinancialMoney(
                                    _sumAmounts(
                                      _transactions.where((tx) {
                                        final type = _pickString([
                                          tx['service_type'],
                                          tx['type'],
                                        ]).toLowerCase();
                                        return type.contains('withdraw');
                                      }).toList(),
                                    ),
                                    'TZS',
                                    locale: 'en_US',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _openCustomerRegistration,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              style: FilledButton.styleFrom(
                                backgroundColor: ui.iconMuted,
                                foregroundColor: const Color(0xFF151617),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              label: const Text('Register customer'),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openCashOperationFlow('deposit'),
                                    icon: const Icon(
                                      Icons.arrow_downward_rounded,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ui.textPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(color: ui.borderStrong),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    label: const Text('Deposit'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openCashOperationFlow('withdrawal'),
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ui.textPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(color: ui.borderStrong),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    label: const Text('Withdraw'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        ui: ui,
                        title: 'Float wallets',
                        emptyMessage: 'No agent wallets.',
                        items: _wallets,
                        builder: (wallet) => _listTile(
                          ui: ui,
                          title: _pickString([
                            wallet['name'],
                            wallet['wallet_type'],
                            'Wallet',
                          ]),
                          subtitle: _pickString([
                            wallet['status'],
                            wallet['currency'],
                          ]),
                          trailing: formatFinancialMoney(
                            _pickDouble([
                              wallet['balance'],
                              wallet['available_balance'],
                            ]),
                            _pickString([wallet['currency'], 'TZS']),
                            locale: 'en_US',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        ui: ui,
                        title: 'Cash activity',
                        emptyMessage: 'No cash activity.',
                        headerTrailing: Wrap(
                          spacing: 8,
                          children: [
                            _filterChip(
                              ui: ui,
                              label: 'All',
                              active: _transactionFilter == 'ALL',
                              onTap: () =>
                                  setState(() => _transactionFilter = 'ALL'),
                            ),
                            _filterChip(
                              ui: ui,
                              label: 'Deposit',
                              active: _transactionFilter == 'DEPOSIT',
                              onTap: () => setState(
                                () => _transactionFilter = 'DEPOSIT',
                              ),
                            ),
                            _filterChip(
                              ui: ui,
                              label: 'Withdraw',
                              active: _transactionFilter == 'WITHDRAW',
                              onTap: () => setState(
                                () => _transactionFilter = 'WITHDRAW',
                              ),
                            ),
                          ],
                        ),
                        items: _filteredTransactions,
                        builder: (tx) => _listTile(
                          ui: ui,
                          title: _pickString([
                            tx['service_type'],
                            tx['type'],
                            'Cash transaction',
                          ]),
                          subtitle: _pickString([
                            tx['status'],
                            tx['reference_id'],
                            tx['transaction_id'],
                          ]),
                          trailing: formatFinancialMoney(
                            _pickDouble([tx['amount']]),
                            _pickString([tx['currency'], 'TZS']),
                            locale: 'en_US',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        ui: ui,
                        title: 'Linked customers',
                        emptyMessage: 'No linked customers.',
                        items: _customers,
                        builder: (customer) => _listTile(
                          ui: ui,
                          title: _pickString([
                            customer['full_name'],
                            customer['customer_name'],
                            'Customer',
                          ]),
                          subtitle: _pickString([
                            customer['customer_customer_id'],
                            customer['relationship_type'],
                            customer['status'],
                          ]),
                          trailing: customer['commission_enabled'] == true
                              ? 'Commission on'
                              : '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        ui: ui,
                        title: 'Commission history',
                        emptyMessage: 'No commissions yet.',
                        headerTrailing: Wrap(
                          spacing: 8,
                          children: [
                            _filterChip(
                              ui: ui,
                              label: 'All',
                              active: _commissionFilter == 'ALL',
                              onTap: () =>
                                  setState(() => _commissionFilter = 'ALL'),
                            ),
                            _filterChip(
                              ui: ui,
                              label: 'Pending',
                              active: _commissionFilter == 'PENDING',
                              onTap: () =>
                                  setState(() => _commissionFilter = 'PENDING'),
                            ),
                            _filterChip(
                              ui: ui,
                              label: 'Paid',
                              active: _commissionFilter == 'PAID',
                              onTap: () =>
                                  setState(() => _commissionFilter = 'PAID'),
                            ),
                          ],
                        ),
                        items: _filteredCommissions,
                        builder: (commission) => _listTile(
                          ui: ui,
                          title: _pickString([
                            commission['commission_type'],
                            'Commission',
                          ]),
                          subtitle: _pickString([
                            commission['status'],
                            commission['source_transaction_id'],
                          ]),
                          trailing: formatFinancialMoney(
                            _pickDouble([commission['amount']]),
                            _pickString([commission['currency'], 'TZS']),
                            locale: 'en_US',
                          ),
                        ),
                      ),
                      if (_lastOperationPreview != null) ...[
                        const SizedBox(height: 14),
                        OrbiSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last preview',
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _lastOperationPreview.toString(),
                                style: TextStyle(
                                  color: ui.textMuted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _metric(OrbiUiTokens ui, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ui.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required OrbiUiTokens ui,
    required String title,
    required String emptyMessage,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) builder,
    Widget? headerTrailing,
  }) {
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: headerTrailing),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(emptyMessage, style: TextStyle(color: ui.textMuted))
          else
            ...items.take(8).map(builder),
        ],
      ),
    );
  }

  Widget _filterChip({
    required OrbiUiTokens ui,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ui.accentSoft : ui.cardMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? ui.borderStrong : ui.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _listTile({
    required OrbiUiTokens ui,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Expanded(
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
                Text(subtitle, style: TextStyle(color: ui.textMuted)),
              ],
            ),
          ),
          if (trailing.isNotEmpty)
            Text(
              trailing,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  String _pickString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Widget _agentProviderChoiceCard({
    required String provider,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final providerColor = _agentProviderColor(provider);
    final country = ProviderAssetResolver.resolveCountry(
      context.read<AuthController>(),
    );
    final assetCandidates = ProviderAssetResolver.movementAssetCandidates(
      country: country,
      flow: 'Withdraw',
      category: 'External Agents',
      providerName: provider,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: ui.card.withValues(alpha: 0.99),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? providerColor
                : ui.borderStrong.withValues(alpha: 0.72),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? providerColor : Colors.black).withValues(
                alpha: selected ? 0.10 : 0.04,
              ),
              blurRadius: selected ? 16 : 12,
              offset: const Offset(0, 8),
            ),
            if (selected)
              BoxShadow(
                color: providerColor.withValues(alpha: 0.10),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 88,
              child: _agentAssetPreview(
                candidates: assetCandidates,
                fallbackIcon: Icons.storefront_rounded,
                tint: ui.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? providerColor.withValues(alpha: 0.95)
                    : ui.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.15,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agentAssetPreview({
    required List<String> candidates,
    required IconData fallbackIcon,
    required Color tint,
    int index = 0,
  }) {
    return ProviderLogoImage(
      candidates: candidates.skip(index).toList(growable: false),
      placeholderColor: tint,
      placeholderIcon: fallbackIcon,
      placeholderLabel: 'Logo',
      debugPathLabel: candidates.isEmpty
          ? 'no asset candidate'
          : candidates.first,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  Color _agentProviderColor(String provider) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.contains('mix') ||
        normalized.contains('yas') ||
        normalized.contains('tigo')) {
      return const Color(0xFF1976D2);
    }
    if (normalized.contains('halotel')) {
      return const Color(0xFFF28C28);
    }
    if (normalized.contains('airtel')) return const Color(0xFFFF7043);
    if (normalized.contains('vodacom') ||
        normalized.contains('mpesa') ||
        normalized.contains('m-pesa')) {
      return const Color(0xFFE53935);
    }
    return OrbiTheme.uiOf(context).accent;
  }

  double _pickDouble(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('${value ?? ''}');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
