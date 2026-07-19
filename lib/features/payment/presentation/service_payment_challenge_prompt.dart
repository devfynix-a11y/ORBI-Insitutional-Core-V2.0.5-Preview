import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../data/service_payment_challenge_service.dart';

Future<bool?> showServicePaymentChallengePrompt(
  BuildContext context,
  Map<String, dynamic> challenge,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServicePaymentChallengePrompt(challenge: challenge),
  );
}

class _ServicePaymentChallengePrompt extends StatefulWidget {
  const _ServicePaymentChallengePrompt({required this.challenge});

  final Map<String, dynamic> challenge;

  @override
  State<_ServicePaymentChallengePrompt> createState() =>
      _ServicePaymentChallengePromptState();
}

class _ServicePaymentChallengePromptState
    extends State<_ServicePaymentChallengePrompt> {
  final _service = ServicePaymentChallengeService();
  final _otcController = TextEditingController();
  final Map<String, String> _idempotencyKeys = {};
  String? _busyDecision;

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  @override
  void dispose() {
    _otcController.dispose();
    super.dispose();
  }

  Future<void> _respond(String decision) async {
    final challengeId = _challengeId(widget.challenge);
    if (challengeId.isEmpty || _busyDecision != null) return;
    final otcCode = _otcController.text.trim();
    if (decision == 'approve' &&
        _otcRequired(widget.challenge) &&
        otcCode.isEmpty) {
      _showMessage(
        _t('Enter the OTC code first.', 'Weka msimbo wa OTC kwanza.'),
      );
      return;
    }

    setState(() => _busyDecision = decision);
    try {
      final idempotencyKey = _idempotencyKeys.putIfAbsent(
        '$challengeId:$decision',
        () => _service.createIdempotencyKey('service-payment-$decision'),
      );
      await _service.respond(
        challengeId: challengeId,
        decision: decision,
        idempotencyKey: idempotencyKey,
        otcRequestId: _otcRequestId(widget.challenge),
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
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyDecision = null);
      _showMessage(mapBackendStatusMessage(error.toString(), sw: _isSw));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final challenge = widget.challenge;
    final serviceName = _serviceName(challenge);
    final reference = _reference(challenge);
    final amountText = _amountText(challenge);
    final otcRequired = _otcRequired(challenge);
    final approving = _busyDecision == 'approve';
    final rejecting = _busyDecision == 'reject';
    final busy = _busyDecision != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: ui.sheet,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: ui.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ui.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ui.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: ui.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(
                            'Approve ORBI payment',
                            'Thibitisha malipo ya ORBI',
                          ),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ui.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ui.accent.withValues(alpha: 0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amountText,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'Approve only if you recognize this checkout request.',
                        'Thibitisha tu kama unatambua ombi hili la checkout.',
                      ),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    if (reference.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Ref: $reference',
                        style: TextStyle(
                          color: ui.textSoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (otcRequired) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otcController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: _t('OTC code', 'Msimbo wa OTC'),
                    hintText: '000000',
                    helperText: _t(
                      'Enter the code sent by ORBI.',
                      'Weka msimbo uliotumwa na ORBI.',
                    ),
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => _respond('approve'),
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
                      onPressed: busy ? null : () => _respond('reject'),
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
        ),
      ),
    );
  }

  static Map<String, dynamic> _metadata(Map<String, dynamic> item) {
    final metadata = item['metadata'];
    return metadata is Map ? Map<String, dynamic>.from(metadata) : item;
  }

  static String _challengeId(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return (item['id'] ??
            item['challengeId'] ??
            item['challenge_id'] ??
            metadata['challengeId'] ??
            metadata['challenge_id'] ??
            '')
        .toString()
        .trim();
  }

  static bool _otcRequired(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return item['otcRequired'] == true ||
        item['otc_required'] == true ||
        metadata['otcRequired'] == true ||
        metadata['otc_required'] == true ||
        (item['challengeType'] ?? item['type'] ?? metadata['challengeType'])
                .toString()
                .toUpperCase() ==
            'OTP';
  }

  static String _otcRequestId(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return (item['otcRequestId'] ??
            item['otc_request_id'] ??
            metadata['otcRequestId'] ??
            metadata['otc_request_id'] ??
            '')
        .toString()
        .trim();
  }

  static String _serviceName(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return (item['merchantName'] ??
            item['serviceName'] ??
            item['serviceCode'] ??
            metadata['merchantName'] ??
            metadata['serviceName'] ??
            metadata['serviceCode'] ??
            'ORBI service')
        .toString()
        .trim();
  }

  static String _reference(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    return (item['reference'] ?? metadata['reference'] ?? '').toString().trim();
  }

  static String _amountText(Map<String, dynamic> item) {
    final metadata = _metadata(item);
    final currency = (item['currency'] ?? metadata['currency'] ?? 'TZS')
        .toString()
        .toUpperCase();
    final amount =
        double.tryParse(
          (item['amount'] ?? metadata['amount'] ?? 0).toString(),
        ) ??
        0;
    return formatCurrencyAmount(amount, currency);
  }
}
