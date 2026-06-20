import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_background.dart';
import '../state/auth_controller.dart';

class AccountActivationScreen extends StatefulWidget {
  final String? initialIdentifier;

  const AccountActivationScreen({super.key, this.initialIdentifier});

  @override
  State<AccountActivationScreen> createState() =>
      _AccountActivationScreenState();
}

class _AccountActivationScreenState extends State<AccountActivationScreen> {
  static const _resendCooldown = Duration(minutes: 2);

  final _identifierController = TextEditingController();
  final _replacementContactController = TextEditingController();
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 0;
  String? _requestId;
  String? _status;
  bool _success = false;
  bool _showContactChange = false;

  bool get _canResend => _secondsRemaining <= 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _identifierController.text =
        widget.initialIdentifier ?? auth.pendingActivationIdentifier ?? '';
    _requestId = auth.pendingActivationRequestId;
    if (_requestId != null && _requestId!.isNotEmpty) {
      _startCooldown();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final identifier = _identifierController.text.trim();
        if (identifier.isEmpty) return;
        _requestOtp();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _replacementContactController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String _copy(BuildContext context, String en, String sw) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'sw'
        ? sw
        : en;
  }

  Future<void> _requestOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _status = _copy(
          context,
          'Enter your phone number or email first.',
          'Weka namba ya simu au barua pepe kwanza.',
        );
      });
      return;
    }

    final replacementContact = _showContactChange
        ? _replacementContactController.text.trim()
        : '';
    final auth = context.read<AuthController>();
    final ok = await auth.initiateAccountConfirmation(
      identifier,
      replacementContact: replacementContact.isEmpty
          ? null
          : replacementContact,
    );
    if (!mounted) return;
    if (ok) {
      _requestId = auth.pendingActivationRequestId;
      _startCooldown();
      setState(() {
        _status = _copy(
          context,
          'Activation code sent. Check SMS and email if both are registered.',
          'Msimbo wa kuwezesha umetumwa. Angalia SMS na barua pepe kama vyote vimesajiliwa.',
        );
      });
    } else {
      setState(() => _status = auth.error);
    }
  }

  Future<void> _activate() async {
    final identifier = _identifierController.text.trim();
    final code = _otpController.text.trim();
    final requestId = _requestId;
    if (identifier.isEmpty || code.isEmpty || requestId == null) {
      setState(() {
        _status = _copy(
          context,
          'Request and enter the activation code first.',
          'Omba na uweke msimbo wa kuwezesha kwanza.',
        );
      });
      return;
    }

    final auth = context.read<AuthController>();
    final ok = await auth.completeAccountConfirmation(
      identifier: identifier,
      requestId: requestId,
      code: code,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _success = true;
        _status = _copy(
          context,
          'Account activated. You can now sign in.',
          'Akaunti imewezeshwa. Sasa unaweza kuingia.',
        );
      });
    } else {
      setState(() => _status = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final ui = OrbiTheme.uiOf(context);
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final delivery = auth.pendingActivationDelivery?.trim() ?? '';

    return Scaffold(
      body: OrbiBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  color: ui.card.withValues(alpha: 0.96),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _success
                              ? Icons.verified_rounded
                              : Icons.mark_email_read_rounded,
                          size: 54,
                          color: _success ? ui.success : ui.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isSw ? 'Washa akaunti yako' : 'Activate your account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isSw
                              ? 'Akaunti mpya lazima ithibitishwe kwa OTP ndani ya saa 24 kabla ya kutumia huduma za ORBI.'
                              : 'New accounts must be confirmed by OTP within 24 hours before ORBI services are available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ui.textMuted, height: 1.45),
                        ),
                        if (delivery.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ui.accentSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ui.border),
                            ),
                            child: Text(
                              isSw
                                  ? 'Weka OTP iliyotumwa kwenye: $delivery'
                                  : 'Enter the OTP sent to: $delivery',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        TextField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !auth.isLoading && !_success,
                          decoration: InputDecoration(
                            labelText: isSw
                                ? 'Simu au barua pepe'
                                : 'Phone or email',
                            prefixIcon: const Icon(Icons.person_rounded),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          value: _showContactChange,
                          onChanged: auth.isLoading || _success
                              ? null
                              : (value) {
                                  setState(() => _showContactChange = value);
                                },
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isSw
                                ? 'Badili sehemu ya kupokea OTP'
                                : 'Use a different OTP contact',
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            isSw
                                ? 'Tumia hii kama simu/barua pepe ya awali haipatikani.'
                                : 'Use this only if the original phone/email is not reachable.',
                            style: TextStyle(color: ui.textMuted),
                          ),
                        ),
                        if (_showContactChange) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _replacementContactController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !auth.isLoading && !_success,
                            decoration: InputDecoration(
                              labelText: isSw
                                  ? 'Simu au barua pepe mpya ya OTP'
                                  : 'New OTP phone or email',
                              prefixIcon: const Icon(
                                Icons.contact_mail_rounded,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          enabled: !auth.isLoading && !_success,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: isSw ? 'Msimbo wa OTP' : 'OTP code',
                            prefixIcon: const Icon(Icons.pin_rounded),
                            counterText: '',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if ((_status ?? '').isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _status!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _success ? ui.success : ui.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: auth.isLoading || _success
                              ? null
                              : _activate,
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_user_rounded),
                          label: Text(isSw ? 'Thibitisha' : 'Activate account'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: auth.isLoading || !_canResend || _success
                              ? null
                              : _requestOtp,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _canResend
                                ? (isSw ? 'Tuma OTP mpya' : 'Request new OTP')
                                : (isSw
                                      ? 'Subiri ${_secondsRemaining}s'
                                      : 'Resend in ${_secondsRemaining}s'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(isSw ? 'Rudi kuingia' : 'Back to login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
