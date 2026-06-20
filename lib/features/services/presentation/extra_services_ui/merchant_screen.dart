import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/orbi_amount_field.dart';
import '../../../../core/widgets/orbi_background.dart';
import '../../../../core/widgets/orbi_orbit_loader.dart';
import '../../../../core/widgets/orbi_responsive.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../../core/widgets/orbi_state_card.dart';
import '../../../payment/data/merchant_service.dart';
import '../../data/service_actor_service.dart';

class MerchantScreen extends StatefulWidget {
  const MerchantScreen({super.key});

  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> {
  final ServiceActorService _service = ServiceActorService();
  final MerchantService _merchantService = MerchantService();

  bool _loading = true;
  bool _savingCustomer = false;
  String? _error;
  List<Map<String, dynamic>> _merchantAccounts = const [];
  List<Map<String, dynamic>> _wallets = const [];
  List<Map<String, dynamic>> _transactions = const [];
  List<Map<String, dynamic>> _customers = const [];
  Map<String, dynamic>? _lastPreview;
  String? _selectedMerchantAccountId;

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
      final results = await Future.wait<dynamic>([
        _merchantService.listMyMerchantAccounts(),
        _service.listMerchantWallets(),
        _service.listMerchantTransactions(),
        _service.listMerchantCustomers(),
      ]);
      if (!mounted) return;
      setState(() {
        _merchantAccounts = List<Map<String, dynamic>>.from(results[0] as List);
        _wallets = List<Map<String, dynamic>>.from(results[1] as List);
        _transactions = List<Map<String, dynamic>>.from(results[2] as List);
        _customers = List<Map<String, dynamic>>.from(results[3] as List);
        _selectedMerchantAccountId =
            _selectedMerchantAccountId ??
            _pickString([
              (results[0] as List).isNotEmpty
                  ? (results[0] as List).first['id']
                  : null,
            ]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? get _selectedMerchantAccount {
    if (_merchantAccounts.isEmpty) return null;
    final match = _merchantAccounts.where(
      (account) =>
          _pickString([account['id']]) == (_selectedMerchantAccountId ?? ''),
    );
    if (match.isNotEmpty) return match.first;
    return _merchantAccounts.first;
  }

  Future<void> _openMerchantAccountSetup() async {
    final businessNameController = TextEditingController();
    final ui = OrbiTheme.uiOf(context);

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
                      controller: businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (businessNameController.text
                                    .trim()
                                    .isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Enter business name.'),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => busy = true);
                                try {
                                  await _merchantService.createMerchantAccount({
                                    'business_name': businessNameController.text
                                        .trim(),
                                  });
                                  if (!mounted || !sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Merchant account created.',
                                      ),
                                    ),
                                  );
                                  await _load();
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(() => busy = false);
                                  }
                                }
                              },
                        child: Text(busy ? 'Creating...' : 'Create account'),
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

  Future<void> _openSettlementSetup(Map<String, dynamic> account) async {
    final settlement =
        ((account['merchant_settlements'] as List?)?.isNotEmpty ?? false)
        ? Map<String, dynamic>.from(
            (account['merchant_settlements'] as List).first as Map,
          )
        : <String, dynamic>{};
    final bankNameController = TextEditingController(
      text: _pickString([settlement['bank_name']]),
    );
    final bankAccountController = TextEditingController(
      text: _pickString([settlement['bank_account']]),
    );
    String schedule = _pickString([settlement['settlement_schedule'], 'daily']);
    final accountId = _pickString([account['id']]);
    final ui = OrbiTheme.uiOf(context);

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
                      controller: bankNameController,
                      decoration: const InputDecoration(labelText: 'Bank name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankAccountController,
                      decoration: const InputDecoration(
                        labelText: 'Bank account',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: schedule,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => schedule = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (accountId.isEmpty ||
                                    bankNameController.text.trim().isEmpty ||
                                    bankAccountController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter bank name and account.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => busy = true);
                                try {
                                  await _merchantService
                                      .updateMerchantSettlement(accountId, {
                                        'bank_name': bankNameController.text
                                            .trim(),
                                        'bank_account': bankAccountController
                                            .text
                                            .trim(),
                                        'settlement_schedule': schedule,
                                      });
                                  if (!mounted || !sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Settlement updated.'),
                                    ),
                                  );
                                  await _load();
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(() => busy = false);
                                  }
                                }
                              },
                        child: Text(busy ? 'Saving...' : 'Save settlement'),
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
                                    actorRole: 'MERCHANT',
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

  Future<void> _openMerchantPaymentFlow() async {
    if (_wallets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No merchant wallet.')));
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
            Future<void> previewPayment() async {
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
                preview = await _service.previewMerchantPayment({
                  'sourceWalletId': selectedWalletId,
                  'amount': amount,
                  'currency': currency,
                  'description': descriptionController.text.trim().isEmpty
                      ? 'Merchant payment'
                      : descriptionController.text.trim(),
                  'type': 'EXTERNAL_PAYMENT',
                });
                if (mounted) {
                  setState(() => _lastPreview = preview);
                }
              } finally {
                if (sheetContext.mounted) setSheetState(() => busy = false);
              }
            }

            Future<void> settlePayment() async {
              final amount = AmountInputFormatter.tryParse(
                amountController.text,
              );
              if (amount == null || amount <= 0) return;
              setSheetState(() => busy = true);
              try {
                await _service.settleMerchantPayment({
                  'sourceWalletId': selectedWalletId,
                  'amount': amount,
                  'currency': currency,
                  'description': descriptionController.text.trim().isEmpty
                      ? 'Merchant payment'
                      : descriptionController.text.trim(),
                  'type': 'EXTERNAL_PAYMENT',
                });
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment submitted.')),
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
                    const Text(
                      'Merchant payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedWalletId,
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
                          currency = _pickString([wallet['currency'], 'TZS']);
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
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ui.cardMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ui.border),
                        ),
                        child: Text(
                          preview.toString(),
                          style: TextStyle(color: ui.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : previewPayment,
                            child: Text(busy ? 'Working...' : 'Review'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : settlePayment,
                            child: const Text('Submit'),
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
      appBar: AppBar(title: const Text('Merchant')),
      body: OrbiBackground(
        child: OrbiResponsiveContent(
          child: _loading
              ? const OrbiOrbitLoadingPane(
                  label: 'Loading merchant desk',
                  centerIcon: Icons.point_of_sale_outlined,
                )
              : _error != null
              ? Center(
                  child: OrbiStateCard(
                    icon: Icons.sync_problem_outlined,
                    title: 'Could not load Merchant',
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
                              'Merchant',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Accounts, wallets, customers, and payments.',
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
                                _metric(ui, 'Start here', 'Onboard customer'),
                                _metric(ui, 'Payments', 'Create payment'),
                                _metric(ui, 'Setup', 'Accounts & settlement'),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _metric(
                                    ui,
                                    'Accounts',
                                    '${_merchantAccounts.length}',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _metric(
                                    ui,
                                    'Settlement wallets',
                                    '${_wallets.length}',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _metric(
                                    ui,
                                    'Linked customers',
                                    '${_customers.length}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _openCustomerRegistration,
                                  icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                  ),
                                  label: const Text('Onboard customer'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _merchantAccounts.isEmpty
                                      ? _openMerchantAccountSetup
                                      : () => _openSettlementSetup(
                                          _selectedMerchantAccount ??
                                              _merchantAccounts.first,
                                        ),
                                  icon: const Icon(
                                    Icons.account_balance_outlined,
                                  ),
                                  label: Text(
                                    _merchantAccounts.isEmpty
                                        ? 'Create account'
                                        : 'Settlement setup',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _openMerchantPaymentFlow,
                              icon: const Icon(Icons.point_of_sale_outlined),
                              label: const Text('Create payment'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_merchantAccounts.length > 1) ...[
                        OrbiSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected account',
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _pickString([
                                  _selectedMerchantAccount?['id'],
                                  _merchantAccounts.first['id'],
                                ]),
                                items: _merchantAccounts
                                    .map(
                                      (account) => DropdownMenuItem<String>(
                                        value: _pickString([account['id']]),
                                        child: Text(
                                          _pickString([
                                            account['business_name'],
                                            'Merchant account',
                                          ]),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(
                                    () => _selectedMerchantAccountId = value,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _section(
                        ui: ui,
                        title: 'Merchant accounts',
                        emptyMessage: 'No merchant accounts.',
                        items: _merchantAccounts,
                        builder: (account) {
                          final settlements =
                              (account['merchant_settlements'] as List?) ??
                              const [];
                          final settlement = settlements.isNotEmpty
                              ? Map<String, dynamic>.from(
                                  settlements.first as Map,
                                )
                              : const <String, dynamic>{};
                          return InkWell(
                            onTap: () => _openSettlementSetup(account),
                            borderRadius: BorderRadius.circular(16),
                            child: _listTile(
                              ui: ui,
                              title: _pickString([
                                account['business_name'],
                                account['name'],
                                'Merchant account',
                              ]),
                              subtitle: _pickString([
                                settlement['bank_name'],
                                settlement['settlement_schedule'],
                                account['status'],
                              ]),
                              trailing: account['status']?.toString() ?? '',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_selectedMerchantAccount != null) ...[
                        OrbiSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settlement and fees',
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Builder(
                                builder: (context) {
                                  final account = _selectedMerchantAccount!;
                                  final settlements =
                                      (account['merchant_settlements']
                                          as List?) ??
                                      const [];
                                  final fees =
                                      (account['merchant_fees'] as List?) ??
                                      const [];
                                  final settlement = settlements.isNotEmpty
                                      ? Map<String, dynamic>.from(
                                          settlements.first as Map,
                                        )
                                      : const <String, dynamic>{};
                                  final fee = fees.isNotEmpty
                                      ? Map<String, dynamic>.from(
                                          fees.first as Map,
                                        )
                                      : const <String, dynamic>{};
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _listTile(
                                        ui: ui,
                                        title: _pickString([
                                          settlement['bank_name'],
                                          'Settlement bank not set',
                                        ]),
                                        subtitle: _pickString([
                                          settlement['bank_account'],
                                          settlement['settlement_schedule'],
                                          'No payout details configured yet',
                                        ]),
                                        trailing: _pickString([
                                          settlement['settlement_schedule'],
                                        ]),
                                      ),
                                      _listTile(
                                        ui: ui,
                                        title: 'Fee profile',
                                        subtitle:
                                            'Rate ${_pickDouble([fee['transaction_fee_percent']]).toStringAsFixed(4)}%',
                                        trailing: formatCompactMoney(
                                          _pickDouble([fee['fixed_fee']]),
                                          _pickString([fee['currency'], 'TZS']),
                                          locale: 'en_US',
                                          compactFrom: kCompactMoneyThreshold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _section(
                        ui: ui,
                        title: 'Settlement wallets',
                        emptyMessage: 'No merchant wallets.',
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
                          trailing: formatCompactMoney(
                            _pickDouble([
                              wallet['balance'],
                              wallet['available_balance'],
                            ]),
                            _pickString([wallet['currency'], 'TZS']),
                            locale: 'en_US',
                            compactFrom: kCompactMoneyThreshold,
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
                              ? 'Tracked'
                              : '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        ui: ui,
                        title: 'Payment history',
                        emptyMessage: 'No payments yet.',
                        items: _transactions,
                        builder: (tx) => _listTile(
                          ui: ui,
                          title: _pickString([
                            tx['service_type'],
                            tx['type'],
                            'Transaction',
                          ]),
                          subtitle: _pickString([
                            tx['status'],
                            tx['reference_id'],
                            tx['transaction_id'],
                          ]),
                          trailing: formatCompactMoney(
                            _pickDouble([tx['amount']]),
                            _pickString([tx['currency'], 'TZS']),
                            locale: 'en_US',
                            compactFrom: kCompactMoneyThreshold,
                          ),
                        ),
                      ),
                      if (_lastPreview != null) ...[
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
                                _lastPreview.toString(),
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
  }) {
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
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

  double _pickDouble(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('${value ?? ''}');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
