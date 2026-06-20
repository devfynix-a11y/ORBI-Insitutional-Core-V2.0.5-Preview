import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/theme/orbi_card_styles.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/provider_asset_resolver.dart';
import '../../../core/utils/provider_presentation_resolver.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/service_asset_icon.dart';
import '../../../core/widgets/provider_logo_image.dart';
import '../../auth/state/auth_controller.dart';
import '../../payment/data/gateway_payment_models.dart';
import '../../payment/data/gateway_payment_service.dart';
import '../data/wallet_service.dart';

const Color _linkWalletAccent = Color(0xFF14B8A6);

class LinkExternalWalletScreen extends StatefulWidget {
  const LinkExternalWalletScreen({
    super.key,
    this.sessionCurrency,
    this.onWalletLinked,
  });

  final String? sessionCurrency;
  final Future<void> Function()? onWalletLinked;

  @override
  State<LinkExternalWalletScreen> createState() =>
      _LinkExternalWalletScreenState();
}

class _LinkExternalWalletScreenState extends State<LinkExternalWalletScreen> {
  final GatewayPaymentService _gatewayService = GatewayPaymentService();
  final WalletService _walletService = WalletService();

  bool _loading = true;
  bool _actionLoading = false;
  String? _actionMessage;
  String? _error;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  List<GatewayProvider> _providers = const [];
  String _selectedCategory = 'all';

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  String get _sessionCurrency {
    final provided = (widget.sessionCurrency ?? '').trim().toUpperCase();
    if (provided.isNotEmpty) return provided;

    final session = context.read<AuthController>().session;
    final user = session['user'];
    if (user is Map) {
      for (final key in const [
        'currency',
        'currency_code',
        'preferred_currency',
      ]) {
        final value = (user[key] ?? '').toString().trim().toUpperCase();
        if (value.isNotEmpty) return value;
      }
    }
    for (final key in const ['currency', 'currency_code']) {
      final value = (session[key] ?? '').toString().trim().toUpperCase();
      if (value.isNotEmpty) return value;
    }
    return 'TZS';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProviders());
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final providers = await _gatewayService.listProviders();
      if (!mounted) return;
      providers.sort(_providerSort);
      setState(() {
        _providers = providers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = UserFacingError.from(
          error,
          fallback: _t(
            'Unable to load available providers. Please try again.',
            'Imeshindikana kupakia watoa huduma. Tafadhali jaribu tena.',
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

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final canPop = Navigator.canPop(context);
    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(_t('Link wallet', 'Unganisha walleti')),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: OrbiLoadingOverlay(
        loading: _actionLoading,
        message:
            _actionMessage ??
            _t('Loading providers...', 'Inapakia watoa huduma...'),
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinkWalletIntro(
                    title: _t('Connect a wallet', 'Unganisha walleti'),
                    message: _t(
                      'Choose an approved bank, mobile money, card, or wallet provider when it becomes available.',
                      'Chagua benki, mobile money, kadi, au walleti iliyoidhinishwa itakapopatikana.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CategorySelector(
                    selected: _selectedCategory,
                    onSelected: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 12),
                  _ProviderCountStrip(
                    visibleCount: _visibleProviderCount,
                    totalCount: _providers
                        .where((provider) => provider.isActive)
                        .length,
                    loading: _loading,
                    label: _t('Providers', 'Watoa huduma'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody(ui)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(OrbiUiTokens ui) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              _t('Loading providers...', 'Inapakia watoa huduma...'),
              style: TextStyle(color: ui.textMuted),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: _t('Provider load failed', 'Imeshindikana'),
        message: _error,
        onRetry: _loadProviders,
      );
    }

    final active = _providers.where((provider) => provider.isActive).toList();
    final filtered = active
        .where((provider) => _matchesCategory(provider, _selectedCategory))
        .toList();
    final visible = filtered.isEmpty && active.isNotEmpty ? active : filtered;

    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: _t('No linkable wallets yet', 'Hakuna walleti za kuunganisha'),
        message: _t(
          'No active bank, mobile money, card, or wallet provider is configured for linking yet.',
          'Hakuna mtoa huduma wa benki, mobile money, kadi, au walleti aliyesanidiwa kwa kuunganisha bado.',
        ),
        onRetry: _loadProviders,
      );
    }

    return _ProviderTable(
      providers: visible,
      onSelect: (provider) => _openLinkSheet(provider),
    );
  }

  int get _visibleProviderCount {
    final active = _providers.where((provider) => provider.isActive).toList();
    if (_selectedCategory == 'all') return active.length;
    final filtered = active
        .where((provider) => _matchesCategory(provider, _selectedCategory))
        .length;
    return filtered == 0 && active.isNotEmpty ? active.length : filtered;
  }

  bool _matchesCategory(GatewayProvider provider, String category) {
    if (category == 'all') return true;
    final group = provider.groupLabel.toLowerCase();
    final type = provider.type.toLowerCase();
    final channels = provider.channels.map((c) => c.toLowerCase()).toSet();

    bool hasChannel(String value) => channels.contains(value);

    switch (category) {
      case 'mobile':
        return group == 'mobile' ||
            type.contains('mobile') ||
            hasChannel('mobile_money');
      case 'bank':
        return group == 'bank' ||
            type.contains('bank') ||
            hasChannel('bank_transfer') ||
            hasChannel('bank_account');
      case 'crypto':
        return group == 'crypto' ||
            type.contains('crypto') ||
            hasChannel('crypto');
      case 'cards':
        return type.contains('card') ||
            hasChannel('card') ||
            (group == 'gateways' && hasChannel('card'));
      case 'ewallets':
        return hasChannel('paypal') ||
            hasChannel('wallet') ||
            hasChannel('checkout_link') ||
            group == 'gateways';
      default:
        return true;
    }
  }

  Future<void> _openLinkSheet(GatewayProvider provider) async {
    final ui = OrbiTheme.uiOf(context);
    final providerAccent = _ProviderRow._providerColorStatic(provider, ui);
    final nameController = TextEditingController(text: provider.brandLabel);
    final accountController = TextEditingController();
    final currencies = provider.supportedCurrencies.isNotEmpty
        ? provider.supportedCurrencies
        : [_sessionCurrency];
    String selectedCurrency = currencies.first;
    final categoryKey = _selectedCategory;
    final accountLabel = _accountLabel(categoryKey);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            String accountPreview = _maskAccountInput(
              categoryKey,
              accountController.text.trim(),
            );
            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: providerAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: providerAccent.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ProviderIconBadge(provider: provider, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _t(
                                  'Link ${provider.brandLabel}',
                                  'Unganisha ${provider.brandLabel}',
                                ),
                                style: TextStyle(
                                  color: providerAccent.withValues(alpha: 0.96),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nameController,
                          decoration: _fieldDecoration(
                            ui,
                            _t('Wallet label', 'Jina la akaunti'),
                            Icons.account_balance_wallet_outlined,
                            accent: providerAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: accountController,
                          keyboardType: _accountKeyboardType(categoryKey),
                          inputFormatters: _accountFormatters(categoryKey),
                          maxLength: _accountMaxLength(categoryKey),
                          onChanged: (value) => setSheetState(() {
                            accountPreview = _maskAccountInput(
                              categoryKey,
                              value.trim(),
                            );
                          }),
                          decoration: _fieldDecoration(
                            ui,
                            accountLabel,
                            _accountIcon(categoryKey),
                            accent: providerAccent,
                          ),
                        ),
                        if (accountPreview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _t('Preview: ', 'Muhtasari: ') + accountPreview,
                            style: TextStyle(
                              color: providerAccent.withValues(alpha: 0.88),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _currencySelector(
                          ui,
                          currencies,
                          selectedCurrency,
                          (next) =>
                              setSheetState(() => selectedCurrency = next),
                        ),
                        const SizedBox(height: 14),
                        _providerSummary(provider, ui),
                        const SizedBox(height: 16),
                        _primaryActionButton(
                          context: context,
                          accent: providerAccent,
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (nameController.text.trim().isEmpty) {
                                    _showSnack(
                                      _t(
                                        'Please enter a wallet label.',
                                        'Tafadhali weka jina la akaunti.',
                                      ),
                                    );
                                    return;
                                  }
                                  final accountError = _validateAccountInput(
                                    categoryKey,
                                    accountController.text.trim(),
                                  );
                                  if (accountError != null) {
                                    _showSnack(accountError);
                                    return;
                                  }
                                  setSheetState(() => submitting = true);
                                  if (mounted) {
                                    setState(() {
                                      _actionLoading = true;
                                      _actionMessage = _t(
                                        'Linking wallet...',
                                        'Inaunganisha akaunti...',
                                      );
                                    });
                                  }
                                  try {
                                    await _walletService.createWallet({
                                      'name': nameController.text.trim(),
                                      'currency': selectedCurrency,
                                      'color': provider.color,
                                      'icon': _iconHintForCategory(categoryKey),
                                      'type': 'linked_$categoryKey',
                                      'metadata': {
                                        'provider_id': provider.id,
                                        'provider_name': provider.brandLabel,
                                        'provider_group': provider.groupLabel,
                                        'provider_channels': provider.channels,
                                        'provider_icon': provider.icon,
                                        'provider_color': provider.color,
                                        'account_number': accountController.text
                                            .trim(),
                                        'account_masked': accountPreview,
                                        'display_name': nameController.text
                                            .trim(),
                                        'category': categoryKey,
                                      },
                                    });
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                    if (!mounted) return;
                                    _showSnack(
                                      _t(
                                        'Wallet linked successfully.',
                                        'Akaunti imeunganishwa kikamilifu.',
                                      ),
                                    );
                                    try {
                                      await widget.onWalletLinked?.call();
                                    } catch (_) {
                                      // Linking already succeeded; list refresh can retry later.
                                    }
                                  } catch (error) {
                                    _showSnack(
                                      UserFacingError.from(
                                        error,
                                        fallback: _t(
                                          'Unable to link wallet right now.',
                                          'Imeshindikana kuunganisha akaunti sasa hivi.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _actionLoading = false;
                                        _actionMessage = null;
                                      });
                                    }
                                    if (sheetContext.mounted) {
                                      setSheetState(() => submitting = false);
                                    }
                                  }
                                },
                          icon: null,
                          label: _t('Link wallet', 'Unganisha'),
                          leading: ServiceAssetIcon(
                            assetPath: 'assets/icons/link wallet.svg',
                            color: _linkWalletAccent,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _maskAccountInput(String category, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';

    if (category == 'ewallets' && clean.contains('@')) {
      final parts = clean.split('@');
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        final name = parts[0];
        final head = name.length > 1 ? name[0] : name;
        return '$head***@${parts[1]}';
      }
    }

    if (category == 'crypto') {
      if (clean.length <= 10) return clean;
      return '${clean.substring(0, 4)}•••${clean.substring(clean.length - 4)}';
    }

    final digits = clean.replaceAll(RegExp(r'\\D'), '');
    if (digits.isEmpty) return clean;
    final keep = category == 'mobile' ? 3 : 4;
    if (digits.length <= keep) return digits;
    final masked =
        '•' * (digits.length - keep) + digits.substring(digits.length - keep);
    if (category == 'cards' && masked.length >= 16) {
      return masked
          .replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m.group(0)} ')
          .trimRight();
    }
    return masked;
  }

  TextInputType _accountKeyboardType(String category) {
    switch (category) {
      case 'mobile':
        return TextInputType.phone;
      case 'bank':
      case 'cards':
        return TextInputType.number;
      case 'ewallets':
        return TextInputType.emailAddress;
      case 'crypto':
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _accountFormatters(String category) {
    switch (category) {
      case 'mobile':
      case 'bank':
      case 'cards':
        return [FilteringTextInputFormatter.digitsOnly];
      default:
        return const [];
    }
  }

  int? _accountMaxLength(String category) {
    switch (category) {
      case 'mobile':
        return 15;
      case 'bank':
        return 24;
      case 'cards':
        return 19;
      default:
        return null;
    }
  }

  String? _validateAccountInput(String category, String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return _t(
        'Please enter account details.',
        'Tafadhali jaza maelezo ya akaunti.',
      );
    }

    if (category == 'mobile') {
      final digits = clean.replaceAll(RegExp(r'\\D'), '');
      if (digits.length < 9 || digits.length > 15) {
        return _t('Enter a valid mobile number.', 'Weka namba sahihi ya simu.');
      }
      return null;
    }

    if (category == 'bank') {
      final digits = clean.replaceAll(RegExp(r'\\D'), '');
      if (digits.length < 6) {
        return _t(
          'Enter a valid bank account number.',
          'Weka namba sahihi ya akaunti ya benki.',
        );
      }
      return null;
    }

    if (category == 'cards') {
      final digits = clean.replaceAll(RegExp(r'\\D'), '');
      if (digits.length < 12 || digits.length > 19) {
        return _t('Enter a valid card number.', 'Weka namba sahihi ya kadi.');
      }
      return null;
    }

    if (category == 'crypto') {
      if (clean.length < 10) {
        return _t(
          'Enter a valid wallet address.',
          'Weka anuani sahihi ya wallet.',
        );
      }
      return null;
    }

    if (category == 'ewallets') {
      if (clean.contains('@')) {
        final emailOk = RegExp(
          r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$',
        ).hasMatch(clean);
        if (!emailOk) {
          return _t('Enter a valid email address.', 'Weka barua pepe sahihi.');
        }
        return null;
      }
      if (clean.length < 4) {
        return _t('Enter a valid wallet ID.', 'Weka ID sahihi ya wallet.');
      }
      return null;
    }

    return null;
  }

  String _accountLabel(String category) {
    switch (category) {
      case 'mobile':
        return _t('Mobile number', 'Namba ya simu');
      case 'bank':
        return _t('Bank account number', 'Namba ya akaunti ya benki');
      case 'crypto':
        return _t('Wallet address', 'Anuani ya wallet');
      case 'cards':
        return _t('Card reference', 'Namba ya kadi');
      case 'ewallets':
        return _t('E-wallet email or ID', 'Barua pepe au ID ya e-wallet');
      default:
        return _t('Account reference', 'Rejea ya akaunti');
    }
  }

  IconData _accountIcon(String category) {
    switch (category) {
      case 'mobile':
        return Icons.phone_iphone_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'crypto':
        return Icons.currency_bitcoin_outlined;
      case 'cards':
        return Icons.credit_card_outlined;
      case 'ewallets':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.link_outlined;
    }
  }

  String _iconHintForCategory(String category) {
    switch (category) {
      case 'mobile':
        return 'mobile_money';
      case 'bank':
        return 'bank';
      case 'crypto':
        return 'coin';
      case 'cards':
        return 'card';
      case 'ewallets':
        return 'wallet';
      default:
        return 'wallet';
    }
  }

  Widget _currencySelector(
    OrbiUiTokens ui,
    List<String> currencies,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: ui.iconMuted),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: currencies
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerSummary(GatewayProvider provider, OrbiUiTokens ui) {
    final accent = _ProviderRow._providerColorStatic(provider, ui);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Provider details', 'Maelezo ya mtoa huduma'),
            style: TextStyle(
              color: accent.withValues(alpha: 0.96),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: _t('Group', 'Kundi'),
                value: provider.groupLabel,
              ),
              _InfoChip(
                label: _t('Channels', 'Njia'),
                value: provider.channels.isEmpty
                    ? _t('Standard', 'Kawaida')
                    : provider.channels.join(', '),
              ),
              _InfoChip(
                label: _t('Currencies', 'Sarafu'),
                value: provider.supportedCurrencies.isEmpty
                    ? _sessionCurrency
                    : provider.supportedCurrencies.join(', '),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    OrbiUiTokens ui,
    String label,
    IconData icon, {
    Color? accent,
  }) {
    final color = accent ?? _linkWalletAccent;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: ui.cardMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: ui.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: ui.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: 1.4),
      ),
    );
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
              raw.contains('unable') ||
              raw.contains('invalid') ||
              raw.contains('failed')
          ? OrbiStatusTone.error
          : OrbiStatusTone.success;
    });
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isSw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    final categories = <_CategoryChip>[
      _CategoryChip('all', isSw ? 'Zote' : 'All', Icons.grid_view_rounded),
      _CategoryChip('mobile', isSw ? 'Mobile' : 'Mobile', Icons.phone_iphone),
      _CategoryChip('bank', isSw ? 'Benki' : 'Bank', Icons.account_balance),
      _CategoryChip('cards', isSw ? 'Kadi' : 'Cards', Icons.credit_card),
      _CategoryChip(
        'ewallets',
        isSw ? 'E-Wallets' : 'E-Wallets',
        Icons.account_balance_wallet_outlined,
      ),
      _CategoryChip(
        'crypto',
        isSw ? 'Crypto' : 'Crypto',
        Icons.currency_bitcoin,
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final columns = ((width - 32) / 116).floor().clamp(3, 4);
    const spacing = 10.0;
    final itemWidth = ((width - 32 - (spacing * (columns - 1))) / columns)
        .clamp(0, 140)
        .toDouble();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: categories.map((category) {
        final isSelected = selected == category.key;
        return SizedBox(
          width: itemWidth,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelected(category.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.alphaBlend(
                        _linkWalletAccent.withValues(alpha: 0.08),
                        ui.card.withValues(alpha: 0.995),
                      )
                    : ui.card.withValues(alpha: 0.99),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? _linkWalletAccent : ui.border,
                  width: isSelected ? 1.35 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? _linkWalletAccent.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: isSelected ? 14 : 10,
                    offset: Offset(0, isSelected ? 8 : 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    width: isSelected ? 32 : 18,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _linkWalletAccent.withValues(alpha: 0.94)
                          : ui.border.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _linkWalletAccent.withValues(
                        alpha: isSelected ? 0.14 : 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.icon,
                      size: 16,
                      color: _linkWalletAccent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    category.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1.15,
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
}

class _LinkWalletIntro extends StatelessWidget {
  const _LinkWalletIntro({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: OrbiCardStyles.primaryHeroDecoration(context, radius: 20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _linkWalletAccent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _linkWalletAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCountStrip extends StatelessWidget {
  const _ProviderCountStrip({
    required this.visibleCount,
    required this.totalCount,
    required this.loading,
    required this.label,
  });

  final int visibleCount;
  final int totalCount;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final count = loading ? '...' : '$visibleCount/$totalCount';

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _linkWalletAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _linkWalletAccent.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            count,
            style: const TextStyle(
              color: _linkWalletAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _ProviderTable extends StatelessWidget {
  const _ProviderTable({required this.providers, required this.onSelect});

  final List<GatewayProvider> providers;
  final ValueChanged<GatewayProvider> onSelect;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = ((width - 32) / 112).floor().clamp(3, 4);
    const spacing = 10.0;
    final itemWidth = ((width - 32 - (spacing * (columns - 1))) / columns)
        .clamp(0, 140)
        .toDouble();
    return SingleChildScrollView(
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: providers
            .map(
              (provider) => SizedBox(
                width: itemWidth,
                child: _ProviderRow(
                  provider: provider,
                  onSelect: () => onSelect(provider),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider, required this.onSelect});

  final GatewayProvider provider;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final brandColor = _providerColorStatic(provider, ui);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: ui.card.withValues(alpha: 0.995),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ui.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: _ProviderIconBadge(provider: provider, size: 64),
            ),
            const SizedBox(height: 6),
            Text(
              provider.brandLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: brandColor,
                fontWeight: FontWeight.w800,
                fontSize: 10.3,
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
    );
  }

  static Color _providerColorStatic(GatewayProvider provider, OrbiUiTokens ui) {
    return ProviderPresentationResolver.resolveGatewayColor(
      provider,
      ui.accent,
    );
  }
}

class _ProviderIconBadge extends StatelessWidget {
  const _ProviderIconBadge({required this.provider, required this.size});

  final GatewayProvider provider;
  final double size;

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

    return ProviderLogoImage(
      candidates: assetCandidates,
      placeholderColor: _providerColor(provider, ui),
      placeholderIcon: _fallbackIconData(provider),
      placeholderLabel: 'Logo',
      debugPathLabel: assetCandidates.isEmpty
          ? 'no asset candidate'
          : assetCandidates.first,
      padding: const EdgeInsets.all(4),
    );
  }

  String _movementCategory(GatewayProvider provider) {
    final type =
        '${provider.groupLabel} ${provider.type} ${provider.brandLabel}'
            .toLowerCase();
    if (type.contains('bank')) return 'Banks';
    return 'Mobile Money';
  }

  Color _providerColor(GatewayProvider provider, OrbiUiTokens ui) {
    return ProviderPresentationResolver.resolveGatewayColor(
      provider,
      ui.accent,
    );
  }

  IconData _fallbackIconData(GatewayProvider provider) {
    return ProviderPresentationResolver.resolveGatewayIcon(
      provider,
      fallback: Icons.account_balance_wallet_outlined,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(
          color: ui.card.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ui.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _linkWalletAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: _linkWalletAccent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ((message ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _secondaryActionButton(
              context: context,
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
              label:
                  Localizations.localeOf(context).languageCode.toLowerCase() ==
                      'sw'
                  ? 'Pakia tena'
                  : 'Reload',
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip {
  const _CategoryChip(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

Widget _primaryActionButton({
  required BuildContext context,
  required Color accent,
  required VoidCallback? onPressed,
  IconData? icon,
  Widget? leading,
  required String label,
}) {
  final ui = OrbiTheme.uiOf(context);
  return SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: leading ?? Icon(icon),
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

Widget _secondaryActionButton({
  required BuildContext context,
  required VoidCallback? onPressed,
  required IconData icon,
  required String label,
}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: _linkWalletAccent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      side: BorderSide(color: _linkWalletAccent.withValues(alpha: 0.28)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
