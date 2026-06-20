import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/transaction_geo_context.dart';
import '../../../core/security/device_fingerprint.dart';
import '../../../core/session/activity_tracker.dart';
import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/utils/provider_asset_resolver.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_dialogs.dart';
import '../../../core/widgets/orbi_feature_card.dart';
import '../../../core/widgets/orbi_logo.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/pin_prompt.dart';
import '../../../core/widgets/provider_logo_image.dart';
import '../../../core/widgets/security_otp_dialog.dart';
import '../../auth/state/auth_controller.dart';
import '../../goals/data/goals_service.dart';
import '../../goals/state/goals_controller.dart';
import '../../services/data/service_actor_service.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/fx_quote_service.dart';
import '../../payment/data/gateway_payment_models.dart';
import '../../payment/data/gateway_payment_service.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({
    super.key,
    this.initialRecipientInput,
    this.initialAmount,
    this.initialNote,
    this.startInExternalMode = false,
    this.externalOnly = false,
    this.titleOverride,
    this.iconAssetPath,
    this.externalExperience = ExternalExperience.send,
  });

  final String? initialRecipientInput;
  final String? initialAmount;
  final String? initialNote;
  final bool startInExternalMode;
  final bool externalOnly;
  final String? titleOverride;
  final String? iconAssetPath;
  final ExternalExperience externalExperience;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

enum _TransferMode { internalP2P, external }

enum ExternalExperience { send, transfer, withdraw }

enum _ExternalTransferRail { bank, mobileWallet, externalAgent, paypal, crypto }

enum _ExternalSourceWalletType { internal, externalMobileWallet, externalBank }

class _RecipientPreview {
  final String internalId;
  final String recipientId;
  final String displayIdentifier;
  final String fullName;
  final String? avatarUrl;
  final String registryType;
  final bool isPaysafeVerified;

  const _RecipientPreview({
    required this.internalId,
    required this.recipientId,
    required this.displayIdentifier,
    required this.fullName,
    this.avatarUrl,
    required this.registryType,
    required this.isPaysafeVerified,
  });
}

class _SendMoneyScreenState extends State<SendMoneyScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _transactionRequestTimeout = Duration(seconds: 15);
  static const Duration _previewRequestTimeout = Duration(seconds: 25);
  static const List<String> _withdrawAgentProviders = ['ORBI Wakala'];
  final GlobalKey<FormState> _internalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _externalFormKey = GlobalKey<FormState>();
  bool _otpDialogOpen = false;
  bool _internalSourceWalletExpanded = false;

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  Color get _flowAccent {
    final ui = OrbiTheme.uiOf(context);
    if (_mode == _TransferMode.internalP2P) {
      return const Color(0xFF0F9D7A);
    }
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return ui.accent;
      case ExternalExperience.withdraw:
        return ui.accent;
      case ExternalExperience.send:
        return const Color(0xFF0F9D7A);
    }
  }

  Color get _flowAccentFaint {
    final ui = OrbiTheme.uiOf(context);
    return Color.lerp(ui.cardMuted, _flowAccent, 0.10) ?? ui.cardMuted;
  }

  Color get _activeExternalProviderAccent {
    final provider = _externalProviderController.text.trim();
    if (provider.isEmpty) return _flowAccent;
    return _movementProviderColor(provider);
  }

  List<_ExternalTransferRail> get _availableExternalRails {
    final configured = <_ExternalTransferRail>[
      if (widget.externalExperience == ExternalExperience.withdraw)
        _ExternalTransferRail.externalAgent,
      if (_providersForRail(_ExternalTransferRail.bank).isNotEmpty)
        _ExternalTransferRail.bank,
      if (_providersForRail(_ExternalTransferRail.mobileWallet).isNotEmpty)
        _ExternalTransferRail.mobileWallet,
      if (_providersForRail(_ExternalTransferRail.crypto).isNotEmpty)
        _ExternalTransferRail.crypto,
    ];
    if (configured.isNotEmpty || !_loadingExternalPaymentProviders) {
      return configured;
    }
    switch (widget.externalExperience) {
      case ExternalExperience.withdraw:
        return const [_ExternalTransferRail.externalAgent];
      case ExternalExperience.transfer:
      case ExternalExperience.send:
        return const [];
    }
  }

  String get _movementAssetFlow =>
      widget.externalExperience == ExternalExperience.withdraw
      ? 'Withdraw'
      : 'Transfers';

  String get _movementAssetCategory {
    switch (_externalRail) {
      case _ExternalTransferRail.bank:
        return 'Banks';
      case _ExternalTransferRail.mobileWallet:
        return 'Mobile Money';
      case _ExternalTransferRail.externalAgent:
        return 'External Agents';
      case _ExternalTransferRail.paypal:
        return 'PayPal';
      case _ExternalTransferRail.crypto:
        return 'Crypto';
    }
  }

  String get _externalContinueLabel {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw ? 'Continue Transfer' : 'Continue Transfer';
      case ExternalExperience.withdraw:
        return _isSw ? 'Continue Withdraw' : 'Continue Withdraw';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyContinueExternalTransferLabel;
    }
  }

  IconData get _externalContinueIcon {
    if (widget.externalExperience == ExternalExperience.withdraw) {
      switch (_externalRail) {
        case _ExternalTransferRail.externalAgent:
          return Icons.storefront_rounded;
        case _ExternalTransferRail.mobileWallet:
          return Icons.phone_android_rounded;
        case _ExternalTransferRail.bank:
          return Icons.account_balance_rounded;
        default:
          return Icons.arrow_forward_rounded;
      }
    }
    return Icons.arrow_forward_rounded;
  }

  String get _externalRailSectionTitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw
            ? 'Njia na provider ya transfer'
            : 'Transfer route & provider';
      case ExternalExperience.withdraw:
        return _isSw
            ? 'Njia na provider ya withdraw'
            : 'Withdraw route & provider';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionRailProviderTitle;
    }
  }

  String get _externalRailSectionSubtitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw
            ? 'Chagua njia na provider.'
            : 'Choose route and provider.';
      case ExternalExperience.withdraw:
        return _isSw ? 'Chagua njia na provider' : 'Choose route and provider';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionRailProviderSubtitle;
    }
  }

  String get _externalDestinationSectionTitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw ? 'Mahali pa transfer' : 'Transfer destination';
      case ExternalExperience.withdraw:
        return _isSw ? 'Mahali pa payout' : 'Withdraw destination';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionDestinationTitle;
    }
  }

  String get _externalDestinationSectionSubtitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        if (_externalRail == _ExternalTransferRail.bank) {
          return _isSw
              ? 'Weka namba ya akaunti ya benki.'
              : 'Enter bank account number.';
        }
        if (_externalRail == _ExternalTransferRail.mobileWallet) {
          return _isSw
              ? 'Weka namba ya Mobile Money.'
              : 'Enter Mobile Money number.';
        }
        if (_externalRail == _ExternalTransferRail.paypal) {
          return _isSw
              ? 'Weka barua pepe au handle ya PayPal ya mpokeaji.'
              : 'Enter PayPal email or handle.';
        }
        if (_externalRail == _ExternalTransferRail.crypto) {
          return _isSw
              ? 'Weka wallet address au memo ya mpokeaji wa transfer.'
              : 'Enter wallet address or memo.';
        }
        return _isSw
            ? 'Weka taarifa za mpokeaji.'
            : 'Enter destination details.';
      case ExternalExperience.withdraw:
        if (_externalRail == _ExternalTransferRail.externalAgent) {
          return _isSw ? 'Weka Agent ID Number' : 'Enter Agent ID number';
        }
        if (_externalRail == _ExternalTransferRail.mobileWallet) {
          return _isSw
              ? 'Weka namba ya Mobile Money'
              : 'Enter Mobile Money number';
        }
        return _isSw
            ? 'Weka namba ya akaunti ya benki'
            : 'Enter bank account number';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionDestinationSubtitle;
    }
  }

  String get _externalFundingSectionTitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw ? 'Fedha ya transfer' : 'Transfer funding';
      case ExternalExperience.withdraw:
        return _isSw ? 'Chanzo cha withdraw' : 'Withdraw funding';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionFundingTitle;
    }
  }

  String get _externalFundingSectionSubtitle {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        return _isSw ? 'Chagua wallet.' : 'Choose wallet.';
      case ExternalExperience.withdraw:
        return _isSw ? 'Chagua wallet ya kutoa' : 'Choose funding wallet';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyExternalSectionFundingSubtitle;
    }
  }

  String get _externalReferenceLabel {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        if (_externalRail == _ExternalTransferRail.bank) {
          return _isSw ? 'Jina la mwenye akaunti' : 'Bank recipient';
        }
        if (_externalRail == _ExternalTransferRail.mobileWallet) {
          return _isSw ? 'Jina la mwenye namba' : 'Mobile Money recipient';
        }
        if (_externalRail == _ExternalTransferRail.paypal) {
          return _isSw ? 'Mpokeaji wa PayPal' : 'PayPal recipient';
        }
        if (_externalRail == _ExternalTransferRail.crypto) {
          return _isSw ? 'Mpokeaji wa wallet' : 'Wallet recipient';
        }
        return _isSw ? 'Mpokeaji wa transfer' : 'Transfer recipient';
      case ExternalExperience.withdraw:
        return _isSw ? 'Mpokeaji' : 'Recipient';
      case ExternalExperience.send:
        return AppLocalizations.of(context)!.sendMoneyRecipientReferenceLabel;
    }
  }

  String get _externalReferenceHint {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        if (_externalRail == _ExternalTransferRail.bank) {
          return _isSw
              ? 'Weka jina la mwenye akaunti ya benki'
              : 'Enter the bank account holder name';
        }
        if (_externalRail == _ExternalTransferRail.mobileWallet) {
          return _isSw
              ? 'Weka jina la mwenye namba ya Mobile Money'
              : 'Enter the Mobile Money account holder name';
        }
        if (_externalRail == _ExternalTransferRail.paypal) {
          return _isSw
              ? 'Weka jina au handle ya PayPal'
              : 'Enter the PayPal name or handle';
        }
        if (_externalRail == _ExternalTransferRail.crypto) {
          return _isSw
              ? 'Weka jina au rejea ya wallet'
              : 'Enter the wallet owner name or reference';
        }
        return _isSw
            ? 'Jina au rejea ya mpokeaji'
            : 'Recipient name or transfer reference';
      case ExternalExperience.withdraw:
        return _isSw
            ? 'Jina litarudishwa na mtoa huduma baada ya uthibitisho'
            : 'Name will be returned by the provider after verification';
      case ExternalExperience.send:
        return AppLocalizations.of(context)!.sendMoneyRecipientReferenceHint;
    }
  }

  String get _externalReferenceRequiredMessage {
    switch (widget.externalExperience) {
      case ExternalExperience.transfer:
        if (_externalRail == _ExternalTransferRail.bank) {
          return _isSw
              ? 'Weka jina la mwenye akaunti ya benki.'
              : 'Bank recipient name is required.';
        }
        if (_externalRail == _ExternalTransferRail.mobileWallet) {
          return _isSw
              ? 'Weka jina la mwenye namba ya Mobile Money.'
              : 'Mobile Money recipient name is required.';
        }
        if (_externalRail == _ExternalTransferRail.paypal) {
          return _isSw
              ? 'Weka mpokeaji wa PayPal.'
              : 'PayPal recipient is required.';
        }
        if (_externalRail == _ExternalTransferRail.crypto) {
          return _isSw
              ? 'Weka mpokeaji wa wallet.'
              : 'Wallet recipient is required.';
        }
        return _isSw
            ? 'Weka mpokeaji wa transfer'
            : 'Enter the transfer recipient';
      case ExternalExperience.withdraw:
        return _isSw ? 'Mpokeaji anahitajika.' : 'Recipient is required.';
      case ExternalExperience.send:
        return AppLocalizations.of(
          context,
        )!.sendMoneyRecipientReferenceRequiredMessage;
    }
  }

  final TextEditingController _recipientIdController = TextEditingController();
  final TextEditingController _internalAmountController =
      TextEditingController();
  final TextEditingController _internalNoteController = TextEditingController();

  final TextEditingController _externalRecipientController =
      TextEditingController();
  final TextEditingController _externalProviderController =
      TextEditingController();
  final TextEditingController _externalCardNoController =
      TextEditingController();
  final TextEditingController _externalAmountController =
      TextEditingController();
  final TextEditingController _externalNoteController = TextEditingController();
  final WalletService _walletService = WalletService();
  final GoalsService _goalsService = GoalsService();
  final FxQuoteService _fxQuoteService = FxQuoteService();
  final GatewayPaymentService _gatewayPaymentService = GatewayPaymentService();
  final ServiceActorService _serviceActorService = ServiceActorService();
  final OtpAutoFillService _otpAutoFill = OtpAutoFillService();
  final Uuid _uuid = const Uuid();
  final String _fingerprint = DeviceFingerprint.generate();

  _TransferMode _mode = _TransferMode.internalP2P;
  _ExternalTransferRail _externalRail = _ExternalTransferRail.bank;
  _ExternalSourceWalletType _externalSourceWalletType =
      _ExternalSourceWalletType.internal;

  Timer? _lookupDebounce;
  Timer? _agentLookupDebounce;
  bool _lookupLoading = false;
  bool _agentLookupLoading = false;
  bool _isPreviewing = false;
  bool _isPreviewSheetOpen = false;
  bool _isSubmittingInternal = false;
  bool _isSubmittingExternal = false;
  bool _loadingSourceWallets = false;
  bool _loadingBudgetCategories = false;
  String? _lookupError;
  String? _agentLookupError;
  String? _sourceWalletError;
  String? _budgetCategoryError;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  _RecipientPreview? _recipientPreview;
  _OrbiAgentPreview? _orbiAgentPreview;
  String _lastLookupId = '';
  int _lookupGeneration = 0;
  int _agentLookupGeneration = 0;
  List<Map<String, dynamic>> _backendWallets = const [];
  List<Map<String, dynamic>> _budgetCategories = const [];
  List<GatewayProvider> _externalPaymentProviders = const [];
  bool _loadingExternalPaymentProviders = false;
  String? _externalPaymentProviderError;
  String? _selectedExternalProviderCode;
  String? _selectedExternalSourceWalletId;
  String? _selectedInternalSourceWalletId;
  String? _selectedInternalCategoryId;
  String? _selectedExternalCategoryId;
  late final AnimationController _entryController;
  _PendingSettleAttempt? _pendingInternalAttempt;
  _PendingSettleAttempt? _pendingExternalAttempt;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInExternalMode
        ? _TransferMode.external
        : _TransferMode.internalP2P;
    if (widget.externalOnly) {
      _mode = _TransferMode.external;
    }
    if (widget.externalExperience == ExternalExperience.withdraw) {
      _externalRail = _ExternalTransferRail.externalAgent;
      _externalProviderController.text = _withdrawAgentProviders.first;
      _selectedExternalProviderCode = 'ORBI_AGENT';
    }
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _applyInitialValues();
    _loadSourceWallets();
    _loadBudgetCategories();
    _loadExternalPaymentProviders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureTransferSourcesLoaded();
      }
    });
  }

  void _applyInitialValues() {
    final recipient = widget.initialRecipientInput?.trim();
    final amount = widget.initialAmount?.trim();
    final note = widget.initialNote?.trim();

    if (recipient != null && recipient.isNotEmpty) {
      _recipientIdController.text = recipient;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRecipientIdChanged(recipient);
      });
    }
    if (amount != null && amount.isNotEmpty) {
      _internalAmountController.text = AmountInputFormatter.format(amount);
    }
    if (note != null && note.isNotEmpty) {
      _internalNoteController.text = note;
    }
  }

  @override
  void dispose() {
    _otpAutoFill.stopListening();
    _entryController.dispose();
    _lookupDebounce?.cancel();
    _agentLookupDebounce?.cancel();
    _recipientIdController.dispose();
    _internalAmountController.dispose();
    _internalNoteController.dispose();
    _externalRecipientController.dispose();
    _externalProviderController.dispose();
    _externalCardNoController.dispose();
    _externalAmountController.dispose();
    _externalNoteController.dispose();
    super.dispose();
  }

  Map<String, String> _headers(String token, {String? idempotencyKey}) {
    return OrbiRequestHeaders.build(
      token: token,
      fingerprint: _fingerprint,
      trace: _uuid.v4(),
      idempotencyKey: idempotencyKey,
    );
  }

  void _markUserActivity() {
    final auth = context.read<AuthController>();
    ActivityTracker.markActivity();
    auth.registerUserActivity();
    if (auth.isAuthenticated) {
      auth.sessionManager.resetInactivityTimer();
    }
  }

  bool get _hasLiveSessionContext {
    final auth = context.read<AuthController>();
    return auth.isAuthenticated ||
        auth.currentSession != null ||
        auth.session.isNotEmpty;
  }

  String get _sessionVerificationRetryMessage {
    return _isSw
        ? 'Hatukuweza kuthibitisha kikao chako kwa sasa. Tafadhali jaribu tena.'
        : 'We could not confirm your session right now. Please try again.';
  }

  Future<String?> _requestTransferAccessToken({
    bool showDialogOnFailure = false,
  }) async {
    final auth = context.read<AuthController>();
    final hadSessionBeforeCheck = _hasLiveSessionContext;
    final token = await auth.getValidAccessToken(expireSessionIfMissing: false);
    if (!mounted) return null;
    if (token != null && token.isNotEmpty) return token;

    final message = hadSessionBeforeCheck
        ? _sessionVerificationRetryMessage
        : AppLocalizations.of(context)!.sendMoneySessionExpiredMessage;

    if (showDialogOnFailure) {
      if (hadSessionBeforeCheck) {
        await OrbiErrorDialog.show(
          context: context,
          title: _isSw ? 'Kikao hakijathibitishwa' : 'Session not verified',
          message: message,
          icon: Icons.shield_outlined,
        );
      } else {
        await OrbiErrorDialog.showSessionExpired(context);
      }
    } else {
      _showSnack(message);
    }
    return null;
  }

  String _normalizeTransferErrorMessage(
    Object error, {
    required String fallback,
  }) {
    final message = UserFacingError.from(error, fallback: fallback);
    final lower = message.toLowerCase();
    if (_hasLiveSessionContext &&
        (lower.contains('session expired') || lower.contains('log in again'))) {
      return _sessionVerificationRetryMessage;
    }
    return message;
  }

  Future<void> _loadSourceWallets() async {
    setState(() {
      _loadingSourceWallets = true;
      _sourceWalletError = null;
    });
    try {
      final wallets = await _walletService.getWallets();
      if (!mounted) return;
      setState(() {
        _backendWallets = wallets;
      });
      _syncSelectedSourceWallet();
      _syncSelectedInternalSourceWallet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sourceWalletError = UserFacingError.from(
          e,
          fallback: AppLocalizations.of(
            context,
          )!.sendMoneyLoadSourceWalletsFailedMessage,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSourceWallets = false;
        });
      }
    }
  }

  Future<void> _loadBudgetCategories() async {
    final token = await _requestTransferAccessToken();
    if (!mounted || token == null || token.isEmpty) return;
    setState(() {
      _loadingBudgetCategories = true;
      _budgetCategoryError = null;
    });
    try {
      final categories = await _goalsService.fetchCategories(token);
      if (!mounted) return;
      setState(() {
        _budgetCategories = categories;
      });
      _syncSelectedBudgetCategories();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _budgetCategoryError = UserFacingError.from(
          e,
          fallback: AppLocalizations.of(
            context,
          )!.sendMoneyBudgetCategoriesLoadFailedMessage,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBudgetCategories = false;
        });
      }
    }
  }

  Future<void> _loadExternalPaymentProviders() async {
    setState(() {
      _loadingExternalPaymentProviders = true;
      _externalPaymentProviderError = null;
    });
    try {
      final providers = await _gatewayPaymentService.listProviders(
        countryCode: 'TZ',
        currency: _resolveCurrency(),
        operation: 'DISBURSEMENT_REQUEST',
      );
      final active = providers.where((provider) => provider.isActive).toList()
        ..sort(_paymentProviderSort);
      if (!mounted) return;
      setState(() {
        _externalPaymentProviders = active;
        _loadingExternalPaymentProviders = false;
      });
      _syncExternalRailAfterProviderLoad();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _externalPaymentProviders = const [];
        _loadingExternalPaymentProviders = false;
        _externalPaymentProviderError = UserFacingError.from(
          error,
          fallback: _isSw
              ? 'Imeshindikana kupakia njia za malipo zilizowezeshwa.'
              : 'Unable to load enabled payment routes.',
        );
      });
    }
  }

  int _paymentProviderSort(GatewayProvider a, GatewayProvider b) {
    final group = a.groupLabel.compareTo(b.groupLabel);
    if (group != 0) return group;
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    return a.brandLabel.compareTo(b.brandLabel);
  }

  void _syncExternalRailAfterProviderLoad() {
    final rails = _availableExternalRails;
    if (rails.isEmpty || rails.contains(_externalRail)) return;
    setState(() => _applyExternalRailSelection(rails.first));
  }

  Future<void> _ensureTransferSourcesLoaded() async {
    final token = await _requestTransferAccessToken();
    if (!mounted || token == null || token.isEmpty) return;
    final goalsController = context.read<GoalsController>();
    if (goalsController.isLoading) return;
    if (goalsController.goals.isNotEmpty &&
        goalsController.categories.isNotEmpty) {
      return;
    }
    await goalsController.loadAll(token, notify: true);
    if (!mounted) return;
    setState(() {
      _syncSelectedInternalSourceWallet();
      _syncSelectedBudgetCategories();
    });
  }

  List<Map<String, dynamic>> _filteredSourceWallets() {
    final wallets = _backendWallets.where((wallet) {
      if (_isEscrowWallet(wallet) || _walletId(wallet).isEmpty) return false;
      switch (_externalSourceWalletType) {
        case _ExternalSourceWalletType.internal:
          return _matchesSourceWalletType(
                wallet,
                _ExternalSourceWalletType.internal,
              ) ||
              _isLikelyOperatingWallet(wallet);
        case _ExternalSourceWalletType.externalMobileWallet:
          return _matchesSourceWalletType(
            wallet,
            _ExternalSourceWalletType.externalMobileWallet,
          );
        case _ExternalSourceWalletType.externalBank:
          return _matchesSourceWalletType(
            wallet,
            _ExternalSourceWalletType.externalBank,
          );
      }
    }).toList();
    wallets.sort(
      (a, b) => _sourceWalletPriority(
        b,
        _externalSourceWalletType,
      ).compareTo(_sourceWalletPriority(a, _externalSourceWalletType)),
    );
    return wallets;
  }

  void _syncSelectedSourceWallet() {
    if (_externalSourceWalletType == _ExternalSourceWalletType.internal) {
      _selectedExternalSourceWalletId = null;
      return;
    }
    final options = _filteredSourceWallets();
    if (options.isEmpty) {
      _selectedExternalSourceWalletId = null;
      return;
    }
    final hasSelected = options.any(
      (w) => _walletId(w) == _selectedExternalSourceWalletId,
    );
    if (!hasSelected) {
      _selectedExternalSourceWalletId = _walletId(options.first);
    }
  }

  String _walletId(Map<String, dynamic> wallet) {
    return _pickString([wallet['wallet_id'], wallet['id']]);
  }

  String _walletName(Map<String, dynamic> wallet) {
    return _pickString([
      wallet['name'],
      wallet['wallet_name'],
      wallet['title'],
      wallet['alias'],
    ]);
  }

  String _walletType(Map<String, dynamic> wallet) {
    return _pickString([
      wallet['wallet_type'],
      wallet['type'],
      wallet['management_tier'],
      wallet['vault_role'],
      wallet['role'],
    ]).toLowerCase();
  }

  String _walletTier(Map<String, dynamic> wallet) {
    return _pickString([
      wallet['management_tier'],
      wallet['managementTier'],
      wallet['tier'],
      wallet['vault_role'],
      wallet['role'],
    ]).toLowerCase();
  }

  String _walletRole(Map<String, dynamic> wallet) {
    return _pickString([
      wallet['vault_role'],
      wallet['vaultRole'],
      wallet['role'],
      wallet['system_role'],
    ]).toLowerCase();
  }

  Map<String, dynamic> _walletMetadata(Map<String, dynamic> wallet) {
    final data = wallet['metadata'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  String _walletAccountNumber(Map<String, dynamic> wallet) {
    final metadata = _walletMetadata(wallet);
    return _pickString([
      wallet['accountNumber'],
      wallet['account_number'],
      wallet['account_no'],
      metadata['account_number'],
      metadata['account_no'],
      metadata['linked_customer_id'],
    ]);
  }

  bool _isEscrowWallet(Map<String, dynamic> wallet) {
    final name = _walletName(wallet).toLowerCase();
    final type = _walletType(wallet).toLowerCase();
    final role = _walletRole(wallet).toLowerCase();
    final metadata = _walletMetadata(wallet);
    final accountNumber = _walletAccountNumber(wallet).toUpperCase();
    final isEscrowMeta = metadata['is_secure_escrow'] == true;
    return role.contains('internal_transfer') ||
        type.contains('internal_transfer') ||
        name.contains('paysafe') ||
        isEscrowMeta ||
        accountNumber.startsWith('ESC-');
  }

  bool _isWalletLocked(Map<String, dynamic> wallet) {
    final status = _pickString([
      wallet['status'],
      wallet['state'],
      wallet['wallet_status'],
      wallet['walletStatus'],
      wallet['lifecycle'],
    ]).toLowerCase();
    if (_looksLocked(status)) return true;
    if (wallet['locked'] == true ||
        wallet['is_locked'] == true ||
        wallet['isLocked'] == true) {
      return true;
    }
    final metadata = _walletMetadata(wallet);
    if (metadata['locked'] == true ||
        metadata['is_locked'] == true ||
        metadata['isLocked'] == true ||
        metadata['is_frozen'] == true ||
        metadata['isFrozen'] == true) {
      return true;
    }
    final metaStatus = _pickString([
      metadata['status'],
      metadata['state'],
      metadata['lifecycle'],
    ]).toLowerCase();
    return _looksLocked(metaStatus);
  }

  bool _looksLocked(String value) {
    if (value.isEmpty) return false;
    return value.contains('lock') ||
        value.contains('freeze') ||
        value.contains('blocked') ||
        value.contains('suspend');
  }

  Map<String, dynamic>? _findWalletById(String walletId) {
    if (walletId.trim().isEmpty) return null;
    for (final wallet in _backendWallets) {
      if (_walletId(wallet) == walletId) return wallet;
    }
    return null;
  }

  String _effectiveInternalWalletId() {
    final selected = _selectedInternalSourceWallet();
    if (selected != null) return _transferSourceWalletId(selected);
    return _resolveOperatingWalletId();
  }

  Map<String, dynamic>? _effectiveInternalWallet() {
    final selected = _selectedInternalSourceWallet();
    if (selected != null) {
      if (!_isGoalSourceWallet(selected)) return selected;
      final walletId = _transferSourceWalletId(selected);
      if (walletId.isNotEmpty) {
        return _findWalletById(walletId);
      }
    }
    final operatingId = _resolveOperatingWalletId();
    if (operatingId.isEmpty) return null;
    return _findWalletById(operatingId);
  }

  String _effectiveExternalWalletId() {
    final sourceWallet = _externalSourceWalletValue(_externalSourceWalletType);
    if (sourceWallet == 'internal') return _resolveOperatingWalletId();
    return _selectedExternalSourceWalletId ?? '';
  }

  Map<String, dynamic>? _effectiveExternalWallet() {
    final walletId = _effectiveExternalWalletId();
    if (walletId.isEmpty) return null;
    return _findWalletById(walletId);
  }

  double _walletBalance(Map<String, dynamic> wallet) {
    return _doubleFromDynamic([
      wallet['available_balance'],
      wallet['balance'],
      wallet['ledger_balance'],
      wallet['amount'],
      wallet['current'],
      wallet['current_amount'],
      wallet['currentAmount'],
    ]);
  }

  String _walletCurrency(Map<String, dynamic> wallet) {
    return resolveCurrencyCode([
      wallet['currency'],
      wallet['currency_code'],
      wallet['asset_currency'],
    ]);
  }

  String _walletBalanceLabel(Map<String, dynamic> wallet) {
    if (context.read<AppSettingsController>().hideBalances) {
      return AppSettingsController.hiddenBalanceText;
    }
    final amount = _walletBalance(wallet);
    final currency = _walletCurrency(wallet);
    return formatCompactMoney(
      amount,
      currency,
      locale: _localeTag,
      hideBalances: context.read<AppSettingsController>().hideBalances,
      compactFrom: kCompactMoneyThreshold,
    );
  }

  IconData _walletIcon(Map<String, dynamic> wallet) {
    final composite = '${_walletType(wallet)} ${_walletName(wallet)}'
        .toLowerCase();
    if (composite.contains('bank')) return Icons.account_balance_rounded;
    if (composite.contains('card')) return Icons.credit_card_rounded;
    if (composite.contains('mobile') || composite.contains('wallet')) {
      return Icons.phone_android_rounded;
    }
    if (composite.contains('paypal')) return Icons.paypal_rounded;
    if (composite.contains('crypto') || composite.contains('coin')) {
      return Icons.currency_bitcoin_rounded;
    }
    return Icons.account_balance_wallet_rounded;
  }

  Widget _sourceWalletChoiceCard(Map<String, dynamic> wallet) {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    final id = _walletId(wallet);
    final selected = id == _selectedExternalSourceWalletId;
    final name = _walletName(wallet);
    final balance = _walletBalanceLabel(wallet);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  ui.cardStrong.withValues(alpha: isDark ? 0.92 : 0.94),
                ]
              : [
                  ui.card.withValues(alpha: isDark ? 0.90 : 0.96),
                  ui.cardMuted.withValues(alpha: isDark ? 0.84 : 0.90),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.78)
              : ui.borderStrong.withValues(alpha: isDark ? 0.56 : 0.72),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (selected ? accent : Colors.black).withValues(
              alpha: selected ? (isDark ? 0.14 : 0.10) : (isDark ? 0.12 : 0.04),
            ),
            blurRadius: selected ? 16 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loadingSourceWallets
              ? null
              : () {
                  setState(() {
                    _selectedExternalSourceWalletId = id;
                  });
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ui.cardStrong.withValues(alpha: isDark ? 0.94 : 0.98),
                        accent.withValues(alpha: isDark ? 0.16 : 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ui.border.withValues(alpha: isDark ? 0.50 : 0.72),
                    ),
                  ),
                  child: Icon(
                    _walletIcon(wallet),
                    size: 20,
                    color: selected ? accent : ui.iconMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? id : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance,
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
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? accent
                        : ui.cardStrong.withValues(alpha: isDark ? 0.88 : 0.96),
                    border: Border.all(
                      color: selected
                          ? accent
                          : ui.border.withValues(alpha: isDark ? 0.5 : 0.7),
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: selected ? Colors.white : ui.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _externalFundingSummary() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    final isWithdraw = widget.externalExperience == ExternalExperience.withdraw;
    final source = _externalSourceWalletValue(_externalSourceWalletType);
    final selected = _filteredSourceWallets().where((wallet) {
      return _walletId(wallet) == _selectedExternalSourceWalletId;
    }).toList();
    final selectedWallet = selected.isEmpty ? null : selected.first;
    final selectedLabel = selectedWallet == null
        ? 'Auto / not selected'
        : _walletName(selectedWallet).isEmpty
        ? _walletId(selectedWallet)
        : _walletName(selectedWallet);
    final sourceLabel = _externalSourceWalletLabel(_externalSourceWalletType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWithdraw
              ? [
                  ui.card.withValues(alpha: 0.99),
                  ui.cardStrong.withValues(alpha: 0.95),
                ]
              : [
                  _flowAccentFaint.withValues(alpha: 0.6),
                  ui.card.withValues(alpha: 0.98),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWithdraw
              ? ui.borderStrong.withValues(alpha: 0.72)
              : accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(
              isWithdraw
                  ? Icons.account_balance_wallet_rounded
                  : Icons.tune_rounded,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWithdraw
                      ? (_isSw ? 'Chanzo cha utoaji' : 'Withdrawal source')
                      : 'Source summary',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Source: $sourceLabel ($source) • Wallet: $selectedLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSourceWalletType(
    Map<String, dynamic> wallet,
    _ExternalSourceWalletType sourceType,
  ) {
    if (_isEscrowWallet(wallet)) return false;
    final type = _walletType(wallet);
    final name = _walletName(wallet).toLowerCase();
    final composite = '$type $name';
    switch (sourceType) {
      case _ExternalSourceWalletType.internal:
        return composite.contains('internal') ||
            composite.contains('operating') ||
            composite.contains('vault') ||
            composite.contains('sovereign');
      case _ExternalSourceWalletType.externalMobileWallet:
        return composite.contains('mobile') ||
            composite.contains('mpesa') ||
            composite.contains('airtel') ||
            composite.contains('tigo') ||
            composite.contains('halo') ||
            composite.contains('yas') ||
            composite.contains('wallet');
      case _ExternalSourceWalletType.externalBank:
        return composite.contains('bank') ||
            composite.contains('card') ||
            composite.contains('nmb') ||
            composite.contains('crdb') ||
            composite.contains('nbc') ||
            composite.contains('platinum');
    }
  }

  int _sourceWalletPriority(
    Map<String, dynamic> wallet,
    _ExternalSourceWalletType sourceType,
  ) {
    final matchesPreferredType = _matchesSourceWalletType(wallet, sourceType);
    if (sourceType == _ExternalSourceWalletType.internal) {
      return matchesPreferredType ? 3 : 0;
    }
    if (matchesPreferredType) return 3;
    if (_isLikelyOperatingWallet(wallet)) return 2;
    final tier = _walletTier(wallet);
    if (tier.contains('linked') || tier.contains('sovereign')) return 1;
    return 0;
  }

  List<Map<String, dynamic>> _transferGoalSources() {
    final goals = context.read<GoalsController>().goals;
    final items = <Map<String, dynamic>>[];
    for (final goal in goals) {
      final goalId = _pickString([goal['id'], goal['goalId'], goal['goal_id']]);
      if (goalId.isEmpty) continue;
      final sourceWalletId = _pickString([
        goal['sourceWalletId'],
        goal['source_wallet_id'],
        goal['walletId'],
        goal['wallet_id'],
        goal['operating_wallet_id'],
        goal['operatingWalletId'],
      ]);
      items.add({
        'wallet_id': 'goal::$goalId',
        'name': _pickString([goal['name'], goal['title']]),
        'wallet_type': 'goal',
        'balance': _doubleFromDynamic([
          goal['current'],
          goal['current_amount'],
          goal['currentAmount'],
        ]),
        'currency': _pickString([
          goal['currency'],
          goal['currency_code'],
          goal['asset_currency'],
        ]),
        'metadata': {
          'source_kind': 'goal',
          'goal_id': goalId,
          if (sourceWalletId.isNotEmpty) 'source_wallet_id': sourceWalletId,
        },
      });
    }
    return items;
  }

  bool _isGoalSourceWallet(Map<String, dynamic> wallet) {
    final metadata = _walletMetadata(wallet);
    return metadata['source_kind'] == 'goal' ||
        _walletType(wallet).contains('goal');
  }

  String _goalIdFromSourceWallet(Map<String, dynamic> wallet) {
    final metadata = _walletMetadata(wallet);
    return _pickString([
      metadata['goal_id'],
      wallet['goal_id'],
      wallet['goalId'],
    ]);
  }

  String _transferSourceWalletId(Map<String, dynamic> wallet) {
    if (!_isGoalSourceWallet(wallet)) return _walletId(wallet);
    final metadata = _walletMetadata(wallet);
    final sourceWalletId = _pickString([
      metadata['source_wallet_id'],
      wallet['source_wallet_id'],
      wallet['sourceWalletId'],
    ]);
    if (sourceWalletId.isNotEmpty) return sourceWalletId;
    return _resolveOperatingWalletId();
  }

  void _onRecipientIdChanged(String value) {
    _markUserActivity();
    _lookupDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _lookupGeneration++;
      setState(() {
        _lookupLoading = false;
        _lookupError = null;
        _recipientPreview = null;
      });
      return;
    }

    if (query.length < 5) {
      _lookupGeneration++;
      setState(() {
        _lookupLoading = false;
        _recipientPreview = null;
        _lookupError = AppLocalizations.of(
          context,
        )!.sendMoneySearchMinCharsMessage;
      });
      return;
    }

    final normalized = _normalizeLookupQuery(query);
    if (normalized == _lastLookupId) return;
    final generation = ++_lookupGeneration;
    _lookupDebounce = Timer(const Duration(milliseconds: 350), () {
      _lookupRecipient(normalized, generation);
    });
  }

  Future<void> _lookupRecipient(String query, int generation) async {
    _markUserActivity();
    final token = await _requestTransferAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      if (!_isLookupStillCurrent(query, generation)) return;
      setState(() {
        _lookupError = _hasLiveSessionContext
            ? _sessionVerificationRetryMessage
            : AppLocalizations.of(context)!.sendMoneySessionExpiredMessage;
        _lookupLoading = false;
      });
      return;
    }

    setState(() {
      _lookupLoading = true;
      _lookupError = null;
    });

    try {
      final endpoints = [
        Uri.parse('${AppConfig.apiUrl}/user/lookup'),
        Uri.parse('${AppConfig.baseUrl}/v1/user/lookup'),
        Uri.parse('${AppConfig.baseUrl}/api/v1/user/lookup'),
      ];

      Map<String, dynamic>? parsed;
      for (final endpoint in endpoints) {
        parsed = await _tryLookupGet(endpoint, query, token);
        if (_hasSuccessfulLookup(parsed)) break;
      }

      final payload = parsed ?? <String, dynamic>{};
      final success = payload['success'] == true;
      final data = _extractLookupData(payload);
      final internalId = _pickString([data['id']]);
      final fullName = _pickString([
        data['full_name'],
        data['fullName'],
        data['name'],
        data['display_name'],
      ]);
      final resolvedId = _pickString([
        data['customer_id'],
        data['customerId'],
        data['recipient_id'],
        data['recipientId'],
        query,
      ]);
      final avatar = _pickString([
        data['avatar_url'],
        data['avatarUrl'],
        data['profile_image'],
      ]);
      final registryType = _pickString([
        data['registry_type'],
        data['registryType'],
      ]);
      final isVerified =
          data['is_paysafe_verified'] == true ||
          data['isPaysafeVerified'] == true;
      final rawInput = _recipientIdController.text.trim();
      final displayIdentifier = _isLikelyCustomerId(rawInput)
          ? resolvedId
          : (rawInput.isNotEmpty ? rawInput : query);

      if (!_isLookupStillCurrent(query, generation)) return;

      if (!success || fullName.isEmpty || internalId.isEmpty) {
        setState(() {
          _lookupLoading = false;
          _lookupError = AppLocalizations.of(
            context,
          )!.sendMoneyRecipientNotFoundMessage;
          if (_lastLookupId != query) {
            _recipientPreview = null;
          }
        });
        return;
      }

      setState(() {
        _lookupLoading = false;
        _lookupError = null;
        _lastLookupId = query;
        _recipientPreview = _RecipientPreview(
          internalId: internalId,
          recipientId: resolvedId,
          displayIdentifier: displayIdentifier,
          fullName: fullName,
          avatarUrl: avatar.isEmpty ? null : avatar,
          registryType: registryType,
          isPaysafeVerified: isVerified,
        );
      });
    } catch (e) {
      if (!_isLookupStillCurrent(query, generation)) return;
      setState(() {
        _lookupLoading = false;
        _lookupError = _normalizeTransferErrorMessage(
          e,
          fallback: AppLocalizations.of(
            context,
          )!.sendMoneySearchUnavailableMessage,
        );
        if (_lastLookupId != query) {
          _recipientPreview = null;
        }
      });
    } finally {
      if (mounted) {
        _markUserActivity();
      }
    }
  }

  bool _isLookupStillCurrent(String query, int generation) {
    if (generation != _lookupGeneration) return false;
    final current = _normalizeLookupQuery(_recipientIdController.text.trim());
    return current == query;
  }

  void _onExternalAgentIdChanged(String value) {
    if (widget.externalExperience != ExternalExperience.withdraw ||
        _externalRail != _ExternalTransferRail.externalAgent) {
      return;
    }
    _markUserActivity();
    _agentLookupDebounce?.cancel();
    final query = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (query.isEmpty) {
      _agentLookupGeneration++;
      setState(() {
        _agentLookupLoading = false;
        _agentLookupError = null;
        _orbiAgentPreview = null;
      });
      return;
    }

    if (query.length < 4) {
      _agentLookupGeneration++;
      setState(() {
        _agentLookupLoading = false;
        _orbiAgentPreview = null;
        _agentLookupError = _isSw
            ? 'Weka angalau tarakimu 4 za Agent ID.'
            : 'Enter at least 4 digits of the Agent ID.';
      });
      return;
    }

    final generation = ++_agentLookupGeneration;
    _agentLookupDebounce = Timer(const Duration(milliseconds: 350), () {
      _lookupOrbiAgent(query, generation);
    });
  }

  Future<void> _lookupOrbiAgent(String query, int generation) async {
    setState(() {
      _agentLookupLoading = true;
      _agentLookupError = null;
    });
    try {
      final data = await _serviceActorService.lookupAgentByCode(query);
      if (!_isAgentLookupStillCurrent(query, generation)) return;

      final agentId = _pickString([data['agent_id'], data['id']]);
      final displayName = _pickString([
        data['display_name'],
        data['full_name'],
        data['fullName'],
        data['name'],
      ]);
      final tillNumber = _pickString([
        data['cash_withdraw_till'],
        data['cashWithdrawTill'],
      ]);
      final serviceNumber = _pickString([
        data['service_pay_number'],
        data['servicePayNumber'],
      ]);
      final branch = _pickString([
        data['branch'],
        (data['metadata'] is Map) ? (data['metadata'] as Map)['branch'] : null,
      ]);
      final status = _pickString([data['status']]).toLowerCase();

      if (agentId.isEmpty || displayName.isEmpty) {
        setState(() {
          _agentLookupLoading = false;
          _agentLookupError = _isSw
              ? 'Agent wa ORBI hakupatikana.'
              : 'ORBI Agent not found.';
          _orbiAgentPreview = null;
        });
        return;
      }

      setState(() {
        _agentLookupLoading = false;
        _agentLookupError = null;
        _orbiAgentPreview = _OrbiAgentPreview(
          agentId: agentId,
          displayName: displayName,
          tillNumber: tillNumber,
          serviceNumber: serviceNumber,
          branch: branch,
          status: status,
        );
      });
    } catch (e) {
      if (!_isAgentLookupStillCurrent(query, generation)) return;
      setState(() {
        _agentLookupLoading = false;
        _agentLookupError = UserFacingError.from(
          e,
          fallback: _isSw
              ? 'Huduma ya kutafuta Agent haipatikani sasa.'
              : 'Agent lookup is unavailable right now.',
        );
        _orbiAgentPreview = null;
      });
    }
  }

  bool _isAgentLookupStillCurrent(String query, int generation) {
    if (generation != _agentLookupGeneration) return false;
    final current = _externalCardNoController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return current == query;
  }

  Future<Map<String, dynamic>?> _tryLookupGet(
    Uri base,
    String query,
    String token,
  ) async {
    final uri = base.replace(queryParameters: {'q': query});
    final res = await http.get(uri, headers: _headers(token));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  bool _hasSuccessfulLookup(Map<String, dynamic>? response) {
    if (response == null) return false;
    if (response['success'] == true) return true;
    final data = _extractLookupData(response);
    return data.isNotEmpty;
  }

  Map<String, dynamic> _extractLookupData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    final user = response['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    return <String, dynamic>{};
  }

  String _normalizeLookupQuery(String value) {
    if (_isLikelyCustomerId(value)) {
      return value.trim().toUpperCase();
    }
    return value.trim();
  }

  bool _isLikelyCustomerId(String value) {
    final upper = value.trim().toUpperCase();
    return upper.startsWith('OB') || upper.contains('-');
  }

  String _pickString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    IconData? icon,
    String? helperText,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
    Widget? prefixIcon,
    String? prefixText,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      hintStyle: TextStyle(color: ui.textSoft),
      labelStyle: TextStyle(color: ui.textMuted),
      helperStyle: TextStyle(color: ui.textSoft),
      floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
      alignLabelWithHint: alignLabelWithHint,
      prefixText: prefixText,
      prefixStyle: prefixText == null
          ? null
          : TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w800),
      prefixIcon:
          prefixIcon ?? (icon != null ? Icon(icon, color: accent) : null),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _flowAccentFaint.withValues(alpha: 0.78),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ui.danger, width: 1.2),
      ),
    );
  }

  Widget _formSurface({required Widget child}) {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.card.withValues(alpha: isDark ? 0.88 : 0.96),
            Color.lerp(
              ui.cardStrong,
              accent,
              isDark ? 0.08 : 0.04,
            )!.withValues(alpha: isDark ? 0.82 : 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<bool> _ensureWalletUnlockedForTransfer({
    required String walletId,
    Map<String, dynamic>? wallet,
  }) async {
    final trimmedId = walletId.trim();
    if (trimmedId.isEmpty) return true;
    final resolvedWallet = wallet ?? _findWalletById(trimmedId);
    if (resolvedWallet == null) return true;
    if (!_isWalletLocked(resolvedWallet)) return true;

    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthController>();
    final hasPin = await auth.hasSecurityPinConfigured();
    if (!mounted) return false;
    if (!hasPin) {
      final pinSet = await promptPinSetup(context);
      if (!mounted) return false;
      if (!pinSet) return false;
    }

    final pin = await showSecurityCodeDialog(
      context: context,
      title: l10n.loginEnterPinTitle,
      helperText: l10n.loginUsePinInstead,
      fieldLabel: l10n.loginPinLabel,
      confirmLabel: l10n.actionUnlock,
      cancelLabel: l10n.actionCancel,
      maxLength: 6,
      minLength: 4,
      obscureText: true,
      digitsOnly: true,
      keyboardType: TextInputType.number,
    );
    if (pin == null) return false;

    final ok = await auth.verifySecurityPin(pin);
    if (!mounted) return false;
    if (!ok) {
      await OrbiErrorDialog.show(
        context: context,
        title: l10n.loginEnterPinTitle,
        message: l10n.loginInvalidPinMessage,
        icon: Icons.lock_outline,
      );
      return false;
    }

    await _walletService.unlockWallet(trimmedId, pin: pin);
    return true;
  }

  Future<void> _submitInternalTransfer() async {
    _markUserActivity();
    final valid = _internalFormKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_recipientPreview == null) {
      await OrbiErrorDialog.show(
        context: context,
        title: 'Recipient Required',
        message: AppLocalizations.of(context)!.sendMoneySearchRecipientMessage,
        icon: Icons.person_add_outlined,
      );
      return;
    }
    final amount = AmountInputFormatter.tryParse(
      _internalAmountController.text,
    );
    if (amount == null || amount <= 0) {
      await OrbiErrorDialog.show(
        context: context,
        title: 'Invalid Amount',
        message: AppLocalizations.of(context)!.sendMoneyEnterValidAmountMessage,
        icon: Icons.attach_money_rounded,
      );
      return;
    }

    final token = await _requestTransferAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      return;
    }

    final effectiveWalletId = _effectiveInternalWalletId();
    final unlocked = await _ensureWalletUnlockedForTransfer(
      walletId: effectiveWalletId,
      wallet: _effectiveInternalWallet(),
    );
    if (!unlocked) return;

    if (_selectedInternalSourceIsGoal()) {
      final proceed = await _confirmGoalSourceTransfer();
      if (!proceed) return;
    }
    final budgetProceed = await _validateBudgetSelection(
      categoryId: _selectedInternalCategoryId,
      amount: amount,
    );
    if (!budgetProceed) return;
    final transferCurrency = _requireTransferCurrency();
    if (transferCurrency == null) return;

    setState(() => _isPreviewing = true);
    try {
      final sourceParts = _buildInternalSourcePayloadParts();
      final payload = await _withRequiredTransactionGeo({
        'recipient_customer_id': _recipientPreview!.recipientId,
        if ((_recipientPreview?.internalId ?? '').isNotEmpty)
          'recipient_id': _recipientPreview!.internalId,
        'amount': amount,
        'currency': transferCurrency,
        'type': 'INTERNAL_TRANSFER',
        'description': _internalNoteController.text.trim(),
        if ((_selectedInternalCategoryId ?? '').isNotEmpty)
          'categoryId': _selectedInternalCategoryId,
        'metadata': {
          'category': 'Transfer',
          if ((_selectedInternalCategoryId ?? '').isNotEmpty)
            'category_id': _selectedInternalCategoryId,
          if (_internalNoteController.text.trim().isNotEmpty)
            'notes': _internalNoteController.text.trim(),
        },
        // Backend is source of truth for source wallet resolution.
        ...sourceParts,
        'current_user': _currentUserContext(),
      });

      final preview = await _fetchTransactionPreview(token, payload);
      if (!mounted) return;
      setState(() => _isPreviewing = false);
      await _openPreviewSheet(preview);
    } on _TransactionChallengeRequiredException catch (challenge) {
      final verified = await _handleTransactionChallenge(token, challenge);
      if (!verified) {
        if (!mounted) return;
        setState(() => _isPreviewing = false);
        await OrbiErrorDialog.show(
          context: context,
          title: 'Verification Cancelled',
          message: AppLocalizations.of(
            context,
          )!.sendMoneyVerificationCancelledMessage,
          icon: Icons.lock_outline,
        );
        return;
      }

      final sourceParts = _buildInternalSourcePayloadParts();
      final retryPayload = await _withRequiredTransactionGeo({
        'recipient_customer_id': _recipientPreview!.recipientId,
        if ((_recipientPreview?.internalId ?? '').isNotEmpty)
          'recipient_id': _recipientPreview!.internalId,
        'amount': amount,
        'currency': transferCurrency,
        'type': 'INTERNAL_TRANSFER',
        'description': _internalNoteController.text.trim(),
        if ((_selectedInternalCategoryId ?? '').isNotEmpty)
          'categoryId': _selectedInternalCategoryId,
        'metadata': {
          'category': 'Transfer',
          if ((_selectedInternalCategoryId ?? '').isNotEmpty)
            'category_id': _selectedInternalCategoryId,
          if (_internalNoteController.text.trim().isNotEmpty)
            'notes': _internalNoteController.text.trim(),
        },
        ...sourceParts,
        'current_user': _currentUserContext(),
      });

      final preview = await _fetchTransactionPreview(token, retryPayload);
      if (!mounted) return;
      setState(() => _isPreviewing = false);
      await _openPreviewSheet(preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreviewing = false);
      await OrbiErrorDialog.show(
        context: context,
        title: 'Transaction Failed',
        message: _normalizeTransferErrorMessage(
          e,
          fallback: AppLocalizations.of(context)!.sendMoneyPreviewFailedMessage,
        ),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isPreviewing = false);
      }
    }
  }

  String _resolveCurrency() {
    final session = context.read<AuthController>().session;
    final user = session['user'];
    if (user is Map) {
      return resolveCurrencyCode([
        user['currency'],
        user['currency_code'],
        user['preferred_currency'],
      ]);
    }
    return resolveCurrencyCode([session['currency'], session['currency_code']]);
  }

  String? _requireTransferCurrency() {
    final currency = _resolveCurrency();
    if (currency.isNotEmpty) return currency;
    _showSnack(
      'Account currency is missing. Transfers are blocked until the profile currency is fixed.',
    );
    return null;
  }

  Future<Map<String, dynamic>> _withRequiredTransactionGeo(
    Map<String, dynamic> payload, {
    bool allowNetworkFallback = true,
  }) async {
    final geoMetadata = await TransactionGeoContext.requiredMetadata(
      allowNetworkFallback: allowNetworkFallback,
    );
    final metadata = payload['metadata'] is Map
        ? Map<String, dynamic>.from(payload['metadata'] as Map)
        : <String, dynamic>{};
    return {
      ...payload,
      'metadata': TransactionGeoContext.mergeInto(metadata, geoMetadata),
    };
  }

  String get _localeTag {
    final locale = Localizations.localeOf(context);
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }

  Future<_TransactionPreviewData> _fetchTransactionPreview(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final endpoints = _transactionApiEndpoints('/transactions/preview');
    http.Response? res;
    http.Response? lastFailure;
    _TransientNetworkException? transientFailure;
    for (final endpoint in endpoints) {
      _traceTxApi(
        'POST /transactions/preview',
        uri: endpoint,
        requestBody: payload,
      );
      http.Response attempt;
      try {
        attempt = await _postJson(
          endpoint,
          headers: _headers(token),
          body: payload,
          timeoutMessage: AppLocalizations.of(
            context,
          )!.sendMoneyPreviewTimedOutMessage,
          timeout: _previewRequestTimeout,
        );
      } on _TransientNetworkException catch (e) {
        transientFailure = e;
        _traceTxApi(
          'POST /transactions/preview transient failure',
          uri: endpoint,
          extra: {'error': e.message},
        );
        continue;
      }
      _traceTxApi(
        'POST /transactions/preview response',
        uri: endpoint,
        statusCode: attempt.statusCode,
        responseBody: attempt.body,
      );
      if (attempt.statusCode >= 200 && attempt.statusCode < 300) {
        res = attempt;
        break;
      }
      final challengePayload = _tryParseJsonMap(attempt.body);
      if (challengePayload != null && _isChallengeResponse(challengePayload)) {
        throw _buildChallengeException(challengePayload);
      }
      lastFailure = attempt;
    }

    if (res == null) {
      if (lastFailure == null && transientFailure != null) {
        throw _TransientNetworkException(
          _transactionStageUnavailableMessage(
            stage: _isSw ? 'hakiki gharama' : 'preview',
            safeResult: _isSw
                ? 'Hakuna quote ya muamala iliyopokelewa.'
                : 'No transaction quote was returned.',
          ),
        );
      }
      final status = lastFailure?.statusCode;
      final backendMessage = _extractBackendMessage(
        lastFailure?.body,
        statusCode: status,
      );
      final fallback = status == null
          ? l10n.sendMoneyPreviewRequestFailedMessage
          : l10n.sendMoneyPreviewRequestFailedWithStatus(status);
      throw Exception(backendMessage.isNotEmpty ? backendMessage : fallback);
    }

    final body = jsonDecode(res.body);
    if (body is! Map) {
      throw Exception(l10n.sendMoneyPreviewInvalidFormatMessage);
    }
    final map = Map<String, dynamic>.from(body);
    if (map['success'] != true) {
      throw Exception(
        _pickString([
          map['message'],
          map['error'],
          l10n.sendMoneyPreviewUnavailableMessage,
        ]),
      );
    }

    final dataRaw = map['data'];
    if (dataRaw is! Map) {
      throw Exception(l10n.sendMoneyPreviewDataMissingMessage);
    }
    final data = Map<String, dynamic>.from(dataRaw);
    if (data['success'] == false) {
      throw Exception(
        _pickString([
          data['error'],
          data['message'],
          map['message'],
          map['error'],
          l10n.sendMoneyPreviewRejectedMessage,
        ]),
      );
    }
    final feesRaw = data['fees'] as Map? ?? {};
    final fees = Map<String, dynamic>.from(feesRaw);
    final debitRaw = data['debit'] as Map? ?? {};
    final debit = Map<String, dynamic>.from(debitRaw);
    final balanceRaw = data['balance'] as Map? ?? {};
    final balance = Map<String, dynamic>.from(balanceRaw);
    final riskRaw = data['risk'] as Map? ?? {};
    final risk = Map<String, dynamic>.from(riskRaw);
    final sourceWalletRaw = data['sourceWallet'] as Map? ?? {};
    final sourceWallet = Map<String, dynamic>.from(sourceWalletRaw);
    final breakdownRaw = data['breakdown'] as Map? ?? {};
    final breakdown = Map<String, dynamic>.from(breakdownRaw);
    final metadataRaw = data['metadata'] as Map? ?? {};
    final metadata = Map<String, dynamic>.from(metadataRaw);
    final receiverDetailsRaw = metadata['receiver_details'] as Map? ?? {};
    final receiverDetails = Map<String, dynamic>.from(receiverDetailsRaw);
    final profileRaw = receiverDetails['profile'] as Map? ?? {};
    final profile = Map<String, dynamic>.from(profileRaw);
    final transactionRaw = data['transaction'] as Map? ?? {};
    final transaction = Map<String, dynamic>.from(transactionRaw);
    final taxInfoRaw =
        (data['tax_info'] is Map
                ? data['tax_info']
                : (transaction['tax_info'] is Map
                      ? transaction['tax_info']
                      : {}))
            as Map;
    final taxInfo = Map<String, dynamic>.from(taxInfoRaw);

    final baseAmount = _firstNonZeroAmount([
      breakdown['base'],
      breakdown['amount'],
      data['amount'],
      data['base_amount'],
      debit['amount'],
      transaction['amount'],
    ]);
    final taxAmount = _firstNonZeroAmount([
      breakdown['tax'],
      breakdown['vat'],
      data['tax'],
      data['vat'],
      fees['taxAmount'],
      fees['tax_amount'],
      taxInfo['tax'],
      taxInfo['vat'],
    ]);
    final feeAmount = _firstNonZeroAmount([
      breakdown['fee'],
      breakdown['service_fee'],
      data['fee'],
      data['service_fee'],
      fees['totalFee'],
      fees['total_fee'],
      debit['fee'],
      taxInfo['fee'],
    ]);
    final computedTotal = baseAmount + taxAmount + feeAmount;
    final totalAmount = _firstNonZeroAmount([
      breakdown['total'],
      data['total'],
      data['amount_total'],
      debit['total'],
      data['totalDebit'],
      data['total_debit'],
      transaction['total'],
      computedTotal > 0 ? computedTotal : null,
      transaction['amount'],
    ]);
    final availableBalance = _firstAmountOrNull([
      breakdown['available_balance'],
      breakdown['availableBalance'],
      data['available_balance'],
      data['availableBalance'],
      balance['available'],
      transaction['available_balance'],
      transaction['availableBalance'],
    ]);
    final requiredBalance = _firstAmountOrNull([
      balance['required'],
      debit['total'],
      data['required_balance'],
      data['requiredBalance'],
    ]);
    final previewState = _pickString([data['state'], data['status']]);
    final previewIssueMessage = _extractPreviewIssueMessage(data);
    final canSubmit = _boolFrom(data['canSubmit']) ?? true;
    final fxQuote = await _maybeFetchFxQuote(payload);

    _traceTxApi(
      'PREVIEW_PARSE_SUMMARY',
      extra: {
        'top_level_keys': map.keys.toList(),
        'data_keys': data.keys.toList(),
        'breakdown_keys': breakdown.keys.toList(),
        'tax_info_keys': taxInfo.keys.toList(),
        'parsed_base': baseAmount,
        'parsed_tax': taxAmount,
        'parsed_fee': feeAmount,
        'parsed_total': totalAmount,
        'preview_state': previewState,
        'preview_issue': previewIssueMessage,
      },
    );

    if (baseAmount == 0 &&
        taxAmount == 0 &&
        feeAmount == 0 &&
        totalAmount == 0) {
      _traceTxApi(
        'PREVIEW_ALL_ZERO_WARNING',
        extra: {
          'hint':
              'Backend preview returned no recognized amount fields. Check response schema.',
          'breakdown': breakdown,
          'data_amount_fields': {
            'amount': data['amount'],
            'total': data['total'],
            'base_amount': data['base_amount'],
          },
          'transaction_amount_fields': {
            'amount': transaction['amount'],
            'total': transaction['total'],
          },
          'tax_info': taxInfo,
        },
      );
    }

    return _TransactionPreviewData(
      quoteId: _pickString([data['quoteId'], data['quote_id']]),
      quoteHash: _pickString([data['quoteHash'], data['quote_hash']]),
      status: _pickString([data['status'], data['state']]),
      securityDecision: _pickString([
        risk['decision'],
        metadata['security_decision'],
      ]).toUpperCase(),
      currency: _resolveCurrency(),
      recipientName: _pickString([
        profile['full_name'],
        _recipientPreview?.fullName,
      ]),
      recipientCustomerId: _pickString([
        profile['customer_id'],
        _recipientPreview?.recipientId,
      ]),
      recipientDisplayIdentifier: _pickString([
        _recipientPreview?.displayIdentifier,
        profile['customer_id'],
      ]),
      recipientAvatarUrl: _pickString([
        profile['avatar_url'],
        _recipientPreview?.avatarUrl,
      ]),
      baseAmount: baseAmount,
      taxAmount: taxAmount,
      feeAmount: feeAmount,
      totalAmount: totalAmount,
      availableBalance: availableBalance,
      requiredBalance: requiredBalance,
      sourceWalletId: _pickString([sourceWallet['id']]),
      sourceWalletName: _pickString([
        sourceWallet['name'],
        sourceWallet['role'],
        sourceWallet['type'],
      ]),
      canSubmit: canSubmit,
      issueMessage: previewIssueMessage,
      state: previewState,
      fxQuote: fxQuote,
    );
  }

  String _extractPreviewIssueMessage(Map<String, dynamic> data) {
    final issuesRaw = data['issues'];
    if (issuesRaw is! List) return '';
    for (final rawIssue in issuesRaw) {
      if (rawIssue is! Map) continue;
      final issue = Map<String, dynamic>.from(rawIssue);
      final severity = _pickString([issue['severity']]).toLowerCase();
      final code = _pickString([issue['code']]);
      final message = _pickString([issue['message'], issue['detail']]);
      if (severity == 'blocking') {
        return [
          code,
          message,
        ].where((part) => part.trim().isNotEmpty).join(': ');
      }
    }
    for (final rawIssue in issuesRaw) {
      if (rawIssue is! Map) continue;
      final issue = Map<String, dynamic>.from(rawIssue);
      final code = _pickString([issue['code']]);
      final message = _pickString([issue['message'], issue['detail']]);
      final text = [
        code,
        message,
      ].where((part) => part.trim().isNotEmpty).join(': ');
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _extractBackendMessage(String? rawBody, {int? statusCode}) {
    if (rawBody == null || rawBody.trim().isEmpty) {
      return statusCode == null ? '' : 'Request failed ($statusCode).';
    }
    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is Map) {
        final map = Map<String, dynamic>.from(parsed);
        final data = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : <String, dynamic>{};
        final controlId = _extractControlIdFromPayload(map);

        final baseMessage = _pickString([
          map['message'],
          map['error'],
          map['detail'],
          map['reason'],
          data['message'],
          data['error'],
          data['detail'],
          data['reason'],
        ]);
        final code = _pickString([
          map['code'],
          map['error_code'],
          data['code'],
          data['error_code'],
        ]);
        final fieldErrors = _extractValidationErrors([
          map['errors'],
          map['details'],
          data['errors'],
          data['details'],
          data['validation_errors'],
        ]);

        final pieces = <String>[];
        if (statusCode != null) {
          pieces.add('Request failed ($statusCode).');
        }
        if (code.isNotEmpty) {
          pieces.add(code);
        }
        if (baseMessage.isNotEmpty) {
          pieces.add(baseMessage);
        }
        if (fieldErrors.isNotEmpty) {
          pieces.add(fieldErrors);
        }
        if (controlId.isNotEmpty &&
            !pieces.any((piece) => piece.contains(controlId))) {
          pieces.add('Control ID: $controlId');
        }
        if (pieces.isNotEmpty) {
          return pieces.join(' - ');
        }
      }
      if (parsed is String) {
        final text = parsed.trim();
        if (text.isEmpty) {
          return statusCode == null ? '' : 'Request failed ($statusCode).';
        }
        final controlId = _extractControlIdFromText(text);
        final base = statusCode == null
            ? text
            : 'Request failed ($statusCode). - $text';
        return _appendControlIdMessage(base, controlId);
      }
    } catch (_) {
      final text = rawBody.trim();
      if (text.isNotEmpty) {
        final controlId = _extractControlIdFromText(text);
        final base = statusCode == null
            ? text
            : 'Request failed ($statusCode). - $text';
        return _appendControlIdMessage(base, controlId);
      }
    }
    return statusCode == null ? '' : 'Request failed ($statusCode).';
  }

  String _extractControlIdFromPayload(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final tx = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    return _pickString([
      payload['controlId'],
      payload['control_id'],
      payload['referenceId'],
      payload['reference_id'],
      data['controlId'],
      data['control_id'],
      data['referenceId'],
      data['reference_id'],
      tx['controlId'],
      tx['control_id'],
      tx['referenceId'],
      tx['reference_id'],
    ]);
  }

  String _extractControlIdFromText(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return '';
    final match = RegExp(
      r'(controlId|control_id|referenceId|reference_id)\s*[:=]\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      final value = match.group(2) ?? '';
      return value.trim();
    }
    final refMatch = RegExp(r'\bREF[-_][A-Za-z0-9]+\b').firstMatch(raw);
    return refMatch?.group(0) ?? '';
  }

  String _appendControlIdMessage(String message, String controlId) {
    final trimmed = message.trim();
    if (controlId.isEmpty) return trimmed;
    if (trimmed.contains(controlId)) return trimmed;
    if (trimmed.isEmpty) return 'Control ID: $controlId';
    return '$trimmed - Control ID: $controlId';
  }

  String _extractValidationErrors(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is List) {
        final items = <String>[];
        for (final item in candidate) {
          if (item is String && item.trim().isNotEmpty) {
            items.add(item.trim());
            continue;
          }
          if (item is Map) {
            final row = _pickString([
              item['message'],
              item['error'],
              item['detail'],
            ]);
            final field = _pickString([
              item['field'],
              item['path'],
              item['param'],
            ]);
            if (row.isNotEmpty && field.isNotEmpty) {
              items.add('$field: $row');
            } else if (row.isNotEmpty) {
              items.add(row);
            }
          }
        }
        if (items.isNotEmpty) {
          return items.join('; ');
        }
      }
      if (candidate is Map) {
        final pairs = <String>[];
        candidate.forEach((key, value) {
          final message = value is String
              ? value.trim()
              : (value is List
                    ? value.whereType<String>().join(', ').trim()
                    : '');
          if (message.isNotEmpty) {
            pairs.add('$key: $message');
          }
        });
        if (pairs.isNotEmpty) {
          return pairs.join('; ');
        }
      }
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _firstNonZeroAmount(List<dynamic> values) {
    double? firstParsed;
    for (final value in values) {
      if (value == null) continue;
      final parsed = _toDouble(value);
      firstParsed ??= parsed;
      if (parsed != 0) return parsed;
    }
    return firstParsed ?? 0.0;
  }

  double? _firstAmountOrNull(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return _toDouble(value);
    }
    return null;
  }

  Future<FxQuote?> _maybeFetchFxQuote(Map<String, dynamic> payload) async {
    final toCurrency = (payload['currency'] ?? _resolveCurrency())
        .toString()
        .toUpperCase();
    final fromCurrency = _resolveSelectedSourceCurrency();
    if (fromCurrency.isEmpty ||
        toCurrency.isEmpty ||
        fromCurrency == toCurrency) {
      return null;
    }
    final amount = _toDouble(payload['amount']);
    if (amount <= 0) return null;
    return _fxQuoteService.fetch(
      from: fromCurrency,
      to: toCurrency,
      amount: amount,
    );
  }

  String _resolveSelectedSourceCurrency() {
    final selectedId =
        _selectedInternalSourceWalletId ?? _selectedExternalSourceWalletId;
    if (selectedId == null || selectedId.isEmpty) {
      return _resolveCurrency();
    }
    final match = _backendWallets.firstWhere(
      (w) => _walletId(w) == selectedId,
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) return _resolveCurrency();
    return _walletCurrency(match);
  }

  void _traceTxApi(
    String label, {
    Uri? uri,
    int? statusCode,
    dynamic requestBody,
    String? responseBody,
    Map<String, dynamic>? extra,
  }) {
    final ts = DateFormat('HH:mm:ss').format(DateTime.now());
    final parts = <String>['[$ts] $label'];
    if (uri != null) parts.add('url=$uri');
    if (statusCode != null) parts.add('status=$statusCode');
    if (requestBody != null) {
      parts.add('request=${_truncateTxLog(_safeTxJsonEncode(requestBody))}');
    }
    if (responseBody != null) {
      parts.add('response=${_truncateTxLog(responseBody)}');
    }
    if (extra != null && extra.isNotEmpty) {
      parts.add('extra=${_truncateTxLog(_safeTxJsonEncode(extra))}');
    }
    debugPrint('🧾 TX_DEBUG ${parts.join(' | ')}');
  }

  String _safeTxJsonEncode(dynamic value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _truncateTxLog(String text) {
    const max = 1000;
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  Future<void> _openPreviewSheet(_TransactionPreviewData preview) async {
    if (_isPreviewSheetOpen || !mounted) return;
    _isPreviewSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (sheetContext) {
          final ui = OrbiTheme.uiOf(sheetContext);
          var isSubmitting = false;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final available = preview.availableBalance;
              final isInsufficient =
                  available != null && preview.totalAmount > available;
              final blockedByPreview =
                  !preview.canSubmit ||
                  preview.securityDecision.toUpperCase() == 'BLOCK' ||
                  preview.issueMessage.isNotEmpty;
              return SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ui.cardStrong.withValues(alpha: 0.98),
                        ui.card.withValues(alpha: 0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ui.borderStrong),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: ui.borderStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      _PreviewHeroCard(
                        preview: preview,
                        blocked: blockedByPreview || isInsufficient,
                      ),
                      const SizedBox(height: 10),
                      _PreviewBreakdownCard(preview: preview),
                      if (preview.issueMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _PreviewIssueCard(message: preview.issueMessage),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: ui.border),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.actionCancel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : isInsufficient
                                  ? null
                                  : blockedByPreview
                                  ? null
                                  : () async {
                                      setSheetState(() => isSubmitting = true);
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                      await _submitConfirmedInternalTransfer(
                                        preview,
                                      );
                                    },
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.sendMoneyConfirmAction,
                              ),
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
    } finally {
      _isPreviewSheetOpen = false;
    }
  }

  Future<bool> _submitConfirmedInternalTransfer(
    _TransactionPreviewData preview,
  ) async {
    _markUserActivity();
    if (_isSubmittingInternal || _isSubmittingExternal) return false;
    if (!preview.canSubmit ||
        preview.securityDecision.toUpperCase() == 'BLOCK' ||
        preview.issueMessage.isNotEmpty) {
      _showSnack(
        preview.issueMessage.isNotEmpty
            ? preview.issueMessage
            : AppLocalizations.of(context)!.sendMoneyTransferBlockedMessage,
      );
      return false;
    }

    final token = await _requestTransferAccessToken();
    if (!mounted) return false;
    if (token == null || token.isEmpty) {
      return false;
    }

    final allowNetworkFallback = _allowNetworkLocationForInternalSettle(
      preview,
    );
    final payload = await _withRequiredTransactionGeo(
      _buildInternalSettlePayload(preview),
      allowNetworkFallback: allowNetworkFallback,
    );
    final attempt = _resolvePendingAttempt(payload, external: false);
    if (mounted) {
      setState(() => _isSubmittingInternal = true);
    }
    try {
      final response = await _submitTransactionWith2Fa(
        token,
        payload,
        idempotencyKey: attempt.idempotencyKey,
      );
      final verifiedResponse = await _awaitInternalSettlement(token, response);
      _clearPendingAttempt(external: false);
      if (!mounted) return false;
      final settlementStatus = _settlementStatus(verifiedResponse);
      final isPending = !_isFinalSettlementSuccess(settlementStatus);
      await _showSettleResultDialog(
        success: true,
        pending: isPending,
        title: isPending
            ? (_isSw
                  ? 'Transfer inalindwa na inakamilishwa'
                  : 'Transfer secured and processing')
            : AppLocalizations.of(context)!.sendMoneyTransactionSuccessfulTitle,
        message: isPending
            ? (_isSw
                  ? 'Fedha zimehifadhiwa salama kwenye PaySafe. ORBI itaendelea kukamilisha transfer hii bila kukata fedha mara mbili.'
                  : 'Funds are safely held in PaySafe. ORBI will continue settlement without debiting you twice.')
            : _settleSuccessMessage(verifiedResponse, external: false),
        response: verifiedResponse,
        requestPayload: payload,
      );
      if (mounted) {
        _resetInternalForm();
      }
      return true;
    } catch (e) {
      if (!_shouldKeepPendingAttempt(e)) {
        _clearPendingAttempt(external: false);
      }
      if (!mounted) return false;
      if (e is TransactionGeoException) {
        setState(() => _isSubmittingInternal = false);
        await _showLocationRequiredDialog(e.message);
        return false;
      }
      final sourceError = _normalizeTransferErrorMessage(
        e,
        fallback: AppLocalizations.of(context)!.sendMoneySubmitFailedMessage,
      );
      setState(() => _isSubmittingInternal = false);
      await _showSettleResultDialog(
        success: false,
        title: AppLocalizations.of(context)!.sendMoneyTransactionFailedTitle,
        message: sourceError,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingInternal = false);
      }
    }
  }

  Future<Map<String, dynamic>> _submitTransactionWith2Fa(
    String token,
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) async {
    try {
      return await _submitTransactionForReview(
        token,
        payload,
        idempotencyKey: idempotencyKey,
      );
    } on _TransactionChallengeRequiredException catch (challenge) {
      final verified = await _handleTransactionChallenge(token, challenge);
      if (!verified) {
        throw const _ChallengeCancelledException(
          'Transaction verification was cancelled. Please try again.',
        );
      }
      final controlId = challenge.controlId.trim();
      if (controlId.isEmpty) {
        throw Exception(
          'Security challenge missing controlId. Please try again.',
        );
      }
      final followUpPayload = Map<String, dynamic>.from(payload)
        ..['referenceId'] = controlId;
      final followUpIdempotencyKey = _generateIdempotencyKey();
      return _submitTransactionForReview(
        token,
        followUpPayload,
        idempotencyKey: followUpIdempotencyKey,
      );
    }
  }

  Future<Map<String, dynamic>> _awaitInternalSettlement(
    String token,
    Map<String, dynamic> initialResponse,
  ) async {
    var response = Map<String, dynamic>.from(initialResponse);
    var status = _settlementStatus(response);
    if (_isFinalSettlementSuccess(status)) return response;
    if (_isFinalSettlementFailure(status)) {
      throw Exception(_settlementFailureMessage(response));
    }

    final transactionId = _settlementTransactionId(response);
    if (transactionId.isEmpty) return response;

    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 2 ? 650 : 1200),
      );

      Map<String, dynamic>? transaction;
      for (final endpoint in _transactionApiEndpoints(
        '/transactions/${Uri.encodeComponent(transactionId)}',
      )) {
        try {
          final result = await http
              .get(endpoint, headers: _headers(token))
              .timeout(const Duration(seconds: 8));
          if (result.statusCode == 404) continue;
          if (result.statusCode < 200 || result.statusCode >= 300) continue;
          final parsed = _tryParseJsonMap(result.body);
          final data = parsed?['data'];
          if (data is Map) {
            transaction = Map<String, dynamic>.from(data);
            break;
          }
        } on TimeoutException {
          continue;
        } on SocketException {
          continue;
        } on http.ClientException {
          continue;
        }
      }

      if (transaction == null) continue;
      response = _mergeSettlementTransaction(response, transaction);
      status = _settlementStatus(response);
      if (_isFinalSettlementSuccess(status)) return response;
      if (_isFinalSettlementFailure(status)) {
        throw Exception(_settlementFailureMessage(response));
      }
    }

    return response;
  }

  Map<String, dynamic> _mergeSettlementTransaction(
    Map<String, dynamic> response,
    Map<String, dynamic> transaction,
  ) {
    final merged = Map<String, dynamic>.from(response);
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    data['transaction'] = transaction;
    data['status'] = transaction['status'];
    merged['data'] = data;
    merged['status'] = transaction['status'];
    return merged;
  }

  String _settlementTransactionId(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final transaction = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    return _pickString([
      transaction['internalId'],
      transaction['internal_id'],
      transaction['referenceId'],
      transaction['reference_id'],
      transaction['id'],
      data['transactionId'],
      data['transaction_id'],
      response['controlId'],
      response['control_id'],
    ]);
  }

  String _settlementStatus(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final transaction = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    return _pickString([
      transaction['status'],
      transaction['state'],
      data['status'],
      response['status'],
    ]).toLowerCase();
  }

  bool _isFinalSettlementSuccess(String status) {
    return status == 'completed' ||
        status == 'settled' ||
        status == 'released' ||
        status == 'success' ||
        status == 'successful';
  }

  bool _isFinalSettlementFailure(String status) {
    return status == 'failed' ||
        status == 'reversed' ||
        status == 'refunded' ||
        status == 'cancelled' ||
        status == 'held_for_review';
  }

  String _settlementFailureMessage(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final transaction = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    return _pickString([
      transaction['status_notes'],
      transaction['statusNotes'],
      transaction['message'],
      data['message'],
      response['message'],
      _isSw
          ? 'Transfer haikukamilika. Fedha hazitaondolewa bila settlement iliyothibitishwa.'
          : 'The transfer did not complete. Funds will not leave the protected settlement flow without confirmation.',
    ]);
  }

  Future<bool> _handleTransactionChallenge(
    String token,
    _TransactionChallengeRequiredException challenge,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final requestId = challenge.requestId.trim();
    if (requestId.isEmpty) {
      throw Exception(
        challenge.message.isNotEmpty
            ? challenge.message
            : '2FA challenge was returned without requestId.',
      );
    }

    var hint = challenge.message;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final otp = await _promptChallengeOtp(
        requestId: requestId,
        attempt: attempt,
        helper: hint,
        destinationHint: challenge.otpDestination,
      );
      if (otp == null) return false;

      try {
        await _verifyChallengeOtp(token, requestId, otp);
        if (!mounted) return true;
        _showSnack(l10n.sendMoneyVerificationSuccessMessage);
        return true;
      } catch (e) {
        hint = UserFacingError.from(e, fallback: l10n.otpInvalidCodeMessage);
        if (attempt == 3) {
          throw Exception(hint);
        }
      }
    }
    return false;
  }

  Future<String?> _promptChallengeOtp({
    required String requestId,
    required int attempt,
    String? helper,
    String? destinationHint,
  }) async {
    if (_otpDialogOpen || !mounted) return null;
    _otpDialogOpen = true;
    final destination =
        destinationHint != null && destinationHint.trim().isNotEmpty
        ? destinationHint.trim()
        : _otpDestinationHint();
    final helperText = helper == null || helper.trim().isEmpty
        ? 'Enter the OTP sent to $destination.'
        : helper.trim();

    try {
      final result = await showSecurityOtpDialog(
        context: context,
        title: 'Security Verification',
        helperText: attempt == 1
            ? helperText
            : '$helperText\nAttempt $attempt of 3',
        startListening: (onCode) => _otpAutoFill.startListening(onCode: onCode),
        stopListening: _otpAutoFill.stopListening,
      );
      final code = result?.trim() ?? '';
      if (code.isEmpty) return null;
      return code;
    } finally {
      _otpDialogOpen = false;
    }
  }

  String _otpDestinationHint() {
    final session = context.read<AuthController>().session;
    final user = session['user'] is Map
        ? Map<String, dynamic>.from(session['user'] as Map)
        : <String, dynamic>{};
    final phone = _pickString([user['phone'], user['phone_number']]);
    if (phone.isNotEmpty) {
      return 'your phone (${_maskPhone(phone)})';
    }

    final email = _pickString([user['email']]);
    if (email.isNotEmpty) {
      return 'your email (${_maskEmail(email)})';
    }
    return 'your registered contact';
  }

  String _maskPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.length <= 4) return trimmed;
    final visible = trimmed.substring(trimmed.length - 4);
    return '***$visible';
  }

  String _maskEmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 1) return trimmed;
    final name = trimmed.substring(0, at);
    final domain = trimmed.substring(at);
    final keep = name.length <= 2 ? 1 : 2;
    return '${name.substring(0, keep)}***$domain';
  }

  Future<void> _verifyChallengeOtp(
    String token,
    String requestId,
    String code,
  ) async {
    final verifyPath = AppConfig.endpoints['authVerify'] ?? '/auth/verify';
    final endpoints = [
      Uri.parse('${AppConfig.apiUrl}$verifyPath'),
      Uri.parse('${AppConfig.baseUrl}/v1$verifyPath'),
      Uri.parse('${AppConfig.baseUrl}/api/v1$verifyPath'),
    ];
    final payloadVariants = [
      {'requestId': requestId, 'code': code},
      {'request_id': requestId, 'code': code},
    ];

    http.Response? successResponse;
    http.Response? lastFailure;

    for (final endpoint in endpoints) {
      for (final body in payloadVariants) {
        final attempt = await _postJson(
          endpoint,
          headers: _headers(token),
          body: body,
          timeoutMessage: 'OTP verification timed out. Please try again.',
        );
        _traceTxApi(
          'POST /auth/verify response',
          uri: endpoint,
          statusCode: attempt.statusCode,
          responseBody: attempt.body,
        );
        if (attempt.statusCode >= 200 && attempt.statusCode < 300) {
          successResponse = attempt;
          break;
        }
        lastFailure = attempt;
      }
      if (successResponse != null) break;
    }

    if (successResponse == null) {
      final status = lastFailure?.statusCode;
      final backendMessage = _extractBackendMessage(
        lastFailure?.body,
        statusCode: status,
      );
      throw Exception(
        backendMessage.isNotEmpty
            ? backendMessage
            : 'OTP verification failed. Please try again.',
      );
    }

    final parsed =
        _tryParseJsonMap(successResponse.body) ?? <String, dynamic>{};
    final success =
        parsed['success'] == true ||
        ((parsed['data'] is Map) && (parsed['data'] as Map)['success'] == true);
    if (!success) {
      throw Exception(
        _extractBackendMessage(
          successResponse.body,
          statusCode: successResponse.statusCode,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _submitTransactionForReview(
    String token,
    Map<String, dynamic> payload, {
    required String idempotencyKey,
  }) async {
    final endpoints = _transactionApiEndpoints('/transactions/settle');
    http.Response? res;
    http.Response? lastFailure;
    _TransientNetworkException? transientFailure;
    for (final endpoint in endpoints) {
      _traceTxApi(
        'POST /transactions/settle',
        uri: endpoint,
        requestBody: payload,
      );
      http.Response attempt;
      try {
        attempt = await _postJson(
          endpoint,
          headers: _headers(token, idempotencyKey: idempotencyKey),
          body: payload,
          timeoutMessage: 'Transaction submission timed out. Please try again.',
        );
      } on _TransientNetworkException catch (e) {
        transientFailure = e;
        _traceTxApi(
          'POST /transactions/settle transient failure',
          uri: endpoint,
          extra: {'error': e.message},
        );
        continue;
      }
      _traceTxApi(
        'POST /transactions/settle response',
        uri: endpoint,
        statusCode: attempt.statusCode,
        responseBody: attempt.body,
      );
      if (attempt.statusCode >= 200 && attempt.statusCode < 300) {
        res = attempt;
        break;
      }
      final challengePayload = _tryParseJsonMap(attempt.body);
      if (challengePayload != null && _isChallengeResponse(challengePayload)) {
        throw _buildChallengeException(challengePayload);
      }
      lastFailure = attempt;
    }

    if (res == null) {
      if (lastFailure == null && transientFailure != null) {
        throw _TransientNetworkException(
          _transactionStageUnavailableMessage(
            stage: _isSw ? 'review ya muamala' : 'transaction review',
            safeResult: _isSw
                ? 'Hakuna uthibitisho uliopokelewa, hivyo app haijachukulia muamala kama umefanikiwa.'
                : 'No confirmation was received, so the app did not treat the transfer as successful.',
          ),
        );
      }
      final status = lastFailure?.statusCode;
      final backendMessage = _extractBackendMessage(
        lastFailure?.body,
        statusCode: status,
      );
      if (_isTransientSettleFailure(
        backendMessage,
        statusCode: status,
        responseBody: lastFailure?.body,
      )) {
        throw _TransientSettleException(
          _friendlyTransientSettleMessage(backendMessage),
        );
      }
      final fallback = status == null
          ? 'Submission failed. Please try again.'
          : 'Submission failed ($status). Please try again.';
      throw Exception(backendMessage.isNotEmpty ? backendMessage : fallback);
    }

    final rawBody = res.body;
    if (rawBody.trim().isEmpty) {
      throw const _TransientSettleException(
        'Transaction review did not return a confirmation. Please retry in a moment.',
      );
    }

    Map<String, dynamic> map;
    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is! Map) {
        throw const _TransientSettleException(
          'Transaction review returned an invalid response. Please retry in a moment.',
        );
      }
      map = Map<String, dynamic>.from(parsed);
    } catch (_) {
      throw const _TransientSettleException(
        'Transaction review returned an unreadable response. Please retry in a moment.',
      );
    }

    if (_isChallengeResponse(map)) {
      throw _buildChallengeException(map);
    }

    final nestedData = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : <String, dynamic>{};
    final isSuccess = _isSuccessfulSettleResponse(map, nestedData);
    if (!isSuccess) {
      final backendMessage = _extractBackendMessage(
        rawBody,
        statusCode: res.statusCode,
      );
      if (_isTransientSettleFailure(
        backendMessage,
        statusCode: res.statusCode,
        responseBody: rawBody,
      )) {
        throw _TransientSettleException(
          _friendlyTransientSettleMessage(backendMessage),
        );
      }
      throw Exception(
        backendMessage.isNotEmpty
            ? backendMessage
            : _pickString([
                map['message'],
                map['error'],
                map['code'],
                nestedData['message'],
                nestedData['error'],
                'Transaction submission failed.',
              ]),
      );
    }

    if (nestedData['success'] == false) {
      final controlId = _extractControlIdFromPayload(map);
      throw Exception(
        _appendControlIdMessage(
          _pickString([
            nestedData['error'],
            nestedData['message'],
            map['message'],
            map['error'],
            'Transaction submission rejected by backend.',
          ]),
          controlId,
        ),
      );
    }

    if (map['success'] != true) {
      map['success'] = true;
    }
    if (map['data'] == null || map['data'] is! Map) {
      map['data'] = nestedData;
    }
    if ((map['data'] as Map).isEmpty) {
      throw const _TransientSettleException(
        'Transaction review finished without transaction details. Please retry shortly.',
      );
    }
    return map;
  }

  bool _isTransientSettleFailure(
    String message, {
    int? statusCode,
    String? responseBody,
  }) {
    final haystack =
        '${message.toLowerCase()} ${(responseBody ?? '').toLowerCase()}';
    final isBusinessOrConfigRejection =
        haystack.contains('source_wallet') ||
        haystack.contains('source wallet') ||
        haystack.contains('target_wallet') ||
        haystack.contains('target wallet') ||
        haystack.contains('insufficient_funds') ||
        haystack.contains('insufficient funds') ||
        haystack.contains('provider_route_not_found') ||
        haystack.contains('platform_fee_config_required') ||
        haystack.contains('fee_configuration_required') ||
        haystack.contains('wallet_required') ||
        haystack.contains('account_restricted');
    if (isBusinessOrConfigRejection) return false;
    return statusCode == 408 ||
        statusCode == 409 ||
        statusCode == 423 ||
        statusCode == 429 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504 ||
        haystack.contains('lock_timeout') ||
        haystack.contains('lock timeout') ||
        haystack.contains('under high load') ||
        haystack.contains('unable to acquire resources') ||
        haystack.contains('transient error') ||
        haystack.contains('temporarily unavailable');
  }

  String _friendlyTransientSettleMessage(String backendMessage) {
    final lower = backendMessage.toLowerCase();
    if (lower.contains('lock_timeout') ||
        lower.contains('lock timeout') ||
        lower.contains('unable to acquire resources') ||
        lower.contains('under high load')) {
      return 'Transaction review is busy under high load. No confirmation was received, so the transfer was not treated as successful. Please retry shortly.';
    }
    if (backendMessage.isEmpty) {
      return 'Transaction review is temporarily busy. Please retry in a moment.';
    }
    return backendMessage;
  }

  bool _isSuccessfulSettleResponse(
    Map<String, dynamic> map,
    Map<String, dynamic> data,
  ) {
    if (data['success'] == false) {
      final innerError = _pickString([
        data['error'],
        data['code'],
        data['message'],
      ]);
      if (_isSecurityChallengeError(innerError)) return false;
    }
    if (map['success'] == true || data['success'] == true) return true;
    final status = _pickString([
      map['status'],
      map['result'],
      map['decision'],
      map['code'],
      data['status'],
      data['result'],
      data['decision'],
      data['code'],
    ]).toLowerCase();
    if (status.isEmpty) return false;
    return status.contains('success') ||
        status.contains('ok') ||
        status.contains('approved') ||
        status.contains('processing') ||
        status.contains('pending') ||
        status.contains('completed') ||
        status.contains('settled');
  }

  bool? _boolFrom(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final raw = message.toLowerCase();
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: sw,
        fallback: message,
      );
      _statusTone =
          raw.contains('error') ||
              raw.contains('failed') ||
              raw.contains('unable') ||
              raw.contains('invalid') ||
              raw.contains('insufficient') ||
              raw.contains('required') ||
              raw.contains('locked')
          ? OrbiStatusTone.error
          : OrbiStatusTone.success;
    });
  }

  bool _isSecurityChallengeError(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    const markers = [
      'SECURITY_CHALLENGE',
      'CHALLENGE_REQUIRED',
      'OTP_REQUIRED',
      'TWO_FA_REQUIRED',
      '2FA_REQUIRED',
      'MFA_REQUIRED',
    ];
    return markers.any(normalized.contains);
  }

  bool _isChallengeResponse(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final challenge = data['challenge'] is Map
        ? Map<String, dynamic>.from(data['challenge'] as Map)
        : <String, dynamic>{};

    final flags = [
      payload['challenge_required'],
      payload['challengeRequired'],
      payload['otp_required'],
      payload['otpRequired'],
      payload['require_otp'],
      payload['requires_otp'],
      payload['two_fa_required'],
      payload['twoFaRequired'],
      payload['mfa_required'],
      payload['mfaRequired'],
      payload['verification_required'],
      payload['verificationRequired'],
      data['challenge_required'],
      data['challengeRequired'],
      data['otp_required'],
      data['otpRequired'],
      data['require_otp'],
      data['requires_otp'],
      data['two_fa_required'],
      data['twoFaRequired'],
      data['mfa_required'],
      data['mfaRequired'],
      data['verification_required'],
      data['verificationRequired'],
      challenge['challenge_required'],
      challenge['challengeRequired'],
      challenge['otp_required'],
      challenge['otpRequired'],
      challenge['require_otp'],
      challenge['requires_otp'],
      challenge['two_fa_required'],
      challenge['twoFaRequired'],
      challenge['mfa_required'],
      challenge['mfaRequired'],
      challenge['verification_required'],
      challenge['verificationRequired'],
    ];
    for (final flag in flags) {
      final value = _boolFrom(flag);
      if (value == true) return true;
    }

    final error = _pickString([
      payload['error'],
      payload['message'],
      payload['code'],
      data['error'],
      data['message'],
      data['code'],
      challenge['error'],
      challenge['message'],
      challenge['code'],
    ]);
    if (_isSecurityChallengeError(error)) return true;

    final decision = _pickString([
      payload['decision'],
      payload['security_decision'],
      payload['securityDecision'],
      payload['status'],
      payload['result'],
      payload['code'],
      data['decision'],
      data['security_decision'],
      data['securityDecision'],
      data['status'],
      data['result'],
      data['code'],
      challenge['decision'],
      challenge['security_decision'],
      challenge['securityDecision'],
      challenge['status'],
      challenge['result'],
      challenge['code'],
    ]).toUpperCase();

    if (decision.contains('CHALLENGE') || decision.contains('OTP')) return true;

    return _pickString([
      payload['requestId'],
      payload['request_id'],
      data['requestId'],
      data['request_id'],
      data['challenge_id'],
      data['challengeId'],
      data['verification_id'],
      data['verificationId'],
      challenge['requestId'],
      challenge['request_id'],
      challenge['challenge_id'],
      challenge['challengeId'],
      challenge['verification_id'],
      challenge['verificationId'],
    ]).isNotEmpty;
  }

  Future<http.Response> _postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String timeoutMessage,
    Duration timeout = _transactionRequestTimeout,
  }) async {
    try {
      return await http
          .post(endpoint, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw _TransientNetworkException(timeoutMessage);
    } on SocketException {
      throw const _TransientNetworkException(
        'Network error. Please check your connection and try again.',
      );
    } on http.ClientException catch (e) {
      final lower = e.message.toLowerCase();
      throw _TransientNetworkException(
        lower.contains('failed host lookup') ||
                lower.contains('socketexception') ||
                lower.contains('clientexception') ||
                lower.contains('http://') ||
                lower.contains('https://')
            ? 'Network error. Please check your connection and try again.'
            : (e.message.isEmpty
                  ? 'Network error. Please try again.'
                  : e.message),
      );
    } on HandshakeException {
      throw const _TransientNetworkException(
        'Secure connection failed. Please try again.',
      );
    } on HttpException catch (e) {
      throw _TransientNetworkException(
        e.message.isEmpty ? 'Network error. Please try again.' : e.message,
      );
    }
  }

  List<Uri> _transactionApiEndpoints(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final seen = <String>{};
    final candidates = <Uri>[];
    for (final root in AppConfig.baseUrls) {
      final base = root.endsWith('/')
          ? root.substring(0, root.length - 1)
          : root;
      for (final prefix in const ['/v1', '/api/v1']) {
        final url = '$base$prefix$cleanPath';
        if (seen.add(url)) candidates.add(Uri.parse(url));
      }
    }
    return candidates;
  }

  String _transactionStageUnavailableMessage({
    required String stage,
    required String safeResult,
  }) {
    if (_isSw) {
      return 'Huduma ya $stage haipatikani kwa sasa. $safeResult Tafadhali hakiki mtandao wako kisha ujaribu tena.';
    }
    return 'The $stage service is unreachable right now. $safeResult Please check your connection and try again.';
  }

  _TransactionChallengeRequiredException _buildChallengeException(
    Map<String, dynamic> payload,
  ) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};
    final challenge = data['challenge'] is Map
        ? Map<String, dynamic>.from(data['challenge'] as Map)
        : <String, dynamic>{};
    final requestId = _pickString([
      payload['requestId'],
      payload['request_id'],
      payload['challenge_id'],
      payload['challengeId'],
      payload['verification_id'],
      payload['verificationId'],
      data['requestId'],
      data['request_id'],
      data['challenge_id'],
      data['challengeId'],
      data['verification_id'],
      data['verificationId'],
      challenge['requestId'],
      challenge['request_id'],
      challenge['challenge_id'],
      challenge['challengeId'],
      challenge['verification_id'],
      challenge['verificationId'],
    ]);
    final controlId = _pickString([
      payload['controlId'],
      payload['control_id'],
      payload['referenceId'],
      payload['reference_id'],
      data['controlId'],
      data['control_id'],
      data['referenceId'],
      data['reference_id'],
      challenge['controlId'],
      challenge['control_id'],
      challenge['referenceId'],
      challenge['reference_id'],
    ]);
    final message = _pickString([
      challenge['message'],
      data['message'],
      payload['message'],
      payload['error'],
      'OTP verification required to continue this transaction.',
    ]);
    final destination = _pickString([
      challenge['otp_destination'],
      challenge['otpDestination'],
      challenge['masked_destination'],
      challenge['maskedDestination'],
      challenge['destination'],
      challenge['target'],
      challenge['phone_masked'],
      challenge['email_masked'],
      data['otp_destination'],
      data['otpDestination'],
      data['masked_destination'],
      data['maskedDestination'],
      data['destination'],
      data['target'],
      payload['otp_destination'],
      payload['otpDestination'],
      payload['masked_destination'],
      payload['maskedDestination'],
      payload['destination'],
      payload['target'],
    ]);
    final channel = _pickString([
      challenge['channel'],
      challenge['delivery_channel'],
      data['channel'],
      data['delivery_channel'],
      payload['channel'],
      payload['delivery_channel'],
    ]).toLowerCase();
    return _TransactionChallengeRequiredException(
      requestId: requestId,
      message: message,
      otpDestination: _formatChallengeDestination(
        channel: channel,
        destination: destination,
      ),
      controlId: controlId,
      payload: payload,
    );
  }

  String _formatChallengeDestination({
    required String channel,
    required String destination,
  }) {
    final dest = destination.trim();
    if (dest.isEmpty) return '';
    if (channel.contains('sms') || channel.contains('phone')) {
      return 'your phone ($dest)';
    }
    if (channel.contains('mail') || channel.contains('email')) {
      return 'your email ($dest)';
    }
    return 'your registered contact ($dest)';
  }

  Map<String, dynamic>? _tryParseJsonMap(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (_) {}
    return null;
  }

  String _settleSuccessMessage(
    Map<String, dynamic> response, {
    required bool external,
  }) {
    final controlId = _pickString([
      response['controlId'],
      response['control_id'],
      response['referenceId'],
      response['reference_id'],
    ]);
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final tx = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    final breakdown = data['breakdown'] is Map
        ? Map<String, dynamic>.from(data['breakdown'] as Map)
        : <String, dynamic>{};
    final status = _pickString([
      response['status'],
      data['status'],
      tx['status'],
      tx['state'],
    ]).toLowerCase();

    final ref = _pickString([
      tx['reference'],
      tx['transaction_reference'],
      tx['transaction_id'],
      tx['id'],
    ]);
    final total = _toDouble(breakdown['total']);
    final currency = _pickString([tx['currency'], breakdown['currency']]);
    final isProcessing =
        status.contains('processing') || status.contains('pending');
    final prefix = isProcessing
        ? (external
              ? 'External transfer is processing.'
              : 'Transfer is processing.')
        : (external ? 'External transfer submitted.' : 'Transfer submitted.');

    final resolvedControlId = _pickString([
      controlId,
      data['controlId'],
      data['control_id'],
      data['referenceId'],
      data['reference_id'],
      tx['controlId'],
      tx['control_id'],
      tx['referenceId'],
      tx['reference_id'],
    ]);
    final controlSuffix = resolvedControlId.isEmpty
        ? ''
        : ' Control ID: $resolvedControlId';

    if (ref.isNotEmpty && total > 0) {
      final money = formatAppBalanceAmount(total, currency, locale: _localeTag);
      return '$prefix Ref: $ref. Total: $money.$controlSuffix';
    }
    if (ref.isNotEmpty) return '$prefix Ref: $ref.$controlSuffix';
    return '$prefix$controlSuffix';
  }

  Future<void> _showSettleResultDialog({
    required bool success,
    required String title,
    required String message,
    bool pending = false,
    Map<String, dynamic>? response,
    Map<String, dynamic>? requestPayload,
  }) async {
    if (!mounted) return;
    final receiptRows = success
        ? _buildReceiptRows(response: response, requestPayload: requestPayload)
        : const <MapEntry<String, String>>[];

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final ui = OrbiTheme.uiOf(dialogContext);
        final iconColor = pending
            ? ui.warning
            : success
            ? ui.success
            : ui.danger;
        final icon = pending
            ? Icons.schedule_rounded
            : success
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;
        return Dialog(
          backgroundColor: ui.card,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.75, end: 1),
                      curve: Curves.elasticOut,
                      duration: const Duration(milliseconds: 700),
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Icon(icon, color: iconColor, size: 64),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ui.textMuted, fontSize: 13),
                    ),
                  ),
                  if (success && receiptRows.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _receiptCard(receiptRows),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 360;
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (success && receiptRows.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _printReceipt(
                                      rows: receiptRows,
                                      title: title,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.actionPrintReceipt,
                                  ),
                                ),
                              if (success && receiptRows.isNotEmpty)
                                const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Text(
                                  success
                                      ? AppLocalizations.of(context)!.actionDone
                                      : AppLocalizations.of(
                                          context,
                                        )!.actionClose,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            if (success && receiptRows.isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await _printReceipt(
                                      rows: receiptRows,
                                      title: title,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.actionPrintReceipt,
                                  ),
                                ),
                              ),
                            if (success && receiptRows.isNotEmpty)
                              const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Text(
                                  success
                                      ? AppLocalizations.of(context)!.actionDone
                                      : AppLocalizations.of(
                                          context,
                                        )!.actionClose,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<MapEntry<String, String>> _buildReceiptRows({
    Map<String, dynamic>? response,
    Map<String, dynamic>? requestPayload,
  }) {
    final data = response?['data'] is Map
        ? Map<String, dynamic>.from(response!['data'] as Map)
        : <String, dynamic>{};
    final tx = data['transaction'] is Map
        ? Map<String, dynamic>.from(data['transaction'] as Map)
        : <String, dynamic>{};
    final breakdown = data['breakdown'] is Map
        ? Map<String, dynamic>.from(data['breakdown'] as Map)
        : <String, dynamic>{};
    final req = requestPayload ?? const <String, dynamic>{};

    final controlId = _pickString([
      response?['controlId'],
      response?['control_id'],
      response?['referenceId'],
      response?['reference_id'],
      data['controlId'],
      data['control_id'],
      data['referenceId'],
      data['reference_id'],
      tx['controlId'],
      tx['control_id'],
      tx['referenceId'],
      tx['reference_id'],
      req['referenceId'],
      req['reference_id'],
      req['controlId'],
      req['control_id'],
    ]);

    final currency = _pickString([
      tx['currency'],
      breakdown['currency'],
      req['currency'],
    ]);
    final resolvedCurrency = currency;
    final createdAt = _pickString([
      tx['created_at'],
      tx['createdAt'],
      tx['timestamp'],
      DateTime.now().toIso8601String(),
    ]);
    final parsedTime = DateTime.tryParse(createdAt);
    final timeText = parsedTime == null
        ? createdAt
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedTime.toLocal());

    final sourceWallet = req['source_wallet'];
    final sourceWalletValue = sourceWallet is String
        ? sourceWallet
        : (sourceWallet is Map
              ? _pickString([
                  sourceWallet['selection'],
                  sourceWallet['wallet_label'],
                  sourceWallet['wallet_id'],
                ])
              : '');

    return [
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptTransactionId,
        _pickString([tx['id'], tx['transaction_id'], tx['reference']]),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptReference,
        _pickString([
          tx['reference'],
          tx['transaction_reference'],
          tx['transaction_id'],
          tx['id'],
        ]),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptControlId,
        controlId,
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptStatus,
        _pickString([tx['status'], tx['state'], 'SUCCESS']),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptType,
        _pickString([req['type'], tx['type']]),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptTransaction,
        _pickString([req['transaction_type'], tx['transaction_type']]),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptRecipient,
        _pickString([
          req['recipient_customer_id'],
          req['recipient_reference'],
          tx['recipient_customer_id'],
          tx['recipient_reference'],
        ]),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptSourceWallet,
        sourceWalletValue,
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptAmount,
        formatAppBalanceAmount(
          _toDouble(breakdown['base'] ?? req['amount']),
          resolvedCurrency,
          locale: _localeTag,
        ),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptTax,
        formatAppBalanceAmount(
          _toDouble(breakdown['tax']),
          resolvedCurrency,
          locale: _localeTag,
        ),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptFee,
        formatAppBalanceAmount(
          _toDouble(breakdown['fee']),
          resolvedCurrency,
          locale: _localeTag,
        ),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptTotal,
        formatAppBalanceAmount(
          _toDouble(breakdown['total'] ?? req['amount']),
          resolvedCurrency,
          locale: _localeTag,
        ),
      ),
      MapEntry(
        AppLocalizations.of(context)!.sendMoneyReceiptDescription,
        _pickString([req['description'], tx['description']]),
      ),
      MapEntry(AppLocalizations.of(context)!.sendMoneyReceiptTime, timeText),
    ].where((row) => row.value.trim().isNotEmpty).toList();
  }

  List<int> _barcodeWidths(String raw) {
    final input = raw.trim().isEmpty ? 'ORBI' : raw.trim();
    final widths = <int>[];
    for (final rune in input.runes) {
      final seed = rune % 9;
      widths.add(1 + (seed % 3));
      widths.add(1 + ((seed + 1) % 3));
      widths.add(1 + ((seed + 2) % 3));
      widths.add(1 + ((seed + 3) % 2));
    }
    return widths;
  }

  Widget _barcodeStrip(String value, {required OrbiUiTokens ui}) {
    final widths = _barcodeWidths(value);
    final totalWidth = widths.fold<int>(0, (sum, width) => sum + width);
    var dark = true;
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.borderStrong),
      ),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.center,
          child: SizedBox(
            width: totalWidth.toDouble(),
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widths.map((w) {
                final bar = Container(
                  width: w.toDouble(),
                  color: dark ? ui.textPrimary : ui.card,
                );
                dark = !dark;
                return bar;
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _receiptBarcodeValue(List<MapEntry<String, String>> rows) {
    String lookup(String key) {
      for (final row in rows) {
        if (row.key.toLowerCase() == key.toLowerCase()) {
          return row.value.trim();
        }
      }
      return '';
    }

    final txId = lookup('Transaction ID');
    if (txId.isNotEmpty) return txId;
    final ref = lookup('Reference');
    if (ref.isNotEmpty) return ref;
    return 'ORBI-${DateTime.now().millisecondsSinceEpoch}';
  }

  Widget _receiptCard(List<MapEntry<String, String>> rows) {
    final ui = OrbiTheme.uiOf(context);
    final barcodeValue = _receiptBarcodeValue(rows);
    const receiptPaper = Color(0xFFFFFFFF);
    const receiptInk = Color(0xFF163126);
    const receiptMutedInk = Color(0xFF5E7268);
    const receiptBorder = Color(0xFF2E8B57);
    const receiptSoft = Color(0xFFE7F5EC);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipPath(
          clipper: const _ReceiptZigZagClipper(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              color: receiptPaper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: receiptBorder, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const OrbiLogoV2(
                          width: 40,
                          showWord: false,
                          color: receiptInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: receiptSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: receiptBorder),
                        ),
                        child: Text(
                          'ORBI',
                          style: GoogleFonts.michroma(
                            color: receiptBorder,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'TRANSACTION RECEIPT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: receiptInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Orbi Financial Technologies\n'
                        'P.O. BOX 02, Dar es Salaam, Tanzania\n'
                        'Main Branch, Kariakoo Alikoma-Magira Street, Block No 123, Second Floor\n'
                        'Tel +255764258114',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: receiptMutedInk,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: receiptBorder, height: 1),
                const SizedBox(height: 9),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 122,
                          child: Text(
                            row.key.toUpperCase(),
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: receiptMutedInk,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              color: receiptInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: receiptInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: _barcodeStrip(
                      barcodeValue,
                      ui: ui.copyWith(
                        card: receiptPaper,
                        borderStrong: receiptBorder,
                        textPrimary: receiptInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    barcodeValue,
                    style: const TextStyle(
                      color: receiptMutedInk,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Thank you for choosing ORBI. We value your trust.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: receiptBorder,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
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

  Future<void> _printReceipt({
    required List<MapEntry<String, String>> rows,
    required String title,
  }) async {
    try {
      final logoBytes = await _loadReceiptLogoBytes();
      final brandFont = await PdfGoogleFonts.michromaRegular();
      final doc = pw.Document();
      final receiptInk = PdfColor.fromHex('#163126');
      final receiptMutedInk = PdfColor.fromHex('#5E7268');
      final receiptBorder = PdfColor.fromHex('#2E8B57');
      final receiptSoft = PdfColor.fromHex('#E7F5EC');
      final now = DateTime.now();
      final printedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final tzName = now.timeZoneName.trim();
      final offset = now.timeZoneOffset;
      final offsetSign = offset.isNegative ? '-' : '+';
      final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
      final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(
        2,
        '0',
      );
      final offsetLabel = 'UTC$offsetSign$offsetHours:$offsetMinutes';
      final printedAtLabel = tzName.isNotEmpty && tzName.toUpperCase() != 'UTC'
          ? '$printedAt $tzName ($offsetLabel)'
          : printedAt;

      final receiptPageFormat = PdfPageFormat(
        80 * PdfPageFormat.mm,
        PdfPageFormat.a4.height,
      );

      final barcodeValue = _receiptBarcodeValue(rows);
      final bars = _barcodeWidths(barcodeValue);
      var dark = true;
      final pdfBars = bars.map((w) {
        final bar = pw.Container(
          width: w.toDouble(),
          color: dark ? receiptInk : PdfColor.fromHex('#FFFFFF'),
        );
        dark = !dark;
        return bar;
      }).toList();

      doc.addPage(
        pw.Page(
          pageFormat: receiptPageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            final receiptBody = pw.CustomPaint(
              foregroundPainter: (canvas, size) {
                const zigZagHeight = 4.0;
                const zigZagWidth = 10.0;
                final width = size.x;
                final height = size.y;
                canvas
                  ..setStrokeColor(receiptBorder)
                  ..setLineWidth(0.8);
                var x = 0.0;
                canvas.moveTo(0, height - zigZagHeight);
                while (x < width) {
                  canvas
                    ..lineTo(x + zigZagWidth / 2, height)
                    ..lineTo(x + zigZagWidth, height - zigZagHeight);
                  x += zigZagWidth;
                }
                canvas.strokePath();
                x = width;
                canvas.moveTo(width, zigZagHeight);
                while (x > 0) {
                  canvas
                    ..lineTo(x - zigZagWidth / 2, 0)
                    ..lineTo(x - zigZagWidth, zigZagHeight);
                  x -= zigZagWidth;
                }
                canvas.strokePath();
              },
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.DefaultTextStyle(
                  style: pw.TextStyle(color: receiptInk),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Header(
                        level: 0,
                        margin: pw.EdgeInsets.zero,
                        child: pw.Center(
                          child: pw.Column(
                            children: [
                              if (logoBytes != null) ...[
                                pw.Image(
                                  pw.MemoryImage(logoBytes),
                                  width: 34,
                                  height: 34,
                                ),
                                pw.SizedBox(height: 6),
                              ],
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: receiptSoft,
                                  border: pw.Border.all(color: receiptBorder),
                                  borderRadius: pw.BorderRadius.circular(999),
                                ),
                                child: pw.Text(
                                  'ORBI',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: receiptBorder,
                                    font: brandFont,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'TRANSACTION RECEIPT',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Orbi Financial Technologies\n'
                                'P.O. BOX 02, Dar es Salaam, Tanzania\n'
                                'Main Branch Kariakoo Alikoma-Magira Street, Block No 123 Second Floor\n'
                                'Tel +255764258114',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: receiptMutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Table(
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2.2),
                          1: const pw.FixedColumnWidth(14),
                          2: const pw.FlexColumnWidth(3.8),
                        },
                        defaultVerticalAlignment:
                            pw.TableCellVerticalAlignment.top,
                        children: rows
                            .map(
                              (row) => pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      bottom: 7,
                                    ),
                                    child: pw.Text(
                                      row.key.toUpperCase(),
                                      style: pw.TextStyle(
                                        fontSize: 8.6,
                                        color: receiptMutedInk,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      bottom: 7,
                                    ),
                                    child: pw.Text(
                                      ':',
                                      textAlign: pw.TextAlign.center,
                                      style: const pw.TextStyle(fontSize: 9),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      bottom: 7,
                                    ),
                                    child: pw.Text(
                                      row.value,
                                      softWrap: true,
                                      style: pw.TextStyle(
                                        fontSize: 9.2,
                                        fontWeight:
                                            row.key == 'Amount' ||
                                                row.key == 'Base Amount' ||
                                                row.key == 'Tax' ||
                                                row.key == 'Service Fee' ||
                                                row.key == 'Total Charged'
                                            ? pw.FontWeight.bold
                                            : pw.FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        width: double.infinity,
                        height: 56,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                        decoration: pw.BoxDecoration(
                          color: receiptSoft,
                          border: pw.Border.all(color: receiptBorder),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: pdfBars,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Center(
                        child: pw.Text(
                          'Printed: $printedAtLabel',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            color: receiptMutedInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return receiptBody;
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        UserFacingError.from(e, fallback: 'Unable to print receipt right now.'),
      );
    }
  }

  Future<Uint8List?> _loadReceiptLogoBytes() async {
    try {
      final data = await rootBundle.load(
        'assets/images/brand/orbi-logo-v2-dark-blue.png',
      );
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildInternalSettlePayload(
    _TransactionPreviewData preview,
  ) {
    final amount =
        AmountInputFormatter.tryParse(_internalAmountController.text) ?? 0.0;
    final note = _internalNoteController.text.trim();
    final sourceParts = _buildInternalSourcePayloadParts();
    return {
      'quoteId': preview.quoteId,
      'quoteHash': preview.quoteHash,
      'transfer_mode': 'Internal',
      'category': 'Transfer',
      'type': 'INTERNAL_TRANSFER',
      'amount': amount,
      'currency': _resolveCurrency(),
      'description': note,
      'transaction_type': 'INTERNAL_P2P',
      'metadata': {
        'category': 'Transfer',
        if ((_selectedInternalCategoryId ?? '').isNotEmpty)
          'category_id': _selectedInternalCategoryId,
        if (note.isNotEmpty) 'notes': note,
      },
      'recipient_customer_id': preview.recipientCustomerId,
      if ((_recipientPreview?.internalId ?? '').isNotEmpty)
        'recipient_id': _recipientPreview!.internalId,
      if ((_selectedInternalCategoryId ?? '').isNotEmpty)
        'categoryId': _selectedInternalCategoryId,
      // Backend remains canonical; these are best-effort hints.
      ...sourceParts,
      'current_user': _currentUserContext(),
      'ui_submission': {
        'flow': 'send_money',
        'mode': 'internal',
        'steps': {
          'recipient_input': _recipientIdController.text.trim(),
          'recipient_display_identifier': preview.recipientDisplayIdentifier,
          'recipient_full_name': preview.recipientName,
          'amount_input': AmountInputFormatter.sanitize(
            _internalAmountController.text,
          ),
          'description_input': note,
          'source_wallet_input':
              _selectedInternalSourceWalletId ?? 'OPERATING_WALLET_AUTO',
        },
      },
      'preview_snapshot': {
        'quoteId': preview.quoteId,
        'quoteHash': preview.quoteHash,
        'status': preview.status,
        'security_decision': preview.securityDecision,
        'breakdown': {
          'base': preview.baseAmount,
          'tax': preview.taxAmount,
          'fee': preview.feeAmount,
          'total': preview.totalAmount,
        },
      },
    };
  }

  Map<String, dynamic> _buildExternalSettlePayload() {
    final amount =
        AmountInputFormatter.tryParse(_externalAmountController.text) ?? 0.0;
    final note = _externalNoteController.text.trim();
    final rawRecipient = _externalRecipientController.text.trim();
    final providerLabel = _externalProviderController.text.trim();
    final provider = (_selectedExternalProviderCode ?? providerLabel)
        .trim()
        .toUpperCase();
    final cardNo = _externalCardNoController.text.trim();
    final recipient = widget.externalExperience == ExternalExperience.withdraw
        ? (_externalRail == _ExternalTransferRail.externalAgent ? cardNo : '')
        : rawRecipient;
    final sourceWallet = _externalSourceWalletValue(_externalSourceWalletType);
    final selectedWallet = _backendWallets
        .where((w) {
          return _walletId(w) == _selectedExternalSourceWalletId;
        })
        .cast<Map<String, dynamic>>()
        .toList();
    final selectedSourceWallet = selectedWallet.isEmpty
        ? null
        : selectedWallet.first;
    final walletId = selectedSourceWallet == null
        ? ''
        : _walletId(selectedSourceWallet);
    final walletName = selectedSourceWallet == null
        ? ''
        : _walletName(selectedSourceWallet);
    final operatingWalletId = _resolveOperatingWalletId();
    final sourceWalletDetails = sourceWallet == 'internal'
        ? _buildSourceContext(walletId: operatingWalletId)
        : {
            'selection': sourceWallet,
            if (walletId.isNotEmpty) 'wallet_id': walletId,
            if (walletName.isNotEmpty) 'wallet_name': walletName,
          };
    final effectiveWalletId = sourceWallet == 'internal'
        ? operatingWalletId
        : walletId;
    final sourceFields = _buildSourceTopLevelFields(
      walletId: effectiveWalletId,
    );
    final externalWalletType = sourceWallet == 'internal'
        ? 'internal_vault'
        : 'External';
    final transactionType = '${_externalRailPrefix(_externalRail)}_$provider';
    final counterpartyType = _externalRail == _ExternalTransferRail.bank
        ? 'BANK'
        : _externalRail == _ExternalTransferRail.mobileWallet
        ? 'MOBILE_MONEY'
        : _externalRail == _ExternalTransferRail.externalAgent
        ? 'EXTERNAL_AGENT'
        : _externalRailPrefix(_externalRail).toUpperCase();
    final journeyCategory =
        widget.externalExperience == ExternalExperience.withdraw
        ? 'Withdraw'
        : _externalRail == _ExternalTransferRail.bank
        ? 'Transfer'
        : 'Pay';
    return {
      'transfer_mode': sourceWallet == 'internal' ? 'Internal' : 'External',
      'category': journeyCategory,
      'walletType': externalWalletType,
      'type': _mapExternalApiType(_externalRail),
      'transactionType': transactionType,
      'providerInput': provider,
      if (_selectedExternalProviderCode != null)
        'paymentRailCapabilityCode': _selectedExternalProviderCode,
      'counterpartyType': counterpartyType,
      'amount': amount,
      'currency': _resolveCurrency(),
      'description': note,
      'metadata': {
        'category': journeyCategory,
        if ((_selectedExternalCategoryId ?? '').isNotEmpty)
          'category_id': _selectedExternalCategoryId,
        'external_rail': _externalRailPrefix(_externalRail),
        if (provider.isNotEmpty) 'provider': provider,
        if (providerLabel.isNotEmpty) 'provider_label': providerLabel,
        if (_selectedExternalProviderCode != null)
          'payment_rail_capability_code': _selectedExternalProviderCode,
        if (widget.externalExperience == ExternalExperience.withdraw &&
            _externalRail == _ExternalTransferRail.externalAgent &&
            _orbiAgentPreview != null)
          'agent_lookup': {
            'agent_id': _orbiAgentPreview!.agentId,
            'display_name': _orbiAgentPreview!.displayName,
            if (_orbiAgentPreview!.tillNumber.isNotEmpty)
              'cash_withdraw_till': _orbiAgentPreview!.tillNumber,
            if (_orbiAgentPreview!.serviceNumber.isNotEmpty)
              'service_pay_number': _orbiAgentPreview!.serviceNumber,
            if (_orbiAgentPreview!.branch.isNotEmpty)
              'branch': _orbiAgentPreview!.branch,
          },
        if (note.isNotEmpty) 'notes': note,
      },
      'transaction_type': transactionType,
      'recipient_reference': recipient,
      'card_no': cardNo,
      'source_wallet': sourceWallet,
      if ((_selectedExternalCategoryId ?? '').isNotEmpty)
        'categoryId': _selectedExternalCategoryId,
      if (effectiveWalletId.isNotEmpty) 'sourceWalletId': effectiveWalletId,
      'source_wallet_details': sourceWalletDetails,
      'source_wallet_context': {
        'wallet_id': effectiveWalletId,
        'wallet_type': externalWalletType,
        'selection': sourceWallet,
        'auto_resolve': effectiveWalletId.isEmpty,
      },
      ...sourceFields,
      'current_user': _currentUserContext(),
      'ui_submission': {
        'flow': 'send_money',
        'mode': 'external',
        'steps': {
          'external_type': _externalRailLabel(_externalRail),
          'provider_input': provider,
          'card_no_input': cardNo,
          'source_wallet_input': sourceWallet,
          'wallet_id_input': walletId,
          if (walletName.isNotEmpty) 'wallet_name_input': walletName,
          'recipient_input': recipient,
          'amount_input': AmountInputFormatter.sanitize(
            _externalAmountController.text,
          ),
          'description_input': note,
        },
      },
    };
  }

  bool _allowNetworkLocationForInternalSettle(_TransactionPreviewData preview) {
    final decision = preview.securityDecision.toUpperCase();
    final state = preview.state.toUpperCase();
    final status = preview.status.toUpperCase();
    final blockedOrPendingReview =
        decision.contains('CHALLENGE') ||
        decision.contains('BLOCK') ||
        state.contains('REVIEW') ||
        status.contains('REVIEW') ||
        preview.issueMessage.trim().isNotEmpty;
    if (blockedOrPendingReview) return false;
    return preview.totalAmount <= _lowRiskIpFallbackSettlementLimit();
  }

  double _lowRiskIpFallbackSettlementLimit() {
    final currency = _resolveCurrency().toUpperCase();
    if (currency == 'TZS') return 10000;
    if (currency == 'KES' || currency == 'UGX') return 5000;
    return 5;
  }

  Map<String, dynamic> _currentUserContext() {
    final session = context.read<AuthController>().session;
    final user = session['user'] is Map
        ? Map<String, dynamic>.from(session['user'] as Map)
        : <String, dynamic>{};
    return {
      'id': _pickString([user['id'], user['user_id'], user['userId']]),
      'customer_id': _pickString([
        user['customer_id'],
        user['customerId'],
        session['customer_id'],
        session['customerId'],
      ]),
      'email': _pickString([user['email']]),
      'phone': _pickString([user['phone'], user['phone_number']]),
      'full_name': _pickString([
        user['full_name'],
        user['fullName'],
        user['name'],
      ]),
    }..removeWhere((_, value) => value is String && value.trim().isEmpty);
  }

  bool _isLikelyOperatingWallet(Map<String, dynamic> wallet) {
    if (_isEscrowWallet(wallet)) return false;
    final type = _walletType(wallet);
    final tier = _walletTier(wallet);
    final name = _walletName(wallet).toLowerCase();
    return type.contains('operating') ||
        type.contains('internal_main') ||
        tier.contains('operating') ||
        name.contains('operating') ||
        name.contains('main default') ||
        name.contains('internal vault') ||
        name.contains('dilpesa');
  }

  List<Map<String, dynamic>> _internalSubWallets() {
    final wallets = _backendWallets
        .where(
          (wallet) =>
              _matchesSourceWalletType(
                wallet,
                _ExternalSourceWalletType.internal,
              ) &&
              !_isEscrowWallet(wallet) &&
              !_isLikelyOperatingWallet(wallet) &&
              _walletId(wallet).isNotEmpty,
        )
        .toList();
    wallets.addAll(_transferGoalSources());
    return wallets;
  }

  Map<String, dynamic>? _selectedInternalSourceWallet() {
    final id = _selectedInternalSourceWalletId;
    if (id == null || id.trim().isEmpty) return null;
    for (final wallet in _internalSubWallets()) {
      if (_walletId(wallet) == id) return wallet;
    }
    return null;
  }

  String _internalSubWalletType(Map<String, dynamic> wallet) {
    if (_isGoalSourceWallet(wallet)) return 'GOAL';
    final composite =
        '${_walletType(wallet)} ${_walletTier(wallet)} ${_walletName(wallet)}'
            .toLowerCase();
    if (composite.contains('goal')) return 'GOAL';
    if (composite.contains('budget')) return 'BUDGET';
    if (composite.contains('saving')) return 'SAVINGS';
    return 'SUB_WALLET';
  }

  bool _selectedInternalSourceIsGoal() {
    final selected = _selectedInternalSourceWallet();
    if (selected == null) return false;
    return _internalSubWalletType(selected) == 'GOAL';
  }

  Future<bool> _confirmGoalSourceTransfer() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.sendMoneyGoalSourceWarningTitle),
          content: Text(l10n.sendMoneyGoalSourceWarningBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.sendMoneyGoalSourceContinueAction),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _localizedInternalSubWalletType(Map<String, dynamic> wallet) {
    final l10n = AppLocalizations.of(context)!;
    switch (_internalSubWalletType(wallet)) {
      case 'GOAL':
        return l10n.sendMoneySourceBadgeGoal;
      case 'BUDGET':
        return l10n.sendMoneySourceBadgeBudget;
      case 'SAVINGS':
        return l10n.sendMoneySourceBadgeSavings;
      default:
        return l10n.sendMoneySourceBadgeSubWallet;
    }
  }

  void _syncSelectedInternalSourceWallet() {
    if (_selectedInternalSourceWalletId == null) return;
    final hasSelected = _internalSubWallets().any(
      (wallet) => _walletId(wallet) == _selectedInternalSourceWalletId,
    );
    if (!hasSelected) {
      _selectedInternalSourceWalletId = null;
    }
  }

  void _syncSelectedBudgetCategories() {
    final ids = _budgetCategories.map((item) => _categoryId(item)).toSet();
    if (_selectedInternalCategoryId != null &&
        !ids.contains(_selectedInternalCategoryId)) {
      _selectedInternalCategoryId = null;
    }
    if (_selectedExternalCategoryId != null &&
        !ids.contains(_selectedExternalCategoryId)) {
      _selectedExternalCategoryId = null;
    }
  }

  Map<String, dynamic> _buildSourceContext({required String walletId}) {
    final user = _currentUserContext();
    return {
      'selection': 'OPERATING_WALLET',
      if (walletId.isNotEmpty) 'wallet_id': walletId,
      if (user['customer_id'] is String) 'customer_id': user['customer_id'],
      if (user['id'] is String) 'user_id': user['id'],
    };
  }

  Map<String, dynamic> _buildInternalSourcePayloadParts() {
    final selected = _selectedInternalSourceWallet();
    if (selected != null) {
      final walletId = _transferSourceWalletId(selected);
      final walletType = _internalSubWalletType(selected);
      final goalId = _goalIdFromSourceWallet(selected);
      return {
        'walletType': walletType,
        'sourceWalletId': walletId,
        if (goalId.isNotEmpty) 'sourceGoalId': goalId,
        if (goalId.isNotEmpty) 'source_goal_id': goalId,
        'source_wallet': {
          'selection': walletType,
          if (walletId.isNotEmpty) 'wallet_id': walletId,
          'wallet_type': walletType,
          if (goalId.isNotEmpty) 'goal_id': goalId,
        },
        ..._buildSourceTopLevelFields(walletId: walletId),
      };
    }

    final operatingWalletId = _resolveOperatingWalletId();
    return {
      'walletType': 'internal_vault',
      'source_wallet': _buildSourceContext(walletId: operatingWalletId),
      ..._buildSourceTopLevelFields(walletId: operatingWalletId),
    };
  }

  Map<String, dynamic> _buildSourceTopLevelFields({required String walletId}) {
    final user = _currentUserContext();
    return {
      if (walletId.isNotEmpty) 'source_wallet_id': walletId,
      if (walletId.isNotEmpty) 'wallet_id': walletId,
      if (user['customer_id'] is String)
        'source_customer_id': user['customer_id'],
      if (user['id'] is String) 'source_user_id': user['id'],
    };
  }

  String _resolveOperatingWalletId() {
    final session = context.read<AuthController>().session;
    final user = session['user'];
    if (user is Map) {
      final fromUser = _pickString([
        user['operating_wallet_id'],
        user['operatingWalletId'],
        user['default_wallet_id'],
        user['defaultWalletId'],
        user['wallet_id'],
        user['walletId'],
      ]);
      if (fromUser.isNotEmpty) return fromUser;
    }

    final internalWallets = _backendWallets
        .where(
          (wallet) => _matchesSourceWalletType(
            wallet,
            _ExternalSourceWalletType.internal,
          ),
        )
        .toList();
    for (final wallet in internalWallets) {
      if (_isLikelyOperatingWallet(wallet)) {
        final id = _walletId(wallet);
        if (id.isNotEmpty) return id;
      }
    }
    for (final wallet in internalWallets) {
      final id = _walletId(wallet);
      if (id.isNotEmpty) return id;
    }

    for (final wallet in _backendWallets) {
      final id = _walletId(wallet);
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  String _categoryId(Map<String, dynamic> category) {
    return _pickString([
      category['id'],
      category['category_id'],
      category['categoryId'],
    ]);
  }

  String _categoryName(Map<String, dynamic> category) {
    return _pickString([
      category['name'],
      category['category_name'],
      category['title'],
    ]);
  }

  double _doubleFromDynamic(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final normalized = value.replaceAll(',', '').trim();
        final parsed = double.tryParse(normalized);
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  Map<String, dynamic>? _selectedBudgetCategory(String? categoryId) {
    if (categoryId == null || categoryId.trim().isEmpty) return null;
    for (final category in _budgetCategories) {
      if (_categoryId(category) == categoryId) return category;
    }
    return null;
  }

  double _categoryBudgetAmount(Map<String, dynamic> category) {
    return _firstAmountOrZero([
      category['budget'],
      category['limit_amount'],
      category['limitAmount'],
    ]);
  }

  double _categorySpentAmount(Map<String, dynamic> category) {
    return _firstAmountOrZero([
      category['spent'],
      category['spent_amount'],
      category['spentAmount'],
      category['current'],
    ]);
  }

  double _categoryRemainingAmount(Map<String, dynamic> category) {
    final remaining =
        _categoryBudgetAmount(category) - _categorySpentAmount(category);
    return remaining < 0 ? 0 : remaining;
  }

  bool _categoryHardLimit(Map<String, dynamic> category) {
    return _boolFrom(
          category['hard_limit'] ??
              category['hardLimit'] ??
              category['strict_limit'] ??
              category['strictLimit'],
        ) ??
        false;
  }

  String _categoryPeriodLabel(Map<String, dynamic> category) {
    final raw = _pickString([
      category['period'],
      category['budget_period'],
      category['window'],
    ]);
    final normalized = _normalizeBudgetPeriod(raw);
    final interval = _budgetInterval(category);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    if (sw) {
      final unit = _swBudgetUnit(normalized);
      if (interval <= 1) return 'Kila $unit';
      return 'Kila $unit $interval';
    }
    if (interval <= 1) return _enBudgetLabel(normalized);
    final unit = _enBudgetUnit(normalized);
    final plural = interval == 1 ? unit : '${unit}s';
    return 'Every $interval $plural';
  }

  String _normalizeBudgetPeriod(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('day')) return 'day';
    if (value.contains('week')) return 'week';
    if (value.contains('year') || value.contains('annual')) return 'year';
    return 'month';
  }

  int _budgetInterval(Map<String, dynamic> category) {
    final raw = _pickString([
      category['budget_interval'],
      category['interval'],
      category['period_interval'],
      category['cadence'],
    ]);
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  String _enBudgetUnit(String period) {
    switch (period) {
      case 'day':
        return 'day';
      case 'week':
        return 'week';
      case 'year':
        return 'year';
      case 'month':
      default:
        return 'month';
    }
  }

  String _enBudgetLabel(String period) {
    switch (period) {
      case 'day':
        return 'Daily';
      case 'week':
        return 'Weekly';
      case 'year':
        return 'Yearly';
      case 'month':
      default:
        return 'Monthly';
    }
  }

  String _swBudgetUnit(String period) {
    switch (period) {
      case 'day':
        return 'siku';
      case 'week':
        return 'wiki';
      case 'year':
        return 'mwaka';
      case 'month':
      default:
        return 'mwezi';
    }
  }

  double _firstAmountOrZero(List<dynamic> values) {
    return _firstAmountOrNull(values) ?? 0;
  }

  Future<bool> _validateBudgetSelection({
    required String? categoryId,
    required double amount,
  }) async {
    final category = _selectedBudgetCategory(categoryId);
    final budgetLockEnabled = context
        .read<AppSettingsController>()
        .budgetLockEnabled;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    if (budgetLockEnabled && category == null) {
      _showSnack(
        sw
            ? 'Chagua kundi la bajeti ili kuendelea.'
            : 'Please select a budget category to continue.',
      );
      return false;
    }
    if (category == null) return true;
    final remaining = _categoryRemainingAmount(category);
    final hardLimit = _categoryHardLimit(category);
    final l10n = AppLocalizations.of(context)!;

    if (budgetLockEnabled) {
      if (remaining <= 0 || amount > remaining) {
        _showSnack(
          sw
              ? 'Bajeti hii imefikia kikomo chake.'
              : 'This budget has reached its limit.',
        );
        return false;
      }
    }

    if (remaining <= 0 && hardLimit) {
      _showSnack(
        l10n.sendMoneyBudgetHardLimitMessage(
          _categoryName(category),
          _formatCurrencyForDisplay(remaining),
        ),
      );
      return false;
    }

    if (amount > remaining && remaining > 0) {
      if (hardLimit) {
        _showSnack(
          l10n.sendMoneyBudgetHardLimitMessage(
            _categoryName(category),
            _formatCurrencyForDisplay(remaining),
          ),
        );
        return false;
      }
      return _confirmSoftBudgetOverspend(category, remaining);
    }

    return true;
  }

  Future<bool> _confirmSoftBudgetOverspend(
    Map<String, dynamic> category,
    double remaining,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.sendMoneyBudgetSoftLimitTitle),
          content: Text(
            l10n.sendMoneyBudgetSoftLimitBody(
              _categoryName(category),
              _formatCurrencyForDisplay(remaining),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.sendMoneyBudgetSoftLimitContinue),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _budgetSummaryCard(String? categoryId) {
    final category = _selectedBudgetCategory(categoryId);
    if (category == null) return const SizedBox.shrink();
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final budget = _categoryBudgetAmount(category);
    final spent = _categorySpentAmount(category);
    final remaining = _categoryRemainingAmount(category);
    final hardLimit = _categoryHardLimit(category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hardLimit ? ui.dangerSoft : ui.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hardLimit ? ui.danger : ui.warning).withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sendMoneyBudgetSummaryTitle(_categoryName(category)),
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.sendMoneyBudgetSummaryBody(
              _formatCurrencyForDisplay(budget),
              _formatCurrencyForDisplay(spent),
              _formatCurrencyForDisplay(remaining),
            ),
            style: TextStyle(color: ui.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            hardLimit
                ? l10n.sendMoneyBudgetHardLimitLabel(
                    _categoryPeriodLabel(category),
                  )
                : l10n.sendMoneyBudgetSoftLimitLabel(
                    _categoryPeriodLabel(category),
                  ),
            style: TextStyle(
              color: hardLimit ? ui.danger : ui.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrencyForDisplay(double amount) {
    if (context.read<AppSettingsController>().hideBalances) {
      return AppSettingsController.hiddenBalanceText;
    }
    return formatAppBalanceAmount(
      amount,
      _resolveCurrency(),
      locale: _localeTag,
    );
  }

  String _mapExternalApiType(_ExternalTransferRail rail) {
    return 'EXTERNAL_PAYMENT';
  }

  String _generateIdempotencyKey() {
    final random = Random.secure();
    final a = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final b = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'tx-$ts-$a$b';
  }

  String _payloadSignature(Map<String, dynamic> payload) {
    final normalized = _normalizeJson(payload);
    return jsonEncode(normalized);
  }

  dynamic _normalizeJson(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final keys = map.keys.toList()..sort();
      final sorted = <String, dynamic>{};
      for (final key in keys) {
        sorted[key] = _normalizeJson(map[key]);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_normalizeJson).toList();
    }
    return value;
  }

  _PendingSettleAttempt _resolvePendingAttempt(
    Map<String, dynamic> payload, {
    required bool external,
  }) {
    final signature = _payloadSignature(payload);
    final now = DateTime.now();
    final pending = external
        ? _pendingExternalAttempt
        : _pendingInternalAttempt;
    if (pending != null &&
        pending.payloadSignature == signature &&
        now.difference(pending.createdAt) < const Duration(minutes: 10)) {
      return pending;
    }
    final attempt = _PendingSettleAttempt(
      payloadSignature: signature,
      idempotencyKey: _generateIdempotencyKey(),
      createdAt: now,
    );
    if (external) {
      _pendingExternalAttempt = attempt;
    } else {
      _pendingInternalAttempt = attempt;
    }
    return attempt;
  }

  void _clearPendingAttempt({required bool external}) {
    if (external) {
      _pendingExternalAttempt = null;
    } else {
      _pendingInternalAttempt = null;
    }
  }

  bool _shouldKeepPendingAttempt(Object error) {
    return error is _TransientNetworkException ||
        error is _TransientSettleException ||
        error is _ChallengeCancelledException;
  }

  void _resetInternalForm() {
    _recipientIdController.clear();
    _internalAmountController.clear();
    _internalNoteController.clear();
    setState(() {
      _lookupError = null;
      _recipientPreview = null;
      _lastLookupId = '';
      _lookupGeneration++;
    });
  }

  void _resetExternalForm() {
    _externalRecipientController.clear();
    _externalProviderController.text =
        widget.externalExperience == ExternalExperience.withdraw &&
            _externalRail == _ExternalTransferRail.externalAgent
        ? _withdrawAgentProviders.first
        : '';
    _selectedExternalProviderCode =
        widget.externalExperience == ExternalExperience.withdraw &&
            _externalRail == _ExternalTransferRail.externalAgent
        ? 'ORBI_AGENT'
        : null;
    _externalCardNoController.clear();
    _externalAmountController.clear();
    _externalNoteController.clear();
    setState(() {
      _selectedExternalSourceWalletId = null;
      _agentLookupLoading = false;
      _agentLookupError = null;
      _orbiAgentPreview = null;
      _agentLookupGeneration++;
    });
    _syncSelectedSourceWallet();
  }

  String _externalRailLabel(_ExternalTransferRail rail) {
    switch (rail) {
      case _ExternalTransferRail.bank:
        return AppLocalizations.of(context)!.sendMoneyRailBank;
      case _ExternalTransferRail.mobileWallet:
        return widget.externalExperience == ExternalExperience.withdraw
            ? 'Mobile Money'
            : AppLocalizations.of(context)!.sendMoneyRailMobileWallet;
      case _ExternalTransferRail.externalAgent:
        return _isSw ? 'ORBI Wakala' : 'ORBI Agent';
      case _ExternalTransferRail.paypal:
        return AppLocalizations.of(context)!.sendMoneyRailPaypal;
      case _ExternalTransferRail.crypto:
        return AppLocalizations.of(context)!.sendMoneyRailCrypto;
    }
  }

  void _applyExternalRailSelection(_ExternalTransferRail rail) {
    _externalRail = rail;
    _externalCardNoController.clear();
    _agentLookupDebounce?.cancel();
    _agentLookupLoading = false;
    _agentLookupError = null;
    _orbiAgentPreview = null;
    _agentLookupGeneration++;
    if (widget.externalExperience == ExternalExperience.withdraw &&
        rail == _ExternalTransferRail.externalAgent) {
      _externalProviderController.text = _withdrawAgentProviders.first;
      _selectedExternalProviderCode = 'ORBI_AGENT';
    } else {
      _externalProviderController.clear();
      _selectedExternalProviderCode = null;
    }
  }

  String _externalRailPrefix(_ExternalTransferRail rail) {
    switch (rail) {
      case _ExternalTransferRail.bank:
        return 'bank';
      case _ExternalTransferRail.mobileWallet:
        return 'mobile_wallet';
      case _ExternalTransferRail.externalAgent:
        return 'external_agent';
      case _ExternalTransferRail.paypal:
        return 'paypal';
      case _ExternalTransferRail.crypto:
        return 'crypto';
    }
  }

  String _externalSourceWalletValue(_ExternalSourceWalletType source) {
    switch (source) {
      case _ExternalSourceWalletType.internal:
        return 'internal';
      case _ExternalSourceWalletType.externalMobileWallet:
        return 'external_mobile_wallet';
      case _ExternalSourceWalletType.externalBank:
        return 'external_bank';
    }
  }

  String _externalSourceWalletLabel(_ExternalSourceWalletType source) {
    switch (source) {
      case _ExternalSourceWalletType.internal:
        return AppLocalizations.of(context)!.sendMoneySourceTypeInternal;
      case _ExternalSourceWalletType.externalMobileWallet:
        return AppLocalizations.of(
          context,
        )!.sendMoneySourceTypeExternalMobileWallet;
      case _ExternalSourceWalletType.externalBank:
        return AppLocalizations.of(context)!.sendMoneySourceTypeExternalBank;
    }
  }

  Future<void> _submitExternalTransfer() async {
    _markUserActivity();
    if (_isSubmittingExternal || _isSubmittingInternal) return;
    final valid = _externalFormKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (widget.externalExperience == ExternalExperience.withdraw &&
        _externalProviderController.text.trim().isEmpty) {
      await OrbiErrorDialog.show(
        context: context,
        title: _isSw ? 'Provider inahitajika' : 'Provider required',
        message: _isSw
            ? 'Chagua provider wa withdraw kabla ya kuendelea.'
            : 'Choose a withdraw provider before continuing.',
        icon: Icons.storefront_rounded,
      );
      return;
    }
    if (widget.externalExperience == ExternalExperience.withdraw &&
        _externalRail == _ExternalTransferRail.externalAgent &&
        _orbiAgentPreview == null) {
      await OrbiErrorDialog.show(
        context: context,
        title: _isSw ? 'Agent hajathibitishwa' : 'Agent not verified',
        message: _isSw
            ? 'Weka Agent ID Number sahihi ili ORBI ithibitishe taarifa za wakala kwanza.'
            : 'Enter a valid Agent ID number so ORBI can verify the agent details first.',
        icon: Icons.qr_code_scanner_rounded,
      );
      return;
    }
    final transferCurrency = _requireTransferCurrency();
    if (transferCurrency == null) return;

    final token = await _requestTransferAccessToken(showDialogOnFailure: true);
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      return;
    }
    final amount = AmountInputFormatter.tryParse(
      _externalAmountController.text,
    );
    if (amount == null || amount <= 0) {
      await OrbiErrorDialog.show(
        context: context,
        title: 'Invalid Amount',
        message: AppLocalizations.of(context)!.sendMoneyEnterValidAmountMessage,
        icon: Icons.attach_money_rounded,
      );
      return;
    }
    final budgetProceed = await _validateBudgetSelection(
      categoryId: _selectedExternalCategoryId,
      amount: amount,
    );
    if (!budgetProceed) return;

    final effectiveWalletId = _effectiveExternalWalletId();
    final unlocked = await _ensureWalletUnlockedForTransfer(
      walletId: effectiveWalletId,
      wallet: _effectiveExternalWallet(),
    );
    if (!unlocked) return;

    setState(() => _isSubmittingExternal = true);
    try {
      final payload = await _withRequiredTransactionGeo(
        _buildExternalSettlePayload(),
        allowNetworkFallback: false,
      );
      payload['currency'] = transferCurrency;
      final preview = await _fetchTransactionPreview(token, payload);
      payload['quoteId'] = preview.quoteId;
      payload['quoteHash'] = preview.quoteHash;
      payload['preview_snapshot'] = {
        'quoteId': preview.quoteId,
        'quoteHash': preview.quoteHash,
        'status': preview.status,
        'security_decision': preview.securityDecision,
        'breakdown': {
          'base': preview.baseAmount,
          'tax': preview.taxAmount,
          'fee': preview.feeAmount,
          'total': preview.totalAmount,
        },
      };
      final attempt = _resolvePendingAttempt(payload, external: true);
      final response = await _submitTransactionWith2Fa(
        token,
        payload,
        idempotencyKey: attempt.idempotencyKey,
      );
      _clearPendingAttempt(external: true);
      if (!mounted) return;
      await _showSettleResultDialog(
        success: true,
        title: AppLocalizations.of(
          context,
        )!.sendMoneyTransactionSuccessfulTitle,
        message: _settleSuccessMessage(response, external: true),
        response: response,
        requestPayload: payload,
      );
      if (mounted) {
        _resetExternalForm();
      }
    } catch (e) {
      if (!_shouldKeepPendingAttempt(e)) {
        _clearPendingAttempt(external: true);
      }
      if (!mounted) return;
      if (e is TransactionGeoException) {
        setState(() => _isSubmittingExternal = false);
        await _showLocationRequiredDialog(e.message);
        return;
      }
      final sourceError = _normalizeTransferErrorMessage(
        e,
        fallback: AppLocalizations.of(
          context,
        )!.sendMoneyExternalSubmitFailedMessage,
      );
      setState(() => _isSubmittingExternal = false);
      await _showSettleResultDialog(
        success: false,
        title: AppLocalizations.of(context)!.sendMoneyTransactionFailedTitle,
        message: sourceError,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingExternal = false);
      }
    }
  }

  Future<void> _showLocationRequiredDialog(String message) async {
    if (!mounted) return;
    await OrbiErrorDialog.show(
      context: context,
      title: _isSw ? 'Location inahitajika' : 'Location required',
      message: _isSw
          ? 'Washa Location Services ili ORBI ikamilishe muamala huu kwa usalama.'
          : message,
      icon: Icons.location_on_rounded,
      actionLabel: _isSw ? 'Fungua Settings' : 'Open settings',
      onAction: () {
        Geolocator.openLocationSettings();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GoalsController>();
    context.select<AppSettingsController, bool>(
      (settings) => settings.hideBalances,
    );
    final ui = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);
    final accent = _flowAccent;
    final isBusy =
        _isPreviewing || _isSubmittingInternal || _isSubmittingExternal;
    return OrbiLoadingOverlay(
      loading: isBusy,
      message: _transactionBusyMessage,
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      child: PopScope(
        canPop: !isBusy,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SvgPicture.asset(
                    widget.iconAssetPath ??
                        (widget.startInExternalMode
                            ? 'assets/icons/transfer.svg'
                            : 'assets/icons/send.svg'),
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                  ),
                ),
                Flexible(
                  child: Text(
                    widget.titleOverride ??
                        AppLocalizations.of(context)!.sendMoneyTitle,
                  ),
                ),
              ],
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: ui.textPrimary,
          ),
          body: OrbiBackground(
            padding: EdgeInsets.zero,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: OrbiResponsiveContent(
                  padding: OrbiResponsive.pagePadding(
                    context,
                    top: 10,
                    bottom: 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.externalOnly) ...[
                        _staggeredReveal(
                          index: 0,
                          child: _TransferModeSwitcher(
                            mode: _mode,
                            onChanged: (mode) {
                              if (mode == _mode) return;
                              setState(() => _mode = mode);
                              _entryController.forward(from: 0);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _staggeredReveal(
                        index: widget.externalOnly ? 0 : 1,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _mode == _TransferMode.internalP2P
                              ? _buildInternalForm(
                                  key: const ValueKey('internal'),
                                )
                              : _buildExternalForm(
                                  key: const ValueKey('external'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _transactionBusyMessage {
    if (_isPreviewing) {
      return AppLocalizations.of(context)!.sendMoneyPreparingPreviewLabel;
    }
    return AppLocalizations.of(context)!.sendMoneySubmittingLabel;
  }

  // Retained for alternate entry experiments where the send flow uses a compact
  // guidance card instead of the full movement hero.
  // ignore: unused_element
  Widget _tipCard() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.card.withValues(alpha: 0.98),
            ui.cardStrong.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isSw
                  ? 'Kidokezo: Chagua mpokeaji sahihi ili kutuma pesa kwa usalama.'
                  : 'Tip: Choose the correct recipient to send money securely.',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    final isWithdraw = widget.externalExperience == ExternalExperience.withdraw;
    return OrbiFeatureCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: isWithdraw ? OrbiTheme.uiOf(context).iconMuted : _flowAccent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: child,
    );
  }

  Widget _staggeredReveal({required int index, required Widget child}) {
    final start = (0.08 * index).clamp(0.0, 0.78);
    final end = (start + 0.34).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  Widget _amountPresetRow({
    required TextEditingController controller,
    required String currency,
  }) {
    final ui = OrbiTheme.uiOf(context);
    const presets = <double>[5000, 20000, 50000, 100000];
    final selectedValue = AmountInputFormatter.tryParse(controller.text) ?? -1;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((amount) {
        final selected = (selectedValue - amount).abs() < 0.0001;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            controller.text = AmountInputFormatter.format(
              amount.toStringAsFixed(0),
            );
            _markUserActivity();
            if (mounted) setState(() {});
          },
          label: Text(
            formatAppBalanceAmount(amount, currency, locale: 'en_US'),
          ),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: selected ? ui.textPrimary : ui.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          selectedColor: ui.iconMuted.withValues(alpha: 0.14),
          backgroundColor: ui.cardMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: selected ? ui.iconMuted.withValues(alpha: 0.3) : ui.border,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _primaryActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? accentOverride,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final accent = accentOverride ?? _flowAccent;
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(accent, Colors.white, 0.10) ?? accent,
                    Color.lerp(accent, Colors.black, 0.10) ?? accent,
                  ],
                )
              : null,
          color: enabled ? null : ui.cardStrong,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.26),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: enabled ? Colors.white : ui.textSoft),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? Colors.white : ui.textSoft,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInternalForm({Key? key}) {
    return Form(
      key: _internalFormKey,
      child: _formSurface(
        child: Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: AppLocalizations.of(
                context,
              )!.sendMoneySectionRecipientTitle,
              icon: Icons.person_search_rounded,
              subtitle: AppLocalizations.of(
                context,
              )!.sendMoneySectionRecipientSubtitle,
              child: Column(
                children: [
                  TextFormField(
                    controller: _recipientIdController,
                    onChanged: _onRecipientIdChanged,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [_RecipientSearchInputFormatter()],
                    decoration: _fieldDecoration(
                      label: AppLocalizations.of(
                        context,
                      )!.sendMoneyRecipientFieldLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.sendMoneyRecipientFieldHint,
                      icon: Icons.badge_outlined,
                      helperText: AppLocalizations.of(
                        context,
                      )!.sendMoneySearchMinCharsMessage,
                      suffixIcon: _lookupLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) {
                      final input = (value ?? '').trim();
                      if (input.isEmpty) {
                        return AppLocalizations.of(
                          context,
                        )!.sendMoneyRecipientRequiredMessage;
                      }
                      if (input.length < 5) {
                        return AppLocalizations.of(
                          context,
                        )!.sendMoneySearchMinCharsLongMessage;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_lookupError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _lookupError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_recipientPreview != null) ...[
                    const SizedBox(height: 12),
                    _RecipientPreviewCard(data: _recipientPreview!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: AppLocalizations.of(
                context,
              )!.sendMoneySectionSourceWalletTitle,
              icon: Icons.account_balance_wallet_rounded,
              subtitle: AppLocalizations.of(
                context,
              )!.sendMoneySectionSourceWalletSubtitle,
              child: _buildInternalSourceWalletList(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: AppLocalizations.of(
                context,
              )!.sendMoneySectionAmountNoteTitle,
              icon: Icons.payments_rounded,
              subtitle: AppLocalizations.of(
                context,
              )!.sendMoneySectionAmountNoteSubtitle,
              child: Column(
                children: [
                  OrbiAmountField(
                    controller: _internalAmountController,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [AmountInputFormatter()],
                    label: AppLocalizations.of(context)!.sendMoneyAmountLabel,
                    currency: resolveCurrencyDisplaySymbol(
                      _resolveSelectedSourceCurrency(),
                    ),
                    validator: (value) {
                      final parsed = AmountInputFormatter.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return AppLocalizations.of(
                          context,
                        )!.sendMoneyEnterValidAmountMessage;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _amountPresetRow(
                      controller: _internalAmountController,
                      currency: _resolveCurrency(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _budgetCategoryField(
                    value: _selectedInternalCategoryId,
                    onChanged: (next) {
                      setState(() => _selectedInternalCategoryId = next);
                    },
                  ),
                  const SizedBox(height: 10),
                  _budgetSummaryCard(_selectedInternalCategoryId),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _internalNoteController,
                    maxLines: 3,
                    decoration: _fieldDecoration(
                      label: AppLocalizations.of(
                        context,
                      )!.sendMoneyDescriptionOptionalLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.sendMoneyDescriptionHint,
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 46),
                        child: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: _primaryActionButton(
                onPressed: _isPreviewing ? null : _submitInternalTransfer,
                icon: Icons.arrow_forward_rounded,
                label: AppLocalizations.of(
                  context,
                )!.sendMoneyContinueTransferLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalSourceWalletList() {
    final ui = OrbiTheme.uiOf(context);
    final subWallets = _internalSubWallets();
    if (subWallets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ui.cardMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ui.border),
        ),
        child: Text(
          AppLocalizations.of(context)!.sendMoneyNoGoalWalletsMessage,
          style: TextStyle(color: ui.textMuted, fontSize: 12),
        ),
      );
    }

    final selectedWallet = _selectedInternalSourceWallet();
    final selectedCard = selectedWallet != null
        ? _internalSourceCard(
            title: _walletName(selectedWallet).isEmpty
                ? _walletId(selectedWallet)
                : _walletName(selectedWallet),
            subtitle: AppLocalizations.of(
              context,
            )!.sendMoneyWalletIdLabel(_walletId(selectedWallet)),
            balance: _walletBalanceLabel(selectedWallet),
            badge: _localizedInternalSubWalletType(selectedWallet),
            selected: true,
            onTap: () => setState(() => _internalSourceWalletExpanded = true),
          )
        : _internalSourceCard(
            title: AppLocalizations.of(
              context,
            )!.sendMoneyOperatingWalletAutoTitle,
            subtitle: AppLocalizations.of(
              context,
            )!.sendMoneyOperatingWalletAutoSubtitle,
            balance: '',
            badge: AppLocalizations.of(context)!.sendMoneySourceBadgeOperating,
            selected: _selectedInternalSourceWalletId == null,
            onTap: () => setState(() => _internalSourceWalletExpanded = true),
          );

    if (!_internalSourceWalletExpanded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _internalSourceWalletExpanded = true),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ui.border),
              ),
              child: selectedCard,
            ),
          ),
          if (_selectedInternalSourceIsGoal()) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ui.warningSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ui.warning.withValues(alpha: 0.32)),
              ),
              child: Text(
                AppLocalizations.of(context)!.sendMoneyGoalSourceInlineWarning,
                style: TextStyle(
                  color: ui.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final cards = <Widget>[
      _internalSourceCard(
        title: AppLocalizations.of(context)!.sendMoneyOperatingWalletAutoTitle,
        subtitle: AppLocalizations.of(
          context,
        )!.sendMoneyOperatingWalletAutoSubtitle,
        balance: '',
        badge: AppLocalizations.of(context)!.sendMoneySourceBadgeOperating,
        selected: _selectedInternalSourceWalletId == null,
        isOperating: true,
        onTap: () {
          setState(() {
            _selectedInternalSourceWalletId = null;
            _internalSourceWalletExpanded = false;
          });
        },
      ),
      ...subWallets.map((wallet) {
        final id = _walletId(wallet);
        return _internalSourceCard(
          title: _walletName(wallet).isEmpty ? id : _walletName(wallet),
          subtitle: AppLocalizations.of(context)!.sendMoneyWalletIdLabel(id),
          balance: _walletBalanceLabel(wallet),
          badge: _localizedInternalSubWalletType(wallet),
          selected: _selectedInternalSourceWalletId == id,
          onTap: () {
            setState(() {
              _selectedInternalSourceWalletId = id;
              _internalSourceWalletExpanded = false;
            });
          },
        );
      }),
    ];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border, width: 1.2),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }

  Widget _budgetCategoryField({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    if (_loadingBudgetCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_budgetCategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ui.cardMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ui.border),
        ),
        child: Text(
          _budgetCategoryError ?? l10n.sendMoneyNoBudgetCategoriesMessage,
          style: TextStyle(color: ui.textMuted, fontSize: 12),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      dropdownColor: ui.card,
      decoration: _fieldDecoration(
        label: l10n.sendMoneyBudgetCategoryLabel,
        hint: l10n.sendMoneyBudgetCategoryHint,
        icon: Icons.pie_chart_outline_rounded,
        helperText: l10n.sendMoneyBudgetCategoryOptionalHelper,
      ),
      items: [
        DropdownMenuItem<String>(
          value: '',
          child: Text(l10n.sendMoneyBudgetCategoryNone),
        ),
        ..._budgetCategories.map((category) {
          final id = _categoryId(category);
          return DropdownMenuItem<String>(
            value: id,
            child: Text(
              _categoryName(category).isEmpty ? id : _categoryName(category),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (next) =>
          onChanged(next == null || next.isEmpty ? null : next),
    );
  }

  Widget _internalSourceCard({
    required String title,
    required String subtitle,
    required String balance,
    required String badge,
    required bool selected,
    required VoidCallback onTap,
    bool isOperating = false,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final accent = selected
        ? ui.accent
        : isOperating
        ? ui.success
        : ui.iconMuted;
    final backColor = selected
        ? ui.accentSoft
        : isOperating
        ? ui.successSoft
        : ui.cardMuted;
    final borderColor = selected
        ? ui.accent
        : isOperating
        ? ui.success
        : ui.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selected
                    ? Icons.check_rounded
                    : Icons.account_balance_wallet_rounded,
                size: 16,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ui.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (balance.isNotEmpty)
                  Text(
                    balance,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

  Widget _buildExternalForm({Key? key}) {
    final sectionGap = <Widget>[const SizedBox(height: 14)];
    final transferSections = <Widget>[
      _externalRailProviderSection(),
      ...sectionGap,
      _externalDestinationSection(),
      ...sectionGap,
      _externalAmountNoteSection(),
      ...sectionGap,
      _externalFundingSection(),
    ];
    final withdrawSections = <Widget>[
      _externalRailProviderSection(),
      ...sectionGap,
      _externalDestinationSection(),
      ...sectionGap,
      _externalFundingSection(),
      ...sectionGap,
      _externalAmountNoteSection(),
    ];
    final defaultSections = <Widget>[
      _externalRailProviderSection(),
      ...sectionGap,
      _externalDestinationSection(),
      ...sectionGap,
      _externalFundingSection(),
      ...sectionGap,
      _externalAmountNoteSection(),
    ];

    final sections = switch (widget.externalExperience) {
      ExternalExperience.transfer => transferSections,
      ExternalExperience.withdraw => withdrawSections,
      ExternalExperience.send => defaultSections,
    };

    return Form(
      key: _externalFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...sections,
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: _primaryActionButton(
                    onPressed: (_isPreviewing || _isSubmittingExternal)
                        ? null
                        : _submitExternalTransfer,
                    icon: _externalContinueIcon,
                    label: _externalContinueLabel,
                    accentOverride: _activeExternalProviderAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<GatewayProvider> _externalRailProviders(_ExternalTransferRail rail) {
    switch (rail) {
      case _ExternalTransferRail.externalAgent:
        return widget.externalExperience == ExternalExperience.withdraw
            ? [_orbiAgentProvider()]
            : const [];
      case _ExternalTransferRail.bank:
      case _ExternalTransferRail.mobileWallet:
      case _ExternalTransferRail.crypto:
        return _providersForRail(rail);
      case _ExternalTransferRail.paypal:
        return const [];
    }
  }

  List<GatewayProvider> _providersForRail(_ExternalTransferRail rail) {
    return _externalPaymentProviders
        .where((provider) {
          switch (rail) {
            case _ExternalTransferRail.bank:
              return provider.supportsBank;
            case _ExternalTransferRail.mobileWallet:
              return provider.supportsMobileMoney;
            case _ExternalTransferRail.crypto:
              return provider.supportsCrypto;
            case _ExternalTransferRail.paypal:
              return provider.type.toUpperCase().contains('PAYPAL') ||
                  provider.channels
                      .map((channel) => channel.toLowerCase())
                      .contains('paypal');
            case _ExternalTransferRail.externalAgent:
              return false;
          }
        })
        .toList(growable: false);
  }

  GatewayProvider _orbiAgentProvider() {
    return const GatewayProvider(
      id: 'ORBI_AGENT',
      name: 'ORBI Wakala',
      brandName: 'ORBI Wakala',
      type: 'EXTERNAL_AGENT',
      group: 'External Agents',
      logicType: 'INTERNAL_AGENT',
      status: 'ACTIVE',
      supportedCurrencies: ['TZS'],
      icon: null,
      color: '#0F9D7A',
      checkoutMode: null,
      channels: ['external_agent'],
      sortOrder: 0,
      metadata: {'internal_capability': 'ORBI_AGENT_CASH_OUT'},
    );
  }

  Widget _externalProviderChoiceCard(GatewayProvider provider) {
    final providerLabel = provider.brandLabel;
    final ui = OrbiTheme.uiOf(context);
    final selected = _selectedExternalProviderCode == provider.id;
    final providerColor =
        provider.colorValue ?? _movementProviderColor(providerLabel);
    final country = ProviderAssetResolver.resolveCountry(
      context.read<AuthController>(),
    );
    final assetCandidates = ProviderAssetResolver.movementAssetCandidates(
      country: country,
      flow: _movementAssetFlow,
      category: _movementAssetCategory,
      providerName: providerLabel,
    );

    return InkWell(
      onTap: () {
        setState(() {
          _externalProviderController.text = providerLabel;
          _selectedExternalProviderCode = provider.id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: ui.card.withValues(alpha: 0.99),
          borderRadius: BorderRadius.circular(14),
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
              blurRadius: selected ? 11 : 8,
              offset: const Offset(0, 5),
            ),
            if (selected)
              BoxShadow(
                color: providerColor.withValues(alpha: 0.10),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 62,
              child: _movementAssetPreview(
                candidates: assetCandidates,
                fallbackIcon: _externalRail == _ExternalTransferRail.bank
                    ? Icons.account_balance_rounded
                    : _externalRail == _ExternalTransferRail.externalAgent
                    ? Icons.storefront_rounded
                    : Icons.phone_android_rounded,
                tint: ui.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              providerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? providerColor.withValues(alpha: 0.95)
                    : ui.textMuted,
                fontSize: 8,
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

  Widget _movementAssetPreview({
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

  Widget _directStepHeader({
    required String step,
    required String title,
    required Color accent,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalRailProviderSection() {
    final accent = _flowAccent;
    final isWithdraw = widget.externalExperience == ExternalExperience.withdraw;
    final isTransfer = widget.externalExperience == ExternalExperience.transfer;
    final providersForRail = _externalRailProviders(_externalRail);
    return _sectionCard(
      title: _externalRailSectionTitle,
      icon: Icons.route_rounded,
      subtitle: _externalRailSectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWithdraw)
            _directStepHeader(
              step: '1',
              title: _isSw ? 'Njia na provider' : 'Route & provider',
              accent: accent,
            )
          else if (isTransfer)
            _directStepHeader(
              step: '1',
              title: _isSw ? 'Njia na provider' : 'Route & provider',
              accent: accent,
            ),
          if (isWithdraw)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 150).floor().clamp(
                  1,
                  3,
                );
                final spacing = 10.0;
                final itemWidth =
                    ((constraints.maxWidth - (spacing * (columns - 1))) /
                            columns)
                        .toDouble();
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _availableExternalRails.map((rail) {
                    return SizedBox(
                      width: itemWidth,
                      child: _withdrawRailCard(rail),
                    );
                  }).toList(),
                );
              },
            )
          else if (isTransfer)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 150).floor().clamp(
                  2,
                  4,
                );
                final spacing = 10.0;
                final itemWidth =
                    ((constraints.maxWidth - (spacing * (columns - 1))) /
                            columns)
                        .toDouble();
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _availableExternalRails.map((rail) {
                    return SizedBox(
                      width: itemWidth,
                      child: _transferRailCard(rail),
                    );
                  }).toList(),
                );
              },
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableExternalRails.map((rail) {
                final ui = OrbiTheme.uiOf(context);
                final selected = rail == _externalRail;
                return ChoiceChip(
                  selected: selected,
                  label: Text(_externalRailLabel(rail)),
                  onSelected: (_) =>
                      setState(() => _applyExternalRailSelection(rail)),
                  labelStyle: TextStyle(
                    color: selected ? ui.textPrimary : ui.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  selectedColor: accent.withValues(alpha: 0.14),
                  backgroundColor: _flowAccentFaint.withValues(alpha: 0.54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: selected ? accent : ui.border),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          if (_loadingExternalPaymentProviders) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 2,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.10),
            ),
            const SizedBox(height: 8),
            Text(
              _isSw
                  ? 'Inapakia njia zilizowezeshwa na ORBI Core...'
                  : 'Loading ORBI Core enabled routes...',
              style: TextStyle(
                color: OrbiTheme.uiOf(context).textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_externalPaymentProviderError != null) ...[
            const SizedBox(height: 12),
            Text(
              _externalPaymentProviderError!,
              style: TextStyle(
                color: OrbiTheme.uiOf(context).danger,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if ((_externalRail == _ExternalTransferRail.bank ||
                  _externalRail == _ExternalTransferRail.mobileWallet) ||
              (widget.externalExperience != ExternalExperience.withdraw &&
                  _externalRail == _ExternalTransferRail.externalAgent)) ...[
            const SizedBox(height: 12),
            if (providersForRail.isEmpty && !_loadingExternalPaymentProviders)
              _noConfiguredRailNotice()
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: providersForRail
                    .map((provider) => _externalProviderChoiceCard(provider))
                    .toList(),
              ),
          ],
          const SizedBox(height: 12),
          if (isWithdraw)
            _selectedWithdrawProviderLabel()
          else
            TextFormField(
              controller: _externalProviderController,
              readOnly: true,
              enableInteractiveSelection: false,
              onTap: () {
                if (providersForRail.isEmpty) {
                  _showSnack(
                    _isSw
                        ? 'Hakuna provider aliyewezeshwa kwa njia hii bado.'
                        : 'No enabled provider is configured for this route yet.',
                  );
                }
              },
              textCapitalization: TextCapitalization.characters,
              decoration: _fieldDecoration(
                label: AppLocalizations.of(context)!.sendMoneyProviderCodeLabel,
                hint: AppLocalizations.of(context)!.sendMoneyProviderCodeHint,
                icon: Icons.apartment_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(
                    context,
                  )!.sendMoneyProviderCodeRequiredMessage;
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  Widget _selectedWithdrawProviderLabel() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _activeExternalProviderAccent;
    final provider = _externalProviderController.text.trim();
    final title = _externalRail == _ExternalTransferRail.externalAgent
        ? (_isSw ? 'Huduma ya kutoa' : 'Withdraw service')
        : (_isSw ? 'Mtoa huduma aliyechaguliwa' : 'Selected provider');
    final subtitle = provider.isEmpty
        ? (_isSw ? 'Chagua provider' : 'Choose provider')
        : provider;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: ui.cardStrong.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: provider.isEmpty
              ? ui.borderStrong.withValues(alpha: 0.72)
              : accent.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: provider.isEmpty
                  ? ui.cardMuted
                  : accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _externalRail == _ExternalTransferRail.externalAgent
                  ? Icons.storefront_rounded
                  : Icons.verified_user_outlined,
              size: 12,
              color: provider.isEmpty ? ui.iconMuted : accent,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: provider.isEmpty ? ui.textMuted : ui.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noConfiguredRailNotice() {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_rounded, color: ui.iconMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSw
                  ? 'Njia hii haijawezeshwa na ORBI Core bado. Itaonekana baada ya Configuration Studio kuichapisha kama ACTIVE.'
                  : 'This route is not enabled by ORBI Core yet. It will appear after Configuration Studio publishes it as ACTIVE.',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transferRailCard(_ExternalTransferRail rail) {
    final ui = OrbiTheme.uiOf(context);
    final selected = rail == _externalRail;
    final accent = _flowAccent;
    final icon = switch (rail) {
      _ExternalTransferRail.bank => Icons.account_balance_rounded,
      _ExternalTransferRail.mobileWallet => Icons.phone_android_rounded,
      _ExternalTransferRail.paypal => Icons.alternate_email_rounded,
      _ExternalTransferRail.crypto => Icons.currency_bitcoin_rounded,
      _ => Icons.public_rounded,
    };
    final subtitle = switch (rail) {
      _ExternalTransferRail.bank => _isSw ? 'Benki' : 'Bank',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Mobile Money' : 'Mobile Money',
      _ExternalTransferRail.paypal => _isSw ? 'PayPal' : 'PayPal',
      _ExternalTransferRail.crypto => _isSw ? 'Crypto wallet' : 'Crypto wallet',
      _ => '',
    };

    return InkWell(
      onTap: () => setState(() => _applyExternalRailSelection(rail)),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    ui.card.withValues(alpha: 0.995),
                    Color.lerp(ui.cardStrong, accent, 0.12) ?? ui.cardStrong,
                  ]
                : [
                    ui.card.withValues(alpha: 0.99),
                    ui.cardStrong.withValues(alpha: 0.94),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.28)
                : ui.borderStrong.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? accent : Colors.black).withValues(
                alpha: selected ? 0.08 : 0.04,
              ),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : ui.cardStrong.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.18)
                      : ui.border.withValues(alpha: 0.70),
                ),
              ),
              child: Icon(
                icon,
                color: selected ? accent : ui.iconMuted,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _externalRailLabel(rail),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.2,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? accent.withValues(alpha: 0.92) : ui.textMuted,
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withdrawRailCard(_ExternalTransferRail rail) {
    final ui = OrbiTheme.uiOf(context);
    final selected = rail == _externalRail;
    final accent = _flowAccent;
    final icon = switch (rail) {
      _ExternalTransferRail.externalAgent => Icons.storefront_rounded,
      _ExternalTransferRail.mobileWallet => Icons.phone_android_rounded,
      _ExternalTransferRail.bank => Icons.account_balance_rounded,
      _ => Icons.route_rounded,
    };
    final subtitle = switch (rail) {
      _ExternalTransferRail.externalAgent =>
        _isSw
            ? 'Toa kwa msimbo wa ORBI Wakala'
            : 'Cash out using ORBI Agent code',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Hamisha kwenda namba ya simu' : 'Send out to a mobile number',
      _ExternalTransferRail.bank =>
        _isSw ? 'Toa kwenda akaunti ya benki' : 'Withdraw to a bank account',
      _ => '',
    };

    return InkWell(
      onTap: () => setState(() => _applyExternalRailSelection(rail)),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    ui.card.withValues(alpha: 0.995),
                    Color.lerp(ui.cardStrong, accent, 0.10) ?? ui.cardStrong,
                  ]
                : [
                    ui.card.withValues(alpha: 0.99),
                    ui.cardStrong.withValues(alpha: 0.94),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.28)
                : ui.borderStrong.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? accent : Colors.black).withValues(
                alpha: selected ? 0.08 : 0.04,
              ),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : ui.cardStrong.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.18)
                      : ui.border.withValues(alpha: 0.70),
                ),
              ),
              child: Icon(
                icon,
                color: selected ? accent : ui.iconMuted,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _externalRailLabel(rail),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.2,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? accent.withValues(alpha: 0.92) : ui.textMuted,
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _externalDestinationSection() {
    final isWithdraw = widget.externalExperience == ExternalExperience.withdraw;
    final isTransfer = widget.externalExperience == ExternalExperience.transfer;
    return _sectionCard(
      title: _externalDestinationSectionTitle,
      icon: widget.externalExperience == ExternalExperience.withdraw
          ? Icons.outbound_rounded
          : Icons.flag_rounded,
      subtitle: _externalDestinationSectionSubtitle,
      child: Column(
        children: [
          if (isWithdraw)
            _directStepHeader(
              step: '2',
              title: _externalRail == _ExternalTransferRail.externalAgent
                  ? (_isSw ? 'Agent ID' : 'Agent ID')
                  : (_isSw ? 'Namba ya mpokeaji' : 'Destination number'),
              accent: _flowAccent,
            )
          else if (isTransfer)
            _directStepHeader(
              step: '2',
              title: _isSw ? 'Mahali pa transfer' : 'Transfer destination',
              accent: _flowAccent,
            ),
          if (isWithdraw) ...[
            _withdrawDestinationHintCard(),
            const SizedBox(height: 12),
          ] else if (isTransfer) ...[
            _transferDestinationHintCard(),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _externalCardNoController,
            keyboardType: TextInputType.number,
            onChanged:
                isWithdraw &&
                    _externalRail == _ExternalTransferRail.externalAgent
                ? _onExternalAgentIdChanged
                : null,
            decoration: _fieldDecoration(
              label: widget.externalExperience == ExternalExperience.withdraw
                  ? (_externalRail == _ExternalTransferRail.externalAgent
                        ? (_isSw ? 'Agent ID Number' : 'Agent ID Number')
                        : (_isSw
                              ? 'Namba ya akaunti / namba'
                              : 'Account / number'))
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.bank
                  ? (_isSw
                        ? 'Namba ya akaunti ya benki'
                        : 'Bank account number')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.mobileWallet
                  ? (_isSw ? 'Namba ya Mobile Money' : 'Mobile Money number')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.paypal
                  ? (_isSw ? 'Barua pepe ya PayPal' : 'PayPal email / handle')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.crypto
                  ? (_isSw ? 'Wallet address / memo' : 'Wallet address / memo')
                  : _externalRail == _ExternalTransferRail.bank
                  ? AppLocalizations.of(context)!.sendMoneyCardNumberLabel
                  : _externalRail == _ExternalTransferRail.externalAgent
                  ? (_isSw ? 'Namba ya wakala' : 'Agent number')
                  : AppLocalizations.of(context)!.sendMoneyAccountAddressLabel,
              hint: widget.externalExperience == ExternalExperience.withdraw
                  ? (_externalRail == _ExternalTransferRail.externalAgent
                        ? (_isSw
                              ? 'Weka Agent ID Number ya tarakimu 4 au zaidi'
                              : 'Enter the 4-digit-or-more Agent ID number')
                        : _externalRail == _ExternalTransferRail.mobileWallet
                        ? (_isSw
                              ? 'Weka namba ya Mobile Money'
                              : 'Enter the Mobile Money number')
                        : (_isSw
                              ? 'Weka namba ya akaunti ya benki'
                              : 'Enter the bank account number'))
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.bank
                  ? (_isSw
                        ? 'Weka namba ya akaunti ya benki'
                        : 'Enter the bank account number')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.mobileWallet
                  ? (_isSw
                        ? 'Weka namba ya Mobile Money'
                        : 'Enter the Mobile Money number')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.paypal
                  ? (_isSw
                        ? 'Weka barua pepe au handle ya PayPal'
                        : 'Enter the PayPal email or handle')
                  : widget.externalExperience == ExternalExperience.transfer &&
                        _externalRail == _ExternalTransferRail.crypto
                  ? (_isSw
                        ? 'Weka wallet address au memo'
                        : 'Enter the wallet address or memo')
                  : _externalRail == _ExternalTransferRail.bank
                  ? AppLocalizations.of(context)!.sendMoneyCardNumberHint
                  : _externalRail == _ExternalTransferRail.externalAgent
                  ? (_isSw
                        ? 'Weka namba ya wakala au outlet'
                        : 'Enter the agent or outlet number')
                  : AppLocalizations.of(
                      context,
                    )!.sendMoneyDestinationAccountHint,
              icon: isWithdraw
                  ? _externalRail == _ExternalTransferRail.externalAgent
                        ? Icons.password_rounded
                        : _externalRail == _ExternalTransferRail.mobileWallet
                        ? Icons.phone_android_rounded
                        : Icons.account_balance_rounded
                  : isTransfer
                  ? _externalRail == _ExternalTransferRail.bank
                        ? Icons.account_balance_rounded
                        : _externalRail == _ExternalTransferRail.mobileWallet
                        ? Icons.phone_android_rounded
                        : _externalRail == _ExternalTransferRail.paypal
                        ? Icons.alternate_email_rounded
                        : Icons.currency_bitcoin_rounded
                  : Icons.credit_card_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return widget.externalExperience == ExternalExperience.withdraw
                    ? (_externalRail == _ExternalTransferRail.externalAgent
                          ? (_isSw
                                ? 'Agent ID Number inahitajika.'
                                : 'Agent ID number is required.')
                          : _externalRail == _ExternalTransferRail.mobileWallet
                          ? (_isSw
                                ? 'Namba ya Mobile Money inahitajika.'
                                : 'Mobile Money number is required.')
                          : (_isSw
                                ? 'Namba ya akaunti ya benki inahitajika.'
                                : 'Bank account number is required.'))
                    : widget.externalExperience ==
                              ExternalExperience.transfer &&
                          _externalRail == _ExternalTransferRail.bank
                    ? (_isSw
                          ? 'Namba ya akaunti ya benki inahitajika.'
                          : 'Bank account number is required.')
                    : widget.externalExperience ==
                              ExternalExperience.transfer &&
                          _externalRail == _ExternalTransferRail.mobileWallet
                    ? (_isSw
                          ? 'Namba ya Mobile Money inahitajika.'
                          : 'Mobile Money number is required.')
                    : widget.externalExperience ==
                              ExternalExperience.transfer &&
                          _externalRail == _ExternalTransferRail.paypal
                    ? (_isSw
                          ? 'Barua pepe au handle ya PayPal inahitajika.'
                          : 'PayPal email or handle is required.')
                    : widget.externalExperience ==
                              ExternalExperience.transfer &&
                          _externalRail == _ExternalTransferRail.crypto
                    ? (_isSw
                          ? 'Wallet address au memo inahitajika.'
                          : 'Wallet address or memo is required.')
                    : _externalRail == _ExternalTransferRail.bank
                    ? AppLocalizations.of(
                        context,
                      )!.sendMoneyCardNumberRequiredMessage
                    : _externalRail == _ExternalTransferRail.externalAgent
                    ? (_isSw
                          ? 'Weka namba ya wakala.'
                          : 'Agent number is required.')
                    : AppLocalizations.of(
                        context,
                      )!.sendMoneyAccountAddressRequiredMessage;
              }
              if (widget.externalExperience == ExternalExperience.withdraw &&
                  _externalRail == _ExternalTransferRail.externalAgent &&
                  value.trim().length < 4) {
                return _isSw
                    ? 'Weka angalau tarakimu 4 za Agent ID.'
                    : 'Enter at least 4 digits of the Agent ID.';
              }
              return null;
            },
          ),
          if (isWithdraw &&
              _externalRail == _ExternalTransferRail.externalAgent) ...[
            const SizedBox(height: 12),
            if (_agentLookupLoading)
              _agentLookupMessageCard(
                message: _isSw
                    ? 'Inatafuta ORBI Agent...'
                    : 'Looking up ORBI Agent...',
                tone: OrbiStatusTone.info,
                icon: Icons.travel_explore_rounded,
              ),
            if (_agentLookupError != null)
              _agentLookupMessageCard(
                message: _agentLookupError!,
                tone: OrbiStatusTone.error,
                icon: Icons.warning_amber_rounded,
              ),
            if (_orbiAgentPreview != null)
              _OrbiAgentPreviewCard(data: _orbiAgentPreview!),
          ],
          if (!isWithdraw) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _externalRecipientController,
              decoration: _fieldDecoration(
                label: _externalReferenceLabel,
                hint: _externalReferenceHint,
                icon: isTransfer
                    ? _externalRail == _ExternalTransferRail.bank
                          ? Icons.badge_outlined
                          : _externalRail == _ExternalTransferRail.mobileWallet
                          ? Icons.contact_phone_rounded
                          : _externalRail == _ExternalTransferRail.paypal
                          ? Icons.person_outline_rounded
                          : Icons.vpn_key_outlined
                    : Icons.person_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _externalReferenceRequiredMessage;
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _agentLookupMessageCard({
    required String message,
    required OrbiStatusTone tone,
    required IconData icon,
  }) {
    final ui = OrbiTheme.uiOf(context);
    final color = switch (tone) {
      OrbiStatusTone.success => ui.success,
      OrbiStatusTone.error => ui.danger,
      OrbiStatusTone.info => _flowAccent,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transferDestinationHintCard() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    final icon = switch (_externalRail) {
      _ExternalTransferRail.bank => Icons.account_balance_rounded,
      _ExternalTransferRail.mobileWallet => Icons.phone_android_rounded,
      _ExternalTransferRail.paypal => Icons.alternate_email_rounded,
      _ExternalTransferRail.crypto => Icons.currency_bitcoin_rounded,
      _ => Icons.public_rounded,
    };
    final title = switch (_externalRail) {
      _ExternalTransferRail.bank =>
        _isSw ? 'Transfer ya Benki' : 'Bank transfer',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Transfer ya Mobile Money' : 'Mobile Money transfer',
      _ExternalTransferRail.paypal =>
        _isSw ? 'Transfer ya PayPal' : 'PayPal transfer',
      _ExternalTransferRail.crypto =>
        _isSw ? 'Transfer ya Crypto' : 'Crypto transfer',
      _ => _isSw ? 'Transfer' : 'Transfer',
    };
    final subtitle = switch (_externalRail) {
      _ExternalTransferRail.bank =>
        _isSw ? 'Weka akaunti ya benki.' : 'Enter bank account number.',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Weka namba ya Mobile Money.' : 'Enter Mobile Money number.',
      _ExternalTransferRail.paypal =>
        _isSw
            ? 'Weka barua pepe au handle ya PayPal ya mpokeaji.'
            : 'Enter PayPal email or handle.',
      _ExternalTransferRail.crypto =>
        _isSw
            ? 'Weka wallet address au memo ya mpokeaji.'
            : 'Enter wallet address or memo.',
      _ => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ui.cardStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawDestinationHintCard() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    final icon = switch (_externalRail) {
      _ExternalTransferRail.externalAgent => Icons.password_rounded,
      _ExternalTransferRail.mobileWallet => Icons.phone_android_rounded,
      _ExternalTransferRail.bank => Icons.account_balance_rounded,
      _ => Icons.outbound_rounded,
    };
    final title = switch (_externalRail) {
      _ExternalTransferRail.externalAgent =>
        _isSw ? 'Utoaji kwa ORBI Wakala' : 'ORBI Agent withdrawal',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Utoaji kwa Mobile Money' : 'Mobile Money withdrawal',
      _ExternalTransferRail.bank =>
        _isSw ? 'Utoaji kwa Benki' : 'Bank withdrawal',
      _ => _isSw ? 'Utoaji' : 'Withdrawal',
    };
    final subtitle = switch (_externalRail) {
      _ExternalTransferRail.externalAgent =>
        _isSw ? 'Weka Agent ID Number' : 'Enter Agent ID number',
      _ExternalTransferRail.mobileWallet =>
        _isSw ? 'Weka namba ya Mobile Money' : 'Enter Mobile Money number',
      _ExternalTransferRail.bank =>
        _isSw ? 'Weka namba ya akaunti ya benki' : 'Enter bank account number',
      _ => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ui.cardStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalFundingSection() {
    final isWithdraw = widget.externalExperience == ExternalExperience.withdraw;
    final isTransfer = widget.externalExperience == ExternalExperience.transfer;
    return _sectionCard(
      title: _externalFundingSectionTitle,
      icon: Icons.account_balance_wallet_rounded,
      subtitle: _externalFundingSectionSubtitle,
      child: Column(
        children: [
          if (isWithdraw)
            _directStepHeader(
              step: '3',
              title: _isSw ? 'Wallet ya kutoa' : 'Funding wallet',
              accent: _flowAccent,
            )
          else if (isTransfer)
            _directStepHeader(
              step: '4',
              title: _isSw ? 'Wallet ya transfer' : 'Funding wallet',
              accent: _flowAccent,
            ),
          if (isWithdraw) ...[
            _withdrawFundingHintCard(),
            const SizedBox(height: 12),
          ] else if (isTransfer) ...[
            _transferFundingHintCard(),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<_ExternalSourceWalletType>(
            initialValue: _externalSourceWalletType,
            isExpanded: true,
            dropdownColor: OrbiTheme.uiOf(context).card,
            decoration: _fieldDecoration(
              label: AppLocalizations.of(context)!.sendMoneySourceWalletLabel,
              hint: AppLocalizations.of(context)!.sendMoneySourceWalletHint,
              icon: Icons.account_balance_wallet_outlined,
            ),
            items: _ExternalSourceWalletType.values
                .map(
                  (source) => DropdownMenuItem(
                    value: source,
                    child: Text(_externalSourceWalletLabel(source)),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) {
                setState(() {
                  _externalSourceWalletType = next;
                });
                _syncSelectedSourceWallet();
              }
            },
          ),
          if (_externalSourceWalletType !=
              _ExternalSourceWalletType.internal) ...[
            const SizedBox(height: 12),
            FormField<String>(
              initialValue: _selectedExternalSourceWalletId,
              validator: (_) {
                if (_externalSourceWalletType ==
                    _ExternalSourceWalletType.internal) {
                  return null;
                }
                if ((_selectedExternalSourceWalletId ?? '').trim().isEmpty) {
                  return AppLocalizations.of(
                    context,
                  )!.sendMoneySelectSourceWalletRequiredMessage;
                }
                return null;
              },
              builder: (field) {
                final wallets = _filteredSourceWallets();
                final ui = OrbiTheme.uiOf(context);
                return InputDecorator(
                  decoration: _fieldDecoration(
                    label: AppLocalizations.of(
                      context,
                    )!.sendMoneyBackendSourceWalletLabel,
                    hint: _loadingSourceWallets
                        ? AppLocalizations.of(
                            context,
                          )!.sendMoneyLoadingWalletsHint
                        : AppLocalizations.of(
                            context,
                          )!.sendMoneySelectLoadedWalletHint,
                    icon: Icons.badge_outlined,
                    helperText: _sourceWalletError,
                  ).copyWith(errorText: field.errorText),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.sendMoneySelectLoadedWalletHint,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingSourceWallets)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: _flowAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.sendMoneyLoadingWalletsHint,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (wallets.isEmpty)
                        Text(
                          _sourceWalletError ??
                              (AppLocalizations.of(
                                context,
                              )!.sendMoneySelectSourceWalletRequiredMessage),
                          style: TextStyle(
                            color: field.errorText != null
                                ? Theme.of(context).colorScheme.error
                                : ui.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 340),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: wallets.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              return _sourceWalletChoiceCard(wallets[i]);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          _externalFundingSummary(),
        ],
      ),
    );
  }

  Widget _withdrawFundingHintCard() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ui.cardStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSw ? 'Wallet ya kutoa' : 'Withdrawal wallet',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSw ? 'Chagua wallet' : 'Choose wallet',
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transferFundingHintCard() {
    final ui = OrbiTheme.uiOf(context);
    final accent = _flowAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ui.cardStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSw ? 'Wallet ya transfer' : 'Transfer wallet',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSw ? 'Chagua wallet' : 'Choose wallet',
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalAmountNoteSection() {
    return _sectionCard(
      title: widget.externalExperience == ExternalExperience.withdraw
          ? (_isSw
                ? 'Kiasi na maelezo ya withdraw'
                : 'Withdraw amount & details')
          : widget.externalExperience == ExternalExperience.transfer
          ? (_isSw
                ? 'Kiasi na maelezo ya transfer'
                : 'Transfer amount & details')
          : AppLocalizations.of(
              context,
            )!.sendMoneyExternalSectionAmountNoteTitle,
      icon: widget.externalExperience == ExternalExperience.withdraw
          ? Icons.outbox_rounded
          : Icons.request_quote_rounded,
      child: Column(
        children: [
          if (widget.externalExperience == ExternalExperience.transfer)
            _directStepHeader(
              step: '3',
              title: _isSw ? 'Kiasi' : 'Amount',
              accent: _flowAccent,
            )
          else if (widget.externalExperience == ExternalExperience.withdraw)
            _directStepHeader(
              step: '4',
              title: _isSw ? 'Kiasi' : 'Amount',
              accent: _flowAccent,
            ),
          OrbiAmountField(
            controller: _externalAmountController,
            inputFormatters: [AmountInputFormatter()],
            label: AppLocalizations.of(context)!.sendMoneyAmountLabel,
            currency: resolveCurrencyDisplaySymbol(
              _resolveSelectedSourceCurrency(),
            ),
            validator: (value) {
              final parsed = AmountInputFormatter.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return AppLocalizations.of(
                  context,
                )!.sendMoneyEnterValidAmountMessage;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _externalNoteController,
            maxLines: 3,
            decoration: _fieldDecoration(
              label: AppLocalizations.of(
                context,
              )!.sendMoneyDescriptionOptionalLabel,
              hint: AppLocalizations.of(context)!.sendMoneyDescriptionHint,
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 46),
                child: Icon(Icons.notes_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _budgetCategoryField(
            value: _selectedExternalCategoryId,
            onChanged: (next) {
              setState(() => _selectedExternalCategoryId = next);
            },
          ),
          const SizedBox(height: 10),
          _budgetSummaryCard(_selectedExternalCategoryId),
        ],
      ),
    );
  }

  Color _movementProviderColor(String provider) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.contains('mix') ||
        normalized.contains('yas') ||
        normalized.contains('tigo')) {
      return const Color(0xFF1976D2);
    }
    if (normalized.contains('halotel') ||
        normalized.contains('halopesa') ||
        normalized.contains('halo pesa')) {
      return const Color(0xFFF28C28);
    }
    if (normalized.contains('airtel')) return const Color(0xFFFF7043);
    if (normalized.contains('vodacom') ||
        normalized.contains('mpesa') ||
        normalized.contains('m-pesa')) {
      return const Color(0xFFE53935);
    }
    if (normalized.contains('crdb')) return const Color(0xFF2E7D32);
    if (normalized.contains('nmb')) return const Color(0xFF00897B);
    if (normalized == 'nbc' || normalized.contains('national bank')) {
      return const Color(0xFF1565C0);
    }
    if (normalized.contains('absa')) return const Color(0xFFC62828);
    if (normalized.contains('equity')) return const Color(0xFF8E24AA);
    if (normalized.contains('diamond')) return const Color(0xFF3949AB);
    return _flowAccent;
  }
}

class _TransferModeSwitcher extends StatelessWidget {
  final _TransferMode mode;
  final ValueChanged<_TransferMode> onChanged;

  const _TransferModeSwitcher({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeChip(
              context: context,
              selected: mode == _TransferMode.internalP2P,
              title: AppLocalizations.of(context)!.sendMoneyModeInternalTitle,
              subtitle: AppLocalizations.of(
                context,
              )!.sendMoneyModeInternalSubtitle,
              onTap: () => onChanged(_TransferMode.internalP2P),
              selectedColor: ui.accent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _modeChip(
              context: context,
              selected: mode == _TransferMode.external,
              title: AppLocalizations.of(context)!.sendMoneyModeExternalTitle,
              subtitle: AppLocalizations.of(
                context,
              )!.sendMoneyModeExternalSubtitle,
              onTap: () => onChanged(_TransferMode.external),
              selectedColor: ui.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required BuildContext context,
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color selectedColor,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.2)
              : ui.cardMuted.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor.withValues(alpha: 0.5) : ui.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: ui.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RecipientPreviewCard extends StatelessWidget {
  final _RecipientPreview data;

  const _RecipientPreviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final avatar = data.avatarUrl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ui.successSoft,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
                ? Icon(Icons.person, color: ui.textPrimary, size: 21)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.sendMoneyRecipientIdLabel,
                  style: TextStyle(fontSize: 11),
                ),
                Text(
                  data.recipientId,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context)!.sendMoneyFullNameLabel,
                  style: TextStyle(fontSize: 11),
                ),
                Text(
                  data.fullName,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (data.registryType.isNotEmpty)
                      _miniTag(
                        label: data.registryType.toUpperCase(),
                        color: ui.accent,
                      ),
                    _miniTag(
                      label: data.isPaysafeVerified
                          ? AppLocalizations.of(context)!.sendMoneyVerifiedLabel
                          : AppLocalizations.of(
                              context,
                            )!.sendMoneyNotVerifiedLabel,
                      color: data.isPaysafeVerified ? ui.success : ui.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            data.isPaysafeVerified
                ? Icons.verified_rounded
                : Icons.shield_outlined,
            color: data.isPaysafeVerified ? ui.success : ui.iconMuted,
          ),
        ],
      ),
    );
  }

  Widget _miniTag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrbiAgentPreviewCard extends StatelessWidget {
  final _OrbiAgentPreview data;

  const _OrbiAgentPreviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final accent = ui.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.storefront_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.displayName,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metaChip(
                      label: data.tillNumber.isNotEmpty
                          ? data.tillNumber
                          : data.agentId,
                      color: accent,
                    ),
                    if (data.branch.isNotEmpty)
                      _metaChip(label: data.branch, color: ui.accent),
                    _metaChip(
                      label: data.status.isEmpty
                          ? 'ACTIVE'
                          : data.status.toUpperCase(),
                      color: data.status == 'active' ? ui.success : ui.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: ui.success, size: 20),
        ],
      ),
    );
  }

  Widget _metaChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TransactionPreviewData {
  final String quoteId;
  final String quoteHash;
  final String status;
  final String securityDecision;
  final String currency;
  final String recipientName;
  final String recipientCustomerId;
  final String recipientDisplayIdentifier;
  final String recipientAvatarUrl;
  final double baseAmount;
  final double taxAmount;
  final double feeAmount;
  final double totalAmount;
  final double? availableBalance;
  final double? requiredBalance;
  final String sourceWalletId;
  final String sourceWalletName;
  final bool canSubmit;
  final String issueMessage;
  final String state;
  final FxQuote? fxQuote;

  const _TransactionPreviewData({
    required this.quoteId,
    required this.quoteHash,
    required this.status,
    required this.securityDecision,
    required this.currency,
    required this.recipientName,
    required this.recipientCustomerId,
    required this.recipientDisplayIdentifier,
    required this.recipientAvatarUrl,
    required this.baseAmount,
    required this.taxAmount,
    required this.feeAmount,
    required this.totalAmount,
    required this.availableBalance,
    required this.requiredBalance,
    required this.sourceWalletId,
    required this.sourceWalletName,
    required this.canSubmit,
    required this.issueMessage,
    required this.state,
    required this.fxQuote,
  });
}

class _OrbiAgentPreview {
  final String agentId;
  final String displayName;
  final String tillNumber;
  final String serviceNumber;
  final String branch;
  final String status;

  const _OrbiAgentPreview({
    required this.agentId,
    required this.displayName,
    required this.tillNumber,
    required this.serviceNumber,
    required this.branch,
    required this.status,
  });
}

class _PreviewHeroCard extends StatelessWidget {
  final _TransactionPreviewData preview;
  final bool blocked;

  const _PreviewHeroCard({required this.preview, required this.blocked});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    final amount = formatAppBalanceAmount(
      preview.totalAmount,
      preview.currency,
      locale: localeTag,
    );
    final color = blocked ? ui.warning : ui.success;
    final state = preview.state.isNotEmpty
        ? preview.state.replaceAll('_', ' ')
        : preview.status.replaceAll('_', ' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            ui.cardMuted.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  blocked
                      ? Icons.report_problem_rounded
                      : Icons.verified_rounded,
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.sendMoneyConfirmTransferTitle,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: MoneyText(
                  value: amount,
                  textAlign: TextAlign.end,
                  mainFontSize: 20,
                  sideFontSize: 11,
                  fontWeight: FontWeight.w900,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PreviewMiniDetail(
                  label: 'From',
                  value: preview.sourceWalletName.isNotEmpty
                      ? preview.sourceWalletName
                      : 'Source wallet',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PreviewMiniDetail(
                  label: 'To',
                  value: preview.recipientName.isNotEmpty
                      ? preview.recipientName
                      : preview.recipientDisplayIdentifier,
                  icon: Icons.person_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMiniDetail extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PreviewMiniDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.border.withValues(alpha: 0.70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ui.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900,
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

class _PendingSettleAttempt {
  final String payloadSignature;
  final String idempotencyKey;
  final DateTime createdAt;

  const _PendingSettleAttempt({
    required this.payloadSignature,
    required this.idempotencyKey,
    required this.createdAt,
  });
}

class _TransientNetworkException implements Exception {
  final String message;
  const _TransientNetworkException(this.message);

  @override
  String toString() => message;
}

class _TransientSettleException implements Exception {
  final String message;
  const _TransientSettleException(this.message);

  @override
  String toString() => message;
}

class _ChallengeCancelledException implements Exception {
  final String message;
  const _ChallengeCancelledException(this.message);

  @override
  String toString() => message;
}

class _TransactionChallengeRequiredException implements Exception {
  final String requestId;
  final String message;
  final String otpDestination;
  final String controlId;
  final Map<String, dynamic> payload;

  const _TransactionChallengeRequiredException({
    required this.requestId,
    required this.message,
    required this.otpDestination,
    required this.controlId,
    required this.payload,
  });

  @override
  String toString() => message;
}

// ignore: unused_element
class _PreviewRecipientRow extends StatelessWidget {
  final _TransactionPreviewData preview;
  const _PreviewRecipientRow({required this.preview});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final avatar = preview.recipientAvatarUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: ui.successSoft,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Icon(Icons.person, color: ui.textPrimary, size: 20)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.recipientName.isNotEmpty
                    ? preview.recipientName
                    : AppLocalizations.of(context)!.sendMoneyRecipientFallback,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                preview.recipientDisplayIdentifier,
                style: TextStyle(color: ui.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewBreakdownCard extends StatelessWidget {
  final _TransactionPreviewData preview;
  const _PreviewBreakdownCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    String money(double amount) =>
        formatAppBalanceAmount(amount, preview.currency, locale: localeTag);
    final available = preview.availableBalance;
    final availableValue = available ?? 0.0;
    final hasAvailable = available != null;
    final isShort = hasAvailable && preview.totalAmount > availableValue;
    final shortfall = isShort ? (preview.totalAmount - availableValue) : 0.0;
    final fxQuote = preview.fxQuote;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ui.cardMuted.withValues(alpha: 0.82),
            ui.card.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.borderStrong.withValues(alpha: 0.70)),
      ),
      child: Column(
        children: [
          _row(
            AppLocalizations.of(context)!.sendMoneyReceiptAmount,
            money(preview.baseAmount),
            ui: ui,
            moneyValue: true,
          ),
          const SizedBox(height: 7),
          _row(
            AppLocalizations.of(context)!.sendMoneyReceiptTax,
            money(preview.taxAmount),
            ui: ui,
            moneyValue: true,
          ),
          const SizedBox(height: 7),
          _row(
            AppLocalizations.of(context)!.sendMoneyPreviewServiceFeeLabel,
            money(preview.feeAmount),
            ui: ui,
            moneyValue: true,
          ),
          if (hasAvailable) ...[
            const SizedBox(height: 7),
            _row(
              AppLocalizations.of(
                context,
              )!.sendMoneyPreviewAvailableBalanceLabel,
              money(availableValue),
              ui: ui,
              moneyValue: true,
            ),
          ],
          if (fxQuote != null) ...[
            const SizedBox(height: 7),
            _row(
              AppLocalizations.of(context)!.sendMoneyPreviewRecipientGetsLabel,
              formatAppBalanceAmount(
                fxQuote.finalAmount,
                fxQuote.toCurrency,
                locale: localeTag,
              ),
              ui: ui,
              moneyValue: true,
            ),
          ],
          if (isShort) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              )!.sendMoneyInsufficientBalanceMessage(money(shortfall)),
              style: TextStyle(
                color: ui.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    required OrbiUiTokens ui,
    bool bold = false,
    bool moneyValue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: moneyValue
              ? MoneyText(
                  value: value,
                  textAlign: TextAlign.end,
                  mainFontSize: 13,
                  sideFontSize: 10,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  mainColor: ui.textPrimary,
                  sideColor: ui.textMuted,
                  fitToWidth: true,
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  // ignore: unused_element
  String _fxRateLabel(String fromCurrency, double rate, String toCurrency) {
    return '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency';
  }
}

// ignore: unused_element
class _PreviewSecurityBadge extends StatelessWidget {
  final _TransactionPreviewData preview;
  const _PreviewSecurityBadge({required this.preview});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final decision = preview.securityDecision.isEmpty
        ? 'ALLOW'
        : preview.securityDecision;
    final blocked = decision == 'BLOCK';
    final challenge = decision == 'CHALLENGE';
    final color = blocked
        ? ui.danger
        : challenge
        ? ui.warning
        : ui.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            blocked
                ? Icons.warning_amber_rounded
                : challenge
                ? Icons.shield_outlined
                : Icons.verified_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              blocked
                  ? AppLocalizations.of(
                      context,
                    )!.sendMoneySecurityCheckStatus('BLOCK')
                  : challenge
                  ? AppLocalizations.of(
                      context,
                    )!.sendMoneySecurityCheckStatus('CHALLENGE')
                  : AppLocalizations.of(
                      context,
                    )!.sendMoneySecurityCheckStatus('ALLOW'),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewIssueCard extends StatelessWidget {
  final String message;
  const _PreviewIssueCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ui.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: ui.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientSearchInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawInput = newValue.text.trimLeft();
    final upper = rawInput.toUpperCase();
    final idMode = upper.startsWith('O') || upper.startsWith('OB');
    final emailMode = rawInput.contains('@');

    if (idMode) {
      final raw = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final buffer = StringBuffer();
      for (var i = 0; i < raw.length && i < 12; i++) {
        buffer.write(raw[i]);
        if ((i == 3 || i == 7) && i != raw.length - 1) {
          buffer.write('-');
        }
      }
      final formatted = buffer.toString();
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (emailMode) {
      final emailSafe = rawInput.replaceAll(RegExp(r'[^A-Za-z0-9@._+\-]'), '');
      return TextEditingValue(
        text: emailSafe,
        selection: TextSelection.collapsed(offset: emailSafe.length),
      );
    }

    final startsWithPlus = rawInput.startsWith('+');
    final digitsOnly = rawInput.replaceAll(RegExp(r'[^\d]'), '');
    final limitedDigits = digitsOnly.length > 15
        ? digitsOnly.substring(0, 15)
        : digitsOnly;
    final formatted = startsWithPlus ? '+$limitedDigits' : limitedDigits;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ReceiptZigZagClipper extends CustomClipper<Path> {
  const _ReceiptZigZagClipper();

  @override
  Path getClip(Size size) {
    const zigZagHeight = 6.0;
    const zigZagWidth = 12.0;
    final path = Path();
    final height = size.height;
    final width = size.width;

    path.moveTo(0, zigZagHeight);
    var x = 0.0;
    while (x < width) {
      path.lineTo(x + zigZagWidth / 2, 0);
      path.lineTo(x + zigZagWidth, zigZagHeight);
      x += zigZagWidth;
    }

    path.lineTo(width, height - zigZagHeight);
    x = width;
    while (x > 0) {
      path.lineTo(x - zigZagWidth / 2, height);
      path.lineTo(x - zigZagWidth, height - zigZagHeight);
      x -= zigZagWidth;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
