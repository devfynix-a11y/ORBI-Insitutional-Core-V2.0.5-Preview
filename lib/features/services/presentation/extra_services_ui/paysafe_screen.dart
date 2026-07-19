import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/state/app_runtime_cache.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/utils/backend_status_message.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/orbi_amount_field.dart';
import '../../../../core/widgets/orbi_async_feedback.dart';
import '../../../payment/data/escrow_service.dart';
import '../../../profile/data/profile_service.dart';
import '../../../notifications/state/notification_controller.dart';

class PaySafeScreen extends StatefulWidget {
  const PaySafeScreen({super.key});

  @override
  State<PaySafeScreen> createState() => _PaySafeScreenState();
}

class _PaySafeScreenState extends State<PaySafeScreen>
    with SingleTickerProviderStateMixin {
  final EscrowService _escrowService = EscrowService();
  late final AnimationController _orbitController;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _escrows = const [];
  Set<String> _trashedHistoryRefs = const {};
  Set<String> _currentIdentityTokens = const {};
  StreamSubscription<Map<String, dynamic>>? _paySafeRealtimeSubscription;
  Timer? _paySafeRealtimeDebounce;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTrashedHistoryRefs();
      if (!mounted) return;
      await _loadPaySafe();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paySafeRealtimeSubscription ??= context
        .read<NotificationController>()
        .balanceUpdates
        .listen(_handlePaySafeRealtimeEvent);
  }

  @override
  void dispose() {
    _paySafeRealtimeDebounce?.cancel();
    _paySafeRealtimeSubscription?.cancel();
    _orbitController.dispose();
    super.dispose();
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String get _localeTag => _isSw ? 'sw_TZ' : 'en_US';

  String _t(String en, String sw) => _isSw ? sw : en;

  static const String _trashedHistoryPrefsKey = 'paysafe_trashed_history_refs';

  Future<void> _loadTrashedHistoryRefs() async {
    final prefs = await SharedPreferences.getInstance();
    final refs =
        prefs
            .getStringList(_trashedHistoryPrefsKey)
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        const <String>{};
    if (!mounted) return;
    setState(() => _trashedHistoryRefs = refs);
  }

  Future<void> _rememberTrashedHistoryRefs(Set<String> refs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_trashedHistoryPrefsKey, refs.toList()..sort());
  }

  Future<void> _trashHistoryItem(Map<String, dynamic> escrow) async {
    final reference = _referenceId(escrow);
    if (reference.isEmpty) return;
    final next = {..._trashedHistoryRefs, reference};
    await _rememberTrashedHistoryRefs(next);
    if (!mounted) return;
    setState(() => _trashedHistoryRefs = next);
    _showSnack(
      _t('PaySafe moved to trash.', 'PaySafe imepelekwa kwenye trash.'),
    );
  }

  Future<void> _clearVisibleHistory(List<Map<String, dynamic>> escrows) async {
    final references = escrows
        .map(_referenceId)
        .where((reference) => reference.isNotEmpty)
        .toSet();
    if (references.isEmpty) return;
    final confirmed = await _confirmAction(
      title: _t('Trash history?', 'Tupa historia?'),
      message: _t(
        'This only hides completed PaySafe items from this device. Audit records remain available.',
        'Hii inaficha PaySafe zilizokamilika kwenye kifaa hiki tu. Rekodi za audit zinabaki salama.',
      ),
      confirmLabel: _t('Trash', 'Tupa'),
    );
    if (!confirmed) return;
    final next = {..._trashedHistoryRefs, ...references};
    await _rememberTrashedHistoryRefs(next);
    if (!mounted) return;
    setState(() => _trashedHistoryRefs = next);
    _showSnack(_t('PaySafe history hidden.', 'Historia ya PaySafe imefichwa.'));
  }

  Future<void> _restoreTrashedHistory() async {
    if (_trashedHistoryRefs.isEmpty) return;
    final confirmed = await _confirmAction(
      title: _t('Restore history?', 'Rudisha historia?'),
      message: _t(
        'Completed PaySafe references hidden on this device will appear in History again.',
        'PaySafe references zilizofichwa kwenye kifaa hiki zitaonekana tena kwenye Historia.',
      ),
      confirmLabel: _t('Restore', 'Rudisha'),
    );
    if (!confirmed) return;
    await _rememberTrashedHistoryRefs(const <String>{});
    if (!mounted) return;
    setState(() => _trashedHistoryRefs = const <String>{});
    _showSnack(
      _t('PaySafe history restored.', 'Historia ya PaySafe imerudishwa.'),
    );
  }

  Future<void> _copyReference(String reference) async {
    if (reference.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: reference));
    if (!mounted) return;
    _showSnack(_t('PaySafe ID copied.', 'ID ya PaySafe imenakiliwa.'));
  }

  List<Map<String, dynamic>> _historyEscrows() {
    return _escrows
        .where((escrow) {
          if (_isActiveEscrow(escrow)) return false;
          final reference = _referenceId(escrow);
          return reference.isEmpty || !_trashedHistoryRefs.contains(reference);
        })
        .toList(growable: false);
  }

  Future<void> _openPaySafeMenu() async {
    final colors = OrbiTheme.uiOf(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final history = _historyEscrows();
            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.38,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t('PaySafe menu', 'Menu ya PaySafe'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colors.textPrimary,
                                  ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: _t('Refresh', 'Sasisha'),
                            onPressed: _busy
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    _loadPaySafe();
                                  },
                            icon: const Icon(Icons.sync_rounded),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: _t('Close', 'Funga'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Completed PaySafe references are kept here so your active queue stays clean.',
                          'PaySafe zilizokamilika zinabaki hapa ili orodha ya zinazoendelea ibaki safi.',
                        ),
                        style: TextStyle(color: colors.textMuted, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _PaySafeMenuAction(
                              icon: Icons.add_rounded,
                              label: _t('New PaySafe', 'PaySafe mpya'),
                              onTap: _busy
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      _createPaySafe();
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PaySafeMenuAction(
                              icon: Icons.delete_sweep_rounded,
                              label: _t('Trash all', 'Tupa zote'),
                              onTap: history.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      _clearVisibleHistory(history);
                                    },
                            ),
                          ),
                        ],
                      ),
                      if (_trashedHistoryRefs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PaySafeMenuAction(
                          icon: Icons.restore_rounded,
                          label: _t(
                            'Restore trashed history',
                            'Rudisha historia iliyotupwa',
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _restoreTrashedHistory();
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        _t('History', 'Historia'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 10),
                      if (history.isEmpty)
                        _PaySafeEmptyState(
                          icon: Icons.history_rounded,
                          title: _t(
                            'No completed PaySafe',
                            'Hakuna PaySafe iliyokamilika',
                          ),
                          message: _t(
                            'Released, refunded, and closed PaySafe references will appear here.',
                            'PaySafe zilizoachiwa, kurejeshwa, au kufungwa zitaonekana hapa.',
                          ),
                          actionLabel: _t('Refresh', 'Sasisha'),
                          onAction: _busy
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _loadPaySafe();
                                },
                        )
                      else
                        for (final escrow in history) ...[
                          _PaySafeHistoryTile(
                            title: _title(escrow),
                            reference: _referenceId(escrow),
                            status: _status(escrow),
                            amount: _amount(escrow),
                            summary: _holdSummary(escrow),
                            isSw: _isSw,
                            onCopy: () => _copyReference(_referenceId(escrow)),
                            onTrash: () async {
                              await _trashHistoryItem(escrow);
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadPaySafe({bool quiet = false}) async {
    if (!mounted) return;
    setState(() {
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      _primeCurrentIdentityFromCache();
      final escrows = await _escrowService.listEscrows().timeout(
        const Duration(seconds: 10),
      );
      if (_currentIdentityTokens.isEmpty) {
        await _refreshCurrentIdentity().timeout(
          const Duration(seconds: 4),
          onTimeout: () => const <String>{},
        );
      } else {
        unawaited(_refreshCurrentIdentity());
      }
      if (!mounted) return;
      setState(() {
        _escrows = escrows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _escrows = const [];
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  void _handlePaySafeRealtimeEvent(Map<String, dynamic> event) {
    final text = event.toString().toLowerCase();
    final isPaySafeEvent =
        text.contains('paysafe') ||
        text.contains('pay_safe') ||
        text.contains('escrow') ||
        text.contains('release') ||
        text.contains('refund') ||
        text.contains('return_pending');
    if (!isPaySafeEvent) return;
    _paySafeRealtimeDebounce?.cancel();
    _paySafeRealtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _loading) return;
      unawaited(_loadPaySafe(quiet: true));
    });
  }

  Future<void> _createPaySafe() async {
    final result = await showModalBottomSheet<_PaySafeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaySafeCreateSheet(isSw: _isSw),
    );
    if (result == null) return;
    final confirmed = await _confirmPaySafeCreation(result);
    if (!confirmed) return;
    final idempotencyKey = _escrowService.createIdempotencyKey(
      'paysafe-create',
    );

    await _runAction(
      success: _t('PaySafe created.', 'PaySafe imeundwa.'),
      action: () => _escrowService.createEscrow({
        'recipientCustomerId': result.recipientId,
        if (result.recipientUserId.isNotEmpty)
          'recipientUserId': result.recipientUserId,
        if (result.recipientCustomerId.isNotEmpty)
          'recipient_customer_id': result.recipientCustomerId,
        if (result.recipientIdentifier.isNotEmpty)
          'identifier': result.recipientIdentifier,
        'amount': result.amount,
        'description': result.description,
        'conditions': {
          'terms': result.terms,
          'holdWindowHours': result.holdWindowHours,
          'releaseRequiresReceiverAcceptance': true,
        },
      }, idempotencyKey: idempotencyKey),
      referenceId: null,
      actionType: 'create',
    );
  }

  Future<bool> _confirmPaySafeCreation(_PaySafeDraft draft) async {
    final amount = formatAppBalanceAmount(
      draft.amount,
      'TZS',
      locale: _isSw ? 'sw_TZ' : 'en_US',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = OrbiTheme.uiOf(dialogContext);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.successSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.verified_user_rounded, color: colors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Confirm PaySafe', 'Thibitisha PaySafe'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.successSoft.withValues(alpha: 0.88),
                        colors.cardMuted.withValues(alpha: 0.72),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.success.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    _t(
                      'Money is safe until you confirm release.',
                      'Fedha ziko salama hadi uthibitishe kuziachia.',
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PaySafeConfirmRow(
                  label: _t('Receiver', 'Mpokeaji'),
                  value: draft.recipientName,
                ),
                _PaySafeConfirmRow(
                  label: _t('Amount', 'Kiasi'),
                  value: amount,
                  highlight: true,
                ),
                _PaySafeConfirmRow(
                  label: _t('Hold window', 'Muda wa hold'),
                  value: _t(
                    '${draft.holdWindowHours} hours',
                    'Saa ${draft.holdWindowHours}',
                  ),
                ),
                _PaySafeConfirmRow(
                  label: _t('Purpose', 'Sababu'),
                  value: draft.description,
                ),
                _PaySafeConfirmRow(
                  label: _t('Release terms', 'Masharti'),
                  value: draft.terms,
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'We will notify both sides after this PaySafe is created.',
                    'Tutawajulisha pande zote baada ya PaySafe hii kuundwa.',
                  ),
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Review', 'Pitia tena')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.lock_rounded),
              label: Text(_t('Confirm & Create', 'Thibitisha na Unda')),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _releasePaySafe(Map<String, dynamic> escrow) async {
    final referenceId = _referenceId(escrow);
    if (referenceId.isEmpty) {
      _showSnack(
        _t(
          'This PaySafe cannot be released yet.',
          'PaySafe hii haiwezi kuachiwa kwa sasa.',
        ),
        isError: true,
      );
      return;
    }
    final confirmed = await _confirmAction(
      title: _t('Request release?', 'Omba release?'),
      message: _t(
        'The receiver will be asked to accept or reject this release before funds move.',
        'Mpokeaji ataombwa kukubali au kukataa release hii kabla fedha hazijahama.',
      ),
      confirmLabel: _t('Request release', 'Omba release'),
    );
    if (!confirmed) return;
    await _runAction(
      success: _t(
        'Release requested. Waiting for receiver final acceptance.',
        'Release imeombwa. Inasubiri idhini ya mwisho ya mpokeaji.',
      ),
      action: () => _escrowService.releaseEscrow(
        referenceId,
        idempotencyKey: _escrowService.createIdempotencyKey('paysafe-release'),
      ),
      referenceId: referenceId,
      actionType: 'release',
    );
  }

  Future<void> _acceptPaySafe(Map<String, dynamic> escrow) async {
    final referenceId = _referenceId(escrow);
    if (referenceId.isEmpty) {
      _showSnack(
        _t(
          'This PaySafe cannot be accepted yet.',
          'PaySafe hii haiwezi kukubaliwa kwa sasa.',
        ),
        isError: true,
      );
      return;
    }
    final confirmed = await _confirmAction(
      title: _isReturnPending(escrow)
          ? _t('Accept return?', 'Kubali return?')
          : _isReleasePending(escrow)
          ? _t('Accept release?', 'Kubali release?')
          : _t('Confirm PaySafe?', 'Thibitisha PaySafe?'),
      message: _isReturnPending(escrow)
          ? _t(
              'Funds will return to the sender and this PaySafe will close.',
              'Fedha zitarudi kwa mtumaji na PaySafe hii itafungwa.',
            )
          : _isReleasePending(escrow)
          ? _t(
              'Funds will be credited to your account.',
              'Fedha zitaingia kwenye akaunti yako.',
            )
          : _t(
              'This confirms the hold. Funds will remain locked until the sender requests release.',
              'Hii inathibitisha hold. Fedha zitaendelea kushikiliwa hadi mtumaji aombe release.',
            ),
      confirmLabel: _isReleasePending(escrow)
          ? _t('Accept release', 'Kubali release')
          : _t('Confirm', 'Thibitisha'),
    );
    if (!confirmed) return;
    await _runAction(
      success: _isReturnPending(escrow)
          ? _t(
              'Return accepted. Funds will go back to the sender.',
              'Return imekubaliwa. Fedha zitarudi kwa mtumaji.',
            )
          : _isReleasePending(escrow)
          ? _t(
              'Release accepted. Funds have been credited to your account.',
              'Release imekubaliwa. Fedha zimeingia kwenye akaunti yako.',
            )
          : _t(
              'PaySafe confirmed. Waiting for sender release.',
              'PaySafe imethibitishwa. Inasubiri mtumaji a-release.',
            ),
      action: () => _escrowService.acceptEscrow(
        referenceId,
        idempotencyKey: _escrowService.createIdempotencyKey('paysafe-accept'),
      ),
      referenceId: referenceId,
      actionType: 'accept',
    );
  }

  Future<void> _refundPaySafe(Map<String, dynamic> escrow) async {
    final referenceId = _referenceId(escrow);
    if (referenceId.isEmpty) {
      _showSnack(
        _t(
          'This PaySafe cannot be refunded yet.',
          'PaySafe hii haiwezi kurejeshwa kwa sasa.',
        ),
        isError: true,
      );
      return;
    }
    final confirmed = await _confirmAction(
      title: _receiverAccepted(escrow)
          ? _t('Request return?', 'Omba return?')
          : _t('Cancel PaySafe?', 'Ghairi PaySafe?'),
      message: _receiverAccepted(escrow)
          ? _t(
              'Because the receiver already confirmed, this will send a return request with a 24-hour response window.',
              'Kwa kuwa mpokeaji ameshathibitisha, hii itatuma ombi la return lenye dirisha la saa 24.',
            )
          : _t(
              'The receiver has not confirmed yet, so funds will return instantly.',
              'Mpokeaji bado hajathibitisha, hivyo fedha zitarudi papo hapo.',
            ),
      confirmLabel: _receiverAccepted(escrow)
          ? _t('Request return', 'Omba return')
          : _t('Cancel PaySafe', 'Ghairi PaySafe'),
    );
    if (!confirmed) return;
    await _runAction(
      success: _receiverAccepted(escrow)
          ? _t(
              'Return requested. Receiver has 24 hours to accept or dispute.',
              'Ombi la kurudisha limetumwa. Mpokeaji ana saa 24 kukubali au kufungua pingamizi.',
            )
          : _t(
              'PaySafe cancelled. Funds are returning instantly.',
              'PaySafe imeghairiwa. Fedha zinarudi papo hapo.',
            ),
      action: () => _escrowService.refundEscrow(
        referenceId,
        idempotencyKey: _escrowService.createIdempotencyKey('paysafe-refund'),
      ),
      referenceId: referenceId,
      actionType: 'refund',
    );
  }

  Future<void> _disputePaySafe(Map<String, dynamic> escrow) async {
    final referenceId = _referenceId(escrow);
    if (referenceId.isEmpty) {
      _showSnack(
        _t(
          'This PaySafe cannot be disputed yet.',
          'PaySafe hii haiwezi kupingwa kwa sasa.',
        ),
        isError: true,
      );
      return;
    }
    final reason = await _askDisputeReason();
    if (reason == null || reason.trim().isEmpty) return;
    final confirmed = await _confirmAction(
      title: _t('Open dispute?', 'Fungua pingamizi?'),
      message: _t(
        'Funds will stay locked while customer care reviews this PaySafe.',
        'Fedha zitaendelea kushikiliwa wakati huduma kwa wateja wakikagua PaySafe hii.',
      ),
      confirmLabel: _t('Open dispute', 'Fungua pingamizi'),
    );
    if (!confirmed) return;
    await _runAction(
      success: _t('Dispute submitted.', 'Pingamizi limetumwa.'),
      action: () => _escrowService.disputeEscrow(
        referenceId,
        reason: reason.trim(),
        idempotencyKey: _escrowService.createIdempotencyKey('paysafe-dispute'),
      ),
      referenceId: referenceId,
      actionType: 'dispute',
    );
  }

  Future<String?> _askDisputeReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('Dispute PaySafe', 'Fungua pingamizi la PaySafe')),
          content: TextField(
            controller: controller,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: _t(
                'Tell us what needs review',
                'Eleza tatizo au sababu ya ukaguzi',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Cancel', 'Ghairi')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(_t('Submit', 'Tuma')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Cancel', 'Ghairi')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _runAction({
    required Future<dynamic> Function() action,
    required String success,
    required String? referenceId,
    required String actionType,
  }) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final rawResult = await action().timeout(const Duration(seconds: 16));
      final result = rawResult is Map
          ? Map<String, dynamic>.from(rawResult)
          : const <String, dynamic>{};
      if (actionType == 'create') {
        await _loadPaySafe(quiet: true);
      } else if (referenceId != null && referenceId.isNotEmpty) {
        _mergeEscrowMutation(referenceId, (current) {
          return _resolveActionUpdate(
            current: current,
            response: result,
            action: actionType,
          );
        });
      }
      if (!mounted) return;
      _showSnack(success);
      unawaited(_loadPaySafe(quiet: true));
    } catch (error) {
      if (!mounted) return;
      if (_isActionPendingError(error)) {
        setState(() => _busy = false);
        if (referenceId != null && referenceId.isNotEmpty) {
          _mergeEscrowMutation(referenceId, (current) {
            return _resolveActionUpdate(
              current: current,
              response: const {'client_pending_confirmation': true},
              action: actionType,
            );
          });
        }
        _showSnack(
          _t(
            'PaySafe action was sent. We are confirming the final status.',
            'Hatua ya PaySafe imetumwa. Tunathibitisha status ya mwisho.',
          ),
        );
        unawaited(
          _refreshAfterPendingAction(
            referenceId: referenceId,
            actionType: actionType,
          ),
        );
        return;
      }
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isActionPendingError(Object error) {
    if (error is TimeoutException) return true;
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return false;
  }

  Future<void> _refreshAfterPendingAction({
    required String? referenceId,
    required String actionType,
  }) async {
    final delays = <Duration>[
      const Duration(milliseconds: 800),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 7),
    ];

    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        if (referenceId != null && referenceId.isNotEmpty) {
          final latest = await _escrowService
              .getEscrow(referenceId)
              .timeout(const Duration(seconds: 6));
          if (!mounted) return;
          if (latest.isNotEmpty) {
            _mergeEscrowMutation(referenceId, (current) {
              return _resolveActionUpdate(
                current: current,
                response: latest,
                action: actionType,
              );
            });
          }
        }
        await _loadPaySafe(quiet: true);
      } catch (_) {
        if (!mounted) return;
        await _loadPaySafe(quiet: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = OrbiTheme.uiOf(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? colors.danger : colors.success,
          content: Text(message),
        ),
      );
  }

  String _friendlyError(Object error) {
    String raw = error.toString();
    if (error is TimeoutException) {
      raw = _t(
        'PaySafe is taking longer than expected. Please try again.',
        'PaySafe inachukua muda kuliko kawaida. Tafadhali jaribu tena.',
      );
    } else if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        // Prefer machine-readable codes so localized business guidance is not
        // masked by a generic gateway message.
        raw = (data['code'] ?? data['error'] ?? data['message'] ?? data)
            .toString();
      } else {
        raw = error.message ?? raw;
      }
    }
    return mapBackendStatusMessage(
      raw,
      sw: _isSw,
      fallback: _t(
        'PaySafe is temporarily unavailable. Please try again.',
        'PaySafe haipatikani kwa muda. Tafadhali jaribu tena.',
      ),
    );
  }

  String _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  double _pickDouble(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('${value ?? ''}'.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _referenceId(Map<String, dynamic> escrow) => _pickString([
    escrow['referenceId'],
    escrow['reference_id'],
    escrow['reference'],
    escrow['id'],
  ]);

  bool _pickBool(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }
    return false;
  }

  void _primeCurrentIdentityFromCache() {
    final tokens = _identityTokensFrom(AppRuntimeCache.profile);
    if (tokens.isNotEmpty) {
      _currentIdentityTokens = tokens;
    }
  }

  Future<Set<String>> _refreshCurrentIdentity() async {
    try {
      final profile = await ProfileService().fetchProfile();
      final tokens = _identityTokensFrom(profile);
      if (tokens.isNotEmpty) {
        AppRuntimeCache.rememberProfile(profile);
        if (mounted) {
          setState(() => _currentIdentityTokens = tokens);
        } else {
          _currentIdentityTokens = tokens;
        }
      }
      return tokens;
    } catch (_) {
      return _currentIdentityTokens;
    }
  }

  Set<String> _identityTokensFrom(Map<String, dynamic>? source) {
    if (source == null) return const {};
    final tokens = <String>{};

    void add(dynamic value) {
      final normalized = _identityToken(value);
      if (normalized.isNotEmpty) tokens.add(normalized);
    }

    void addFromMap(Map<dynamic, dynamic> map) {
      for (final key in const [
        'id',
        'uid',
        'user_id',
        'userId',
        'customer_id',
        'customerId',
        'orbi_id',
        'orbiId',
        'account_id',
        'accountId',
        'phone',
        'mobile',
        'mobile_number',
        'mobileNumber',
        'email',
      ]) {
        add(map[key]);
      }
      for (final key in const ['user', 'profile', 'account', 'metadata']) {
        final nested = map[key];
        if (nested is Map) addFromMap(nested);
      }
    }

    addFromMap(source);
    return tokens;
  }

  String _identityToken(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty || raw == 'null') return '';
    return raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  bool _matchesCurrentIdentity(Iterable<dynamic> values) {
    final tokens = _currentIdentityTokens;
    if (tokens.isEmpty) return false;
    for (final value in values) {
      final token = _identityToken(value);
      if (token.isNotEmpty && tokens.contains(token)) return true;
    }
    return false;
  }

  DateTime? _pickDate(Iterable<dynamic> values) {
    for (final value in values) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty || raw.toLowerCase() == 'null') continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  String _normalizedStatus(Map<String, dynamic> escrow) {
    return _pickString([
      escrow['status'],
      escrow['state'],
      escrow['escrow_status'],
    ]).toUpperCase();
  }

  String _actorRole(Map<String, dynamic> escrow) {
    final raw = _pickString([
      escrow['actorRole'],
      escrow['actor_role'],
      escrow['viewerRole'],
      escrow['viewer_role'],
      escrow['currentUserRole'],
      escrow['current_user_role'],
      escrow['relationship'],
      escrow['side'],
      escrow['direction'],
    ]).toLowerCase();
    final normalized = raw.replaceAll('-', '_').replaceAll(' ', '_');
    if ([
      'sender',
      'initiator',
      'payer',
      'source',
      'creator',
      'created_by_you',
    ].contains(normalized)) {
      return 'sender';
    }
    if ([
      'receiver',
      'recipient',
      'beneficiary',
      'payee',
      'seller',
      'acceptor',
      'destination',
    ].contains(normalized)) {
      return 'receiver';
    }
    if (normalized == 'incoming' || normalized == 'inbound') {
      return 'receiver';
    }
    if (normalized == 'outgoing' || normalized == 'outbound') {
      return 'sender';
    }
    if (_pickBool([
      escrow['isSender'],
      escrow['is_sender'],
      escrow['actorIsSender'],
      escrow['actor_is_sender'],
    ])) {
      return 'sender';
    }
    if (_pickBool([
      escrow['isReceiver'],
      escrow['is_receiver'],
      escrow['isRecipient'],
      escrow['is_recipient'],
      escrow['actorIsReceiver'],
      escrow['actor_is_receiver'],
    ])) {
      return 'receiver';
    }
    final metadata = escrow['metadata'] is Map
        ? Map<dynamic, dynamic>.from(escrow['metadata'] as Map)
        : const <dynamic, dynamic>{};
    final transaction = escrow['transaction'] is Map
        ? Map<dynamic, dynamic>.from(escrow['transaction'] as Map)
        : const <dynamic, dynamic>{};
    if (_matchesCurrentIdentity([
      escrow['sender_id'],
      escrow['senderId'],
      escrow['sender_user_id'],
      escrow['senderUserId'],
      escrow['payer_id'],
      escrow['payerId'],
      escrow['initiator_id'],
      escrow['initiatorId'],
      escrow['created_by'],
      escrow['createdBy'],
      metadata['sender_id'],
      metadata['senderId'],
      metadata['payer_id'],
      metadata['payerId'],
      transaction['user_id'],
      transaction['userId'],
    ])) {
      return 'sender';
    }
    if (_matchesCurrentIdentity([
      escrow['receiver_id'],
      escrow['receiverId'],
      escrow['receiver_user_id'],
      escrow['receiverUserId'],
      escrow['recipient_id'],
      escrow['recipientId'],
      escrow['recipient_user_id'],
      escrow['recipientUserId'],
      escrow['recipient_customer_id'],
      escrow['recipientCustomerId'],
      escrow['beneficiary_id'],
      escrow['beneficiaryId'],
      escrow['payee_id'],
      escrow['payeeId'],
      metadata['receiver_id'],
      metadata['receiverId'],
      metadata['recipient_id'],
      metadata['recipientId'],
      metadata['recipient_customer_id'],
      metadata['recipientCustomerId'],
    ])) {
      return 'receiver';
    }
    return normalized;
  }

  bool _availableActionFlag(Map<String, dynamic> escrow, String action) {
    final actions = escrow['availableActions'] ?? escrow['available_actions'];
    if (actions is Map) {
      final normalized = Map<String, dynamic>.from(actions);
      return _pickBool([
        normalized[action],
        normalized[action.toLowerCase()],
        normalized[action.toUpperCase()],
      ]);
    }
    if (actions is Iterable) {
      return actions
          .map((value) => value.toString().trim().toLowerCase())
          .contains(action.toLowerCase());
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
        status.contains('PENDING_RELEASE') ||
        status.contains('AWAITING_RECEIVER_ACCEPTANCE');
  }

  bool _isAwaitingReceiverAcceptance(Map<String, dynamic> escrow) {
    if (_isReleasePending(escrow)) return true;
    if (_receiverAccepted(escrow)) return false;
    final status = _normalizedStatus(escrow);
    if (status == 'HELD') return true;
    return status.contains('AWAIT') ||
        status.contains('PENDING_ACCEPT') ||
        status.contains('PENDING_RECEIVER') ||
        status.contains('RECEIVER_CONFIRM') ||
        status.contains('RECIPIENT_CONFIRM') ||
        status.contains('CREATED') ||
        status.contains('FUNDED') ||
        status.contains('RELEASE_PENDING') ||
        status.contains('RELEASE_REQUESTED') ||
        status.contains('HOLD_ACCEPTANCE') ||
        status.contains('ACCEPTANCE');
  }

  bool _isActiveEscrow(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    return !_isTerminalStatus(status) && !status.contains('ARCHIVE');
  }

  _PaySafeSide _actorSide(Map<String, dynamic> escrow) {
    final role = _actorRole(escrow);
    if (role == 'sender') return _PaySafeSide.sender;
    if (role == 'receiver') return _PaySafeSide.receiver;
    return _PaySafeSide.unknown;
  }

  _PaySafeStage _stageOf(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    if (_isTerminalStatus(status)) return _PaySafeStage.closed;
    if (_isBlockedStatus(status)) return _PaySafeStage.review;
    if (_isReturnPending(escrow)) return _PaySafeStage.returnPending;
    if (_isReleasePending(escrow)) return _PaySafeStage.releasePending;
    if (_receiverAccepted(escrow)) return _PaySafeStage.held;
    if (_isAwaitingReceiverAcceptance(escrow)) {
      return _PaySafeStage.awaitingReceiver;
    }
    return _PaySafeStage.awaitingReceiver;
  }

  String _sideLabel(Map<String, dynamic> escrow) {
    switch (_actorSide(escrow)) {
      case _PaySafeSide.sender:
        return _t('Sender side', 'Upande wa mtumaji');
      case _PaySafeSide.receiver:
        return _t('Receiver side', 'Upande wa mpokeaji');
      case _PaySafeSide.unknown:
        return _t('Role pending', 'Nafasi inasubiri');
    }
  }

  bool _isHoldWindowOpen(Map<String, dynamic> escrow) {
    final flaggedExpired = _pickBool([
      escrow['holdWindowExpired'],
      escrow['hold_window_expired'],
    ]);
    if (flaggedExpired) return false;
    final expiry = _holdExpiry(escrow);
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  bool _isHoldWindowExpired(Map<String, dynamic> escrow) {
    return !_isHoldWindowOpen(escrow);
  }

  bool _canRelease(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'release')) return true;
    return _actorSide(escrow) == _PaySafeSide.sender &&
        _stageOf(escrow) == _PaySafeStage.held;
  }

  bool _canAccept(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'accept')) return true;
    if (_actorSide(escrow) != _PaySafeSide.receiver) return false;
    if (!_isHoldWindowOpen(escrow)) return false;
    return switch (_stageOf(escrow)) {
      _PaySafeStage.awaitingReceiver ||
      _PaySafeStage.releasePending ||
      _PaySafeStage.returnPending => true,
      _ => false,
    };
  }

  bool _canRefund(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'refund')) return true;
    if (_actorSide(escrow) != _PaySafeSide.sender) return false;
    return switch (_stageOf(escrow)) {
      _PaySafeStage.awaitingReceiver || _PaySafeStage.held => true,
      _ => false,
    };
  }

  bool _canDispute(Map<String, dynamic> escrow) {
    if (_availableActionFlag(escrow, 'dispute')) return true;
    if (_actorSide(escrow) == _PaySafeSide.unknown) return false;
    return switch (_stageOf(escrow)) {
      _PaySafeStage.awaitingReceiver ||
      _PaySafeStage.held ||
      _PaySafeStage.releasePending ||
      _PaySafeStage.returnPending => true,
      _ => false,
    };
  }

  List<_PaySafeTileAction> _actionPlan(Map<String, dynamic> escrow) {
    final actions = <_PaySafeTileAction>[];
    if (_canAccept(escrow)) {
      actions.add(
        _PaySafeTileAction(
          label: _acceptActionLabel(escrow),
          onPressed: _busy ? null : () => _acceptPaySafe(escrow),
          style: _PaySafeActionStyle.primary,
        ),
      );
    } else if (_actorSide(escrow) == _PaySafeSide.receiver &&
        switch (_stageOf(escrow)) {
          _PaySafeStage.awaitingReceiver ||
          _PaySafeStage.releasePending ||
          _PaySafeStage.returnPending => true,
          _ => false,
        }) {
      actions.add(
        _PaySafeTileAction(
          label: _acceptActionLabel(escrow),
          onPressed: null,
          style: _PaySafeActionStyle.primary,
        ),
      );
    }
    if (_canRelease(escrow)) {
      actions.add(
        _PaySafeTileAction(
          label: _t('Release', 'Achia'),
          onPressed: _busy ? null : () => _releasePaySafe(escrow),
          style: _PaySafeActionStyle.tonal,
        ),
      );
    }
    if (_canRefund(escrow)) {
      actions.add(
        _PaySafeTileAction(
          label: _refundActionLabel(escrow),
          onPressed: _busy ? null : () => _refundPaySafe(escrow),
        ),
      );
    }
    if (_canDispute(escrow)) {
      actions.add(
        _PaySafeTileAction(
          label: _t('Dispute', 'Pingamizi'),
          onPressed: _busy ? null : () => _disputePaySafe(escrow),
        ),
      );
    }
    return actions;
  }

  void _mergeEscrowMutation(
    String referenceId,
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) {
    if (!mounted) return;
    setState(() {
      _escrows = _escrows
          .map((escrow) {
            if (_referenceId(escrow) != referenceId) return escrow;
            final next = Map<String, dynamic>.from(escrow);
            next.addAll(transform(next));
            return next;
          })
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _resolveActionUpdate({
    required Map<String, dynamic> current,
    required Map<String, dynamic> response,
    required String action,
  }) {
    final nested =
        response['data'] ?? response['escrow'] ?? response['agreement'];
    final explicitStatus = _pickString([
      response['status'],
      response['state'],
      response['escrow_status'],
      if (nested is Map) nested['status'],
      if (nested is Map) nested['state'],
      if (nested is Map) nested['escrow_status'],
    ]);
    final merged = Map<String, dynamic>.from(current);
    if (nested is Map) {
      merged.addAll(Map<String, dynamic>.from(nested));
    }
    merged.addAll(response);
    if (explicitStatus.isNotEmpty) {
      return merged;
    }

    switch (action) {
      case 'release':
        return {
          ...merged,
          'status': 'RELEASE_PENDING',
          'release_requested_at': DateTime.now().toUtc().toIso8601String(),
        };
      case 'refund':
        return {
          ...merged,
          'status': _receiverAccepted(current) ? 'RETURN_PENDING' : 'REFUNDED',
          'return_pending': _receiverAccepted(current),
        };
      case 'accept':
        return {
          ...merged,
          'status': _isReturnPending(current)
              ? 'REFUNDED'
              : _isReleasePending(current)
              ? 'RELEASED'
              : 'HELD',
          'receiver_accepted': true,
          'receiver_accepted_at': DateTime.now().toUtc().toIso8601String(),
        };
      case 'dispute':
        return {...merged, 'status': 'UNDER_REVIEW'};
      default:
        return merged;
    }
  }

  String _status(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    if (status.contains('REFUNDED')) {
      return _t('Refunded', 'Imerejeshwa');
    }
    if (status.contains('RELEASED') || status.contains('COMPLETED')) {
      return _t('Released', 'Imeachiwa');
    }
    if (_isBlockedStatus(status)) {
      return _t('Under review', 'Inakaguliwa');
    }
    if (_isReturnPending(escrow)) {
      return _t('Return requested', 'Return imeombwa');
    }
    if (_isReleasePending(escrow)) {
      return _t('Release waiting for receiver', 'Release inasubiri mpokeaji');
    }
    if (_receiverAccepted(escrow)) {
      return _t('Receiver confirmed PaySafe', 'Mpokeaji amethibitisha PaySafe');
    }
    if (_isAwaitingReceiverAcceptance(escrow)) {
      return _t('Awaiting receiver acceptance', 'Inasubiri idhini ya mpokeaji');
    }
    if (status.isEmpty) return _t('Pending', 'Inasubiri');
    return status.replaceAll('_', ' ');
  }

  String _currency(Map<String, dynamic> escrow) {
    final currency = _pickString([
      escrow['currency'],
      escrow['currencyCode'],
      escrow['currency_code'],
    ]).toUpperCase();
    return currency.isEmpty ? 'TZS' : currency;
  }

  String _amount(Map<String, dynamic> escrow) {
    final amount = _pickDouble([
      escrow['amount'],
      escrow['value'],
      escrow['totalAmount'],
      escrow['total_amount'],
    ]);
    return formatFinancialMoney(amount, _currency(escrow), locale: _localeTag);
  }

  String _title(Map<String, dynamic> escrow) {
    final description = _pickString([
      escrow['description'],
      escrow['purpose'],
      escrow['title'],
    ]);
    if (description.isNotEmpty) return description;
    final recipient = _pickString([
      escrow['recipientCustomerId'],
      escrow['recipient_customer_id'],
      escrow['recipient'],
    ]);
    return recipient.isEmpty
        ? _t('Protected payment', 'Malipo yaliyolindwa')
        : recipient;
  }

  String _holdSummary(Map<String, dynamic> escrow) {
    final status = _normalizedStatus(escrow);
    if (status.contains('REFUNDED')) {
      return _t(
        'This PaySafe was cancelled or returned. Funds are no longer held.',
        'PaySafe hii imeghairiwa au kurejeshwa. Fedha hazishikiliwi tena.',
      );
    }
    if (status.contains('RELEASED') || status.contains('COMPLETED')) {
      return _t(
        'This PaySafe was released successfully. Funds have moved to the approved receiver.',
        'PaySafe hii imeachiwa kikamilifu. Fedha zimeenda kwa mpokeaji aliyethibitishwa.',
      );
    }
    if (_isBlockedStatus(status)) {
      return _t(
        'This PaySafe is under review. Funds remain locked until customer care resolves it.',
        'PaySafe hii inakaguliwa. Fedha zinaendelea kushikiliwa hadi huduma kwa wateja watakapotoa uamuzi.',
      );
    }
    final expiry = _holdExpiry(escrow);
    final awaitingAcceptance = _isAwaitingReceiverAcceptance(escrow);
    final receiverAccepted = _receiverAccepted(escrow);
    final actorRole = _actorRole(escrow);
    final expired = _isHoldWindowExpired(escrow);
    if (expired && (_isReleasePending(escrow) || _isReturnPending(escrow))) {
      return actorRole == 'receiver'
          ? _t(
              'The response window has ended. Accept is locked; open a dispute if this PaySafe needs review.',
              'Dirisha la kujibu limeisha. Kubali imefungwa; fungua pingamizi kama PaySafe hii inahitaji ukaguzi.',
            )
          : _t(
              'The receiver response window has ended. This PaySafe needs review or automated resolution.',
              'Dirisha la majibu ya mpokeaji limeisha. PaySafe hii inahitaji ukaguzi au maamuzi ya mfumo.',
            );
    }
    if (_isReturnPending(escrow)) {
      return actorRole == 'receiver'
          ? _t(
              'Sender requested a return. Accept it or open a dispute within 24 hours.',
              'Mtumaji ameomba kurudisha. Kubali au fungua pingamizi ndani ya saa 24.',
            )
          : _t(
              'Return request is waiting for receiver response. It auto-returns after 24 hours if there is no dispute.',
              'Ombi la kurudisha linasubiri jibu la mpokeaji. Fedha zitarudi kiotomatiki baada ya saa 24 kama hakuna pingamizi.',
            );
    }
    if (_isReleasePending(escrow)) {
      return actorRole == 'receiver'
          ? _t(
              'Sender requested release. Accept to receive funds, or open a dispute if something is wrong.',
              'Mtumaji ameomba kuachia fedha. Kubali upokee fedha, au fungua pingamizi kama kuna tatizo.',
            )
          : _t(
              'Release is waiting for receiver final acceptance.',
              'Release inasubiri idhini ya mwisho ya mpokeaji.',
            );
    }
    if (receiverAccepted) {
      return _t(
        'Receiver confirmed this PaySafe. Sender can now release funds.',
        'Mpokeaji amethibitisha PaySafe hii. Mtumaji anaweza ku-release fedha.',
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

  String _acceptActionLabel(Map<String, dynamic> escrow) {
    if (_isReturnPending(escrow)) return _t('Accept', 'Kubali');
    if (_isReleasePending(escrow)) return _t('Accept', 'Kubali');
    return _t('Confirm', 'Thibitisha');
  }

  String _refundActionLabel(Map<String, dynamic> escrow) {
    return _receiverAccepted(escrow)
        ? _t('Return', 'Rudisha')
        : _t('Cancel', 'Ghairi');
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);
    final activeEscrows = _escrows
        .where(_isActiveEscrow)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ORBI PaySafe'),
        actions: [
          IconButton(
            tooltip: _t('PaySafe menu', 'Menu ya PaySafe'),
            onPressed: _busy ? null : _openPaySafeMenu,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: OrbiLoadingOverlay(
        loading: _busy,
        message: _t(
          'Processing PaySafe securely...',
          'Tunachakata PaySafe kwa usalama...',
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.accent.withValues(alpha: 0.14),
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: () => _loadPaySafe(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _PaySafeHero(
                    animation: _orbitController,
                    title: _t(
                      'Money held safely',
                      'Fedha zinashikiliwa salama',
                    ),
                    subtitle: _t(
                      'Create a PaySafe when money should wait until both sides are ready.',
                      'Tumia PaySafe pale fedha zinapotakiwa kusubiri hadi pande zote ziwe tayari.',
                    ),
                    onCreate: _busy ? null : _createPaySafe,
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    _PaySafeLoading(animation: _orbitController)
                  else if (_error != null)
                    _PaySafeEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: _t(
                        'PaySafe could not load',
                        'PaySafe haikuweza kupakia',
                      ),
                      message: _error!,
                      actionLabel: _t('Try again', 'Jaribu tena'),
                      onAction: () => _loadPaySafe(),
                    )
                  else if (_escrows.isEmpty)
                    _PaySafeEmptyState(
                      icon: Icons.verified_user_outlined,
                      title: _t('No PaySafe yet', 'Bado huna PaySafe'),
                      message: _t(
                        'Start one when you need a trusted hold before release, refund, or review.',
                        'Anzisha moja pale unapohitaji fedha zishikiliwe kabla ya kuachia, kurejesha, au kukagua.',
                      ),
                      actionLabel: _t('New PaySafe', 'PaySafe mpya'),
                      onAction: _busy ? null : _createPaySafe,
                    )
                  else ...[
                    Text(
                      _t('Active PaySafe', 'PaySafe zinazoendelea'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (activeEscrows.isEmpty)
                      _PaySafeEmptyState(
                        icon: Icons.task_alt_rounded,
                        title: _t(
                          'No active hold right now',
                          'Hakuna hold hai kwa sasa',
                        ),
                        message: _t(
                          'Released, refunded, and completed PaySafe items move out of the active queue.',
                          'PaySafe zilizokamilika, kurejeshwa, au kuachiwa huondolewa kwenye foleni ya active.',
                        ),
                        actionLabel: _t('New PaySafe', 'PaySafe mpya'),
                        onAction: _busy ? null : _createPaySafe,
                      ),
                    for (final escrow in activeEscrows) ...[
                      _PaySafeTile(
                        title: _title(escrow),
                        reference: _referenceId(escrow),
                        status: _status(escrow),
                        sideLabel: _sideLabel(escrow),
                        summary: _holdSummary(escrow),
                        amount: _amount(escrow),
                        actions: _actionPlan(escrow),
                        isSw: _isSw,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaySafeMenuAction extends StatelessWidget {
  const _PaySafeMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? colors.accentSoft.withValues(alpha: 0.70)
          : colors.cardMuted.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? colors.accent : colors.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled ? colors.textPrimary : colors.textMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaySafeHistoryTile extends StatelessWidget {
  const _PaySafeHistoryTile({
    required this.title,
    required this.reference,
    required this.status,
    required this.amount,
    required this.summary,
    required this.isSw,
    required this.onCopy,
    required this.onTrash,
  });

  final String title;
  final String reference;
  final String status;
  final String amount;
  final String summary;
  final bool isSw;
  final VoidCallback onCopy;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accentSoft.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.shield_rounded, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                amount,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isSw ? 'Nakili ID' : 'Copy ID',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
                IconButton(
                  tooltip: isSw ? 'Tupa' : 'Trash',
                  onPressed: onTrash,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ],
          if (summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaySafeDraft {
  const _PaySafeDraft({
    required this.recipientId,
    required this.recipientName,
    required this.recipientUserId,
    required this.recipientCustomerId,
    required this.recipientIdentifier,
    required this.amount,
    required this.description,
    required this.terms,
    required this.holdWindowHours,
  });

  final String recipientId;
  final String recipientName;
  final String recipientUserId;
  final String recipientCustomerId;
  final String recipientIdentifier;
  final double amount;
  final String description;
  final String terms;
  final int holdWindowHours;
}

class _PaySafeRecipientPreview {
  const _PaySafeRecipientPreview({
    required this.recipientId,
    required this.name,
    required this.displayIdentifier,
    required this.userId,
    required this.customerId,
    required this.identifier,
    this.avatarUrl,
  });

  final String recipientId;
  final String name;
  final String displayIdentifier;
  final String userId;
  final String customerId;
  final String identifier;
  final String? avatarUrl;
}

class _PaySafeCreateSheet extends StatefulWidget {
  const _PaySafeCreateSheet({required this.isSw});

  final bool isSw;

  @override
  State<_PaySafeCreateSheet> createState() => _PaySafeCreateSheetState();
}

class _PaySafeCreateSheetState extends State<_PaySafeCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termsController = TextEditingController();
  Timer? _lookupDebounce;
  bool _lookupLoading = false;
  String? _lookupError;
  _PaySafeRecipientPreview? _recipientPreview;
  int _lookupGeneration = 0;
  int _holdWindowHours = 24;

  @override
  void dispose() {
    _lookupGeneration++;
    _lookupDebounce?.cancel();
    _recipientController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  String _t(String en, String sw) => widget.isSw ? sw : en;

  void _onRecipientChanged(String value) {
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
        _lookupError = _t(
          'Enter at least 5 characters to search.',
          'Weka angalau herufi 5 kutafuta.',
        );
      });
      return;
    }

    final normalized = _normalizeLookupQuery(query);
    final generation = ++_lookupGeneration;
    setState(() {
      _lookupLoading = true;
      _lookupError = null;
      _recipientPreview = null;
    });
    _lookupDebounce = Timer(const Duration(milliseconds: 350), () {
      _lookupRecipient(normalized, generation);
    });
  }

  Future<void> _lookupRecipient(String query, int generation) async {
    try {
      final users = await _profileService.lookupUsers(query);
      if (!mounted || !_isLookupCurrent(query, generation)) return;
      final match = users.isEmpty ? null : users.first;
      if (match == null) {
        setState(() {
          _lookupLoading = false;
          _recipientPreview = null;
          _lookupError = _t(
            'Recipient not found. Check the ORBI ID or mobile number.',
            'Mpokeaji hajapatikana. Hakiki ORBI ID au namba ya simu.',
          );
        });
        return;
      }

      final recipientId = _pickString([
        match['customer_id'],
        match['customerId'],
        match['recipient_id'],
        match['recipientId'],
        match['id'],
      ]);
      final userId = _pickString([
        match['id'],
        match['user_id'],
        match['userId'],
        match['profile_id'],
        match['profileId'],
      ]);
      final customerId = _pickString([
        match['customer_id'],
        match['customerId'],
        match['recipient_customer_id'],
        match['recipientCustomerId'],
        match['orbi_id'],
        match['orbiId'],
      ]);
      final phone = _pickString([
        match['phone'],
        match['phone_number'],
        match['phoneNumber'],
        match['msisdn'],
      ]);
      final email = _pickString([match['email']]);
      final name = _pickString([
        match['full_name'],
        match['fullName'],
        match['name'],
        match['display_name'],
      ]);
      if (recipientId.isEmpty || name.isEmpty) {
        setState(() {
          _lookupLoading = false;
          _recipientPreview = null;
          _lookupError = _t(
            'Recipient details are incomplete. Try another ORBI ID or phone.',
            'Taarifa za mpokeaji hazijakamilika. Jaribu ORBI ID au simu nyingine.',
          );
        });
        return;
      }

      setState(() {
        _lookupLoading = false;
        _lookupError = null;
        _recipientPreview = _PaySafeRecipientPreview(
          recipientId: recipientId,
          name: name,
          displayIdentifier: _pickString([customerId, phone, email, query]),
          userId: userId,
          customerId: customerId,
          identifier: _pickString([customerId, phone, email, userId, query]),
          avatarUrl: _pickString([
            match['avatar_url'],
            match['avatarUrl'],
            match['profile_image'],
          ]),
        );
      });
    } catch (error) {
      if (!mounted || !_isLookupCurrent(query, generation)) return;
      setState(() {
        _lookupLoading = false;
        _recipientPreview = null;
        _lookupError = mapBackendStatusMessage(
          error.toString(),
          sw: widget.isSw,
          fallback: _t(
            'Recipient lookup is unavailable right now. Please try again.',
            'Utafutaji wa mpokeaji haupatikani kwa sasa. Tafadhali jaribu tena.',
          ),
        );
      });
    }
  }

  bool _isLookupCurrent(String query, int generation) =>
      mounted &&
      generation == _lookupGeneration &&
      _normalizeLookupQuery(_recipientController.text.trim()) == query;

  String _normalizeLookupQuery(String value) {
    final trimmed = value.trim();
    final upper = trimmed.toUpperCase();
    if (upper.startsWith('OB') || upper.contains('-')) return upper;
    return trimmed;
  }

  String _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.52,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.border),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('New PaySafe', 'PaySafe mpya'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Set the receiver, hold window, and release rules before money moves.',
                    'Weka mpokeaji, muda wa hold, na masharti ya kuachia kabla fedha hazijasogea.',
                  ),
                  style: TextStyle(color: colors.textMuted),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _recipientController,
                  textInputAction: TextInputAction.next,
                  onChanged: _onRecipientChanged,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Recipient ORBI ID / Mobile Number',
                      'ORBI ID / Namba ya simu ya mpokeaji',
                    ),
                    hintText: 'OB26-0000-0000 / +255...',
                    suffixIcon: _lookupLoading
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _recipientPreview != null
                        ? Icon(Icons.verified_rounded, color: colors.success)
                        : null,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _t(
                        'Enter recipient ORBI ID or mobile number',
                        'Weka ORBI ID au namba ya simu ya mpokeaji',
                      );
                    }
                    if (_recipientPreview == null) {
                      return _t(
                        'Verify the recipient before continuing.',
                        'Thibitisha mpokeaji kabla ya kuendelea.',
                      );
                    }
                    return null;
                  },
                ),
                if (_lookupError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lookupError!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_recipientPreview != null) ...[
                  const SizedBox(height: 10),
                  _PaySafeRecipientCard(
                    preview: _recipientPreview!,
                    isSw: widget.isSw,
                  ),
                ],
                const SizedBox(height: 12),
                OrbiAmountField(
                  controller: _amountController,
                  inputFormatters: [AmountInputFormatter()],
                  textInputAction: TextInputAction.next,
                  label: _t('Amount', 'Kiasi'),
                  hint: '50,000',
                  validator: (value) {
                    final amount =
                        AmountInputFormatter.tryParse(value ?? '') ?? 0;
                    if (amount <= 0) return _t('Enter amount', 'Weka kiasi');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _t('Payment purpose', 'Sababu ya malipo'),
                    hintText: _t('Goods, service, order', 'Mzigo, huduma, oda'),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _t('Enter purpose', 'Weka sababu');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _t('Release terms', 'Masharti ya kuachia'),
                    hintText: _t(
                      'Release when both sides confirm.',
                      'Acha fedha pande zote zikithibitisha.',
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _t('Enter terms', 'Weka masharti');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _holdWindowHours,
                  decoration: InputDecoration(
                    labelText: _t('Hold window', 'Dirisha la hold'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 6, child: Text('6 hours')),
                    DropdownMenuItem(value: 12, child: Text('12 hours')),
                    DropdownMenuItem(value: 24, child: Text('24 hours')),
                    DropdownMenuItem(value: 48, child: Text('48 hours')),
                    DropdownMenuItem(value: 72, child: Text('72 hours')),
                    DropdownMenuItem(value: 168, child: Text('7 days')),
                  ],
                  onChanged: (value) {
                    setState(() => _holdWindowHours = value ?? 24);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'After release, the receiver should accept the hold before settlement is treated as complete.',
                    'Baada ya release, mpokeaji anatakiwa akubali hold kabla settlement haijachukuliwa kuwa imekamilika.',
                  ),
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _lookupLoading || _recipientPreview == null
                      ? null
                      : () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final amount =
                              AmountInputFormatter.tryParse(
                                _amountController.text,
                              ) ??
                              0;
                          if (amount <= 0) return;
                          final recipient = _recipientPreview;
                          if (recipient == null) return;
                          Navigator.of(context).pop(
                            _PaySafeDraft(
                              recipientId: recipient.recipientId,
                              recipientName: recipient.name,
                              recipientUserId: recipient.userId,
                              recipientCustomerId: recipient.customerId,
                              recipientIdentifier: recipient.identifier,
                              amount: amount,
                              description: _descriptionController.text.trim(),
                              terms: _termsController.text.trim(),
                              holdWindowHours: _holdWindowHours,
                            ),
                          );
                        },
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(_t('Create PaySafe', 'Unda PaySafe')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaySafeRecipientCard extends StatelessWidget {
  const _PaySafeRecipientCard({required this.preview, required this.isSw});

  final _PaySafeRecipientPreview preview;
  final bool isSw;

  String _t(String en, String sw) => isSw ? sw : en;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final avatarUrl = preview.avatarUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.card, colors.cardMuted.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderStrong.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.success.withValues(alpha: 0.55)),
              color: colors.successSoft.withValues(alpha: 0.35),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colors.cardStrong,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(Icons.person_rounded, color: colors.success)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.successSoft.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.success.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    _t('Recipient verified', 'Mpokeaji amethibitishwa'),
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preview.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview.displayIdentifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.successSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.check_rounded, color: colors.success, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PaySafeConfirmRow extends StatelessWidget {
  const _PaySafeConfirmRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? colors.success : colors.textPrimary,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaySafeHero extends StatelessWidget {
  const _PaySafeHero({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.onCreate,
  });

  final Animation<double> animation;
  final String title;
  final String subtitle;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.94),
            const Color(0xFF062C37),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          _OrbitMark(
            animation: animation,
            size: 74,
            onBrandSurface: true,
            animate: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORBI PaySafe',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colors.accent,
                  ),
                  child: const Text('New PaySafe'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _PaySafeSide { sender, receiver, unknown }

enum _PaySafeStage {
  awaitingReceiver,
  held,
  releasePending,
  returnPending,
  review,
  closed,
}

enum _PaySafeActionStyle { outline, primary, tonal }

class _PaySafeTileAction {
  const _PaySafeTileAction({
    required this.label,
    required this.onPressed,
    this.style = _PaySafeActionStyle.outline,
  });

  final String label;
  final VoidCallback? onPressed;
  final _PaySafeActionStyle style;
}

class _PaySafeTile extends StatelessWidget {
  const _PaySafeTile({
    required this.title,
    required this.reference,
    required this.status,
    required this.sideLabel,
    required this.summary,
    required this.amount,
    required this.actions,
    required this.isSw,
  });

  final String title;
  final String reference;
  final String status;
  final String sideLabel;
  final String summary;
  final String amount;
  final List<_PaySafeTileAction> actions;
  final bool isSw;

  String _t(String en, String sw) => isSw ? sw : en;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final accent = _statusAccent(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.20),
                          colors.accent.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: Icon(Icons.shield_outlined, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sideLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PaySafeStatusChip(
                          label: status,
                          color: accent,
                          expanded: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 136),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        amount,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (reference.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PaySafeReferenceRow(
                  reference: reference,
                  copiedLabel: _t(
                    'Escrow ID copied',
                    'ID ya Escrow imenakiliwa',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.cardMuted.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          height: 1.38,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, actionConstraints) {
                    final twoColumn = actionConstraints.maxWidth >= 300;
                    final itemWidth = twoColumn
                        ? (actionConstraints.maxWidth - 8) / 2
                        : actionConstraints.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in actions)
                          _PaySafeActionButton(
                            width: itemWidth,
                            label: action.label,
                            onPressed: action.onPressed,
                            filled: action.style == _PaySafeActionStyle.primary,
                            tonal: action.style == _PaySafeActionStyle.tonal,
                          ),
                      ],
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardMuted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Text(
                    _t(
                      'No action is required from you right now.',
                      'Hakuna hatua inayohitajika kutoka kwako kwa sasa.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusAccent(BuildContext context) {
    final lower = status.toLowerCase();
    if (lower.contains('refund') || lower.contains('return')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('release') || lower.contains('confirmed')) {
      return const Color(0xFF2563EB);
    }
    if (lower.contains('review') || lower.contains('dispute')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('released') || lower.contains('completed')) {
      return const Color(0xFF10B981);
    }
    return OrbiTheme.uiOf(context).accent;
  }
}

class _PaySafeReferenceRow extends StatelessWidget {
  const _PaySafeReferenceRow({
    required this.reference,
    required this.copiedLabel,
  });

  final String reference;
  final String copiedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
      decoration: BoxDecoration(
        color: colors.cardMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(copiedLabel),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            icon: Icon(Icons.copy_rounded, size: 18, color: colors.accent),
          ),
        ],
      ),
    );
  }
}

class _PaySafeStatusChip extends StatelessWidget {
  const _PaySafeStatusChip({
    required this.label,
    required this.color,
    this.expanded = false,
  });

  final String label;
  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: chip) : chip;
  }
}

class _PaySafeActionButton extends StatelessWidget {
  const _PaySafeActionButton({
    required this.width,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.tonal = false,
  });

  final double width;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(Size.zero),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 6),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
    if (filled) {
      return SizedBox(
        width: width,
        height: 44,
        child: FilledButton(onPressed: onPressed, style: style, child: child),
      );
    }
    if (tonal) {
      return SizedBox(
        width: width,
        height: 44,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: 44,
      child: OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class _PaySafeEmptyState extends StatelessWidget {
  const _PaySafeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.accent, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _PaySafeLoading extends StatelessWidget {
  const _PaySafeLoading({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_OrbitMark(animation: animation, size: 64)],
      ),
    );
  }
}

class _OrbitMark extends StatelessWidget {
  const _OrbitMark({
    required this.animation,
    required this.size,
    this.onBrandSurface = false,
    this.animate = true,
  });

  final Animation<double> animation;
  final double size;
  final bool onBrandSurface;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = OrbiTheme.uiOf(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final angle = animate ? animation.value * math.pi * 2 : 0.0;
        final orbitColor = onBrandSurface
            ? Colors.white.withValues(alpha: 0.54)
            : Color.lerp(
                colors.accent,
                colors.borderStrong,
                isDark ? 0.24 : 0.34,
              )!.withValues(alpha: isDark ? 0.78 : 0.86);
        final orbitGlow = onBrandSurface
            ? Colors.white.withValues(alpha: 0.16)
            : colors.accent.withValues(alpha: isDark ? 0.24 : 0.18);
        final lockColor = onBrandSurface ? Colors.white : colors.accent;
        final dotColor = onBrandSurface ? Colors.white : colors.accent;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.92,
                height: size * 0.92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: orbitGlow,
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbitColor,
                    width: onBrandSurface ? 1.5 : 1.8,
                  ),
                ),
              ),
              if (animate)
                Transform.rotate(
                  angle: angle,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: size * 0.22,
                      height: size * 0.22,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.42),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Icon(Icons.lock_rounded, color: lockColor, size: size * 0.36),
            ],
          ),
        );
      },
    );
  }
}
