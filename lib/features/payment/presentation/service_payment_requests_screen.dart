import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_empty_state.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../data/service_payment_challenge_service.dart';

class ServicePaymentRequestsScreen extends StatefulWidget {
  const ServicePaymentRequestsScreen({super.key});

  @override
  State<ServicePaymentRequestsScreen> createState() =>
      _ServicePaymentRequestsScreenState();
}

class _ServicePaymentRequestsScreenState
    extends State<ServicePaymentRequestsScreen> {
  final ServicePaymentChallengeService _service =
      ServicePaymentChallengeService();
  final Map<String, TextEditingController> _otcControllers = {};
  final Map<String, String> _idempotencyKeys = {};

  bool _loading = true;
  String? _error;
  String? _busyKey;
  List<Map<String, dynamic>> _items = const [];

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _otcControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await _service.listPending();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mapBackendStatusMessage(error.toString(), sw: _isSw);
      });
    }
  }

  Future<void> _respond(Map<String, dynamic> item, String decision) async {
    final challengeId = _challengeId(item);
    if (challengeId.isEmpty || _busyKey != null) return;

    final otcRequired = _otcRequired(item);
    final otcCode = _otcControllers[challengeId]?.text.trim() ?? '';
    if (decision == 'approve' && otcRequired && otcCode.isEmpty) {
      _showMessage(_t('Enter the OTC code first.', 'Weka msimbo wa OTC kwanza.'));
      return;
    }

    setState(() => _busyKey = '$challengeId:$decision');
    try {
      final idempotencyKey = _idempotencyKeys.putIfAbsent(
        '$challengeId:$decision',
        () => _service.createIdempotencyKey('service-payment-$decision'),
      );
      await _service.respond(
        challengeId: challengeId,
        decision: decision,
        idempotencyKey: idempotencyKey,
        otcRequestId: _otcRequestId(item),
        otcCode: otcCode,
      );
      if (!mounted) return;
      _showMessage(
        decision == 'approve'
            ? _t(
                'Payment request approved. ORBI is processing it securely.',
                'Ombi la malipo limethibitishwa. ORBI inaendelea kulichakata kwa usalama.',
              )
            : _t('Payment request rejected.', 'Ombi la malipo limekataliwa.'),
      );
      await _load(quiet: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(mapBackendStatusMessage(error.toString(), sw: _isSw));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return OrbiBackground(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: OrbiResponsive.pagePadding(context, top: 16, bottom: 28),
          children: [
            _HeaderCard(ui: ui, isSw: _isSw, onRefresh: _loading ? null : _load),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 42),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              OrbiEmptyStateCard(
                icon: Icons.sync_problem_rounded,
                title: _t('Could not load requests', 'Maombi hayajapakia'),
                subtitle: _error!,
                actionLabel: _t('Retry', 'Jaribu tena'),
                onAction: _load,
              )
            else if (_items.isEmpty)
              OrbiEmptyStateCard(
                icon: Icons.verified_user_outlined,
                title: _t(
                  'No payment requests',
                  'Hakuna maombi ya malipo',
                ),
                subtitle: _t(
                  'Third-party ORBI payments that need your approval will appear here.',
                  'Malipo ya ORBI kutoka huduma za nje yanayohitaji uthibitisho wako yataonekana hapa.',
                ),
              )
            else
              ..._items.map((item) => _ChallengeTile(
                    item: item,
                    isSw: _isSw,
                    busyKey: _busyKey,
                    controller: _otcControllers.putIfAbsent(
                      _challengeId(item),
                      TextEditingController.new,
                    ),
                    onApprove: () => _respond(item, 'approve'),
                    onReject: () => _respond(item, 'reject'),
                  )),
          ],
        ),
      ),
    );
  }

  static String _challengeId(Map<String, dynamic> item) =>
      (item['id'] ??
              item['challengeId'] ??
              item['challenge_id'] ??
              item['challenge']?['challengeId'] ??
              '')
          .toString()
          .trim();

  static Map<String, dynamic> _metadata(Map<String, dynamic> item) {
    final metadata = item['metadata'];
    return metadata is Map ? Map<String, dynamic>.from(metadata) : {};
  }

  static bool _otcRequired(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return metadata['otcRequired'] == true ||
        metadata['otc_required'] == true ||
        (item['type'] ?? item['challengeType']).toString().toUpperCase() ==
            'OTP';
  }

  static String _otcRequestId(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return (metadata['otcRequestId'] ?? metadata['otc_request_id'] ?? '')
        .toString()
        .trim();
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.ui,
    required this.isSw,
    required this.onRefresh,
  });

  final OrbiUiTokens ui;
  final bool isSw;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.security_rounded, color: ui.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSw ? 'Maombi ya malipo' : 'Payment requests',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSw
                      ? 'Thibitisha malipo kutoka huduma zilizounganishwa na ORBI.'
                      : 'Approve ORBI payments from connected services.',
                  style: TextStyle(color: ui.textMuted, height: 1.25),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.item,
    required this.isSw,
    required this.busyKey,
    required this.controller,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool isSw;
  final String? busyKey;
  final TextEditingController controller;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _t(String en, String sw) => isSw ? sw : en;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final metadata = _ServicePaymentRequestsScreenState._metadata(item);
    final intent = item['intent'] is Map
        ? Map<String, dynamic>.from(item['intent'] as Map)
        : const <String, dynamic>{};
    final challengeId = _ServicePaymentRequestsScreenState._challengeId(item);
    final serviceName = (metadata['merchantName'] ??
            metadata['serviceName'] ??
            intent['service_code'] ??
            'ORBI service')
        .toString();
    final reference = (metadata['reference'] ?? intent['reference'] ?? '')
        .toString()
        .trim();
    final currency = (metadata['currency'] ?? intent['currency'] ?? 'TZS')
        .toString()
        .toUpperCase();
    final amount = double.tryParse(
          (metadata['amount'] ?? intent['amount'] ?? 0).toString(),
        ) ??
        0;
    final amountText = formatCurrencyAmount(amount, currency);
    final otcRequired = _ServicePaymentRequestsScreenState._otcRequired(item);
    final approving = busyKey == '$challengeId:approve';
    final rejecting = busyKey == '$challengeId:reject';
    final busy = busyKey != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: ui.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  serviceName,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                amountText,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Approve only if you recognize this checkout request.',
              'Thibitisha tu kama unatambua ombi hili la checkout.',
            ),
            style: TextStyle(color: ui.textMuted, height: 1.35),
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ref: $reference',
              style: TextStyle(color: ui.textSoft, fontWeight: FontWeight.w700),
            ),
          ],
          if (otcRequired) ...[
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              enabled: !busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                labelText: _t('OTC code', 'Msimbo wa OTC'),
                hintText: '000000',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: approving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_t('Approve', 'Thibitisha')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: rejecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded),
                  label: Text(_t('Reject', 'Kataa')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
