import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/theme/orbi_card_styles.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_brand_hero_card.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/orbi_section_card.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../../../core/widgets/service_asset_icon.dart';
import '../../auth/state/auth_controller.dart';
import '../../payment/data/escrow_service.dart';
import '../../payment/data/merchant_service.dart';
import '../../profile/state/profile_controller.dart';
import '../data/advanced_services_service.dart';
import 'agent_screen.dart';
import 'merchant_screen.dart';

const Color _paySafeAccent = Color(0xFF8B5CF6);

class AdvancedServicesScreen extends StatefulWidget {
  const AdvancedServicesScreen({
    super.key,
    this.initialServiceAccessRole,
    this.initialShowSafeHold = false,
    this.paySafeOnly = false,
    this.serviceAccessOnly = false,
    this.titleOverride,
  });

  final String? initialServiceAccessRole;
  final bool initialShowSafeHold;
  final bool paySafeOnly;
  final bool serviceAccessOnly;
  final String? titleOverride;

  @override
  State<AdvancedServicesScreen> createState() => _AdvancedServicesScreenState();
}

class _AdvancedServicesScreenState extends State<AdvancedServicesScreen> {
  final AdvancedServicesService _accountService = AdvancedServicesService();
  final EscrowService _escrowService = EscrowService();
  final MerchantService _merchantService = MerchantService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _error;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  List<Map<String, dynamic>> _wallets = const [];
  List<Map<String, dynamic>> _escrows = const [];
  List<Map<String, dynamic>> _merchantCategories = const [];
  List<Map<String, dynamic>> _merchantAccounts = const [];
  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _serviceAccessRequests = const [];

  String? _selectedWalletId;
  bool _initialRequestHandled = false;
  bool _showEscrowTools = false;
  bool _showMerchantTools = false;
  bool _showAccountTools = false;

  @override
  void initState() {
    super.initState();
    _showEscrowTools = widget.initialShowSafeHold;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  String get _localeTag => _isSw ? 'sw_TZ' : 'en_US';

  Color get _screenAccent =>
      widget.paySafeOnly ? _paySafeAccent : OrbiTheme.uiOf(context).iconMuted;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        message,
        sw: _isSw,
        fallback: isError
            ? _t(
                'This request could not be completed. Please try again.',
                'Ombi hili halikuweza kukamilika. Tafadhali jaribu tena.',
              )
            : message,
      );
      _statusTone = isError ? OrbiStatusTone.error : OrbiStatusTone.success;
    });
  }

  String _pickString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  bool _pickBool(List<dynamic> values) {
    for (final value in values) {
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }
    return false;
  }

  DateTime? _pickDate(List<dynamic> values) {
    for (final value in values) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty || raw.toLowerCase() == 'null') continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  double _pickDouble(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('${value ?? ''}');
      if (parsed != null) return parsed;
    }
    return 0;
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

  String get _selectedWalletCurrencyCode {
    final match = _wallets.cast<Map<String, dynamic>?>().firstWhere(
      (wallet) => _walletId(wallet) == _selectedWalletId,
      orElse: () => null,
    );
    return _walletCurrency(match);
  }

  String _money(double amount, String currency) {
    return formatFinancialMoney(amount, currency, locale: _localeTag);
  }

  String _referenceId(Map<String, dynamic> escrow) => _pickString([
    escrow['referenceId'],
    escrow['reference_id'],
    escrow['reference'],
    escrow['id'],
  ]);

  String _normalizedStatus(Map<String, dynamic> escrow) {
    return _pickString([
      escrow['status'],
      escrow['state'],
      escrow['escrow_status'],
    ]).toUpperCase();
  }

  String _actorRole(Map<String, dynamic> escrow) {
    return _pickString([
      escrow['actorRole'],
      escrow['actor_role'],
    ]).toLowerCase();
  }

  bool _availableActionFlag(Map<String, dynamic> escrow, String action) {
    final actions = escrow['availableActions'];
    if (actions is Map) {
      final normalized = Map<String, dynamic>.from(actions);
      return _pickBool([normalized[action]]);
    }
    return false;
  }

  bool _receiverAccepted(Map<String, dynamic> escrow) {
    return _pickBool([
      escrow['receiverAccepted'],
      escrow['receiver_accepted'],
      escrow['recipientAccepted'],
      escrow['recipient_accepted'],
      escrow['beneficiaryAccepted'],
      escrow['beneficiary_accepted'],
      escrow['releaseAccepted'],
      escrow['release_accepted'],
    ]);
  }

  DateTime? _holdExpiry(Map<String, dynamic> escrow) {
    return _pickDate([
      escrow['holdWindowEndsAt'],
      escrow['hold_window_ends_at'],
      escrow['holdExpiresAt'],
      escrow['hold_expires_at'],
      escrow['expiresAt'],
      escrow['expires_at'],
      escrow['releaseWindowEndsAt'],
      escrow['release_window_ends_at'],
    ]);
  }

  bool _isTerminalStatus(String status) {
    return status.contains('REFUND') ||
        status.contains('REVERSE') ||
        status.contains('RELEASED') ||
        status.contains('SETTLED') ||
        status.contains('COMPLETED') ||
        status.contains('CLOSED') ||
        status.contains('CANCEL');
  }

  bool _isBlockedStatus(String status) {
    return status.contains('DISPUT') ||
        status.contains('REVIEW') ||
        status.contains('LOCK');
  }

  bool _isReturnPending(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    return status.contains('RETURN_PENDING') ||
        _pickBool([escrow['returnPending'], escrow['return_pending']]);
  }

  bool _isReleasePending(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    return status.contains('RELEASE_PENDING') ||
        status.contains('RELEASE_REQUESTED') ||
        status.contains('AWAITING_RECEIVER_ACCEPTANCE');
  }

  bool _isAwaitingReceiverAcceptance(Map<String, dynamic> escrow) {
    if (_isReleasePending(escrow)) return true;
    if (_receiverAccepted(escrow)) return false;
    final status = _normalizedStatus(escrow);
    if (status == 'HELD') return true;
    return status.contains('AWAIT') ||
        status.contains('RELEASE_PENDING') ||
        status.contains('RELEASE_REQUESTED') ||
        status.contains('HOLD_ACCEPTANCE') ||
        status.contains('ACCEPTANCE');
  }

  bool _isActiveEscrow(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    return !_isTerminalStatus(status) && !status.contains('ARCHIVE');
  }

  bool _canRelease(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'release')) return true;
    final status = _normalizedStatus(escrow);
    if (_actorRole(escrow) != 'sender') return false;
    return !_isTerminalStatus(status) &&
        !_isBlockedStatus(status) &&
        !_isReturnPending(escrow) &&
        _receiverAccepted(escrow);
  }

  bool _canAccept(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'accept')) return true;
    return _actorRole(escrow) == 'receiver' &&
        (_isAwaitingReceiverAcceptance(escrow) ||
            _isReleasePending(escrow) ||
            _isReturnPending(escrow)) &&
        !_pickBool([
          escrow['holdWindowExpired'],
          escrow['hold_window_expired'],
        ]);
  }

  bool _canRefund(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'refund')) return true;
    final status = _normalizedStatus(escrow);
    if (_actorRole(escrow) != 'sender') return false;
    return !_isTerminalStatus(status) &&
        !_isReturnPending(escrow) &&
        !status.contains('REFUND_PENDING');
  }

  bool _canDispute(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'dispute')) return true;
    final status = _normalizedStatus(escrow);
    return !_isTerminalStatus(status) && !_isBlockedStatus(status);
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  String _escrowSummary(Map<String, dynamic> escrow) {
    final expiry = _holdExpiry(escrow);
    final awaitingAcceptance = _isAwaitingReceiverAcceptance(escrow);
    final receiverAccepted = _receiverAccepted(escrow);
    final actorRole = _actorRole(escrow);
    final expired = _pickBool([
      escrow['holdWindowExpired'],
      escrow['hold_window_expired'],
    ]);
    if (_isReturnPending(escrow)) {
      return actorRole == 'receiver'
          ? _t(
              'Sender requested a return. Accept it or open a dispute within 24 hours.',
              'Mtumaji ameomba return. Ikubali au fungua dispute ndani ya saa 24.',
            )
          : _t(
              'Return request is waiting for receiver response.',
              'Ombi la return linasubiri jibu la mpokeaji.',
            );
    }
    if (_isReleasePending(escrow)) {
      return actorRole == 'receiver'
          ? _t(
              'Sender requested release. Accept to receive funds, or open a dispute if something is wrong.',
              'Mtumaji ameomba release. Kubali upokee fedha, au fungua dispute kama kuna tatizo.',
            )
          : _t(
              'Release is waiting for receiver final acceptance.',
              'Release inasubiri idhini ya mwisho ya mpokeaji.',
            );
    }
    if (receiverAccepted) {
      return _t(
        'Receiver confirmed this PaySafe. Sender can now request release.',
        'Mpokeaji amethibitisha PaySafe hii. Mtumaji anaweza kuomba release.',
      );
    }
    if (expired) {
      return _t(
        'The acceptance window ended. Sender can refund or dispute this hold.',
        'Dirisha la idhini limeisha. Mtumaji anaweza kurejesha au kupinga hold hii.',
      );
    }
    if (awaitingAcceptance && expiry != null) {
      if (actorRole == 'receiver') {
        return _t(
          'Accept this hold before ${_formatDateTime(expiry)} to receive the funds.',
          'Kubali hold hii kabla ya ${_formatDateTime(expiry)} ili upokee fedha.',
        );
      }
      return _t(
        'Receiver must accept before ${_formatDateTime(expiry)}.',
        'Mpokeaji lazima akubali kabla ya ${_formatDateTime(expiry)}.',
      );
    }
    if (awaitingAcceptance) {
      return _t(
        'Receiver must accept the hold before settlement completes.',
        'Mpokeaji lazima akubali hold kabla ya settlement kukamilika.',
      );
    }
    if (expiry != null) {
      return _t(
        'Hold window ends ${_formatDateTime(expiry)}.',
        'Dirisha la hold linaisha ${_formatDateTime(expiry)}.',
      );
    }
    return _t(
      'Sender can release, refund, or dispute while the hold remains active.',
      'Mtumaji anaweza kuachia, kurejesha, au kupinga huku hold ikiwa hai.',
    );
  }

  Future<List<Map<String, dynamic>>> _safeListLoad(
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return await loader().timeout(const Duration(seconds: 8));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 403 || status == 404) {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    } on TimeoutException {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        await context.read<AuthController>().refreshCurrentProfile();
      } catch (_) {
        // Keep the page usable even if profile refresh fails.
      }
      if (widget.paySafeOnly) {
        final escrows = await _safeListLoad(() => _escrowService.listEscrows());
        if (!mounted) return;
        setState(() {
          _wallets = const [];
          _escrows = escrows;
          _merchantCategories = const [];
          _merchantAccounts = const [];
          _documents = const [];
          _serviceAccessRequests = const [];
          _loading = false;
        });
        return;
      }
      final results = await Future.wait<dynamic>([
        _safeListLoad(() => _accountService.listWallets()),
        _safeListLoad(() => _escrowService.listEscrows()),
        _safeListLoad(() => _merchantService.listMerchantCategories()),
        _safeListLoad(() => _merchantService.listMyMerchantAccounts()),
        _safeListLoad(() => _accountService.listDocuments()),
        _safeListLoad(() => _accountService.listServiceAccessRequests()),
      ]);
      if (!mounted) return;
      final wallets = List<Map<String, dynamic>>.from(results[0] as List);
      final firstWallet = wallets.isNotEmpty ? wallets.first : null;
      setState(() {
        _wallets = wallets;
        _escrows = List<Map<String, dynamic>>.from(results[1] as List);
        _merchantCategories = List<Map<String, dynamic>>.from(
          results[2] as List,
        );
        _merchantAccounts = List<Map<String, dynamic>>.from(results[3] as List);
        _documents = List<Map<String, dynamic>>.from(results[4] as List);
        _serviceAccessRequests = List<Map<String, dynamic>>.from(
          results[5] as List,
        );
        _selectedWalletId = _selectedWalletId ?? _walletId(firstWallet);
        _loading = false;
      });
      _maybeOpenInitialServiceRequest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _wallets = const [];
        _escrows = const [];
        _merchantCategories = const [];
        _merchantAccounts = const [];
        _documents = const [];
        _serviceAccessRequests = const [];
        _error = mapBackendStatusMessage(
          error.toString(),
          sw: _isSw,
          fallback: _t(
            'Services could not be loaded. Please refresh and try again.',
            'Huduma hazikuweza kupakiwa. Tafadhali pakia upya kisha jaribu tena.',
          ),
        );
      });
    }
  }

  void _maybeOpenInitialServiceRequest() {
    if (_initialRequestHandled) return;
    final requestedRole = widget.initialServiceAccessRole?.trim().toUpperCase();
    if (requestedRole != 'AGENT' && requestedRole != 'MERCHANT') return;
    final String resolvedRequestedRole = requestedRole!;

    final auth = context.read<AuthController>();
    if ((resolvedRequestedRole == 'AGENT' && auth.isAgent) ||
        (resolvedRequestedRole == 'MERCHANT' && auth.isMerchant)) {
      _initialRequestHandled = true;
      return;
    }

    _initialRequestHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _submitServiceAccessRequest(resolvedRequestedRole);
    });
  }

  String _requestStatusLabel(Map<String, dynamic> item) {
    return _pickString([
      item['status'],
      'pending',
    ]).replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _submitServiceAccessRequest(String requestedRole) async {
    final noteController = TextEditingController();
    final businessController = TextEditingController();
    final phoneController = TextEditingController();
    final ui = OrbiTheme.uiOf(context);

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
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
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
                      color: ui.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: ui.borderStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestedRole == 'AGENT'
                              ? _t(
                                  'Request agent access',
                                  'Omba ruhusa ya agent',
                                )
                              : _t(
                                  'Request merchant access',
                                  'Omba ruhusa ya merchant',
                                ),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: businessController,
                          decoration: _fieldDecoration(
                            ui,
                            requestedRole == 'AGENT'
                                ? _t(
                                    'Outlet or desk name',
                                    'Jina la kituo au desk',
                                  )
                                : _t('Business name', 'Jina la biashara'),
                            Icons.storefront_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          decoration: _fieldDecoration(
                            ui,
                            _t(
                              'Support phone (optional)',
                              'Namba ya simu ya huduma',
                            ),
                            Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: _fieldDecoration(
                            ui,
                            _t(
                              'Why do you need this access?',
                              'Kwa nini unahitaji ruhusa hii?',
                            ),
                            Icons.notes_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (noteController.text.trim().length < 3) {
                                      _showSnack(
                                        _t(
                                          'Add a short note for ORBI review.',
                                          'Weka maelezo mafupi kwa ajili ya ORBI review.',
                                        ),
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setSheetState(() => submitting = true);
                                    if (mounted) {
                                      setState(() {
                                        _busy = true;
                                        _busyMessage = requestedRole == 'AGENT'
                                            ? _t(
                                                'Submitting agent request...',
                                                'Inatuma ombi la agent...',
                                              )
                                            : _t(
                                                'Submitting merchant request...',
                                                'Inatuma ombi la merchant...',
                                              );
                                      });
                                    }
                                    try {
                                      await _accountService
                                          .submitServiceAccessRequest(
                                            requestedRole: requestedRole,
                                            businessName: businessController
                                                .text
                                                .trim(),
                                            note: noteController.text.trim(),
                                            phone: phoneController.text.trim(),
                                          );
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.pop(sheetContext);
                                      _showSnack(
                                        _t(
                                          'Your request has been submitted for ORBI review.',
                                          'Ombi lako limetumwa kwa ORBI review.',
                                        ),
                                      );
                                      await context
                                          .read<AuthController>()
                                          .refreshCurrentProfile();
                                      await _loadAll();
                                    } catch (error) {
                                      _showSnack(
                                        error.toString(),
                                        isError: true,
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _busy = false;
                                          _busyMessage = null;
                                        });
                                      }
                                      if (sheetContext.mounted) {
                                        setSheetState(() => submitting = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.how_to_reg_outlined),
                            label: Text(_t('Send request', 'Tuma ombi')),
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

  Future<void> _uploadDocument() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return;
    setState(() => _busy = true);
    try {
      await _accountService.uploadDocument(image.path);
      if (!mounted) return;
      _showSnack(_t('Document uploaded.', 'Hati imepakiwa.'));
      await _loadAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final id = _pickString([
      document['id'],
      document['document_id'],
      document['documentId'],
    ]);
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _accountService.deleteDocument(id);
      if (!mounted) return;
      _showSnack(_t('Document removed.', 'Hati imeondolewa.'));
      await _loadAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createEscrow() async {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final conditionsController = TextEditingController();
    final ui = OrbiTheme.uiOf(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
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
                      color: ui.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: ui.borderStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('ORBI PaySafe payment', 'Malipo ya ORBI PaySafe'),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t(
                            'Hold funds safely until both sides are ready for release.',
                            'Shikilia fedha kwa usalama hadi pande zote mbili ziwe tayari kuachia.',
                          ),
                          style: TextStyle(color: ui.textMuted, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: recipientController,
                          decoration: _fieldDecoration(
                            ui,
                            _t(
                              'Recipient customer ID',
                              'Namba ya mteja anayepokea',
                            ),
                            Icons.person_search_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OrbiAmountField(
                          controller: amountController,
                          inputFormatters: [AmountInputFormatter()],
                          label: _t('Amount', 'Kiasi'),
                          currency: resolveCurrencyDisplaySymbol(
                            _selectedWalletCurrencyCode,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          decoration: _fieldDecoration(
                            ui,
                            _t('Description', 'Maelezo'),
                            Icons.notes_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: conditionsController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(
                            ui,
                            _t(
                              'PaySafe release terms',
                              'Masharti ya kuachia PaySafe',
                            ),
                            Icons.rule_folder_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final amount =
                                        AmountInputFormatter.tryParse(
                                          amountController.text,
                                        );
                                    if (recipientController.text
                                            .trim()
                                            .isEmpty ||
                                        amount == null ||
                                        amount <= 0) {
                                      _showSnack(
                                        _t(
                                          'Recipient and amount are required.',
                                          'Mpokeaji na kiasi vinahitajika.',
                                        ),
                                      );
                                      return;
                                    }
                                    setSheetState(() => saving = true);
                                    try {
                                      await _escrowService.createEscrow({
                                        'recipientCustomerId':
                                            recipientController.text.trim(),
                                        'amount': amount,
                                        'description': descriptionController
                                            .text
                                            .trim(),
                                        'conditions': conditionsController.text
                                            .trim(),
                                      });
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.pop(sheetContext);
                                      _showSnack(
                                        _t(
                                          'PaySafe created successfully.',
                                          'PaySafe imeundwa vizuri.',
                                        ),
                                      );
                                      await _loadAll();
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setSheetState(() => saving = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.lock_clock_outlined),
                            label: Text(
                              saving
                                  ? _t('Creating...', 'Inaunda...')
                                  : _t('Create PaySafe', 'Unda PaySafe'),
                            ),
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

  Future<void> _escrowAction(Map<String, dynamic> escrow, String action) async {
    final referenceId = _referenceId(escrow);
    if (referenceId.isEmpty) return;

    String reason = '';
    if (action == 'dispute') {
      final controller = TextEditingController();
      final submitted = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('Raise a dispute', 'Fungua mgogoro')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: _t('Reason', 'Sababu')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('Cancel', 'Ghairi')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(_t('Send', 'Tuma')),
            ),
          ],
        ),
      );
      reason = submitted ?? '';
      if (reason.isEmpty) return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _t('Confirm PaySafe action', 'Thibitisha hatua ya PaySafe'),
        ),
        content: Text(
          action == 'release'
              ? _t(
                  'The receiver will need to accept or reject this release before funds move.',
                  'Mpokeaji atahitaji kukubali au kukataa release hii kabla fedha hazijahama.',
                )
              : action == 'accept'
              ? _t(
                  'This will confirm or accept the current PaySafe step.',
                  'Hii itathibitisha au kukubali hatua ya sasa ya PaySafe.',
                )
              : action == 'refund'
              ? _t(
                  'This will cancel instantly if not confirmed, or request a 24-hour return if already confirmed.',
                  'Hii itaghairi papo hapo kama haijathibitishwa, au kuomba return ya saa 24 kama imethibitishwa.',
                )
              : _t(
                  'Funds will stay locked while customer care reviews this PaySafe.',
                  'Fedha zitaendelea kushikiliwa wakati huduma kwa wateja wakikagua PaySafe hii.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'Ghairi')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Confirm', 'Thibitisha')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      if (action == 'release') {
        await _escrowService.releaseEscrow(referenceId);
      } else if (action == 'accept') {
        await _escrowService.acceptEscrow(referenceId);
      } else if (action == 'refund') {
        await _escrowService.refundEscrow(referenceId);
      } else {
        await _escrowService.disputeEscrow(referenceId, reason: reason);
      }
      if (!mounted) return;
      _showSnack(
        action == 'release'
            ? _t(
                'Release requested. Waiting for receiver final acceptance.',
                'Release imeombwa. Inasubiri idhini ya mwisho ya mpokeaji.',
              )
            : action == 'accept'
            ? _t('PaySafe updated successfully.', 'PaySafe imesasishwa vizuri.')
            : action == 'refund'
            ? _t('Return updated.', 'Return imesasishwa.')
            : _t('Dispute submitted.', 'Mgogoro umetumwa.'),
      );
      await _loadAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createMerchantAccount() async {
    final auth = context.read<AuthController>();
    if (!auth.isMerchant) {
      await _submitServiceAccessRequest('MERCHANT');
      return;
    }

    final nameController = TextEditingController();
    final displayController = TextEditingController();
    String category = _merchantCategories.isNotEmpty
        ? _pickString([
            _merchantCategories.first['label'],
            _merchantCategories.first['name'],
            _merchantCategories.first['value'],
          ])
        : '';
    String? walletId = _selectedWalletId;
    final ui = OrbiTheme.uiOf(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ui.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
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
                      color: ui.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: ui.borderStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Merchant account', 'Akaunti ya merchant'),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nameController,
                          decoration: _fieldDecoration(
                            ui,
                            _t('Business name', 'Jina la biashara'),
                            Icons.storefront_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: displayController,
                          decoration: _fieldDecoration(
                            ui,
                            _t('Display name', 'Jina la kuonekana'),
                            Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dropdownContainer(
                          ui,
                          Icons.category_outlined,
                          DropdownButtonFormField<String>(
                            initialValue: category.isEmpty ? null : category,
                            decoration: const InputDecoration.collapsed(
                              hintText: '',
                            ),
                            items: _merchantCategories
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: _pickString([
                                      item['label'],
                                      item['name'],
                                      item['value'],
                                    ]),
                                    child: Text(
                                      _pickString([
                                        item['label'],
                                        item['name'],
                                        item['value'],
                                      ]),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setSheetState(() => category = value ?? category);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dropdownContainer(
                          ui,
                          Icons.account_balance_wallet_outlined,
                          DropdownButtonFormField<String>(
                            initialValue: walletId,
                            decoration: const InputDecoration.collapsed(
                              hintText: '',
                            ),
                            items: _wallets
                                .map(
                                  (wallet) => DropdownMenuItem<String>(
                                    value: _walletId(wallet),
                                    child: Text(_walletLabel(wallet)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setSheetState(() => walletId = value);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (nameController.text.trim().isEmpty) {
                                      _showSnack(
                                        _t(
                                          'Business name is required.',
                                          'Jina la biashara linahitajika.',
                                        ),
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setSheetState(() => saving = true);
                                    if (mounted) {
                                      setState(() {
                                        _busy = true;
                                        _busyMessage = _t(
                                          'Submitting merchant account...',
                                          'Inatuma akaunti ya merchant...',
                                        );
                                      });
                                    }
                                    try {
                                      await _merchantService
                                          .createMerchantAccount({
                                            'businessName': nameController.text
                                                .trim(),
                                            'displayName': displayController
                                                .text
                                                .trim(),
                                            'category': category,
                                            if ((walletId ?? '').isNotEmpty)
                                              'settlementWalletId': walletId,
                                          });
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.pop(sheetContext);
                                      _showSnack(
                                        _t(
                                          'Merchant request submitted.',
                                          'Ombi la merchant limetumwa.',
                                        ),
                                      );
                                      await _loadAll();
                                    } catch (error) {
                                      _showSnack(
                                        error.toString(),
                                        isError: true,
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _busy = false;
                                          _busyMessage = null;
                                        });
                                      }
                                      if (sheetContext.mounted) {
                                        setSheetState(() => saving = false);
                                      }
                                    }
                                  },
                            icon: const Icon(
                              Icons.store_mall_directory_outlined,
                            ),
                            label: Text(
                              _t(
                                'Create merchant account',
                                'Unda akaunti ya merchant',
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final profile = context.watch<ProfileController>().profile;
    final auth = context.watch<AuthController>();
    final paySafeOnly = widget.paySafeOnly;
    final serviceAccessOnly = widget.serviceAccessOnly;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (paySafeOnly) ...[
              ServiceAssetIcon(
                assetPath: 'assets/icons/paysafe.svg',
                color: _paySafeAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
            ] else if (serviceAccessOnly) ...[
              Icon(Icons.verified_user_outlined, color: ui.iconMuted, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.titleOverride ??
                    (paySafeOnly
                        ? _t('ORBI PaySafe', 'ORBI PaySafe')
                        : serviceAccessOnly
                        ? _t('Service access', 'Ruhusa ya huduma')
                        : _t('Services', 'Huduma')),
              ),
            ),
          ],
        ),
      ),
      body: OrbiLoadingOverlay(
        loading: _busy,
        message: _busyMessage ?? _t('Working...', 'Inaendelea...'),
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () {
          if (!mounted) return;
          setState(() => _statusMessage = null);
        },
        child: OrbiBackground(
          padding: EdgeInsets.zero,
          child: SizedBox.expand(
            child: OrbiResponsiveContent(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      color: paySafeOnly ? _paySafeAccent : ui.iconMuted,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        children: [
                          if (_error != null) ...[
                            OrbiStateCard(
                              icon: Icons.info_outline,
                              title: _t(
                                'Some services are temporarily unavailable',
                                'Baadhi ya huduma hazipatikani kwa sasa',
                              ),
                              message: _error!,
                              action: ElevatedButton(
                                onPressed: _loadAll,
                                child: Text(_t('Retry', 'Jaribu tena')),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (paySafeOnly) ...[
                            _escrowSection(ui),
                          ] else if (serviceAccessOnly) ...[
                            _serviceAccessSection(ui, auth),
                          ] else ...[
                            _heroCard(ui),
                            const SizedBox(height: 14),
                            _serviceAccessSection(ui, auth),
                            const SizedBox(height: 14),
                            _collapsibleSection(
                              ui,
                              title: _t('ORBI PaySafe', 'ORBI PaySafe'),
                              subtitle: _t(
                                'Release, dispute, or refund.',
                                'Release, dispute, au refund.',
                              ),
                              icon: Icons.lock_clock_outlined,
                              expanded: _showEscrowTools,
                              onToggle: () => setState(
                                () => _showEscrowTools = !_showEscrowTools,
                              ),
                              emphasized: true,
                              child: _escrowSection(ui),
                            ),
                            if (auth.isMerchant) ...[
                              const SizedBox(height: 14),
                              _collapsibleSection(
                                ui,
                                title: _t(
                                  'Merchant tools',
                                  'Zana za mfanyabiashara',
                                ),
                                subtitle: _t(
                                  'Open for merchant account setup and merchant-only shortcuts.',
                                  'Fungua kwa usanidi wa mfanyabiashara na njia zake za mkato.',
                                ),
                                icon: Icons.storefront_outlined,
                                expanded: _showMerchantTools,
                                onToggle: () => setState(
                                  () =>
                                      _showMerchantTools = !_showMerchantTools,
                                ),
                                child: _merchantSection(ui, profile),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _collapsibleSection(
                              ui,
                              title: _t(
                                'Documents and account support',
                                'Hati na usaidizi wa akaunti',
                              ),
                              subtitle: _t(
                                'Documents and support.',
                                'Hati na usaidizi.',
                              ),
                              icon: Icons.folder_open_outlined,
                              expanded: _showAccountTools,
                              onToggle: () => setState(
                                () => _showAccountTools = !_showAccountTools,
                              ),
                              child: _accountSection(ui),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(OrbiUiTokens ui) {
    return OrbiBrandHeroCard(
      title: _t('Services and tasks', 'Huduma na kazi'),
      subtitle: _t(
        'PaySafe, account access, merchant tools, and documents.',
        'PaySafe, ruhusa za akaunti, zana za biashara, na hati.',
      ),
      icon: Icons.grid_view_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OrbiHeroMetricChip(
            label: _t('Access', 'Ruhusa'),
            value: _t('Request', 'Omba'),
            icon: Icons.verified_user_outlined,
          ),
          OrbiHeroMetricChip(
            label: _t('PaySafe', 'PaySafe'),
            value: _t('Protect', 'Linda'),
            icon: Icons.lock_clock_rounded,
          ),
          OrbiHeroMetricChip(
            label: _t('Support', 'Usaidizi'),
            value: _t('Docs', 'Hati'),
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }

  Widget _collapsibleSection(
    OrbiUiTokens ui, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    bool emphasized = false,
  }) {
    final accent = ui.iconMuted;
    return Container(
      decoration: emphasized
          ? OrbiCardStyles.elevatedCardDecoration(context, radius: 22)
          : BoxDecoration(
              color: ui.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ui.border),
            ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: emphasized
                          ? accent.withValues(alpha: 0.10)
                          : ui.iconMuted.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: emphasized
                            ? accent.withValues(alpha: 0.18)
                            : ui.border.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: emphasized ? accent : ui.iconMuted,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: emphasized
                                ? ui.textPrimary.withValues(alpha: 0.72)
                                : ui.textMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: emphasized ? accent : ui.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _serviceAccessSection(OrbiUiTokens ui, AuthController auth) {
    final role = auth.accountRole;
    final registryType = auth.registryType;
    final latestRequest = _serviceAccessRequests.isEmpty
        ? null
        : _serviceAccessRequests.first;
    final latestStatus = latestRequest == null
        ? ''
        : _requestStatusLabel(latestRequest);
    final hasPending =
        latestStatus == 'PENDING' || latestStatus == 'UNDER REVIEW';

    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            ui,
            _t('Service access', 'Ruhusa ya huduma'),
            Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip(ui, _t('Current role', 'Role ya sasa'), role),
              _metricChip(ui, _t('Registry', 'Usajili'), registryType),
              if (latestRequest != null)
                _metricChip(
                  ui,
                  _t('Last request', 'Ombi la mwisho'),
                  latestStatus,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            auth.isAgent || auth.isMerchant
                ? _t('Access enabled.', 'Ruhusa imewezeshwa.')
                : _t(
                    'Request merchant or agent access.',
                    'Omba ruhusa ya merchant au agent.',
                  ),
            style: TextStyle(color: ui.textMuted, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!auth.isMerchant)
                FilledButton.icon(
                  onPressed: hasPending
                      ? null
                      : () => _submitServiceAccessRequest('MERCHANT'),
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(_t('Request merchant', 'Omba merchant')),
                ),
              if (!auth.isAgent)
                OutlinedButton.icon(
                  onPressed: hasPending
                      ? null
                      : () => _submitServiceAccessRequest('AGENT'),
                  icon: const Icon(Icons.point_of_sale_outlined),
                  label: Text(_t('Request agent', 'Omba agent')),
                ),
              if (auth.isMerchant)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MerchantScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_outlined),
                  label: const Text('Open merchant desk'),
                ),
              if (auth.isAgent)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AgentScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_outlined),
                  label: const Text('Open agent desk'),
                ),
            ],
          ),
          if (_serviceAccessRequests.isNotEmpty) ...[
            const SizedBox(height: 14),
            ..._serviceAccessRequests
                .take(3)
                .map(
                  (request) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ui.cardMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ui.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ui.accentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _pickString([request['requested_role']]) == 'AGENT'
                                ? Icons.point_of_sale_outlined
                                : Icons.storefront_outlined,
                            color: ui.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickString([
                                  request['requested_role'],
                                  _t('Service access', 'Ruhusa ya huduma'),
                                ]),
                                style: TextStyle(
                                  color: ui.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _pickString([
                                  request['note'],
                                  request['review_note'],
                                  _t(
                                    'Awaiting ORBI review.',
                                    'Inasubiri ORBI review.',
                                  ),
                                ]),
                                style: TextStyle(color: ui.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _requestStatusLabel(request),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _escrowSection(OrbiUiTokens ui) {
    final activeEscrows = _escrows
        .where(_isActiveEscrow)
        .toList(growable: false);
    final archivedEscrows = _escrows
        .where((escrow) => !_isActiveEscrow(escrow))
        .toList(growable: false);

    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ui.border.withValues(alpha: 0.78)),
            ),
            child: Text(
              _t('ORBI PaySafe', 'ORBI PaySafe'),
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  ui,
                  _t('ORBI PaySafe', 'ORBI PaySafe'),
                  Icons.lock_clock_outlined,
                  assetPath: 'assets/icons/paysafe.svg',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _createEscrow,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(_t('New PaySafe', 'PaySafe mpya')),
                style: OutlinedButton.styleFrom(
                  backgroundColor: ui.cardMuted.withValues(alpha: 0.72),
                  foregroundColor: ui.textPrimary,
                  side: BorderSide(color: ui.border.withValues(alpha: 0.82)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t('Protected payments.', 'Malipo yaliyolindwa.'),
            style: TextStyle(color: ui.textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          if (_escrows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              decoration: BoxDecoration(
                color: ui.cardMuted.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ui.border.withValues(alpha: 0.84)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _paySafeAccent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _paySafeAccent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_moon_outlined,
                      color: _paySafeAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('No PaySafe yet', 'Bado huna PaySafe'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Create one when you want money held safely until both sides are ready.',
                      'Unda PaySafe pale unapotaka fedha zishikiliwe salama hadi pande zote ziwe tayari.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ui.textMuted, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _createEscrow,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(_t('Create PaySafe', 'Unda PaySafe')),
                  ),
                ],
              ),
            )
          else ...[
            if (activeEscrows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _t(
                    'Released, refunded, and completed PaySafe items move out of the active queue.',
                    'PaySafe zilizokamilika, kurejeshwa, au kuachiwa huondolewa kwenye foleni ya active.',
                  ),
                  style: TextStyle(color: ui.textMuted, height: 1.45),
                ),
              )
            else
              ...activeEscrows
                  .take(5)
                  .map(
                    (escrow) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ui.cardMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ui.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _referenceId(escrow),
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _statusTag(
                                ui,
                                _pickString([
                                  escrow['status'],
                                  escrow['state'],
                                  _t('Pending', 'Inasubiri'),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pickString([
                              escrow['description'],
                              escrow['note'],
                              _escrowSummary(escrow),
                              _t(
                                'Protected transfer',
                                'Uhamisho uliohifadhiwa',
                              ),
                            ]),
                            style: TextStyle(color: ui.textMuted),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _metricChip(
                                ui,
                                _t('Amount', 'Kiasi'),
                                _money(
                                  _pickDouble([
                                    escrow['amount'],
                                    escrow['value'],
                                  ]),
                                  _pickString([
                                    escrow['currency'],
                                    escrow['currency_code'],
                                    _walletCurrency(
                                      _wallets.isEmpty ? null : _wallets.first,
                                    ),
                                  ]),
                                ),
                              ),
                              if (_canAccept(escrow))
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _escrowAction(escrow, 'accept'),
                                  child: Text(_t('Accept Hold', 'Kubali Hold')),
                                ),
                              if (_canRelease(escrow))
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _escrowAction(escrow, 'release'),
                                  child: Text(_t('Release', 'Achia')),
                                ),
                              if (_canDispute(escrow))
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _escrowAction(escrow, 'dispute'),
                                  child: Text(_t('Dispute', 'Mgogoro')),
                                ),
                              if (_canRefund(escrow))
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _escrowAction(escrow, 'refund'),
                                  child: Text(_t('Refund', 'Rudisha')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            if (archivedEscrows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _t('Resolved history', 'Historia iliyokamilika'),
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...archivedEscrows
                  .take(3)
                  .map(
                    (escrow) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ui.cardMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ui.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _referenceId(escrow),
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _statusTag(
                                ui,
                                _pickString([
                                  escrow['status'],
                                  escrow['state'],
                                  _t('Completed', 'Imekamilika'),
                                ]),
                                subdued: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pickString([
                              escrow['description'],
                              escrow['note'],
                              _escrowSummary(escrow),
                            ]),
                            style: TextStyle(color: ui.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _merchantSection(OrbiUiTokens ui, Map<String, dynamic> profile) {
    final auth = context.watch<AuthController>();
    final eligible = _merchantAccounts.isNotEmpty || profile.isNotEmpty;
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  ui,
                  _t('Merchant Lite', 'Merchant Lite'),
                  Icons.storefront_outlined,
                ),
              ),
              FilledButton.icon(
                onPressed: _createMerchantAccount,
                icon: Icon(
                  auth.isMerchant
                      ? Icons.add_business_outlined
                      : Icons.verified_user_outlined,
                ),
                label: Text(
                  auth.isMerchant
                      ? _t('Create', 'Unda')
                      : _t('Request', 'Omba'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_merchantCategories.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _merchantCategories.take(8).map((item) {
                return _statusTag(
                  ui,
                  _pickString([item['label'], item['name'], item['value']]),
                  subdued: true,
                );
              }).toList(),
            ),
          if (_merchantAccounts.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              eligible
                  ? _t(
                      'No merchant account is active yet. You can request one from here without leaving the consumer app.',
                      'Hakuna akaunti ya merchant inayotumika bado. Unaweza kuiomba hapa bila kuondoka kwenye app ya mtumiaji.',
                    )
                  : _t(
                      'Merchant tools stay lightweight here and do not expose any admin or organization management.',
                      'Zana za mfanyabiashara hapa ni nyepesi na hazionyeshi usimamizi wa admin au organization.',
                    ),
              style: TextStyle(color: ui.textMuted, height: 1.45),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ..._merchantAccounts
                .take(4)
                .map(
                  (account) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ui.cardMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ui.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickString([
                            account['displayName'],
                            account['display_name'],
                            account['businessName'],
                            account['business_name'],
                          ]),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pickString([
                            account['category'],
                            account['merchant_type'],
                            _t('Merchant account', 'Akaunti ya merchant'),
                          ]),
                          style: TextStyle(color: ui.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _accountSection(OrbiUiTokens ui) {
    return OrbiSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            ui,
            _t('Documents & Account', 'Hati na Akaunti'),
            Icons.folder_open_outlined,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _uploadDocument,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(_t('Upload document', 'Pakia hati')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip(ui, _t('Documents', 'Hati'), '${_documents.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t('Upload and manage documents.', 'Pakia na simamia hati.'),
            style: TextStyle(color: ui.textMuted, height: 1.45),
          ),
          if (_documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._documents
                .take(3)
                .map(
                  (document) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: ui.iconMuted.withValues(alpha: 0.14),
                      child: Icon(
                        Icons.description_outlined,
                        color: ui.iconMuted,
                      ),
                    ),
                    title: Text(
                      _pickString([
                        document['name'],
                        document['file_name'],
                        document['title'],
                        _t('Document', 'Hati'),
                      ]),
                    ),
                    subtitle: Text(
                      _pickString([
                        _accountService.displayFileSize(document['size']),
                        document['content_type'],
                        document['mimeType'],
                      ]),
                    ),
                    trailing: IconButton(
                      onPressed: _busy ? null : () => _deleteDocument(document),
                      icon: Icon(Icons.delete_outline, color: ui.danger),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(
    OrbiUiTokens ui,
    String title,
    IconData icon, {
    String? assetPath,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _screenAccent;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.14),
                isDark ? ui.cardStrong.withValues(alpha: 0.9) : Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: assetPath == null
              ? Icon(icon, color: accent)
              : Center(
                  child: ServiceAssetIcon(
                    assetPath: assetPath,
                    color: accent,
                    size: 20,
                  ),
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
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _t('Curated service tools', 'Zana za huduma zilizopangwa'),
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

  Widget _metricChip(OrbiUiTokens ui, String label, String value) {
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
        borderRadius: BorderRadius.circular(16),
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
          Text(
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

  Widget _statusTag(OrbiUiTokens ui, String label, {bool subdued = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successText = isDark
        ? const Color(0xFFDDFBEF)
        : const Color(0xFF0E513F);
    final successBackground = isDark
        ? ui.success.withValues(alpha: 0.14)
        : const Color(0xFFE7F4ED);
    final successBorder = isDark
        ? ui.success.withValues(alpha: 0.36)
        : const Color(0xFF8FC9B5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subdued ? ui.cardMuted : successBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: subdued ? ui.border : successBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: subdued ? ui.textPrimary : successText,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _dropdownContainer(OrbiUiTokens ui, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ui.iconMuted),
          const SizedBox(width: 10),
          Expanded(child: child),
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
    final accent = _screenAccent;
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixStyle: prefixText == null
          ? null
          : TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w800),
      prefixIcon: Icon(icon, color: accent),
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
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
  }
}
