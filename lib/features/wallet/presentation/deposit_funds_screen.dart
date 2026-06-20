import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_card_styles.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/provider_asset_resolver.dart';
import '../../../core/utils/provider_presentation_resolver.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/provider_logo_image.dart';
import '../../payment/data/gateway_payment_models.dart';
import '../../payment/data/gateway_payment_service.dart';
import '../../auth/state/auth_controller.dart';
import '../data/deposit_service.dart';
import '../data/wallet_service.dart';

class DepositFundsScreen extends StatefulWidget {
  const DepositFundsScreen({super.key});

  @override
  State<DepositFundsScreen> createState() => _DepositFundsScreenState();
}

class _DepositFundsScreenState extends State<DepositFundsScreen> {
  final GatewayPaymentService _gatewayService = GatewayPaymentService();
  final WalletService _walletService = WalletService();
  final DepositService _depositService = DepositService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _loading = true;
  bool _loadingMovements = false;
  bool _submitting = false;
  String? _error;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  String _selectedCategory = 'mobile';
  List<GatewayProvider> _providers = const [];
  List<Map<String, dynamic>> _movements = const [];
  GatewayProvider? _selectedProvider;
  Map<String, dynamic>? _operatingWallet;
  Map<String, dynamic>? _lastIntent;

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _gatewayService.listProviders(
          countryCode: 'TZ',
          currency: 'TZS',
          operation: 'COLLECTION_REQUEST',
        ),
        _walletService.getWallets(),
        _depositService.listDepositMovements(),
      ]);
      if (!mounted) return;
      final providers =
          (results[0] as List<GatewayProvider>)
              .where((provider) => provider.isActive)
              .toList()
            ..sort(_providerSort);
      final wallets = List<Map<String, dynamic>>.from(
        results[1] as List<Map<String, dynamic>>,
      );
      final movements =
          List<Map<String, dynamic>>.from(
            results[2] as List<Map<String, dynamic>>,
          )..sort(
            (a, b) =>
                _asDate(b['created_at']).compareTo(_asDate(a['created_at'])),
          );
      final operatingWallet = _resolveOperatingWallet(wallets);
      final defaultProvider = providers.firstWhere(
        (provider) => _matchesCategory(provider, _selectedCategory),
        orElse: () => providers.isEmpty
            ? const GatewayProvider(
                id: '',
                name: '',
                brandName: '',
                type: '',
                group: '',
                logicType: '',
                status: '',
                supportedCurrencies: [],
                icon: null,
                color: null,
                checkoutMode: null,
                channels: [],
                sortOrder: 0,
                metadata: {},
              )
            : providers.first,
      );
      setState(() {
        _providers = providers;
        _movements = movements;
        _operatingWallet = operatingWallet;
        _selectedProvider = defaultProvider.id.isEmpty ? null : defaultProvider;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = UserFacingError.from(
          error,
          fallback: _t(
            'Unable to load deposit providers right now.',
            'Imeshindikana kupakia watoa huduma wa amana kwa sasa.',
          ),
        );
      });
    }
  }

  int _providerSort(GatewayProvider a, GatewayProvider b) {
    final group = a.groupLabel.compareTo(b.groupLabel);
    if (group != 0) return group;
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    return a.brandLabel.compareTo(b.brandLabel);
  }

  Map<String, dynamic>? _resolveOperatingWallet(
    List<Map<String, dynamic>> wallets,
  ) {
    for (final wallet in wallets) {
      if (_isOperatingWallet(wallet)) return wallet;
    }
    for (final wallet in wallets) {
      if (_walletId(wallet).isNotEmpty && !_isEscrowWallet(wallet)) {
        return wallet;
      }
    }
    return null;
  }

  bool _isOperatingWallet(Map<String, dynamic> wallet) {
    final type = _pickString([
      wallet['wallet_type'],
      wallet['type'],
      wallet['management_tier'],
      wallet['vault_role'],
      wallet['role'],
    ]).toLowerCase();
    final name = _pickString([
      wallet['name'],
      wallet['wallet_name'],
      wallet['title'],
    ]).toLowerCase();
    return wallet['is_primary'] == true ||
        wallet['isPrimary'] == true ||
        type.contains('operating') ||
        type.contains('internal_main') ||
        name.contains('operating') ||
        name.contains('main default') ||
        name.contains('internal vault') ||
        name.contains('dilpesa');
  }

  bool _isEscrowWallet(Map<String, dynamic> wallet) {
    final type = _pickString([
      wallet['wallet_type'],
      wallet['type'],
      wallet['vault_role'],
      wallet['role'],
    ]).toLowerCase();
    final name = _pickString([
      wallet['name'],
      wallet['wallet_name'],
      wallet['title'],
    ]).toLowerCase();
    final account = _pickString([
      wallet['accountNumber'],
      wallet['account_number'],
      if (wallet['metadata'] is Map)
        (wallet['metadata'] as Map)['account_number'],
    ]).toUpperCase();
    return type.contains('internal_transfer') ||
        name.contains('paysafe') ||
        account.startsWith('ESC-');
  }

  bool _matchesCategory(GatewayProvider provider, String category) {
    final group = provider.groupLabel.toLowerCase();
    final type = provider.type.toLowerCase();
    final channels = provider.channels.map((c) => c.toLowerCase()).toSet();

    bool hasChannel(String value) => channels.contains(value);

    switch (category) {
      case 'mobile':
        return group == 'mobile' ||
            type.contains('mobile') ||
            provider.supportsMobileMoney ||
            hasChannel('mobile_money');
      case 'bank':
        return group == 'bank' ||
            type.contains('bank') ||
            provider.supportsBank ||
            hasChannel('bank_transfer') ||
            hasChannel('bank_account');
      case 'cards':
        return provider.supportsCards ||
            type.contains('card') ||
            hasChannel('card');
      case 'ewallets':
        return hasChannel('wallet') ||
            hasChannel('paypal') ||
            type.contains('wallet') ||
            type.contains('paypal');
      case 'crypto':
        return provider.supportsCrypto ||
            type.contains('crypto') ||
            hasChannel('crypto');
      default:
        return true;
    }
  }

  String _providerRail(GatewayProvider provider) {
    if (_matchesCategory(provider, 'mobile')) return 'MOBILE_MONEY';
    if (_matchesCategory(provider, 'bank')) return 'BANK';
    if (_matchesCategory(provider, 'cards')) return 'CARD_GATEWAY';
    if (_matchesCategory(provider, 'crypto')) return 'CRYPTO';
    return 'WALLET';
  }

  String _walletId(Map<String, dynamic> wallet) =>
      _pickString([wallet['wallet_id'], wallet['id']]);

  double _walletBalance(Map<String, dynamic> wallet) {
    for (final value in [
      wallet['available_balance'],
      wallet['balance'],
      wallet['ledger_balance'],
      wallet['amount'],
    ]) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '').trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  String _walletCurrency(Map<String, dynamic> wallet) {
    return resolveCurrencyCode([
      wallet['currency'],
      wallet['currency_code'],
      wallet['asset_currency'],
    ]);
  }

  String get _amountCurrencyCode {
    final wallet = _operatingWallet;
    if (wallet == null) return 'TZS';
    final code = _walletCurrency(wallet);
    return code.isEmpty ? 'TZS' : code;
  }

  String _walletLabel(Map<String, dynamic> wallet) {
    final name = _pickString([
      wallet['name'],
      wallet['wallet_name'],
      wallet['title'],
    ], fallback: _t('Operating Wallet', 'Walleti ya Uendeshaji'));
    final amount = _walletBalance(wallet);
    final currency = _walletCurrency(wallet);
    final hidden = context.read<AppSettingsController>().hideBalances;
    final balance = hidden
        ? AppSettingsController.hiddenBalanceText
        : formatAppBalanceAmount(amount, currency, locale: _localeTag);
    return '$name • $balance';
  }

  String get _localeTag {
    final locale = Localizations.localeOf(context);
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }

  String _pickString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  DateTime _asDate(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _movementStatus(Map<String, dynamic> movement) {
    return _pickString([
      movement['status'],
      movement['state'],
    ], fallback: 'initiated').toLowerCase();
  }

  Color _movementStatusColor(String status, OrbiUiTokens ui) {
    switch (status) {
      case 'completed':
      case 'settled':
        return ui.success;
      case 'failed':
      case 'reversed':
        return ui.danger;
      case 'processing':
      case 'pending':
        return ui.warning;
      default:
        return ui.accent;
    }
  }

  Future<void> _refreshMovements() async {
    setState(() => _loadingMovements = true);
    try {
      final movements = await _depositService.listDepositMovements();
      if (!mounted) return;
      movements.sort(
        (a, b) => _asDate(b['created_at']).compareTo(_asDate(a['created_at'])),
      );
      setState(() => _movements = movements);
    } catch (_) {
      // Keep the current list when refresh fails.
    } finally {
      if (mounted) setState(() => _loadingMovements = false);
    }
  }

  Future<void> _submit() async {
    final provider = _selectedProvider;
    final wallet = _operatingWallet;
    if (provider == null || wallet == null) return;
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack(
        _t('Enter a valid deposit amount.', 'Weka kiasi sahihi cha amana.'),
      );
      return;
    }
    final accountInput = _accountController.text.trim();
    if (accountInput.isEmpty) {
      _showSnack(
        _t(
          'Enter the payer account or phone number.',
          'Weka akaunti au namba ya simu ya mteja.',
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _depositService.createDepositIntent(
        targetWalletId: _walletId(wallet),
        providerId: provider.id,
        rail: _providerRail(provider),
        amount: amount,
        currency: _walletCurrency(wallet),
        description: _noteController.text.trim(),
        metadata: {
          'deposit_category': _selectedCategory,
          'provider_name': provider.brandLabel,
          'provider_group': provider.groupLabel,
          'payment_rail_capability_code': provider.id,
          if (provider.metadata['payment_rail_capability'] is Map)
            'payment_rail_capability':
                provider.metadata['payment_rail_capability'],
          'payer_input': accountInput,
          'deposit_fee_policy': 'FREE',
        },
      );
      if (!mounted) return;
      setState(() => _lastIntent = result);
      await _refreshMovements();
      _showSnack(
        _t(
          'Deposit request created. Waiting for provider confirmation.',
          'Ombi la amana limeundwa. Tunasubiri uthibitisho wa mtoa huduma.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        UserFacingError.from(
          error,
          fallback: _t(
            'Unable to create the deposit request right now.',
            'Imeshindikana kuunda ombi la amana kwa sasa.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final raw = message.toLowerCase();
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: _isSw,
        fallback: message,
      );
      _statusTone =
          raw.contains('error') ||
              raw.contains('failed') ||
              raw.contains('unable') ||
              raw.contains('invalid') ||
              raw.contains('required') ||
              raw.contains('not available')
          ? OrbiStatusTone.error
          : OrbiStatusTone.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final filteredProviders = _providers
        .where((provider) => _matchesCategory(provider, _selectedCategory))
        .toList();
    final provider =
        _selectedProvider != null &&
            filteredProviders.any((item) => item.id == _selectedProvider!.id)
        ? _selectedProvider
        : (filteredProviders.isEmpty ? null : filteredProviders.first);
    if (provider != _selectedProvider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedProvider = provider);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(_t('Deposit Funds', 'Weka Amana'))),
      body: OrbiLoadingOverlay(
        loading: _submitting,
        message: _submitting
            ? _t('Creating deposit...', 'Inaandaa amana...')
            : _t('Refreshing deposit status...', 'Inasasisha hali ya amana...'),
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        child: OrbiBackground(
          padding: EdgeInsets.zero,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: OrbiResponsive.pagePadding(context, top: 14, bottom: 20),
              children: [
                OrbiResponsiveContent(
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heroCard(ui),
                            const SizedBox(height: 16),
                            _categorySelector(ui),
                            const SizedBox(height: 14),
                            _providersTable(filteredProviders, ui),
                            const SizedBox(height: 16),
                            _depositComposer(provider, ui),
                            if (_lastIntent != null) ...[
                              const SizedBox(height: 16),
                              _intentCard(_lastIntent!, ui),
                            ],
                            const SizedBox(height: 16),
                            _movementsCard(ui),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(OrbiUiTokens ui) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: OrbiCardStyles.primaryHeroDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Deposit to your wallet', 'Weka amana kwenye walleti yako'),
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Choose a mobile money or bank provider, then enter the sender details and amount.',
              'Chagua mtoa huduma wa simu au benki, kisha weka taarifa za mtumaji na kiasi.',
            ),
            style: TextStyle(color: ui.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ui.cardMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ui.border),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: ui.iconMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _operatingWallet == null
                        ? _t(
                            'No operating wallet available.',
                            'Hakuna walleti ya uendeshaji inayopatikana.',
                          )
                        : _walletLabel(_operatingWallet!),
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tipPill(
                ui: ui,
                icon: Icons.phone_android_rounded,
                label: _t(
                  'Mobile: use the sender phone number',
                  'Simu: tumia namba ya mtumaji',
                ),
              ),
              _tipPill(
                ui: ui,
                icon: Icons.account_balance_rounded,
                label: _t(
                  'Bank: use the sending account',
                  'Benki: tumia akaunti inayotuma',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipPill({
    required OrbiUiTokens ui,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ui.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySelector(OrbiUiTokens ui) {
    final categories = const [
      ('mobile', 'Mobile Money', 'M-Pesa / Mixx / Airtel'),
      ('bank', 'Bank', 'Bank transfer / account'),
      ('cards', 'Cards', 'Debit / credit / gateway'),
      ('ewallets', 'E-Wallets', 'PayPal / wallet rails'),
      ('crypto', 'Crypto', 'Crypto networks'),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final columns = ((width - 32) / 116).floor().clamp(3, 4);
    const spacing = 10.0;
    final itemWidth = ((width - 32 - (spacing * (columns - 1))) / columns)
        .clamp(0, 140)
        .toDouble();
    IconData iconFor(String key) {
      switch (key) {
        case 'mobile':
          return Icons.phone_android_rounded;
        case 'bank':
          return Icons.account_balance_rounded;
        case 'cards':
          return Icons.credit_card_rounded;
        case 'ewallets':
          return Icons.account_balance_wallet_rounded;
        case 'crypto':
          return Icons.currency_bitcoin_rounded;
        default:
          return Icons.hub_rounded;
      }
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: categories.map((entry) {
        final selected = _selectedCategory == entry.$1;
        return SizedBox(
          width: itemWidth,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              _selectedCategory = entry.$1;
              _selectedProvider = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                color: selected
                    ? Color.alphaBlend(
                        ui.accent.withValues(alpha: 0.08),
                        ui.card.withValues(alpha: 0.995),
                      )
                    : ui.card.withValues(alpha: 0.99),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? ui.accent : ui.border,
                  width: selected ? 1.35 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? ui.accent.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: selected ? 14 : 10,
                    offset: Offset(0, selected ? 8 : 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    width: selected ? 32 : 18,
                    decoration: BoxDecoration(
                      color: selected
                          ? ui.accent.withValues(alpha: 0.94)
                          : ui.border.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ui.accent.withValues(
                        alpha: selected ? 0.14 : 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconFor(entry.$1), size: 16, color: ui.accent),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? ui.accent : ui.textMuted,
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _providersTable(List<GatewayProvider> providers, OrbiUiTokens ui) {
    if (providers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ui.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ui.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Available Providers', 'Watoa Huduma Waliopo'),
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'No providers are available for this category right now. Try Mobile Money or Bank.',
                'Hakuna watoa huduma wa kundi hili kwa sasa. Jaribu Simu au Benki.',
              ),
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final columns = ((width - 60) / 112).floor().clamp(3, 4);
    const spacing = 10.0;
    final itemWidth = ((width - 60 - (spacing * (columns - 1))) / columns)
        .clamp(0, 140)
        .toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Available Providers', 'Watoa Huduma Waliopo'),
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'Tap one provider to continue with your deposit request.',
              'Gusa mtoa huduma mmoja kuendelea na ombi la amana.',
            ),
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: providers
                .map(
                  (provider) => SizedBox(
                    width: itemWidth,
                    child: _providerChoiceCard(provider, ui),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _providerChoiceCard(GatewayProvider provider, OrbiUiTokens ui) {
    final selected = _selectedProvider?.id == provider.id;
    final providerColor = _providerTint(provider, ui);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                providerColor.withValues(alpha: 0.08),
                ui.card.withValues(alpha: 0.996),
              )
            : ui.card.withValues(alpha: 0.995),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? providerColor.withValues(alpha: 0.52)
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
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _selectedProvider = provider),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 3,
                  width: selected ? 32 : 18,
                  margin: const EdgeInsets.only(left: 2, bottom: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? providerColor.withValues(alpha: 0.94)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: _ProviderBadge(
                    provider: provider,
                    size: 70,
                    tintOverride: providerColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  provider.brandLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? providerColor.withValues(alpha: 0.95)
                        : ui.textPrimary,
                    fontSize: 10.3,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.groupLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _providerTint(GatewayProvider provider, OrbiUiTokens ui) {
    return ProviderPresentationResolver.resolveGatewayColor(
      provider,
      ui.accent,
    );
  }

  Widget _depositComposer(GatewayProvider? provider, OrbiUiTokens ui) {
    final providerAccent = provider == null
        ? ui.iconMuted
        : _providerTint(provider, ui);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: providerAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Create Deposit Request', 'Unda Ombi la Amana'),
            style: TextStyle(
              color: providerAccent.withValues(alpha: 0.96),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          OrbiAmountField(
            controller: _amountController,
            inputFormatters: [AmountInputFormatter()],
            label: _t('Amount', 'Kiasi'),
            currency: resolveCurrencyDisplaySymbol(_amountCurrencyCode),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountController,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9+_\-@.]')),
            ],
            decoration: InputDecoration(
              labelText: _accountLabel(),
              helperText: _accountHelperText(),
              prefixIcon: Icon(_accountIcon()),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _t('Description (optional)', 'Maelezo (si lazima)'),
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _summaryLine(
            ui,
            _t('Selected provider', 'Mtoa huduma aliyechaguliwa'),
            provider?.brandLabel ?? _t('Not selected', 'Hajachaguliwa'),
            valueColor: provider == null ? null : providerAccent,
          ),
          const SizedBox(height: 8),
          _summaryLine(
            ui,
            _t('Target wallet', 'Walleti lengwa'),
            _operatingWallet == null
                ? _t('Unavailable', 'Haipatikani')
                : _walletLabel(_operatingWallet!),
          ),
          const SizedBox(height: 12),
          _depositSummaryCard(ui, providerAccent, provider),
          const SizedBox(height: 16),
          _depositPrimaryActionButton(
            ui: ui,
            accent: providerAccent,
            onPressed:
                _submitting || provider == null || _operatingWallet == null
                ? null
                : _submit,
            icon: Icons.add_card_rounded,
            label: _t('Create Deposit Intent', 'Unda Intent ya Amana'),
          ),
        ],
      ),
    );
  }

  Widget _intentCard(Map<String, dynamic> intent, OrbiUiTokens ui) {
    final movement = intent['movement'] is Map
        ? Map<String, dynamic>.from(intent['movement'] as Map)
        : <String, dynamic>{};
    final instructions = intent['instructions'] is Map
        ? Map<String, dynamic>.from(intent['instructions'] as Map)
        : <String, dynamic>{};
    final reference = _pickString([
      instructions['reference'],
      movement['external_reference'],
    ]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.successSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Deposit Request Ready', 'Ombi la amana liko tayari'),
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _summaryLine(ui, _t('Reference', 'Rejea'), reference),
          const SizedBox(height: 8),
          _summaryLine(
            ui,
            _t('Status', 'Hali'),
            _pickString([movement['status']], fallback: 'initiated'),
          ),
          const SizedBox(height: 8),
          _summaryLine(
            ui,
            _t('Channel', 'Njia'),
            _pickString([instructions['channel']], fallback: 'NETWORK_DEPOSIT'),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'Use this reference to complete the deposit. Your operating wallet updates after confirmation.',
              'Tumia rejea hii kukamilisha amana. Walleti ya operating itaongezeka baada ya uthibitisho.',
            ),
            style: TextStyle(color: ui.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _movementsCard(OrbiUiTokens ui) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t(
                    'Recent Deposit Activity',
                    'Shughuli za Amana za Hivi Karibuni',
                  ),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingMovements ? null : _refreshMovements,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_movements.isEmpty)
            Text(
              _t(
                'No deposit activity yet. New deposit requests will appear here.',
                'Bado hakuna shughuli ya amana. Maombi mapya ya amana yataonekana hapa.',
              ),
              style: TextStyle(color: ui.textMuted, height: 1.4),
            )
          else
            ..._movements.take(8).map((movement) {
              final status = _movementStatus(movement);
              final statusColor = _movementStatusColor(status, ui);
              final currency = resolveCurrencyCode([
                movement['currency'],
                movement['currency_code'],
              ]);
              final grossAmount =
                  double.tryParse((movement['gross_amount'] ?? 0).toString()) ??
                  0;
              final reference = _pickString([
                movement['external_reference'],
                movement['source_external_ref'],
                movement['id'],
              ]);
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ui.cardMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ui.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.download_done_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: MoneyText(
                                  value: formatAppBalanceAmount(
                                    grossAmount,
                                    currency,
                                    locale: _localeTag,
                                  ),
                                  mainFontSize: 14,
                                  sideFontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  mainColor: ui.textPrimary,
                                  sideColor: ui.textMuted,
                                  fitToWidth: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: ui.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _pickString([
                                    movement['description'],
                                  ], fallback: _t('Deposit', 'Amana')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_t('Reference', 'Rejea')}: $reference',
                            style: TextStyle(color: ui.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _asDate(
                              movement['created_at'],
                            ).toLocal().toString(),
                            style: TextStyle(color: ui.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _summaryLine(
    OrbiUiTokens ui,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: TextStyle(color: ui.textMuted, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? ui.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _depositSummaryCard(
    OrbiUiTokens ui,
    Color providerAccent,
    GatewayProvider? provider,
  ) {
    final amount = _amountController.text.trim();
    final account = _accountController.text.trim();
    final walletLabel = _operatingWallet == null
        ? _t('Unavailable', 'Haipatikani')
        : _walletLabel(_operatingWallet!);
    final categoryLabel = switch (_selectedCategory) {
      'mobile' => 'Mobile Money',
      'bank' => 'Bank',
      'cards' => _t('Card', 'Kadi'),
      'crypto' => 'Crypto',
      _ => _t('E-Wallet', 'E-Wallet'),
    };
    final rows = <({String label, String value})>[
      (label: _t('Route', 'Njia'), value: categoryLabel),
      (
        label: _t('Provider', 'Mtoa huduma'),
        value: provider?.brandLabel ?? _t('Not selected', 'Hajachaguliwa'),
      ),
      (label: _t('Sender', 'Mtumaji'), value: account.isEmpty ? '--' : account),
      (label: _t('Amount', 'Kiasi'), value: amount.isEmpty ? '--' : amount),
      (label: _t('Target wallet', 'Walleti lengwa'), value: walletLabel),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: providerAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: providerAccent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: providerAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_accountIcon(), color: providerAccent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('Deposit summary', 'Muhtasari wa amana'),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _accountLabel() {
    switch (_selectedCategory) {
      case 'mobile':
        return _t('Payer phone number', 'Namba ya simu ya mteja');
      case 'bank':
        return _t('Payer bank account', 'Akaunti ya benki ya mteja');
      case 'cards':
        return _t('Card alias / token', 'Alias / token ya kadi');
      case 'crypto':
        return _t('Wallet address / memo', 'Anwani ya wallet / memo');
      default:
        return _t('Payer account or handle', 'Akaunti au handle ya mteja');
    }
  }

  String _accountHelperText() {
    switch (_selectedCategory) {
      case 'mobile':
        return _t(
          'Use the Mobile Money number that will send the deposit.',
          'Tumia namba ya Mobile Money itakayotuma amana.',
        );
      case 'bank':
        return _t(
          'Use the bank account name or number that will send the deposit.',
          'Tumia jina au namba ya akaunti ya benki itakayotuma amana.',
        );
      case 'cards':
        return _t(
          'Use the saved card alias or provider token for this deposit.',
          'Tumia alias ya kadi au token ya mtoa huduma kwa amana hii.',
        );
      case 'crypto':
        return _t(
          'Use the wallet address or memo that will fund the deposit.',
          'Tumia anwani ya wallet au memo itakayofadhili amana hii.',
        );
      default:
        return _t(
          'Use the wallet handle, email, or account used with this provider.',
          'Tumia handle ya wallet, barua pepe, au akaunti inayotumika na mtoa huduma huyu.',
        );
    }
  }

  IconData _accountIcon() {
    switch (_selectedCategory) {
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'cards':
        return Icons.credit_card_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

Widget _depositPrimaryActionButton({
  required OrbiUiTokens ui,
  required Color accent,
  required VoidCallback? onPressed,
  required IconData icon,
  required String label,
}) {
  return SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ui.cardStrong,
        disabledForegroundColor: ui.textSoft,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({
    required this.provider,
    this.size = 32,
    this.tintOverride,
  });

  final GatewayProvider provider;
  final double size;
  final Color? tintOverride;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final country = ProviderAssetResolver.resolveCountry(
      context.read<AuthController>(),
    );
    final category = _movementCategory(provider);
    final assetCandidates = ProviderAssetResolver.movementAssetCandidates(
      country: country,
      flow: 'Deposit',
      category: category,
      providerName: provider.brandLabel,
    );
    return SizedBox(
      width: size,
      height: size,
      child: _providerAssetOrIcon(
        ui: ui,
        assetCandidates: assetCandidates,
        icon: _iconForProvider(provider),
        tint: tintOverride ?? _providerTint(provider, ui),
      ),
    );
  }

  String _movementCategory(GatewayProvider provider) {
    final type =
        '${provider.groupLabel} ${provider.type} ${provider.brandLabel}'
            .toLowerCase();
    if (type.contains('bank')) return 'Banks';
    return 'Mobile Money';
  }

  Widget _providerAssetOrIcon({
    required OrbiUiTokens ui,
    required List<String> assetCandidates,
    required IconData icon,
    required Color tint,
    int index = 0,
  }) {
    return ProviderLogoImage(
      candidates: assetCandidates.skip(index).toList(growable: false),
      placeholderColor: tint,
      placeholderIcon: icon,
      placeholderLabel: 'Logo',
      debugPathLabel: assetCandidates.isEmpty
          ? 'no asset candidate'
          : assetCandidates.first,
      padding: const EdgeInsets.all(5),
    );
  }

  Color _providerTint(GatewayProvider provider, OrbiUiTokens ui) {
    return ProviderPresentationResolver.resolveGatewayColor(
      provider,
      ui.accent,
    );
  }

  IconData _iconForProvider(GatewayProvider provider) {
    return ProviderPresentationResolver.resolveGatewayIcon(provider);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: ui.iconMuted),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: ui.textMuted, height: 1.4)),
          const SizedBox(height: 12),
          _secondaryActionButton(
            ui: ui,
            onPressed: onRetry,
            icon: Icons.refresh_rounded,
            label:
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                    'sw'
                ? 'Jaribu tena'
                : 'Retry',
          ),
        ],
      ),
    );
  }

  Widget _secondaryActionButton({
    required OrbiUiTokens ui,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: ui.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: ui.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
