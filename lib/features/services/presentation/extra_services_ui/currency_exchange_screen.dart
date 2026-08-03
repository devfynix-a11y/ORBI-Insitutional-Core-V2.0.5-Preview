import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/utils/backend_status_message.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_background.dart';
import '../../../../core/widgets/orbi_orbit_loader.dart';
import '../../../../core/widgets/orbi_responsive.dart';
import '../../../../core/widgets/orbi_sparkline.dart';
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
  bool _liveEstimating = false;
  bool _openingCurrencyWallet = false;
  final GlobalKey<FormState> _quoteFormKey = GlobalKey<FormState>();
  String? _error;

  List<Map<String, dynamic>> _wallets = const [];
  Map<String, FxQuote> _boardQuotes = const {};
  String _fromCurrency = 'TZS';
  String _toCurrency = 'USD';
  String? _selectedWalletId;
  String? _targetWalletId;
  FxQuote? _quote;
  String? _settlementIdempotencyKey;
  DateTime? _boardUpdatedAt;

  // Live estimate + countdown
  Timer? _debounceTimer;
  Timer? _countdownTimer;
  Timer? _ratesAutoScrollTimer;
  final ScrollController _ratesScrollController = ScrollController();
  int _quoteSecondsLeft = 0;
  static const int _quoteValiditySeconds = 45;

  String _currencyCode(String? value) => (value ?? '').trim().toUpperCase();

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
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    _ratesAutoScrollTimer?.cancel();
    _ratesScrollController.dispose();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  // ── Live estimate (debounced) ─────────────────────────────────────────────

  void _onAmountChanged() {
    _debounceTimer?.cancel();
    // Clear previous quote while user is typing
    if (_quote != null) {
      _stopCountdown();
      setState(() {
        _clearLockedQuote();
      });
    }
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _requestLiveEstimate();
    });
  }

  Future<void> _requestLiveEstimate() async {
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    if (_fromCurrency == _toCurrency) return;
    if (_busy || _liveEstimating) return;

    setState(() => _liveEstimating = true);
    try {
      final quote = await _fxQuoteService.fetch(
        from: _fromCurrency,
        to: _toCurrency,
        amount: amount,
      );
      if (!mounted) return;
      if (quote != null) {
        setState(() {
          _quote = quote;
        });
        _startCountdown(quote);
        HapticFeedback.selectionClick();
      }
    } finally {
      if (mounted) setState(() => _liveEstimating = false);
    }
  }

  // ── Quote validity countdown ──────────────────────────────────────────────

  void _startCountdown([FxQuote? quote]) {
    _countdownTimer?.cancel();
    final backendSeconds = quote?.expiresAt?.difference(DateTime.now()).inSeconds;
    final configuredSeconds = quote?.expiresInSeconds;
    final seconds = backendSeconds != null && backendSeconds > 0
        ? backendSeconds
        : configuredSeconds != null && configuredSeconds > 0
            ? configuredSeconds
            : _quoteValiditySeconds;
    setState(() => _quoteSecondsLeft = seconds.clamp(1, 300));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_quoteSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _quoteSecondsLeft = 0;
          _clearLockedQuote();
        });
        _showSnack(
          _t(
            'Quote expired. Request a new rate.',
            'Bei imeisha. Omba bei mpya.',
          ),
        );
      } else {
        setState(() => _quoteSecondsLeft--);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _quoteSecondsLeft = 0;
  }

  void _clearLockedQuote() {
    _quote = null;
    _settlementIdempotencyKey = null;
  }

  void _startRatesAutoScroll() {
    _ratesAutoScrollTimer?.cancel();
    _ratesAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || !_ratesScrollController.hasClients) return;
      final position = _ratesScrollController.position;
      if (position.maxScrollExtent <= 0) return;
      final nextOffset = position.pixels + 96;
      _ratesScrollController.animateTo(
        nextOffset >= position.maxScrollExtent ? 0 : nextOffset,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ── Existing helpers (unchanged logic) ────────────────────────────────────

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  String get _localeTag => _isSw ? 'sw_TZ' : 'en_US';

  String _friendlyError(Object error) => mapBackendStatusMessage(
        error.toString(),
        sw: _isSw,
        fallback: _t(
          'Currency exchange could not be loaded. Please try again.',
          'Huduma ya kubadilisha sarafu haikuweza kupakiwa. Tafadhali jaribu tena.',
        ),
      );

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

  double? _walletBalance(Map<String, dynamic>? wallet) {
    if (wallet == null) return null;
    final raw = wallet['balance'] ??
        wallet['available_balance'] ??
        wallet['availableBalance'] ??
        wallet['available'] ??
        wallet['amount'];
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', ''));
  }

  String _walletLabel(Map<String, dynamic> wallet) {
    final name = _pickString([
      wallet['name'],
      wallet['alias'],
      wallet['title'],
      _t('Wallet', 'Pochi'),
    ]);
    final currency = _walletCurrency(wallet, fallback: '');
    return currency.isEmpty ? name : '$name - $currency';
  }

  String _money(double amount, String currency) {
    return formatFinancialMoney(amount, currency, locale: _localeTag);
  }

  Map<String, dynamic>? get _selectedWallet {
    for (final wallet in _wallets) {
      if (_walletId(wallet) == _selectedWalletId) return wallet;
    }
    return _wallets.isEmpty ? null : _wallets.first;
  }

  Map<String, dynamic>? get _targetWallet {
    for (final wallet in _wallets) {
      if (_walletId(wallet) == _targetWalletId) return wallet;
    }
    final matching = _wallets.where(
      (wallet) => _currencyCode(_walletCurrency(wallet, fallback: '')) == _currencyCode(_toCurrency),
    );
    return matching.isEmpty ? null : matching.first;
  }

  List<Map<String, dynamic>> _walletsForCurrency(String currency) {
    final code = _currencyCode(currency);
    return _wallets
        .where((wallet) => _currencyCode(_walletCurrency(wallet, fallback: '')) == code)
        .toList(growable: false);
  }

  void _swapCurrencies() {
    _stopCountdown();
    setState(() {
      final nextFrom = _toCurrency;
      _toCurrency = _fromCurrency;
      _fromCurrency = nextFrom;
      _clearLockedQuote();
    });
    // Re-estimate after swap
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _requestLiveEstimate();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        final targetWallet = _targetWallet;
        if (targetWallet == null || _currencyCode(_walletCurrency(targetWallet, fallback: '')) != _currencyCode(_toCurrency)) {
          _targetWalletId = null;
        }
        _loading = false;
      });
      _refreshQuoteBoard();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRatesAutoScroll());
      // Kick off first live estimate
      _requestLiveEstimate();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openTargetCurrencyWallet() async {
    if (_openingCurrencyWallet) return;
    final currency = _currencyCode(_toCurrency);
    setState(() {
      _openingCurrencyWallet = true;
      _error = null;
    });
    try {
      final result = await _accountService.openCurrencyWallet(currency);
      final wallet = result['wallet'];
      final walletId = wallet is Map ? _walletId(Map<String, dynamic>.from(wallet)) : '';
      await _loadWallets();
      if (!mounted) return;
      if (walletId.isNotEmpty) {
        setState(() => _targetWalletId = walletId);
      }
      _showSnack(
        _t(
          '$currency wallet is ready.',
          'Wallet ya $currency iko tayari.',
        ),
      );
      _requestLiveEstimate();
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _openingCurrencyWallet = false);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRatesAutoScroll());
  }

  String _corridorKey(String from, String to) => '$from-$to';

  String _corridorCountry(Map<String, String> corridor) {
    return _isSw
        ? corridor['countrySw'] ?? corridor['countryEn'] ?? ''
        : corridor['countryEn'] ?? corridor['countrySw'] ?? '';
  }

  void _selectCorridor(Map<String, String> corridor) {
    _stopCountdown();
    setState(() {
      _fromCurrency = corridor['from']!;
      _toCurrency = corridor['to']!;
      _clearLockedQuote();
    });
    _requestLiveEstimate();
  }

  double _rateStrength(FxQuote? quote) {
    if (quote == null || quote.exchangeRate <= 0) return 0.08;
    final scaled = quote.exchangeRate / (quote.exchangeRate + 1000);
    return scaled.clamp(0.16, 0.92);
  }

  bool get _canProceedToPayment =>
      _quote != null &&
      (_quote?.quoteId?.trim().isNotEmpty ?? false) &&
      _selectedWalletId != null &&
      _targetWallet != null &&
      _quoteSecondsLeft > 0;

  Future<void> _settleConversion() async {
    final quote = _quote;
    final sourceWalletId = _selectedWalletId?.trim() ?? '';
    final targetWalletId = _walletId(_targetWallet);
    if (quote == null || sourceWalletId.isEmpty || targetWalletId.isEmpty) {
      _showSnack(
        _t(
          'Select source and destination wallets before converting.',
          'Chagua wallet ya kutoa na ya kupokea kabla ya kubadili.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final description = 'FX conversion $_fromCurrency to $_toCurrency';
      final response = await _fxQuoteService.settle(
        quote: quote,
        sourceWalletId: sourceWalletId,
        targetWalletId: targetWalletId,
        description: description,
        idempotencyKey: _settlementIdempotencyKey ??= _fxIdempotencyKey(quote),
      );
      if (!mounted) return;
      final success = response['success'] == true || response['data'] != null;
      if (!success) {
        throw Exception(response['message'] ?? response['error'] ?? 'FX conversion failed');
      }
      _showSnack(
        _t(
          'Currency converted successfully.',
          'Sarafu imebadilishwa kikamilifu.',
        ),
      );
      setState(() {
        _clearLockedQuote();
      });
      await _loadWallets();
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestQuote() async {
    if (!(_quoteFormKey.currentState?.validate() ?? true)) return;
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
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
        sourceWalletId: _selectedWalletId,
        targetWalletId: _walletId(_targetWallet),
        description: 'FX conversion $_fromCurrency to $_toCurrency',
        lock: true,
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
        _settlementIdempotencyKey = _fxIdempotencyKey(quote);
      });
      _startCountdown(quote);
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF061316) : const Color(0xFFF4FAF8);
    final currencies = <String>{
      'TZS',
      'USD',
      'KES',
      'EUR',
      _currencyCode(_fromCurrency),
      _currencyCode(_toCurrency),
      ..._preferredCorridors
          .expand((corridor) => [corridor['from'], corridor['to']])
          .map(_currencyCode)
          .where((currency) => currency.isNotEmpty),
      ..._wallets
          .map((wallet) => _walletCurrency(wallet, fallback: ''))
          .map(_currencyCode)
          .where((currency) => currency.isNotEmpty),
    }.toList()
      ..sort();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _t('Currency Exchange', 'Kubadili Sarafu'),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        centerTitle: false,
        elevation: 0,
        foregroundColor: ui.textPrimary,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: backgroundColor,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: Stack(
        children: [
          _fxAtmosphere(ui, isDark: isDark),
          OrbiBackground(
            child: OrbiResponsiveContent(
              child: _loading
                  ? OrbiOrbitLoadingPane(
                      label: _t('Loading exchange desk', 'Inapakia sarafu'),
                      centerIcon: Icons.currency_exchange_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWallets,
                      color: ui.accent,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _heroHeader(ui),
                          const SizedBox(height: 20),
                          _liveQuoteBoard(ui),
                          const SizedBox(height: 20),
                          _exchangeTicket(ui, currencies),
                          if (_quote != null) ...[
                            const SizedBox(height: 20),
                            _quoteResultCard(ui),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fxAtmosphere(OrbiUiTokens ui, {required bool isDark}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF061316),
                      Color(0xFF082127),
                      Color(0xFF071017),
                    ]
                  : const [
                      Color(0xFFF4FAF8),
                      Color(0xFFEAF8F3),
                      Color(0xFFF8FCFF),
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                left: -80,
                child: _fxGlow(
                  color: ui.accent.withValues(alpha: isDark ? 0.24 : 0.18),
                  size: 260,
                ),
              ),
              Positioned(
                top: 180,
                right: -110,
                child: _fxGlow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.22 : 0.15),
                  size: 300,
                ),
              ),
              Positioned(
                bottom: -120,
                left: 40,
                child: _fxGlow(
                  color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.12 : 0.10),
                  size: 260,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fxGlow({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────────────────────────

  Widget _heroHeader(OrbiUiTokens ui) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF042F2E),
                  Color(0xFF075985),
                  Color(0xFF08111F),
                ]
              : const [
                  Color(0xFF087A72),
                  Color(0xFF0EA5E9),
                  Color(0xFF12365A),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.28 : 0.20),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.20 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -55,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -34,
            child: Icon(
              Icons.public_rounded,
              size: 116,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.26),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('ORBI FX Desk', 'ORBI FX Desk'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _t(
                            'Live rates. Clear fees.',
                            'Bei live. Ada wazi.',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fromCurrency,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      _toCurrency,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fxIdempotencyKey(FxQuote quote) {
    final quoteId = quote.quoteId?.trim();
    if (quoteId != null && quoteId.isNotEmpty) {
      return 'fx-conversion-$quoteId';
    }
    return 'fx-conversion-${quote.fromCurrency}-${quote.toCurrency}-${quote.originalAmount}';
  }

  // ─────────────────────────────────────────────────────────────
  // LIVE QUOTE BOARD
  // ─────────────────────────────────────────────────────────────

  Widget _liveQuoteBoard(OrbiUiTokens ui) {
    final updated = _boardUpdatedAt == null
        ? _t('Tap refresh for live rates', 'Bonyeza refresh kupata rates')
        : _t(
            'Updated ${DateFormat('HH:mm', _localeTag).format(_boardUpdatedAt!)}',
            'Imeboreshwa ${DateFormat('HH:mm', _localeTag).format(_boardUpdatedAt!)}',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ui.accentSoft.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.show_chart_rounded, color: ui.accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Live Rates', 'Bei za Live'),
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    updated,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: _boardBusy ? null : _refreshQuoteBoard,
              style: IconButton.styleFrom(
                minimumSize: const Size(42, 42),
                maximumSize: const Size(42, 42),
              ),
              icon: _boardBusy
                  ? const OrbiOrbitLoader(size: 20, compact: true, showPanel: false, centerIcon: null)
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: SingleChildScrollView(
            controller: _ratesScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                for (var index = 0; index < _preferredCorridors.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final corridor = _preferredCorridors[index];
                      final from = corridor['from']!;
                      final to = corridor['to']!;
                      final quote = _boardQuotes[_corridorKey(from, to)];
                      return _quoteBoardTile(ui, corridor, quote);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quoteBoardTile(OrbiUiTokens ui, Map<String, String> corridor, FxQuote? quote) {
    final from = corridor['from']!;
    final to = corridor['to']!;
    final active = _fromCurrency == from && _toCurrency == to;
    final rate = quote == null ? '—' : quote.exchangeRate.toStringAsFixed(4);
    final trendColor = quote == null ? ui.iconMuted : ui.accent;
    final tileWidth = OrbiResponsive.isCompact(context) ? 180.0 : 196.0;

    return InkWell(
      onTap: () => _selectCorridor(corridor),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: tileWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? ui.accent.withValues(alpha: 0.08)
              : ui.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? ui.accent.withValues(alpha: 0.45) : ui.border.withValues(alpha: 0.5),
            width: active ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
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
                    color: ui.card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: ui.border.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    corridor['flag']!,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _corridorCountry(corridor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$from → $to',
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active) Icon(Icons.check_circle_rounded, color: ui.accent, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            OrbiSparkline(
              values: _quoteSparklineValues(quote),
              color: trendColor,
              height: 24,
              strokeWidth: 2.0,
              fill: true,
              animate: true,
            ),
            const SizedBox(height: 6),
            Text(
              '1 $from = $rate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: quote == null ? ui.textMuted : ui.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _rateStrength(quote),
                      minHeight: 3.5,
                      color: quote == null
                          ? ui.textMuted.withValues(alpha: 0.3)
                          : ui.accent,
                      backgroundColor: ui.border.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  quote == null ? '--' : _t('live', 'live'),
                  style: TextStyle(
                    color: quote == null ? ui.textMuted : ui.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<double> _quoteSparklineValues(FxQuote? quote) {
    if (quote == null) return const [0.24, 0.28, 0.32, 0.29, 0.33, 0.31];
    final base = quote.exchangeRate;
    return List<double>.generate(6, (index) {
      final modifier = (math.sin(index * 1.1) * 0.02 + 0.025) * base;
      return base + (index.isEven ? modifier : -modifier * 0.8);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // EXCHANGE TICKET
  // ─────────────────────────────────────────────────────────────

  Widget _exchangeTicket(OrbiUiTokens ui, List<String> currencies) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
      child: Form(
        key: _quoteFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ui.accentSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: ui.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Convert Money', 'Badili Fedha'),
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t('Choose route, lock rate, save currency.', 'Chagua njia, funga bei, hifadhi sarafu.'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBanner(ui, _error!),
            ],

            const SizedBox(height: 14),
            _exchangeRouteCard(ui),

            // Wallet selector + balance
            if (_wallets.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _t('Pay from', 'Lipa kutoka'),
                style: TextStyle(color: ui.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _walletSelector(ui),
            ] else ...[
              const SizedBox(height: 14),
              _infoNotice(
                ui,
                _t(
                  'No wallet connected. Add a wallet to enable payment.',
                  'Hakuna wallet. Ongeza wallet ili kuwezesha malipo.',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // From / To legs with swap
            Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    _currencyLeg(
                      ui,
                      title: _t('You send', 'Unatuma'),
                      currency: _fromCurrency,
                      items: currencies,
                      onChanged: (v) {
                        if (v == null) return;
                        _stopCountdown();
                        setState(() {
                          _fromCurrency = v;
                          final sourceWallet = _selectedWallet;
                          if (sourceWallet == null ||
                              _currencyCode(_walletCurrency(sourceWallet, fallback: '')) !=
                                  _currencyCode(_fromCurrency)) {
                            _selectedWalletId = null;
                          }
                          _clearLockedQuote();
                        });
                        _requestLiveEstimate();
                      },
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AmountInputFormatter()],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _t('Enter an amount', 'Weka kiasi');
                          }
                          final amount = AmountInputFormatter.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return _t('Enter a valid amount', 'Weka kiasi sahihi');
                          }
                          return null;
                        },
                        style: GoogleFonts.robotoMono(
                          color: ui.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(color: ui.textMuted.withValues(alpha: 0.5)),
                          prefixText: '${resolveCurrencyDisplaySymbol(_fromCurrency)} ',
                          prefixStyle: TextStyle(
                            color: ui.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _currencyLeg(
                      ui,
                      title: _t('You receive', 'Unapokea'),
                      currency: _toCurrency,
                      items: currencies,
                      onChanged: (v) {
                        if (v == null) return;
                        _stopCountdown();
                        setState(() {
                          _toCurrency = v;
                          final targetWallet = _targetWallet;
                          if (targetWallet == null ||
                              _currencyCode(_walletCurrency(targetWallet, fallback: '')) !=
                                  _currencyCode(_toCurrency)) {
                            _targetWalletId = null;
                          }
                          _clearLockedQuote();
                        });
                        _requestLiveEstimate();
                      },
                      child: _quotedReceiveDisplay(ui),
                    ),
                  ],
                ),
                // Swap button
                Material(
                  color: ui.card,
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: ui.border),
                  ),
                  child: InkWell(
                    onTap: _swapCurrencies,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.swap_vert_rounded, color: ui.textPrimary, size: 24),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Text(
              _t('Save to', 'Hifadhi kwenye'),
              style: TextStyle(color: ui.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _targetWalletSelector(ui),

            const SizedBox(height: 12),

            // Quote status + countdown
            _quoteStatusStrip(ui),

            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: (_busy || _liveEstimating) ? null : _requestQuote,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: (_busy || _liveEstimating)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            _t('Refresh Rate', 'Sasisha Bei'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.tonal(
                    onPressed: (_busy || !_canProceedToPayment) ? null : _settleConversion,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _t('Convert', 'Badili'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quoteStatusStrip(OrbiUiTokens ui) {
    final hasQuote = _quote != null && _quoteSecondsLeft > 0;
    final hasLockedQuote = hasQuote && (_quote?.quoteId?.trim().isNotEmpty ?? false);
    final isEstimating = _liveEstimating;

    Color bg;
    Color border;
    IconData icon;
    Color iconColor;
    String text;

    if (isEstimating) {
      bg = ui.cardMuted.withValues(alpha: 0.6);
      border = ui.border.withValues(alpha: 0.5);
      icon = Icons.hourglass_top_rounded;
      iconColor = ui.textMuted;
      text = _t('Fetching live estimate…', 'Inaleta makadirio…');
    } else if (hasLockedQuote) {
      bg = ui.successSoft;
      border = ui.success.withValues(alpha: 0.25);
      icon = Icons.timer_rounded;
      iconColor = ui.success;
      text = _t(
        '$_fromCurrency → $_toCurrency locked · no FX fee · $_quoteSecondsLeft s',
        '$_fromCurrency → $_toCurrency imefungwa · hakuna ada ya FX · ${_quoteSecondsLeft}s',
      );
    } else if (hasQuote) {
      bg = ui.cardMuted.withValues(alpha: 0.7);
      border = ui.border.withValues(alpha: 0.55);
      icon = Icons.trending_up_rounded;
      iconColor = ui.accent;
      text = _t(
        'Live estimate. Refresh Rate to lock before converting.',
        'Makadirio ya sasa. Sasisha Bei ili uifunge kabla ya kubadili.',
      );
    } else {
      bg = ui.cardMuted.withValues(alpha: 0.6);
      border = ui.border.withValues(alpha: 0.5);
      icon = Icons.schedule_rounded;
      iconColor = ui.textMuted;
      text = _t('Enter amount for live estimate', 'Weka kiasi kupata makadirio');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hasQuote)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: (_quoteSecondsLeft / (_quote?.expiresInSeconds ?? _quoteValiditySeconds))
                    .clamp(0.0, 1.0),
                strokeWidth: 2.5,
                color: ui.success,
                backgroundColor: ui.success.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exchangeRouteCard(OrbiUiTokens ui) {
    final sourceWallet = _selectedWallet;
    final targetWallet = _targetWallet;
    final fromName = sourceWallet == null ? _t('Choose wallet', 'Chagua wallet') : _walletName(sourceWallet);
    final toName = targetWallet == null ? _t('Choose destination', 'Chagua pa kuhifadhi') : _walletName(targetWallet);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _routeLeg(
              ui,
              label: _t('From', 'Kutoka'),
              name: fromName,
              currency: _fromCurrency,
              icon: Icons.account_balance_wallet_rounded,
              color: ui.accent,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ui.accentSoft.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward_rounded, color: ui.textPrimary, size: 18),
          ),
          Expanded(
            child: _routeLeg(
              ui,
              label: _t('To', 'Kwenda'),
              name: toName,
              currency: _toCurrency,
              icon: Icons.savings_rounded,
              color: ui.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeLeg(
    OrbiUiTokens ui, {
    required String label,
    required String name,
    required String currency,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currency,
          style: GoogleFonts.robotoMono(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _walletName(Map<String, dynamic> wallet) {
    return _pickString([
      wallet['name'],
      wallet['wallet_name'],
      wallet['label'],
      wallet['account_name'],
      _t('Wallet', 'Wallet'),
    ]);
  }

  Widget _walletSelector(OrbiUiTokens ui) {
    final selected = _selectedWallet;
    final balance = _walletBalance(selected);
    final currency = _walletCurrency(selected);
    final seenWalletIds = <String>{};
    final walletItems = <DropdownMenuItem<String>>[];
    for (final wallet in _wallets) {
      final id = _walletId(wallet);
      if (id.isEmpty || !seenWalletIds.add(id)) continue;
      walletItems.add(
        DropdownMenuItem<String>(
          value: id,
          child: Text(_walletLabel(wallet), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    final selectedWalletId =
        seenWalletIds.contains(_selectedWalletId) ? _selectedWalletId : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selectedWalletId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              dropdownColor: ui.card,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: ui.accent),
              style: TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
              items: walletItems,
              onChanged: walletItems.isEmpty ? null : (value) {
                final matches = _wallets.where((item) => _walletId(item) == value).toList();
                final selectedWallet = matches.isEmpty ? null : matches.first;
                _stopCountdown();
                setState(() {
                  _selectedWalletId = value;
                  _fromCurrency = _walletCurrency(selectedWallet, fallback: _fromCurrency);
                  if (_fromCurrency == _toCurrency) {
                    _toCurrency = _fromCurrency == 'USD' ? 'TZS' : 'USD';
                  }
                  _clearLockedQuote();
                });
                _requestLiveEstimate();
              },
            ),
          ),
          if (balance != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ui.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ui.border.withValues(alpha: 0.4)),
              ),
              child: Text(
                _money(balance, currency),
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _targetWalletSelector(OrbiUiTokens ui) {
    final targetWallets = _walletsForCurrency(_toCurrency);
    if (targetWallets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ui.warningSoft.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ui.warning.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Open a $_toCurrency wallet to receive this conversion.',
                'Fungua wallet ya $_toCurrency kupokea ubadilishaji huu.',
              ),
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openingCurrencyWallet ? null : _openTargetCurrencyWallet,
                icon: _openingCurrencyWallet
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_card_rounded, size: 18),
                label: Text(
                  _openingCurrencyWallet
                      ? _t('Opening wallet', 'Inafungua wallet')
                      : _t('Open $_toCurrency wallet', 'Fungua wallet ya $_toCurrency'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final seenWalletIds = <String>{};
    final walletItems = <DropdownMenuItem<String>>[];
    for (final wallet in targetWallets) {
      final id = _walletId(wallet);
      if (id.isEmpty || !seenWalletIds.add(id)) continue;
      walletItems.add(
        DropdownMenuItem<String>(
          value: id,
          child: Text(_walletLabel(wallet), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    final selectedId = seenWalletIds.contains(_targetWalletId)
        ? _targetWalletId
        : walletItems.isEmpty
            ? null
            : walletItems.first.value;
    if (_targetWalletId == null && selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _targetWalletId == null) {
          setState(() => _targetWalletId = selectedId);
        }
      });
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: ui.successSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_rounded, color: ui.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selectedId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              dropdownColor: ui.card,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: ui.success),
              style: TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
              items: walletItems,
              onChanged: walletItems.isEmpty
                  ? null
                  : (value) {
                      _stopCountdown();
                      setState(() {
                        _targetWalletId = value;
                        _clearLockedQuote();
                      });
                      _requestLiveEstimate();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyLeg(
    OrbiUiTokens ui, {
    required String title,
    required String currency,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Widget child,
  }) {
    final normalizedCurrency = _currencyCode(currency);
    final dropdownItems = <String>{
      normalizedCurrency,
      ...items.map(_currencyCode).where((code) => code.isNotEmpty),
    }.where((code) => code.isNotEmpty).toList()
      ..sort();
    final selectedCurrency =
        dropdownItems.contains(normalizedCurrency) ? normalizedCurrency : dropdownItems.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ui.border.withValues(alpha: 0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCurrency,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: ui.accent),
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      letterSpacing: 0.4,
                    ),
                    dropdownColor: ui.card,
                    items: dropdownItems
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _quotedReceiveDisplay(OrbiUiTokens ui) {
    if (_liveEstimating) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: ui.accent),
          ),
          const SizedBox(width: 10),
          Text(
            _t('Estimating…', 'Inakadiria…'),
            style: TextStyle(color: ui.textMuted, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      );
    }
    if (_quote == null) {
      return Text(
        _t('Enter amount above', 'Weka kiasi hapo juu'),
        style: TextStyle(color: ui.textMuted, fontWeight: FontWeight.w700, fontSize: 16),
      );
    }
    return MoneyText(
      value: _money(_quote!.finalAmount, _quote!.toCurrency),
      mainFontSize: 22,
      sideFontSize: 13,
      fontWeight: FontWeight.w900,
      mainColor: ui.textPrimary,
      sideColor: ui.textMuted,
      fitToWidth: true,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // QUOTE RESULT
  // ─────────────────────────────────────────────────────────────

  Widget _quoteResultCard(OrbiUiTokens ui) {
    final quote = _quote!;

    return Container(
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ui.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.query_stats_rounded, color: ui.success, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Quote Breakdown', 'Mchanganuo wa Quote'),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (_quoteSecondsLeft > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ui.successSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_quoteSecondsLeft}s',
                    style: TextStyle(
                      color: ui.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _t('You will receive', 'Utapokea'),
            style: TextStyle(color: ui.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          MoneyText(
            value: _money(quote.finalAmount, quote.toCurrency),
            mainFontSize: 28,
            sideFontSize: 15,
            fontWeight: FontWeight.w900,
            mainColor: ui.textPrimary,
            sideColor: ui.textMuted,
            fitToWidth: true,
          ),
          const SizedBox(height: 16),
          OrbiSparkline(
            values: _quoteSparklineValues(quote),
            color: ui.accent,
            height: 48,
            strokeWidth: 2.4,
            fill: true,
            animate: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _metricTile(ui, _t('You send', 'Unatuma'), _money(quote.originalAmount, quote.fromCurrency))),
              const SizedBox(width: 10),
              Expanded(child: _metricTile(ui, _t('You receive', 'Unapokea'), _money(quote.finalAmount, quote.toCurrency))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(OrbiUiTokens ui, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ui.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _errorBanner(OrbiUiTokens ui, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: ui.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: ui.textPrimary, height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoNotice(OrbiUiTokens ui, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: ui.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
