import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_background.dart';
import '../state/auth_controller.dart';

class PasswordResetScreen extends StatefulWidget {
  final String? initialIdentifier;

  const PasswordResetScreen({super.key, this.initialIdentifier});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  static const _resendCooldown = Duration(minutes: 2);

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _timer;
  int _secondsRemaining = 0;
  String? _requestId;
  String? _status;
  bool _success = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _canResend => _secondsRemaining <= 0;

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialIdentifier ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _copy(String en, String sw) => _isSw ? sw : en;

  Future<void> _requestOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _status = _copy(
          'Enter your phone number or email first.',
          'Weka namba ya simu au barua pepe kwanza.',
        );
      });
      return;
    }

    final auth = context.read<AuthController>();
    final ok = await auth.initiatePasswordReset(identifier);
    if (!mounted) return;
    if (ok) {
      _requestId = auth.pendingActivationRequestId;
      _startCooldown();
      setState(() {
        _status = _copy(
          'Password reset OTP sent. Check SMS and email if both are registered.',
          'OTP ya kubadili nywila imetumwa. Angalia SMS na barua pepe kama vyote vimesajiliwa.',
        );
      });
    } else {
      setState(() => _status = auth.error);
    }
  }

  Future<void> _completeReset() async {
    final identifier = _identifierController.text.trim();
    final requestId = _requestId;
    final code = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (identifier.isEmpty || requestId == null || code.isEmpty) {
      setState(() {
        _status = _copy(
          'Request and enter the OTP before changing your password.',
          'Omba na uweke OTP kabla ya kubadili nywila.',
        );
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _status = _copy(
          'Password must be at least 8 characters.',
          'Nywila lazima iwe na herufi au tarakimu angalau 8.',
        );
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _status = _copy('Passwords do not match.', 'Nywila hazifanani.');
      });
      return;
    }

    final auth = context.read<AuthController>();
    final ok = await auth.completePasswordReset(
      password,
      identifier: identifier,
      requestId: requestId,
      code: code,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _success = true;
        _status = _copy(
          'Password updated. You can now sign in securely.',
          'Nywila imebadilishwa. Sasa unaweza kuingia kwa usalama.',
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

    return Scaffold(
      body: OrbiBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
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
                              ? Icons.lock_reset_rounded
                              : Icons.password_rounded,
                          size: 54,
                          color: _success ? ui.success : ui.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _copy('Reset password', 'Badili nywila'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _copy(
                            'For your protection, ORBI sends a one-time code before allowing password changes.',
                            'Kwa usalama wako, ORBI hutuma msimbo wa mara moja kabla ya kuruhusu mabadiliko ya nywila.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ui.textMuted, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !auth.isLoading && !_success,
                          decoration: InputDecoration(
                            labelText: _copy(
                              'Phone or email',
                              'Simu au barua pepe',
                            ),
                            prefixIcon: const Icon(Icons.person_rounded),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          enabled: !auth.isLoading && !_success,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: _copy('OTP code', 'Msimbo wa OTP'),
                            prefixIcon: const Icon(Icons.pin_rounded),
                            counterText: '',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !auth.isLoading && !_success,
                          decoration: InputDecoration(
                            labelText: _copy('New password', 'Nywila mpya'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          enabled: !auth.isLoading && !_success,
                          decoration: InputDecoration(
                            labelText: _copy(
                              'Confirm password',
                              'Thibitisha nywila',
                            ),
                            prefixIcon: const Icon(Icons.lock_person_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
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
                              : _completeReset,
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.task_alt_rounded),
                          label: Text(
                            _copy('Update password', 'Hifadhi nywila'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: auth.isLoading || !_canResend || _success
                              ? null
                              : _requestOtp,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _canResend
                                ? _copy('Request OTP', 'Omba OTP')
                                : _copy(
                                    'Resend in ${_secondsRemaining}s',
                                    'Subiri ${_secondsRemaining}s',
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(_copy('Back to login', 'Rudi kuingia')),
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
