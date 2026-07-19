import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/provider_asset_resolver.dart';
import '../../../core/utils/provider_presentation_resolver.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_brand_hero_card.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../auth/state/auth_controller.dart';
import '../../transfers/presentation/send_money_screen.dart';
import '../../wallet/data/wallet_service.dart';
import '../../wallet/data/wealth_service.dart';
import '../data/models/bill_provider_catalog.dart';
import '../data/payment_bill_matcher.dart';
import '../data/payment_merchant_matcher.dart';
import '../data/payment_routing_catalog_service.dart';
import '../data/payment_scan_confidence_service.dart';
import '../data/payment_scan_matcher.dart';
import '../data/receipt_scan_service.dart';
import '../data/scan_pay_service.dart';
import '../state/payment_controller.dart';
import 'widgets/payment_bill_pay_sheet.dart';
import 'widgets/payment_bill_providers_screen.dart';
import 'widgets/payment_bills_hub.dart';
import 'widgets/payment_merchant_hub.dart';
import 'widgets/payment_orbi_pay_sheet.dart';
import 'widgets/payment_scan_feedback.dart';
import 'widgets/payment_scan_panels.dart';
import 'service_payment_requests_screen.dart';

enum _MerchantPayMode { number, qr, receipt }

class _BillCategory {
  const _BillCategory({
    required this.icon,
    required this.key,
    required this.en,
    required this.sw,
    required this.accent,
    required this.providers,
  });

  final IconData icon;
  final String key;
  final String en;
  final String sw;
  final Color accent;
  final List<BillProviderEntry> providers;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _scannerPulseController;
  late final Animation<double> _scannerPulse;
  final ImagePicker _imagePicker = ImagePicker();
  MobileScannerController? _scannerController;

  final ReceiptScanService _receiptScanService = ReceiptScanService();
  final WalletService _walletService = WalletService();
  final WealthService _wealthService = WealthService();
  final PaymentBillMatcher _billMatcher = const PaymentBillMatcher();
  final PaymentMerchantMatcher _merchantMatcher =
      const PaymentMerchantMatcher();
  final PaymentRoutingCatalogService _routingCatalogService =
      PaymentRoutingCatalogService();
  final PaymentScanConfidenceService _scanConfidenceService =
      const PaymentScanConfidenceService();
  final PaymentScanMatcher _scanMatcher = const PaymentScanMatcher();
  final ScanPayService _scanPayService = const ScanPayService();
  late final PaymentController _paymentController;
  final TextEditingController _merchantNumberController =
      TextEditingController();

  bool _scanPaused = false;
  bool _flashOn = false;
  String? _qrValue;
  ScanPayIntent? _qrIntent;
  File? _selectedFile;
  ReceiptScanResult? _scanResult;
  ScanPayIntent? _receiptIntent;
  bool _scanLoading = false;
  String? _scanError;
  String? _scannerError;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  _MerchantPayMode _merchantMode = _MerchantPayMode.number;
  int _selectedBillCategory = 0;
  int _selectedBillProvider = 0;
  String? _lastAutoOpenedScanRaw;
  PaymentRoutingCatalog _routingCatalog = const PaymentRoutingCatalog();
  bool _isSwahili = false;

  static const List<_BillCategory> _billCategories = [
    _BillCategory(
      icon: Icons.bolt_rounded,
      key: 'electricity',
      en: 'Electricity',
      sw: 'Umeme',
      accent: Color(0xFFE29A2D),
      providers: [
        BillProviderEntry(label: 'TANESCO'),
        BillProviderEntry(label: 'ZESCO'),
        BillProviderEntry(label: 'LUKU'),
      ],
    ),
    _BillCategory(
      icon: Icons.water_drop_rounded,
      key: 'water-bills',
      en: 'Water bills',
      sw: 'Bili za maji',
      accent: Color(0xFF3E8ED0),
      providers: [
        BillProviderEntry(label: 'DAWASA'),
        BillProviderEntry(label: 'RUWASA'),
        BillProviderEntry(label: 'Maji ya mkoa'),
      ],
    ),
    _BillCategory(
      icon: Icons.local_fire_department_rounded,
      key: 'gas',
      en: 'Gas',
      sw: 'Gesi',
      accent: Color(0xFFE26A3C),
      providers: [
        BillProviderEntry(label: 'Oryx Gas'),
        BillProviderEntry(label: 'Taifa Gas'),
        BillProviderEntry(label: 'Lake Gas'),
      ],
    ),
    _BillCategory(
      icon: Icons.wifi_tethering_rounded,
      key: 'bundles',
      en: 'Bundles',
      sw: 'Bando',
      accent: Color(0xFF6D5CE7),
      providers: [
        BillProviderEntry(label: 'Vodacom'),
        BillProviderEntry(label: 'Airtel'),
        BillProviderEntry(label: 'Mix By Yas'),
        BillProviderEntry(label: 'Halotel'),
      ],
    ),
    _BillCategory(
      icon: Icons.router_rounded,
      key: 'internet',
      en: 'Internet',
      sw: 'Intaneti',
      accent: Color(0xFF476FD6),
      providers: [
        BillProviderEntry(label: 'TTCL'),
        BillProviderEntry(label: 'Zuku'),
        BillProviderEntry(label: 'SimbaNET'),
        BillProviderEntry(label: 'Liquid Telecom'),
      ],
    ),
    _BillCategory(
      icon: Icons.school_rounded,
      key: 'school-fees',
      en: 'School fees',
      sw: 'Ada za shule',
      accent: Color(0xFF2E8B79),
      providers: [
        BillProviderEntry(label: 'Ada ya shule'),
        BillProviderEntry(label: 'Ada ya chuo'),
        BillProviderEntry(label: 'Hosteli'),
      ],
    ),
    _BillCategory(
      icon: Icons.account_balance_rounded,
      key: 'government-bills',
      en: 'Government bills',
      sw: 'Bili za serikali',
      accent: Color(0xFF2F6F9F),
      providers: [
        BillProviderEntry(label: 'TRA'),
        BillProviderEntry(label: 'eGovernment'),
        BillProviderEntry(label: 'NIDA'),
        BillProviderEntry(label: 'Local Government'),
      ],
    ),
    _BillCategory(
      icon: Icons.shield_outlined,
      key: 'insurance',
      en: 'Insurance',
      sw: 'Bima',
      accent: Color(0xFF16806D),
      providers: [
        BillProviderEntry(label: 'NHIF'),
        BillProviderEntry(label: 'Jubilee'),
        BillProviderEntry(label: 'NIC'),
        BillProviderEntry(label: 'Alliance Life'),
      ],
    ),
    _BillCategory(
      icon: Icons.call_rounded,
      key: 'telephone',
      en: 'Telephone',
      sw: 'Simu ya mezani',
      accent: Color(0xFF8A5A44),
      providers: [
        BillProviderEntry(label: 'TTCL Voice'),
        BillProviderEntry(label: 'Office Line'),
        BillProviderEntry(label: 'Business Tel'),
      ],
    ),
    _BillCategory(
      icon: Icons.live_tv_rounded,
      key: 'entertainment',
      en: 'Entertainment',
      sw: 'Burudani',
      accent: Color(0xFFC7507A),
      providers: [
        BillProviderEntry(label: 'DSTV'),
        BillProviderEntry(label: 'Azam TV'),
        BillProviderEntry(label: 'Startimes'),
        BillProviderEntry(label: 'Netflix'),
      ],
    ),
    _BillCategory(
      icon: Icons.request_quote_rounded,
      key: 'other-bills',
      en: 'Other bills',
      sw: 'Bili nyingine',
      accent: Color(0xFF7B8694),
      providers: [
        BillProviderEntry(label: 'Service invoice'),
        BillProviderEntry(label: 'Membership fee'),
        BillProviderEntry(label: 'Custom provider'),
      ],
    ),
  ];

  List<_BillCategory> get _activeBillCategories =>
      _paymentController.billCategories.isNotEmpty
      ? _paymentController.billCategories.map(_mapBillCatalogCategory).toList()
      : _billCategories;
  @override
  void initState() {
    super.initState();
    _paymentController = PaymentController()
      ..addListener(_handlePaymentControllerChange);
    _tabController = TabController(length: 3, vsync: this);
    _scannerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scannerPulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _scannerPulseController, curve: Curves.easeInOut),
    );
    _loadRoutingCatalog();
    unawaited(_paymentController.loadBillCatalog());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isSwahili =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
  }

  String _t(String en, String sw) => _isSwahili ? sw : en;

  @override
  void dispose() {
    _paymentController.removeListener(_handlePaymentControllerChange);
    _paymentController.dispose();
    unawaited(_scannerController?.stop() ?? Future<void>.value());
    _tabController.dispose();
    _scannerPulseController.dispose();
    _scannerController?.dispose();
    _merchantNumberController.dispose();
    super.dispose();
  }

  void _disposeControllersSafely(Iterable<TextEditingController> controllers) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _loadRoutingCatalog() async {
    final catalog = await _routingCatalogService.load();
    if (!mounted) return;
    setState(() => _routingCatalog = catalog);
  }

  void _handlePaymentControllerChange() {
    if (!mounted) return;
    final categories = _activeBillCategories;
    if (categories.isEmpty) {
      setState(() {});
      return;
    }
    final safeCategoryIndex = _selectedBillCategory.clamp(
      0,
      categories.length - 1,
    );
    final safeProviderIndex = categories[safeCategoryIndex].providers.isEmpty
        ? 0
        : _selectedBillProvider.clamp(
            0,
            categories[safeCategoryIndex].providers.length - 1,
          );
    setState(() {
      _selectedBillCategory = safeCategoryIndex;
      _selectedBillProvider = safeProviderIndex;
    });
  }

  _BillCategory _mapBillCatalogCategory(BillProviderCategory category) {
    final template = _resolveBillCategoryTemplate(category.key, category.label);
    return _BillCategory(
      icon: template.icon,
      key: category.key,
      en: category.label,
      sw: template.sw,
      accent: template.accent,
      providers: category.providers,
    );
  }

  ({IconData icon, Color accent, String sw}) _resolveBillCategoryTemplate(
    String rawKey,
    String rawLabel,
  ) {
    final normalized =
        '${rawKey.trim().toLowerCase()} ${rawLabel.trim().toLowerCase()}';
    if (normalized.contains('electric')) {
      return (
        icon: Icons.bolt_rounded,
        accent: const Color(0xFFE29A2D),
        sw: 'Umeme',
      );
    }
    if (normalized.contains('water')) {
      return (
        icon: Icons.water_drop_rounded,
        accent: const Color(0xFF3E8ED0),
        sw: 'Bili za maji',
      );
    }
    if (normalized.contains('gas')) {
      return (
        icon: Icons.local_fire_department_rounded,
        accent: const Color(0xFFE26A3C),
        sw: 'Gesi',
      );
    }
    if (normalized.contains('bundle')) {
      return (
        icon: Icons.wifi_tethering_rounded,
        accent: const Color(0xFF6D5CE7),
        sw: 'Bando',
      );
    }
    if (normalized.contains('internet')) {
      return (
        icon: Icons.router_rounded,
        accent: const Color(0xFF476FD6),
        sw: 'Intaneti',
      );
    }
    if (normalized.contains('school')) {
      return (
        icon: Icons.school_rounded,
        accent: const Color(0xFF2E8B79),
        sw: 'Ada za shule',
      );
    }
    if (normalized.contains('government')) {
      return (
        icon: Icons.account_balance_rounded,
        accent: const Color(0xFF2F6F9F),
        sw: 'Bili za serikali',
      );
    }
    if (normalized.contains('insurance')) {
      return (
        icon: Icons.shield_outlined,
        accent: const Color(0xFF16806D),
        sw: 'Bima',
      );
    }
    if (normalized.contains('telephone')) {
      return (
        icon: Icons.call_rounded,
        accent: const Color(0xFF8A5A44),
        sw: 'Simu ya mezani',
      );
    }
    if (normalized.contains('entertainment')) {
      return (
        icon: Icons.live_tv_rounded,
        accent: const Color(0xFFC7507A),
        sw: 'Burudani',
      );
    }
    return (
      icon: Icons.request_quote_rounded,
      accent: const Color(0xFF7B8694),
      sw: 'Bili nyingine',
    );
  }

  Future<void> _setMerchantMode(_MerchantPayMode mode) async {
    if (_merchantMode == mode) return;
    setState(() {
      _merchantMode = mode;
      if (mode == _MerchantPayMode.qr) {
        _scannerError = null;
      }
    });
    try {
      if (mode == _MerchantPayMode.qr) {
        await Future<void>.delayed(Duration.zero);
        await _ensureScannerController().start();
      } else {
        await _scannerController?.stop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerError = _mapStatus('Unable to open QR scanner right now.');
        _statusMessage = _scannerError;
        _statusTone = OrbiStatusTone.error;
      });
    }
  }

  MobileScannerController _ensureScannerController() {
    return _scannerController ??= MobileScannerController(
      autoStart: false,
      torchEnabled: _flashOn,
      detectionTimeoutMs: 900,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanPaused || !mounted) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    setState(() {
      _qrValue = code;
      _qrIntent = _scanPayService.parseQr(code);
      _scanPaused = true;
    });
    final detectedIntent = _qrIntent ?? const ScanPayIntent(rawValue: '');
    final detectedKind = _scanMatcher.classify(detectedIntent);
    final confidence = _scanConfidenceService.evaluate(
      detectedIntent,
      detectedKind,
    );
    debugPrint(
      '[PAY_SCAN] detected | kind=${detectedKind.name} | confidence=${confidence.level.name} | raw=${code.length > 48 ? '${code.substring(0, 48)}...' : code}',
    );
    _scannerController?.stop();
    _prepareQrPaymentDraft();
  }

  Future<void> _toggleTorch() async {
    final controller = _ensureScannerController();
    await controller.toggleTorch();
    if (!mounted) return;
    setState(() => _flashOn = !_flashOn);
  }

  Future<void> _resumeScan() async {
    setState(() {
      _scanPaused = false;
      _scannerError = null;
    });
    _lastAutoOpenedScanRaw = null;
    final controller = _ensureScannerController();
    await controller.start();
  }

  Future<void> _pickDocument(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2200,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedFile = File(picked.path);
      _scanResult = null;
      _receiptIntent = null;
      _scanError = null;
    });
  }

  Future<void> _scanReceipt() async {
    final file = _selectedFile;
    if (file == null) return;
    setState(() {
      _scanLoading = true;
      _scanError = null;
    });
    try {
      final result = await _receiptScanService.scan(file);
      if (!mounted) return;
      setState(() {
        _scanResult = result;
        _receiptIntent = result == null
            ? null
            : _scanPayService.fromReceipt(result);
        _scanError = result == null
            ? 'Unable to read this receipt. Try a clearer photo.'
            : null;
        _statusMessage = result == null
            ? _mapStatus('Unable to read this receipt. Try a clearer photo.')
            : _mapStatus('Receipt analyzed successfully.');
        _statusTone = result == null
            ? OrbiStatusTone.error
            : OrbiStatusTone.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanError = e.toString().replaceFirst('Exception: ', '').trim();
        _statusMessage = _mapStatus(_scanError!);
        _statusTone = OrbiStatusTone.error;
      });
    } finally {
      if (mounted) setState(() => _scanLoading = false);
    }
  }

  String _mapStatus(String message) {
    return mapBackendStatusMessage(message, sw: _isSwahili, fallback: message);
  }

  void _openPrefilledPayment(ScanPayIntent intent) {
    if (_scanMatcher.classify(intent) == PaymentScanKind.merchant) {
      final merchant = _merchantMatcher.matchIntent(
        intent,
        directory: _routingCatalog.merchantDirectory,
      );
      _openOrbiPaySheet(
        merchantInput: merchant?.reference,
        merchantDisplayName: merchant?.displayName,
        intent: intent,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendMoneyScreen(
          initialRecipientInput: intent.recipientInput,
          initialAmount: intent.amount,
          initialNote: intent.note,
        ),
      ),
    );
  }

  void _prepareQrPaymentDraft() {
    final intent = _qrIntent;
    if (intent == null) return;
    final l10n = AppLocalizations.of(context)!;
    final draftKind = _scanMatcher.classify(intent);
    final confidence = _scanConfidenceService.evaluate(intent, draftKind);
    if (confidence.level == PaymentScanConfidenceLevel.invalid) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentScanInvalidStatus);
        _statusTone = OrbiStatusTone.error;
      });
      debugPrint('[PAY_SCAN] invalid | raw=${intent.rawValue}');
      return;
    }
    if (!intent.canPrefillPayment) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentScanNeedsReview);
        _statusTone = OrbiStatusTone.info;
      });
      debugPrint('[PAY_SCAN] review_required | kind=${draftKind.name}');
      return;
    }
    setState(() {
      _statusMessage = _mapStatus(
        draftKind == PaymentScanKind.bill
            ? l10n.paymentScanBillAutoRoute
            : draftKind == PaymentScanKind.merchant
            ? l10n.paymentScanMerchantAutoRoute
            : l10n.paymentScanPaymentReady,
      );
      _statusTone = OrbiStatusTone.success;
    });
    if (draftKind == PaymentScanKind.universal) return;
    if (_lastAutoOpenedScanRaw == intent.rawValue) return;
    if (draftKind == PaymentScanKind.bill) {
      _applyBillCategoryFromIntent(intent);
    }
    _lastAutoOpenedScanRaw = intent.rawValue;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPrefilledPayment(intent);
    });
  }

  void _openMerchantNumberPayment() {
    final l10n = AppLocalizations.of(context)!;
    final recipient = _merchantNumberController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentMerchantNumberLabel);
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }
    final merchant = _merchantMatcher.matchManualInput(recipient);
    _openOrbiPaySheet(
      merchantInput: merchant?.reference,
      merchantDisplayName: merchant?.displayName,
    );
  }

  Future<void> _openOrbiPaySheet({
    String? merchantInput,
    String? merchantDisplayName,
    ScanPayIntent? intent,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    final merchantRef = (merchantInput ?? '').trim();
    if (merchantRef.isEmpty) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentMerchantNumberLabel);
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }

    final wallets = await _walletService.getWallets();
    final sourceWallets = wallets.where((wallet) {
      final linked = (wallet['is_linked'] ?? wallet['linked'] ?? false) == true;
      final locked = (wallet['is_locked'] ?? wallet['locked'] ?? false) == true;
      return !linked && !locked;
    }).toList();

    if (!mounted) return;
    if (sourceWallets.isEmpty) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentOrbiPayNoWallets);
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }

    String selectedWalletId = _walletIdOf(sourceWallets.first);
    String currency = _walletCurrencyOf(sourceWallets.first);
    final amountController = TextEditingController(text: intent?.amount ?? '');
    final noteController = TextEditingController(
      text: intent?.note ?? l10n.paymentMerchantDefaultNote,
    );

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ui.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return PaymentOrbiPaySheet(
            ui: ui,
            l10n: l10n,
            isSwahili: _isSwahili,
            merchantRef: merchantRef,
            merchantDisplayName: merchantDisplayName,
            sourceWallets: sourceWallets,
            initialSelectedWalletId: selectedWalletId,
            initialCurrency: currency,
            initialAmount: amountController.text,
            initialNote: noteController.text,
            walletIdOf: _walletIdOf,
            walletCurrencyOf: _walletCurrencyOf,
            walletDisplayName: _walletDisplayName,
            previewAmountValue: _previewAmountValue,
            previewValue: _previewValue,
            onPreview: (walletId, selectedCurrency, amount, note) {
              return _paymentController.previewOrbiPay(
                _buildMerchantPaymentPayload(
                  walletId: walletId,
                  currency: selectedCurrency,
                  merchantRef: merchantRef,
                  merchantDisplayName: merchantDisplayName,
                  amount: amount,
                  note: note,
                  intent: intent,
                ),
              );
            },
            onSettle: (walletId, selectedCurrency, amount, note, preview) {
              return _paymentController.settleOrbiPay(
                _buildMerchantPaymentPayload(
                  walletId: walletId,
                  currency: selectedCurrency,
                  merchantRef: merchantRef,
                  merchantDisplayName: merchantDisplayName,
                  amount: amount,
                  note: note,
                  intent: intent,
                  preview: preview,
                ),
              );
            },
            onCompleted: () {
              if (!mounted) return;
              setState(() {
                _statusMessage = _mapStatus(l10n.paymentOrbiPaySuccess);
                _statusTone = OrbiStatusTone.success;
              });
            },
          );
        },
      );
    } finally {
      _disposeControllersSafely([amountController, noteController]);
    }
  }

  Map<String, dynamic> _buildBillPaymentPayload({
    required String walletId,
    required String currency,
    required double amount,
    required String provider,
    required _BillCategory category,
    required String reference,
    required String note,
    ScanPayIntent? intent,
    Map<String, dynamic>? preview,
  }) {
    return <String, dynamic>{
      'sourceWalletId': walletId,
      'amount': amount,
      'currency': currency,
      'description': note.isEmpty ? '${category.en} payment' : note,
      'type': 'BILL_PAYMENT',
      'channel': 'ORBI_BILL_PAY',
      'recipientId': intent?.recipientInput ?? provider,
      'provider': provider,
      'billCategory': category.en,
      'reference': reference.isEmpty ? intent?.reference : reference,
      ...?preview == null ? null : {'preview': preview},
    };
  }

  Map<String, dynamic> _buildReserveBillPaymentPayload({
    required Map<String, dynamic> reserve,
    required String currency,
    required double amount,
    required String provider,
    required _BillCategory category,
    required String reference,
    required String note,
    Map<String, dynamic>? preview,
  }) {
    final reserveId =
        (reserve['id'] ?? reserve['bill_reserve_id'] ?? reserve['reserve_id'])
            .toString()
            .trim();
    return <String, dynamic>{
      'bill_reserve_id': reserveId,
      'reserve_id': reserveId,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'billCategory': category.en,
      if (reference.isNotEmpty) 'reference': reference,
      if (note.isNotEmpty) 'description': note,
      ...?preview == null ? null : {'preview': preview},
    };
  }

  Map<String, dynamic> _buildMerchantPaymentPayload({
    required String walletId,
    required String currency,
    required String merchantRef,
    String? merchantDisplayName,
    required double amount,
    required String note,
    ScanPayIntent? intent,
    Map<String, dynamic>? preview,
  }) {
    return <String, dynamic>{
      'sourceWalletId': walletId,
      'amount': amount,
      'currency': currency,
      'description': note.isEmpty ? 'Merchant payment' : note,
      'type': 'MERCHANT_PAYMENT',
      'channel': 'ORBI_PAY',
      'merchantPayNumber': merchantRef,
      'merchantId': intent?.merchantId ?? merchantRef,
      'merchantName': merchantDisplayName ?? intent?.merchantName,
      'recipient': intent?.recipientInput ?? merchantRef,
      'reference': intent?.reference,
      ...?preview == null ? null : {'preview': preview},
    };
  }

  String _walletIdOf(Map<String, dynamic> wallet) {
    final value =
        wallet['id'] ??
        wallet['wallet_id'] ??
        wallet['walletId'] ??
        wallet['sourceWalletId'];
    return value?.toString().trim() ?? '';
  }

  String _walletCurrencyOf(Map<String, dynamic> wallet) {
    final value = wallet['currency'] ?? wallet['wallet_currency'] ?? 'TZS';
    return value.toString().trim().isEmpty ? 'TZS' : value.toString().trim();
  }

  String _walletDisplayName(Map<String, dynamic> wallet) {
    return (wallet['name'] ??
            wallet['wallet_name'] ??
            wallet['label'] ??
            wallet['wallet_type'] ??
            wallet['type'] ??
            _walletIdOf(wallet))
        .toString();
  }

  Map<String, dynamic> _walletMetadata(Map<String, dynamic> wallet) {
    final metadata = wallet['metadata'];
    if (metadata is Map<String, dynamic>) return metadata;
    if (metadata is Map) return Map<String, dynamic>.from(metadata);
    return const <String, dynamic>{};
  }

  String _walletType(Map<String, dynamic> wallet) {
    return (wallet['wallet_type'] ??
            wallet['type'] ??
            _walletMetadata(wallet)['source_kind'] ??
            '')
        .toString()
        .toLowerCase();
  }

  bool _isGoalSourceWallet(Map<String, dynamic> wallet) {
    final metadata = _walletMetadata(wallet);
    return metadata['source_kind'] == 'goal' ||
        _walletType(wallet).contains('goal');
  }

  String _normalizeLoose(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Map<String, dynamic>? _matchBillReserve({
    required List<Map<String, dynamic>> reserves,
    required _BillCategory category,
    required String provider,
    String? reference,
  }) {
    final providerKey = _normalizeLoose(provider);
    final categoryKey = _normalizeLoose(category.en);
    final referenceKey = _normalizeLoose(reference ?? '');
    Map<String, dynamic>? bestMatch;
    var bestScore = 0;

    for (final reserve in reserves) {
      final status = (reserve['status'] ?? 'ACTIVE').toString().toUpperCase();
      if (status != 'ACTIVE') continue;

      final reserveProvider = _normalizeLoose(
        (reserve['provider_name'] ?? reserve['provider'] ?? '').toString(),
      );
      final reserveType = _normalizeLoose(
        (reserve['bill_type'] ?? '').toString(),
      );
      final reserveReference = _normalizeLoose(
        (reserve['reference'] ??
                reserve['bill_reference'] ??
                reserve['account_number'] ??
                reserve['meter_number'] ??
                reserve['customer_number'])
            .toString(),
      );

      final matchesProvider =
          reserveProvider.isNotEmpty &&
          (reserveProvider == providerKey ||
              reserveProvider.contains(providerKey) ||
              providerKey.contains(reserveProvider));
      final matchesCategory =
          reserveType.isNotEmpty &&
          (reserveType == categoryKey ||
              reserveType.contains(categoryKey) ||
              categoryKey.contains(reserveType));
      final matchesReference =
          referenceKey.isNotEmpty &&
          reserveReference.isNotEmpty &&
          (reserveReference == referenceKey ||
              reserveReference.contains(referenceKey) ||
              referenceKey.contains(reserveReference));

      var score = 0;
      if (matchesProvider) score += 5;
      if (matchesCategory) score += 4;
      if (matchesReference) score += 7;
      if (!matchesProvider && !matchesCategory && !matchesReference) continue;
      if (referenceKey.isNotEmpty &&
          reserveReference.isNotEmpty &&
          !matchesReference) {
        score -= 2;
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = Map<String, dynamic>.from(reserve)
          ..['_match_score'] = score;
      }
    }

    return bestScore >= 4 ? bestMatch : null;
  }

  bool _isStrongReserveMatch(Map<String, dynamic>? reserve) {
    if (reserve == null) return false;
    final score = int.tryParse('${reserve['_match_score'] ?? ''}') ?? 0;
    return score >= 9;
  }

  String _previewValue(Map<String, dynamic>? preview, List<String> keys) {
    if (preview == null) return '-';
    for (final key in keys) {
      final value = preview[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '-';
  }

  String _previewAmountValue(Map<String, dynamic>? preview) {
    if (preview == null) return '-';
    final rawAmount = _previewValue(preview, const [
      'amount',
      'netAmount',
      'totalAmount',
    ]);
    final parsedAmount = double.tryParse(rawAmount.replaceAll(',', ''));
    if (parsedAmount == null) return rawAmount;
    final currency = _previewValue(preview, const [
      'currency',
      'fromCurrency',
      'toCurrency',
    ]);
    return formatDisplayMoney(
      parsedAmount,
      currency == '-' ? 'TZS' : currency,
      locale: 'en_US',
    );
  }

  List<String> _providerLogoCandidates(
    String provider,
    _BillCategory category,
  ) {
    final auth = Provider.of<AuthController>(context, listen: false);
    final country = ProviderAssetResolver.resolveCountry(auth);
    return ProviderAssetResolver.billAssetCandidates(
      country: country,
      category: category.key,
      providerName: provider,
    );
  }

  ProviderPresentationSpec _providerStyle(
    BillProviderEntry provider,
    _BillCategory category,
  ) {
    return ProviderPresentationResolver.resolveBillProvider(
      providerName: provider.label,
      providerCode: provider.providerCode,
      colorHint: provider.color,
      iconHint: provider.displayIcon,
      logoUrlHint: provider.logoUrl,
      categoryKey: category.key,
      categoryColor: category.accent,
      categoryIcon: category.icon,
      assetCandidates: _providerLogoCandidates(provider.label, category),
    );
  }

  void _applyBillCategoryFromIntent(ScanPayIntent intent) {
    final categories = _activeBillCategories;
    if (categories.isEmpty) return;
    final match = _billMatcher.match(
      intent,
      categories
          .map(
            (category) =>
                category.providers.map((provider) => provider.label).toList(),
          )
          .toList(),
      additionalAliases: _routingCatalog.providerAliases,
    );
    if (match == null) return;
    setState(() {
      _selectedBillCategory = match.categoryIndex.clamp(
        0,
        categories.length - 1,
      );
      final providers = categories[_selectedBillCategory].providers;
      _selectedBillProvider = providers.isEmpty
          ? 0
          : match.providerIndex.clamp(0, providers.length - 1);
      _tabController.index = 0;
    });
  }

  Future<void> _openBillProvidersScreen(
    int categoryIndex, {
    ScanPayIntent? intent,
  }) async {
    final categories = _activeBillCategories;
    if (categories.isEmpty || categoryIndex >= categories.length) return;
    final category = categories[categoryIndex];
    final initialProviderIndex = category.providers.isEmpty
        ? 0
        : (categoryIndex == _selectedBillCategory ? _selectedBillProvider : 0)
              .clamp(0, category.providers.length - 1);

    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (context) => PaymentBillProvidersScreen(
          categoryTitle: _isSwahili ? category.sw : category.en,
          isSwahili: _isSwahili,
          initialSelectedIndex: initialProviderIndex,
          providers: category.providers
              .map((provider) {
                final style = _providerStyle(provider, category);
                return PaymentBillProviderOption(
                  label: provider.label,
                  icon: style.icon,
                  color: style.color,
                  assetCandidates: style.assetCandidates,
                  logoUrl: style.logoUrl,
                );
              })
              .toList(growable: false),
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _selectedBillCategory = categoryIndex;
      _selectedBillProvider = result;
    });
    final provider = category.providers[result];
    await _openBillPaySheet(
      category: category,
      provider: provider,
      intent: intent,
    );
  }

  Future<void> _openBillPaySheet({
    required _BillCategory category,
    required BillProviderEntry provider,
    ScanPayIntent? intent,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: ui.accent),
              const SizedBox(height: 14),
              Text(
                sw
                    ? 'Tunaandaa malipo ya bili...'
                    : 'Preparing bill payment...',
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    List<Map<String, dynamic>> wallets = const [];
    List<Map<String, dynamic>> reserves = const [];
    List<Map<String, dynamic>> sharedBudgets = const [];
    try {
      final results = await Future.wait([
        _walletService.getWallets(),
        _wealthService.listBillReserves(),
        _wealthService.listSharedBudgets(),
      ]);
      wallets = List<Map<String, dynamic>>.from(results[0] as List);
      reserves = List<Map<String, dynamic>>.from(results[1] as List);
      sharedBudgets = List<Map<String, dynamic>>.from(results[2] as List);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    final sourceWallets = wallets.where((wallet) {
      final linked = (wallet['is_linked'] ?? wallet['linked'] ?? false) == true;
      final locked = (wallet['is_locked'] ?? wallet['locked'] ?? false) == true;
      return !linked && !locked && !_isGoalSourceWallet(wallet);
    }).toList();

    final matchingReserve = _matchBillReserve(
      reserves: reserves,
      category: category,
      provider: provider.label,
      reference: intent?.reference,
    );
    final strongReserveMatch = _isStrongReserveMatch(matchingReserve);

    if (sourceWallets.isEmpty &&
        sharedBudgets.isEmpty &&
        matchingReserve == null) {
      setState(() {
        _statusMessage = _mapStatus(l10n.paymentOrbiPayNoWallets);
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }

    final providerStyle = _providerStyle(provider, category);
    final selectedWalletId = sourceWallets.isNotEmpty
        ? _walletIdOf(sourceWallets.first)
        : '';
    final currency = sourceWallets.isNotEmpty
        ? _walletCurrencyOf(sourceWallets.first)
        : ((matchingReserve?['currency'] ?? 'TZS').toString());
    final selectedSharedBudgetId = sharedBudgets.isNotEmpty
        ? (sharedBudgets.first['id'] ?? '').toString()
        : '';
    final initialFundingMode = matchingReserve != null
        ? PaymentBillFundingMode.reserve
        : sourceWallets.isNotEmpty
        ? PaymentBillFundingMode.wallet
        : PaymentBillFundingMode.sharedBudget;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return PaymentBillPaySheet(
          ui: ui,
          l10n: l10n,
          isSwahili: sw,
          provider: provider.label,
          categoryLabel: category.en,
          providerAccent: providerStyle.color,
          providerIcon: providerStyle.icon,
          providerAssets: providerStyle.assetCandidates,
          providerLogoUrl: providerStyle.logoUrl,
          sourceWallets: sourceWallets,
          sharedBudgets: sharedBudgets,
          matchingReserve: matchingReserve,
          strongReserveMatch: strongReserveMatch,
          initialFundingMode: initialFundingMode,
          initialSelectedWalletId: selectedWalletId,
          initialCurrency: currency,
          initialSelectedSharedBudgetId: selectedSharedBudgetId,
          initialAmount: intent?.amount ?? '',
          initialReference: intent?.reference ?? '',
          initialNote: intent?.note ?? '',
          walletIdOf: _walletIdOf,
          walletCurrencyOf: _walletCurrencyOf,
          walletDisplayName: _walletDisplayName,
          previewAmountValue: _previewAmountValue,
          previewValue: _previewValue,
          onPreviewWallet:
              (walletId, selectedCurrency, amount, reference, note) {
                return _paymentController.previewBillPayment(
                  _buildBillPaymentPayload(
                    walletId: walletId,
                    currency: selectedCurrency,
                    amount: amount,
                    provider: provider.label,
                    category: category,
                    reference: reference,
                    note: note,
                    intent: intent,
                  ),
                );
              },
          onPreviewReserve: (selectedCurrency, amount, reference, note) {
            return _paymentController.previewBillPaymentFromReserve(
              _buildReserveBillPaymentPayload(
                reserve: matchingReserve!,
                currency: selectedCurrency,
                amount: amount,
                provider: provider.label,
                category: category,
                reference: reference,
                note: note,
              ),
            );
          },
          onPreviewSharedBudget: (sharedBudgetId, amount, reference, note) {
            return _wealthService.previewSharedBudgetSpend(sharedBudgetId, {
              'amount': amount,
              'provider': provider.label,
              'type': 'BILL_PAYMENT',
              'bill_category': category.en,
              if (reference.trim().isNotEmpty) 'reference': reference.trim(),
              if (note.trim().isNotEmpty) 'description': note.trim(),
            });
          },
          onSettleWallet:
              (walletId, selectedCurrency, amount, reference, note, preview) {
                return _paymentController.settleBillPayment(
                  _buildBillPaymentPayload(
                    walletId: walletId,
                    currency: selectedCurrency,
                    amount: amount,
                    provider: provider.label,
                    category: category,
                    reference: reference,
                    note: note,
                    intent: intent,
                    preview: preview,
                  ),
                );
              },
          onSettleReserve:
              (selectedCurrency, amount, reference, note, preview) {
                return _paymentController.settleBillPaymentFromReserve(
                  _buildReserveBillPaymentPayload(
                    reserve: matchingReserve!,
                    currency: selectedCurrency,
                    amount: amount,
                    provider: provider.label,
                    category: category,
                    reference: reference,
                    note: note,
                    preview: preview,
                  ),
                );
              },
          onSettleSharedBudget: (sharedBudgetId, amount, reference, note) {
            return _wealthService.settleSharedBudgetSpend(sharedBudgetId, {
              'amount': amount,
              'provider': provider.label,
              'type': 'BILL_PAYMENT',
              'bill_category': category.en,
              if (reference.trim().isNotEmpty) 'reference': reference.trim(),
              if (note.trim().isNotEmpty) 'description': note.trim(),
            });
          },
          onCompleted: (mode) {
            if (!mounted) return;
            setState(() {
              _statusMessage = _mapStatus(
                mode == PaymentBillFundingMode.sharedBudget
                    ? l10n.paymentBillPaySharedBudgetSuccess
                    : mode == PaymentBillFundingMode.reserve
                    ? l10n.paymentBillPayReserveSuccess
                    : l10n.paymentBillPaySuccess,
              );
              _statusTone = OrbiStatusTone.success;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ui.card.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.paymentHubTitle),
        toolbarHeight: 60,
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: ui.textPrimary,
          unselectedLabelColor: ui.textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          indicator: BoxDecoration(
            color: ui.cardStrong.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          splashBorderRadius: BorderRadius.circular(12),
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long_rounded),
              text: l10n.paymentTabBills,
            ),
            Tab(
              icon: const Icon(Icons.storefront_rounded),
              text: l10n.paymentTabMerchants,
            ),
            Tab(
              icon: const Icon(Icons.verified_user_rounded),
              text: _isSwahili ? 'Maombi' : 'Requests',
            ),
          ],
        ),
      ),
      body: OrbiLoadingOverlay(
        loading: _scanLoading,
        message: l10n.paymentAnalyzing,
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        child: OrbiBackground(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              OrbiResponsiveContent(
                padding: OrbiResponsive.pagePadding(
                  context,
                  top: 12,
                  bottom: 0,
                ),
                child: Column(
                  children: [
                    _buildPaymentHeroCard(l10n),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBillsHub(),
                    _buildMerchantHub(),
                    const ServicePaymentRequestsScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillsHub() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return PaymentBillsHub(
      ui: ui,
      l10n: l10n,
      isSwahili: _isSwahili,
      isLoading: _paymentController.isBillCatalogLoading,
      selectedIndex: _selectedBillCategory,
      categories: _activeBillCategories
          .map(
            (item) => PaymentBillsHubCategory(
              label: _isSwahili ? item.sw : item.en,
              icon: item.icon,
              color: item.accent,
              subtitle: _isSwahili
                  ? '${item.providers.length} watoa huduma'
                  : '${item.providers.length} providers',
            ),
          )
          .toList(growable: false),
      onCategoryTap: (index) async {
        setState(() {
          _selectedBillCategory = index;
          _selectedBillProvider = 0;
        });
        await _openBillProvidersScreen(index);
      },
    );
  }

  Widget _buildMerchantHub() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return PaymentMerchantHub(
      ui: ui,
      l10n: l10n,
      title: l10n.paymentMerchantTitle,
      subtitle: _t(
        'Pay merchants your way.',
        'Lipa wafanyabiashara kwa urahisi.',
      ),
      selectedModeIndex: _merchantMode.index,
      modeOptions: [
        PaymentMerchantModeOption(
          icon: Icons.dialpad_rounded,
          label: _isSwahili ? 'Namba ya malipo' : 'Pay number',
        ),
        const PaymentMerchantModeOption(
          icon: Icons.qr_code_scanner_rounded,
          label: 'QR',
        ),
        PaymentMerchantModeOption(
          icon: Icons.receipt_long_rounded,
          label: _isSwahili ? 'Risiti' : 'Receipt',
        ),
      ],
      onModeSelected: (index) {
        unawaited(_setMerchantMode(_MerchantPayMode.values[index]));
      },
      content: _merchantMode == _MerchantPayMode.number
          ? _buildMerchantNumberCard()
          : _merchantMode == _MerchantPayMode.qr
          ? _buildQrScanner()
          : _buildDocumentScanner(),
    );
  }

  Widget _buildMerchantNumberCard() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.store_mall_directory_rounded,
              color: ui.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.paymentMerchantNumberTitle,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.paymentMerchantNumberSubtitle,
            style: TextStyle(color: ui.textMuted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _merchantNumberController,
            decoration: InputDecoration(
              labelText: l10n.paymentMerchantNumberLabel,
              hintText: l10n.paymentMerchantNumberHint,
              prefixIcon: const Icon(Icons.store_mall_directory_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openMerchantNumberPayment,
            icon: const Icon(Icons.payments_outlined),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            label: Text(l10n.paymentContinueMerchantPay),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScanner() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final scannerController = _ensureScannerController();
    final qrIntent = _qrIntent;
    final draftKind = _scanMatcher.classify(
      qrIntent ?? const ScanPayIntent(rawValue: ''),
    );
    final confidence = _scanConfidenceService.evaluate(qrIntent, draftKind);
    final invalidScan =
        _qrValue != null &&
        confidence.level == PaymentScanConfidenceLevel.invalid;
    return PaymentQrScannerPanel(
      ui: ui,
      l10n: l10n,
      scannerView: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _buildScannerErrorView(error),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.14),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 224,
                    height: 224,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Stack(
                      children: [
                        _scannerCorner(Alignment.topLeft, ui),
                        _scannerCorner(Alignment.topRight, ui),
                        _scannerCorner(Alignment.bottomLeft, ui),
                        _scannerCorner(Alignment.bottomRight, ui),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: ui.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.paymentMerchantQrFrameHint,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      statusTitle: _scannerError != null
          ? l10n.paymentScannerUnavailableTitle
          : _qrValue == null
          ? l10n.paymentScanSearching
          : l10n.paymentScanDetected,
      statusSubtitle:
          _scannerError ??
          (_qrValue == null
              ? l10n.paymentScanSearchingSubtitle
              : l10n.paymentScannedValue(_qrValue!)),
      statusIcon: _qrValue == null
          ? Icons.center_focus_strong_rounded
          : Icons.check_circle_rounded,
      statusColor: _qrValue == null ? ui.warning : ui.success,
      flashOn: _flashOn,
      onToggleTorch: _toggleTorch,
      onResumeScan: _resumeScan,
      draftCard: invalidScan
          ? _buildInvalidScanCard()
          : _qrIntent != null
          ? _buildDetectedPaymentDraftCard(
              _qrIntent!,
              sourceLabel: l10n.paymentScanSourceQr,
            )
          : null,
      primaryAction: (_qrIntent?.canPrefillPayment ?? false) && !invalidScan
          ? FilledButton.icon(
              onPressed: () => _openPrefilledPayment(_qrIntent!),
              icon: const Icon(Icons.payments_outlined),
              style: FilledButton.styleFrom(
                backgroundColor: ui.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              label: Text(l10n.paymentScanOpenDraft),
            )
          : null,
    );
  }

  Widget _buildDetectedPaymentDraftCard(
    ScanPayIntent intent, {
    required String sourceLabel,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final draftKind = _scanMatcher.classify(intent);
    final confidence = _scanConfidenceService.evaluate(intent, draftKind);
    final draftAccent = _scanDraftAccent(ui, draftKind);
    final headline = _scanDraftHeadline(l10n, intent, draftKind);
    final subtitle = _scanDraftSubtitle(l10n, intent, draftKind);
    final primaryAmount = (intent.amount ?? '').trim();
    final detailTiles = <Widget>[
      if ((intent.merchantName ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentMerchantLabel,
          intent.merchantName!.trim(),
          ui,
        ),
      if ((intent.provider ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentScanDetailProvider,
          intent.provider!.trim(),
          ui,
        ),
      if ((intent.billCategory ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentScanDetailCategory,
          intent.billCategory!.trim(),
          ui,
        ),
      if ((intent.recipientInput ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentScanDetailRecipient,
          intent.recipientInput!.trim(),
          ui,
        ),
      if ((intent.reference ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentScanDetailReference,
          intent.reference!.trim(),
          ui,
        ),
      if ((intent.merchantId ?? '').trim().isNotEmpty)
        _scanDetailTile(
          l10n.paymentScanDetailMerchantId,
          intent.merchantId!.trim(),
          ui,
        ),
      if (intent.isOrbiSchema)
        _scanDetailTile(
          l10n.paymentScanDetailSchema,
          intent.schemaVersion == null
              ? 'ORBI'
              : 'ORBI ${intent.schemaVersion}',
          ui,
        ),
      if ((intent.note ?? '').trim().isNotEmpty)
        _scanDetailTile(l10n.paymentNoteLabel, intent.note!.trim(), ui),
    ];
    return PaymentDetectedDraftCard(
      ui: ui,
      draftAccent: draftAccent,
      draftIcon: _scanDraftIcon(draftKind),
      headline: headline,
      subtitle: subtitle,
      sourceLabel: sourceLabel,
      confidenceColor: _scanConfidenceColor(ui, confidence.level),
      confidenceLabel: _scanConfidenceLabel(l10n, confidence.level),
      confidenceBadge: ScaleTransition(
        scale: _scannerPulse,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _scanConfidenceColor(
              ui,
              confidence.level,
            ).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _scanConfidenceLabel(l10n, confidence.level),
            style: TextStyle(
              color: _scanConfidenceColor(ui, confidence.level),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
      showMerchantIdentity:
          draftKind == PaymentScanKind.merchant &&
          ((intent.merchantName ?? '').trim().isNotEmpty ||
              (intent.merchantId ?? '').trim().isNotEmpty),
      merchantIdentity: PaymentMerchantIdentityTile(
        ui: ui,
        accent: draftAccent,
        title: (intent.merchantName ?? intent.recipientInput ?? '').trim(),
        subtitle: (intent.merchantId ?? intent.recipientInput ?? '').trim(),
      ),
      draftLabel: _scanDraftLabel(l10n, draftKind),
      primaryAmount: primaryAmount,
      amountPendingLabel: l10n.paymentScanDraftAmountPending,
      referenceText: (intent.reference ?? '').trim().isEmpty
          ? null
          : '${l10n.paymentScanDetailReference}: ${intent.reference!.trim()}',
      autoCreatedLabel: l10n.paymentScanDraftAutoCreated,
      detailTiles: detailTiles,
      readyForPayment: intent.canPrefillPayment,
      readyLabel: l10n.paymentScanPaymentReady,
      needsReviewLabel: l10n.paymentScanNeedsReview,
    );
  }

  Color _scanDraftAccent(OrbiUiTokens ui, PaymentScanKind kind) {
    switch (kind) {
      case PaymentScanKind.bill:
        return const Color(0xFF3E8ED0);
      case PaymentScanKind.merchant:
        return ui.accent;
      case PaymentScanKind.universal:
        return ui.success;
    }
  }

  IconData _scanDraftIcon(PaymentScanKind kind) {
    switch (kind) {
      case PaymentScanKind.bill:
        return Icons.receipt_long_rounded;
      case PaymentScanKind.merchant:
        return Icons.storefront_rounded;
      case PaymentScanKind.universal:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _scanConfidenceColor(
    OrbiUiTokens ui,
    PaymentScanConfidenceLevel level,
  ) {
    switch (level) {
      case PaymentScanConfidenceLevel.high:
        return ui.success;
      case PaymentScanConfidenceLevel.medium:
        return ui.accent;
      case PaymentScanConfidenceLevel.low:
        return ui.warning;
      case PaymentScanConfidenceLevel.invalid:
        return ui.danger;
    }
  }

  String _scanConfidenceLabel(
    AppLocalizations l10n,
    PaymentScanConfidenceLevel level,
  ) {
    switch (level) {
      case PaymentScanConfidenceLevel.high:
        return l10n.paymentScanConfidenceHigh;
      case PaymentScanConfidenceLevel.medium:
        return l10n.paymentScanConfidenceMedium;
      case PaymentScanConfidenceLevel.low:
        return l10n.paymentScanConfidenceLow;
      case PaymentScanConfidenceLevel.invalid:
        return l10n.paymentScanConfidenceInvalid;
    }
  }

  String _scanDraftLabel(AppLocalizations l10n, PaymentScanKind kind) {
    switch (kind) {
      case PaymentScanKind.bill:
        return l10n.paymentScanTypeBill;
      case PaymentScanKind.merchant:
        return l10n.paymentScanTypeMerchant;
      case PaymentScanKind.universal:
        return l10n.paymentScanTypeUniversal;
    }
  }

  String _scanDraftHeadline(
    AppLocalizations l10n,
    ScanPayIntent intent,
    PaymentScanKind kind,
  ) {
    final primary =
        (intent.merchantName ?? intent.provider ?? intent.billCategory ?? '')
            .trim();
    if (primary.isEmpty) {
      return l10n.paymentQrDetectedTitle;
    }
    switch (kind) {
      case PaymentScanKind.bill:
        return l10n.paymentScanBillDraftTitle(primary);
      case PaymentScanKind.merchant:
        return l10n.paymentScanMerchantDraftTitle(primary);
      case PaymentScanKind.universal:
        return l10n.paymentScanUniversalDraftTitle(primary);
    }
  }

  String _scanDraftSubtitle(
    AppLocalizations l10n,
    ScanPayIntent intent,
    PaymentScanKind kind,
  ) {
    if (intent.canPrefillPayment) {
      switch (kind) {
        case PaymentScanKind.bill:
          return l10n.paymentScanBillDraftSubtitle;
        case PaymentScanKind.merchant:
          return l10n.paymentScanMerchantDraftSubtitle;
        case PaymentScanKind.universal:
          return l10n.paymentScanUniversalDraftSubtitle;
      }
    }
    return l10n.paymentScanNeedsReviewSubtitle;
  }

  Widget _scanDetailTile(String label, String value, OrbiUiTokens ui) {
    return PaymentScanDetailTile(label: label, value: value, ui: ui);
  }

  Widget _scannerCorner(Alignment alignment, OrbiUiTokens ui) {
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide(color: ui.accent, width: 4) : BorderSide.none,
            bottom: !top
                ? BorderSide(color: ui.accent, width: 4)
                : BorderSide.none,
            left: left
                ? BorderSide(color: ui.accent, width: 4)
                : BorderSide.none,
            right: !left
                ? BorderSide(color: ui.accent, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildInvalidScanCard() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return PaymentInvalidScanCard(
      ui: ui,
      title: l10n.paymentScanInvalidTitle,
      subtitle: l10n.paymentScanInvalidSubtitle,
      actionLabel: l10n.paymentScanInvalidFallbackAction,
      onFallback: () {
        setState(() => _merchantMode = _MerchantPayMode.number);
      },
    );
  }

  Widget _buildDocumentScanner() {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    return PaymentReceiptScannerPanel(
      ui: ui,
      l10n: l10n,
      selectedFile: _selectedFile,
      onPickGallery: () => _pickDocument(ImageSource.gallery),
      onPickCamera: () => _pickDocument(ImageSource.camera),
      onAnalyze: _scanReceipt,
      analyzeEnabled: !_scanLoading,
      filePathText: _selectedFile == null
          ? null
          : l10n.paymentSavedPath(_selectedFile!.path),
      resultCard: _scanResult == null ? null : _scanResultCard(_scanResult!),
      primaryAction: _receiptIntent?.amount != null
          ? FilledButton.icon(
              onPressed: () => _openPrefilledPayment(
                _receiptIntent ??
                    ScanPayIntent(
                      rawValue: '',
                      amount: _scanResult!.amount.toStringAsFixed(2),
                      note: _scanResult!.merchant,
                    ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.paymentUseForPayment),
            )
          : null,
    );
  }

  Widget _scanResultCard(ReceiptScanResult result) {
    final l10n = AppLocalizations.of(context)!;
    final intent =
        _receiptIntent ??
        ScanPayIntent(
          rawValue:
              '${result.merchant} ${result.amount} ${result.currency} ${result.date}',
          amount: result.amount.toStringAsFixed(2),
          note: result.merchant,
          merchantName: result.merchant,
          reference: result.date,
        );
    return PaymentScanResultCard(
      extractedDetailsLabel: l10n.paymentExtractedDetails,
      merchantLabel: l10n.paymentMerchantLabel,
      amountLabel: l10n.paymentAmountLabel,
      dateLabel: l10n.paymentDateLabel,
      merchantValue: result.merchant,
      amountValue: formatFinancialMoney(
        result.amount,
        result.currency,
        locale: 'en_US',
      ),
      dateValue: result.date,
      draftCard: _buildDetectedPaymentDraftCard(
        intent,
        sourceLabel: l10n.paymentScanSourceReceipt,
      ),
    );
  }

  Widget _buildScannerErrorView(MobileScannerException error) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        l10n.paymentScannerPermissionRequired,
      MobileScannerErrorCode.unsupported => l10n.paymentScannerUnsupported,
      MobileScannerErrorCode.controllerNotAttached =>
        l10n.paymentScannerPreparing,
      _ => l10n.paymentScannerGenericError,
    };
    return PaymentScannerErrorView(
      ui: ui,
      message: _mapStatus(message),
      retryLabel: l10n.actionRetry,
      onRetry: _resumeScan,
      permissionDenied: permissionDenied,
      openSettingsLabel: l10n.paymentScannerOpenSettings,
      onOpenSettings: _openDeviceAppSettings,
    );
  }

  Future<void> _openDeviceAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _mapStatus(
          'Open device settings and allow camera access for ORBI.',
        );
        _statusTone = OrbiStatusTone.info;
      });
    }
  }

  Widget _buildPaymentHeroCard(AppLocalizations l10n) {
    return OrbiBrandHeroCard(
      title: l10n.paymentHubTitle,
      subtitle: _t(
        'Bills, merchants, and QR payments in one place.',
        'Bili, merchant, na QR sehemu moja.',
      ),
      icon: Icons.qr_code_2_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OrbiHeroMetricChip(
            label: _t('Bills', 'Bili'),
            value: _t('Ready', 'Tayari'),
            icon: Icons.receipt_long_rounded,
          ),
          OrbiHeroMetricChip(
            label: _t('Merchants', 'Merchant'),
            value: _t('Scan', 'Scan'),
            icon: Icons.storefront_rounded,
          ),
          OrbiHeroMetricChip(
            label: 'ORBI',
            value: _t('Pay', 'Lipa'),
            icon: Icons.bolt_rounded,
          ),
        ],
      ),
    );
  }
}
