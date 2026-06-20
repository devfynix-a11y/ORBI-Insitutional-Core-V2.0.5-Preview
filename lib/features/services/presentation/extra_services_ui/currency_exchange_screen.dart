import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_background.dart';
import '../../../../core/widgets/orbi_orbit_loader.dart';
import '../../../../core/widgets/orbi_responsive.dart';
import '../../../../core/widgets/orbi_section_card.dart';
import '../../../payment/presentation/payment_screen.dart';
import '../../../transfers/data/fx_quote_service.dart';
import '../../data/advanced_services_service.dart';

class CurrencyExchangeScreen extends StatefulWidget {
  const CurrencyExchangeScreen({super.key});

  @override
  State<CurrencyExchangeScreen> createState() => _CurrencyExchangeScreenState();
}

class _CurrencyExchangeScreenState extends State<CurrencyExchangeScreen> {
  final AdvancedServicesService _accountService = AdvancedServicesService();
  final FxQuoteService _fxQuoteService = FxQuoteService();
  final TextEditingController _amountController = TextEditingController(
    text: '100000',
  );

  bool _loading = true;
  bool _busy = false;
  bool _boardBusy = false;
  String? _error;

  List<Map<String, dynamic>> _wallets = const [];
  Map<String, FxQuote> _boardQuotes = const {};
  String _fromCurrency = 'TZS';
  String _toCurrency = 'USD';
  String? _selectedWalletId;
  FxQuote? _quote;
  DateTime? _quoteFetchedAt;
  DateTime? _boardUpdatedAt;

  static const List<Map<String, String>> _preferredCorridors = [
    {
      'countryEn': 'Tanzania',
      'countrySw': 'Tanzania',
      'flag': 'TZ',
      'from': 'USD',
      'to': 'TZS',
    },
    {
      'countryEn': 'Kenya',
      'countrySw': 'Kenya',
      'flag': 'KE',
      'from': 'USD',
      'to': 'KES',
    },
    {
      'countryEn': 'Uganda',
      'countrySw': 'Uganda',
      'flag': 'UG',
      'from': 'USD',
      'to': 'UGX',
    },
    {
      'countryEn': 'Rwanda',
      'countrySw': 'Rwanda',
      'flag': 'RW',
      'from': 'USD',
      'to': 'RWF',
    },
    {
      'countryEn': 'Europe',
      'countrySw': 'Ulaya',
      'flag': 'EU',
      'from': 'EUR',
      'to': 'TZS',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  String get _localeTag => _isSw ? 'sw_TZ' : 'en_US';

  String _pickString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _walletId(Map<String, dynamic>? wallet) =>
      _pickString([wallet?['id'], wallet?['wallet_id'], wallet?['walletId']]);

  String _walletCurrency(
    Map<String, dynamic>? wallet, {
    String fallback = 'TZS',
  }) {
    final code = _pickString([
      wallet?['currency'],
      wallet?['currency_code'],
      wallet?['code'],
    ]).toUpperCase();
    return code.isEmpty ? fallback : code;
  }

  String _walletLabel(Map<String, dynamic> wallet) {
    final name = _pickString([
      wallet['name'],
      wallet['alias'],
      wallet['title'],
      _t('Wallet', 'Pochi'),
    ]);
    final currency = _walletCurrency(wallet, fallback: '');
    return currency.isEmpty ? name : '$name • $currency';
  }

  String _money(double amount, String currency) {
    return formatCompactMoney(
      amount,
      currency,
      locale: _localeTag,
      compactFrom: kCompactMoneyThreshold,
    );
  }

  String _fxRateLabel(double rate) {
    return '1 $_fromCurrency = ${rate.toStringAsFixed(4)} $_toCurrency';
  }

  Map<String, dynamic>? get _selectedWallet {
    for (final wallet in _wallets) {
      if (_walletId(wallet) == _selectedWalletId) return wallet;
    }
    return _wallets.isEmpty ? null : _wallets.first;
  }

  void _swapCurrencies() {
    setState(() {
      final nextFrom = _toCurrency;
      _toCurrency = _fromCurrency;
      _fromCurrency = nextFrom;
      _quote = null;
      _quoteFetchedAt = null;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadWallets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallets = await _accountService.listWallets();
      if (!mounted) return;
      final firstWallet = wallets.isNotEmpty ? wallets.first : null;
      setState(() {
        _wallets = wallets;
        _selectedWalletId = _selectedWalletId ?? _walletId(firstWallet);
        _fromCurrency = _walletCurrency(firstWallet, fallback: _fromCurrency);
        if (_fromCurrency == _toCurrency) {
          _toCurrency = _fromCurrency == 'USD' ? 'TZS' : 'USD';
        }
        _loading = false;
      });
      _refreshQuoteBoard();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refreshQuoteBoard() async {
    if (_boardBusy) return;
    setState(() => _boardBusy = true);
    final nextQuotes = <String, FxQuote>{};
    for (final corridor in _preferredCorridors) {
      final from = corridor['from']!;
      final to = corridor['to']!;
      final quote = await _fxQuoteService.fetch(from: from, to: to, amount: 1);
      if (quote != null) nextQuotes[_corridorKey(from, to)] = quote;
    }
    if (!mounted) return;
    setState(() {
      _boardQuotes = nextQuotes;
      _boardUpdatedAt = DateTime.now();
      _boardBusy = false;
    });
  }

  String _corridorKey(String from, String to) => '$from-$to';

  String _corridorCountry(Map<String, String> corridor) {
    return _isSw
        ? corridor['countrySw'] ?? corridor['countryEn'] ?? ''
        : corridor['countryEn'] ?? corridor['countrySw'] ?? '';
  }

  void _selectCorridor(Map<String, String> corridor) {
    setState(() {
      _fromCurrency = corridor['from']!;
      _toCurrency = corridor['to']!;
      _quote = null;
      _quoteFetchedAt = null;
    });
  }

  double _rateStrength(FxQuote? quote) {
    if (quote == null || quote.exchangeRate <= 0) return 0.08;
    final scaled = quote.exchangeRate / (quote.exchangeRate + 1000);
    return scaled.clamp(0.16, 0.92);
  }

  Future<void> _requestQuote() async {
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack(
        _t('Enter a valid amount first.', 'Weka kiasi sahihi kwanza.'),
      );
      return;
    }
    if (_fromCurrency == _toCurrency) {
      _showSnack(
        _t(
          'Choose two different currencies to request a quote.',
          'Chagua sarafu mbili tofauti ili kupata quote.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final quote = await _fxQuoteService.fetch(
        from: _fromCurrency,
        to: _toCurrency,
        amount: amount,
      );
      if (!mounted) return;
      if (quote == null) {
        final reason = _fxQuoteService.lastErrorMessage;
        _showSnack(
          reason == null || reason.isEmpty
              ? _t(
                  'No quote is available for that pair right now.',
                  'Hakuna quote kwa jozi hiyo kwa sasa.',
                )
              : _t(
                  'FX quote unavailable: $reason',
                  'Quote ya FX haipatikani: $reason',
                ),
        );
        return;
      }
      setState(() {
        _quote = quote;
        _quoteFetchedAt = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final currencies = <String>{
      'TZS',
      'USD',
      'KES',
      'EUR',
      ..._wallets
          .map((wallet) => _walletCurrency(wallet, fallback: ''))
          .where((currency) => currency.isNotEmpty),
    }.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(_t('Currency Exchange', 'Kubadili Sarafu'))),
      body: OrbiBackground(
        child: OrbiResponsiveContent(
          child: _loading
              ? OrbiOrbitLoadingPane(
                  label: _t('Loading exchange desk', 'Inapakia sarafu'),
                  centerIcon: Icons.currency_exchange_rounded,
                )
              : RefreshIndicator(
                  onRefresh: _loadWallets,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
                    children: [
                      _compactFxHeader(ui),
                      const SizedBox(height: 12),
                      _liveQuoteBoard(ui),
                      const SizedBox(height: 14),
                      _exchangeTicket(ui, currencies),
                      if (_quote != null) ...[
                        const SizedBox(height: 14),
                        _quoteResultCard(ui),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _compactFxHeader(OrbiUiTokens ui) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.cardStrong.withValues(alpha: isDark ? 0.94 : 1),
            ui.card.withValues(alpha: isDark ? 0.86 : 1),
            ui.iconMuted.withValues(alpha: isDark ? 0.08 : 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : ui.border.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ui.accentSoft.withValues(alpha: isDark ? 0.38 : 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ui.borderStrong),
            ),
            child: Icon(Icons.currency_exchange_rounded, color: ui.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Currency exchange', 'Kubadili sarafu'),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Pick a corridor, price the transfer, then continue.',
                    'Chagua njia, pima bei, kisha endelea.',
                  ),
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ui.border),
            ),
            child: Text(
              '$_fromCurrency / $_toCurrency',
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveQuoteBoard(OrbiUiTokens ui) {
    final updated = _boardUpdatedAt == null
        ? _t('Tap refresh for live rates', 'Bonyeza refresh kupata rates')
        : _t(
            'Updated ${DateFormat('HH:mm', _localeTag).format(_boardUpdatedAt!)}',
            'Imeboreshwa ${DateFormat('HH:mm', _localeTag).format(_boardUpdatedAt!)}',
          );
    return OrbiSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Live quote board', 'Bodi ya live quote'),
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      updated,
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _boardBusy ? null : _refreshQuoteBoard,
                icon: _boardBusy
                    ? const OrbiOrbitLoader(
                        size: 22,
                        compact: true,
                        showPanel: false,
                        centerIcon: null,
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _preferredCorridors.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final corridor = _preferredCorridors[index];
                final from = corridor['from']!;
                final to = corridor['to']!;
                final quote = _boardQuotes[_corridorKey(from, to)];
                return _quoteBoardTile(ui, corridor, quote);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteBoardTile(
    OrbiUiTokens ui,
    Map<String, String> corridor,
    FxQuote? quote,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final from = corridor['from']!;
    final to = corridor['to']!;
    final active = _fromCurrency == from && _toCurrency == to;
    final rate = quote == null
        ? _t('Waiting', 'Inasubiri')
        : quote.exchangeRate.toStringAsFixed(4);
    return InkWell(
      onTap: () => _selectCorridor(corridor),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? [
                    ui.accent.withValues(alpha: isDark ? 0.34 : 0.18),
                    ui.card.withValues(alpha: isDark ? 0.94 : 1),
                  ]
                : [
                    isDark
                        ? ui.cardStrong.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.96),
                    ui.cardMuted.withValues(alpha: isDark ? 0.44 : 0.64),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? ui.accent.withValues(alpha: 0.45) : ui.borderStrong,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ui.accentSoft.withValues(alpha: isDark ? 0.36 : 0.8),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    corridor['flag']!,
                    style: TextStyle(
                      color: ui.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.trending_up_rounded,
                  color: active ? ui.accent : ui.iconMuted,
                  size: 18,
                ),
              ],
            ),
            const Spacer(),
            Text(
              _corridorCountry(corridor),
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$from -> $to',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '1 $from = $rate $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: quote == null ? ui.textMuted : ui.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _rateStrength(quote),
                minHeight: 5,
                color: quote == null
                    ? ui.textMuted.withValues(alpha: 0.34)
                    : ui.accent,
                backgroundColor: ui.border.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketSummaryCard(OrbiUiTokens ui) {
    final quote = _quote;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metricChip(ui, _t('Pair', 'Jozi'), '$_fromCurrency / $_toCurrency'),
        _metricChip(
          ui,
          _t('Rate', 'Rate'),
          quote == null
              ? _t('Request quote', 'Omba quote')
              : _fxRateLabel(quote.exchangeRate),
        ),
        _metricChip(
          ui,
          _t('Source', 'Chanzo'),
          _selectedWallet == null
              ? _t('No wallet', 'Hakuna wallet')
              : _walletCurrency(_selectedWallet, fallback: _fromCurrency),
        ),
      ],
    );
  }

  Widget _exchangeTicket(OrbiUiTokens ui, List<String> currencies) {
    final quoteReady = _quote != null;
    final quoteTime = _quoteFetchedAt == null
        ? _t('No live quote yet', 'Bado hakuna quote ya moja kwa moja')
        : _t(
            'Updated ${DateFormat('dd MMM, HH:mm', _localeTag).format(_quoteFetchedAt!)}',
            'Imeboreshwa ${DateFormat('dd MMM, HH:mm', _localeTag).format(_quoteFetchedAt!)}',
          );
    return OrbiSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            ui,
            _t('Exchange ticket', 'Tiketi ya ubadilishaji'),
            Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Build the conversion, request the rate, then continue with the priced payment path.',
              'Tengeneza ubadilishaji, omba rate, kisha endelea na njia ya malipo iliyo na bei.',
            ),
            style: TextStyle(color: ui.textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          _marketSummaryCard(ui),
          const SizedBox(height: 14),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ui.warningSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ui.warning.withValues(alpha: 0.22)),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: ui.textPrimary, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_wallets.isNotEmpty) ...[
            _ticketFieldShell(
              ui,
              label: _t('Pay from wallet', 'Lipa kutoka wallet'),
              child: _dropdownContainer(
                ui,
                Icons.account_balance_wallet_outlined,
                DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  dropdownColor: ui.card,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: ui.accent,
                  ),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  items: _wallets
                      .map(
                        (wallet) => DropdownMenuItem<String>(
                          value: _walletId(wallet),
                          child: Text(
                            _walletLabel(wallet),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    final matches = _wallets
                        .where((item) => _walletId(item) == value)
                        .toList();
                    final selected = matches.isEmpty ? null : matches.first;
                    setState(() {
                      _selectedWalletId = value;
                      _fromCurrency = _walletCurrency(
                        selected,
                        fallback: _fromCurrency,
                      );
                      if (_fromCurrency == _toCurrency) {
                        _toCurrency = _fromCurrency == 'USD' ? 'TZS' : 'USD';
                      }
                      _quote = null;
                      _quoteFetchedAt = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  _currencyLegCard(
                    ui,
                    title: _t('From', 'Kutoka'),
                    currency: _fromCurrency,
                    icon: Icons.south_west_rounded,
                    items: currencies,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _fromCurrency = value;
                        _quote = null;
                        _quoteFetchedAt = null;
                      });
                    },
                    amountField: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [AmountInputFormatter()],
                      style: GoogleFonts.robotoMono(
                        color: ui.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: _fieldDecoration(
                        ui,
                        _t('Amount to convert', 'Kiasi cha kubadili'),
                        Icons.payments_outlined,
                        prefixText: resolveCurrencyDisplaySymbol(_fromCurrency),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _currencyLegCard(
                    ui,
                    title: _t('To', 'Kwenda'),
                    currency: _toCurrency,
                    icon: Icons.north_east_rounded,
                    items: currencies,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _toCurrency = value;
                        _quote = null;
                        _quoteFetchedAt = null;
                      });
                    },
                    amountField: _quotedReceiveField(ui),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _swapCurrencies,
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: ui.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ui.borderStrong),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: ui.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: quoteReady
                  ? ui.successSoft
                  : ui.cardMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: quoteReady
                    ? ui.success.withValues(alpha: 0.22)
                    : ui.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  quoteReady ? Icons.verified_rounded : Icons.schedule_rounded,
                  color: quoteReady ? ui.success : ui.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    quoteTime,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _requestQuote,
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: Text(
                    _busy
                        ? _t('Fetching quote...', 'Inaleta quote...')
                        : _t('Price conversion', 'Pima ubadilishaji'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaymentScreen()),
                    );
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(_t('Go to payment', 'Nenda kulipa')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quoteResultCard(OrbiUiTokens ui) {
    final quote = _quote!;
    return OrbiSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            ui,
            _t('Quote breakdown', 'Mchanganuo wa quote'),
            Icons.query_stats_rounded,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ui.cardMuted.withValues(alpha: 0.88),
                  ui.card.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ui.borderStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    'Estimated receive amount',
                    'Kiasi kinachokadiriwa kupokelewa',
                  ),
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                MoneyText(
                  value: _money(quote.finalAmount, quote.toCurrency),
                  mainFontSize: 24,
                  sideFontSize: 14,
                  fontWeight: FontWeight.w900,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metricChip(
                      ui,
                      _t('Debit', 'Kukatwa'),
                      _money(quote.originalAmount, quote.fromCurrency),
                      moneyValue: true,
                    ),
                    _metricChip(
                      ui,
                      _t('Fee impact', 'Athari ya ada'),
                      _money(quote.fee, quote.fromCurrency),
                      moneyValue: true,
                    ),
                    _metricChip(
                      ui,
                      _t('Rate used', 'Rate iliyotumika'),
                      _fxRateLabel(quote.exchangeRate),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(OrbiUiTokens ui, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ui.iconMuted.withValues(alpha: 0.14),
                isDark ? ui.cardStrong.withValues(alpha: 0.9) : Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ui.borderStrong),
          ),
          child: Icon(icon, color: ui.iconMuted),
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
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _t('Focused quote workflow', 'Mtiririko maalum wa quote'),
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricChip(
    OrbiUiTokens ui,
    String label,
    String value, {
    bool moneyValue = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? ui.cardStrong.withValues(alpha: 0.92)
                : const Color(0xFFFFFFFF),
            isDark ? ui.card.withValues(alpha: 0.82) : const Color(0xFFF5F7F9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : ui.border.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: ui.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          moneyValue
              ? MoneyText(
                  value: value,
                  mainFontSize: 13.5,
                  sideFontSize: 10,
                  fontWeight: FontWeight.w800,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }

  Widget _dropdownContainer(OrbiUiTokens ui, IconData icon, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? ui.cardStrong.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.96),
            isDark
                ? ui.card.withValues(alpha: 0.76)
                : ui.cardMuted.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ui.accentSoft.withValues(alpha: isDark ? 0.45 : 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ui.accent.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: ui.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketFieldShell(
    OrbiUiTokens ui, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ui.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _currencyLegCard(
    OrbiUiTokens ui, {
    required String title,
    required String currency,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Widget amountField,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? ui.cardStrong.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.98),
            isDark
                ? ui.card.withValues(alpha: 0.78)
                : ui.cardMuted.withValues(alpha: 0.64),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ui.accentSoft.withValues(alpha: isDark ? 0.40 : 0.84),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ui.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ui.cardMuted.withValues(alpha: isDark ? 0.5 : 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ui.border),
                ),
                child: Text(
                  currency,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dropdownContainer(
            ui,
            Icons.currency_exchange_outlined,
            DropdownButtonFormField<String>(
              initialValue: currency,
              decoration: const InputDecoration.collapsed(hintText: ''),
              dropdownColor: ui.card,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: ui.accent),
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
              items: items
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 12),
          amountField,
        ],
      ),
    );
  }

  Widget _quotedReceiveField(OrbiUiTokens ui) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = _quote == null
        ? _t('Quote required', 'Quote inahitajika')
        : _money(_quote!.finalAmount, _quote!.toCurrency);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ui.accentSoft.withValues(alpha: isDark ? 0.28 : 0.55),
            ui.card.withValues(alpha: isDark ? 0.82 : 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Estimated receive', 'Makadirio ya kupokea'),
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _quote == null
              ? Text(
                  text,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                )
              : MoneyText(
                  value: text,
                  mainFontSize: 19,
                  sideFontSize: 12,
                  fontWeight: FontWeight.w900,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    OrbiUiTokens ui,
    String label,
    IconData icon, {
    String? prefixText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(
        color: ui.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      prefixText: prefixText == null ? null : '$prefixText ',
      prefixStyle: prefixText == null
          ? null
          : TextStyle(
              color: ui.accent,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
      prefixIcon: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: ui.accentSoft.withValues(alpha: isDark ? 0.38 : 0.88),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: ui.accent, size: 20),
      ),
      filled: true,
      fillColor: isDark
          ? ui.cardStrong.withValues(alpha: 0.78)
          : Colors.white.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: ui.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: ui.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: ui.accent, width: 1.5),
      ),
    );
  }
}
