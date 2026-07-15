import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
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
  Timer? _completeTimer;
  int _secondsRemaining = 0;
  int _completeSecondsRemaining = 0;
  String? _requestId;
  String? _status;
  int _step = 0;
  bool _success = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _canResend => _secondsRemaining <= 0;
  bool get _canComplete => _completeSecondsRemaining <= 0;

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialIdentifier ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _completeTimer?.cancel();
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

  void _startCompleteCooldown([int seconds = 60]) {
    _completeTimer?.cancel();
    setState(() => _completeSecondsRemaining = seconds);
    _completeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_completeSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _completeSecondsRemaining = 0);
      } else {
        setState(() => _completeSecondsRemaining -= 1);
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
        _step = 1;
        _otpController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _status = _copy(
          'Password reset OTP sent. Check SMS and email if both are registered.',
          'OTP ya kubadili nywila imetumwa. Angalia SMS na barua pepe kama vyote vimesajiliwa.',
        );
      });
    } else {
      setState(() => _status = _localizedAuthMessage(auth.error));
    }
  }

  Future<void> _completeReset() async {
    if (!_canComplete) {
      setState(() {
        _status = _copy(
          'Too many attempts. Please wait $_completeSecondsRemaining seconds before trying again.',
          'Majaribio ni mengi. Tafadhali subiri sekunde $_completeSecondsRemaining kabla ya kujaribu tena.',
        );
      });
      return;
    }

    final identifier = _identifierController.text.trim();
    final requestId = _requestId;
    final code = _otpController.text.replaceAll(RegExp(r'[\s-]'), '').trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (identifier.isEmpty || requestId == null || code.isEmpty) {
      setState(() {
        if (requestId == null) _step = 0;
        _status = _copy(
          'Request and enter the OTP before changing your password.',
          'Omba na uweke OTP kabla ya kubadili nywila.',
        );
      });
      return;
    }
    final passwordError = _passwordPolicyError(password);
    if (passwordError != null) {
      setState(() {
        _status = passwordError;
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
      final message = auth.error ?? '';
      final lower = message.toLowerCase();
      if (lower.contains('too many') ||
          lower.contains('rate limit') ||
          lower.contains('429')) {
        _startCompleteCooldown(60);
      }
      setState(() => _status = _localizedAuthMessage(message));
    }
  }

  void _backToRequestStep() {
    setState(() {
      _step = 0;
      _requestId = null;
      _otpController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _status = null;
    });
  }

  String? _passwordPolicyError(String password) {
    if (password.length < 8) {
      return _copy(
        'Password must be at least 8 characters.',
        'Nywila lazima iwe na angalau herufi/tarakimu 8.',
      );
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return _copy(
        'Password must include a lowercase letter.',
        'Nywila lazima iwe na herufi ndogo.',
      );
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return _copy(
        'Password must include an uppercase letter.',
        'Nywila lazima iwe na herufi kubwa.',
      );
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return _copy(
        'Password must include a number.',
        'Nywila lazima iwe na namba.',
      );
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return _copy(
        'Password must include a special character, for example @, #, or !.',
        'Nywila lazima iwe na alama maalum, mfano @, #, au !.',
      );
    }
    return null;
  }

  String? _localizedAuthMessage(String? message) {
    final raw = (message ?? '').trim();
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    final mapped = mapBackendStatusMessage(
      raw,
      sw: _isSw,
      fallback: raw,
    );
    if (mapped != raw) return mapped;

    if (lower.contains('too many') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('throttle')) {
      return _copy(
        'Too many attempts. Please wait about 60 seconds, then try again.',
        'Majaribio ni mengi. Tafadhali subiri takriban sekunde 60, kisha jaribu tena.',
      );
    }
    if (lower.contains('invalid otp') ||
        lower.contains('otp code is invalid') ||
        lower.contains('otp expired')) {
      return _copy(
        'The OTP code is invalid or expired. Request a new code and try again.',
        'Msimbo wa OTP si sahihi au umeisha muda. Omba msimbo mpya kisha jaribu tena.',
      );
    }
    if (lower.contains('registered email') ||
        lower.contains('outside tanzania')) {
      return _copy(
        'For accounts outside Tanzania, password reset works best with your registered email.',
        'Kwa akaunti zilizo nje ya Tanzania, kubadili nywila hufanya kazi vizuri kwa email uliyosajili.',
      );
    }
    if (lower.contains('password must') ||
        lower.contains('invalid_password_policy')) {
      return _copy(
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
        'Nywila lazima iwe na angalau herufi/tarakimu 8, herufi kubwa, herufi ndogo, namba, na alama maalum.',
      );
    }
    if (lower.contains('unable to') ||
        lower.contains('server') ||
        lower.contains('network') ||
        lower.contains('timeout')) {
      return _copy(
        'We could not complete this request right now. Please try again shortly.',
        'Hatukuweza kukamilisha ombi hili sasa. Tafadhali jaribu tena baada ya muda mfupi.',
      );
    }
    return raw;
  }

  Widget _recoveryHint(OrbiUiTokens ui) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.accentSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: ui.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _copy(
                'If you do not receive the OTP by phone, go back and try your registered email.',
                'Kama hujapata OTP kwa simu, rudi nyuma ujaribu email uliyosajili.',
              ),
              style: TextStyle(
                color: ui.textMuted,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
                          _success
                              ? _copy('Password updated', 'Nywila imebadilishwa')
                              : _step == 0
                              ? _copy('Reset password', 'Badili nywila')
                              : _copy('Enter OTP', 'Weka OTP'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _success
                              ? _copy(
                                  'You can now sign in with your new password.',
                                  'Sasa unaweza kuingia kwa kutumia nywila mpya.',
                                )
                              : _step == 0
                              ? _copy(
                                  'First request a one-time code using your registered phone or email.',
                                  'Kwanza omba msimbo wa mara moja kwa kutumia simu au barua pepe uliyosajili.',
                                )
                              : _copy(
                                  'Now enter the OTP we sent, then create a strong new password.',
                                  'Sasa weka OTP tuliyotuma, kisha tengeneza nywila mpya yenye nguvu.',
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ui.textMuted, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                        if (!_success && _step == 0) ...[
                          TextField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !auth.isLoading,
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
                          _recoveryHint(ui),
                        ],
                        if (!_success && _step == 1) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ui.cardMuted.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: ui.border.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: ui.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _identifierController.text.trim(),
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : _backToRequestStep,
                                  child: Text(
                                    _copy('Change', 'Badili'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            enabled: !auth.isLoading,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: _copy('OTP code', 'Msimbo wa OTP'),
                              prefixIcon: const Icon(Icons.pin_rounded),
                              counterText: '',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _recoveryHint(ui),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !auth.isLoading,
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
                              helperText: _copy(
                                'Use uppercase, lowercase, number, and special character.',
                                'Tumia herufi kubwa, ndogo, namba, na alama maalum.',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            enabled: !auth.isLoading,
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
                        ],
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
                        if (!_success && _step == 0)
                          ElevatedButton.icon(
                            onPressed: auth.isLoading || !_canResend
                                ? null
                                : _requestOtp,
                            icon: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sms_rounded),
                            label: Text(
                              _canResend
                                  ? _copy('Request OTP', 'Omba OTP')
                                  : _copy(
                                      'Resend in ${_secondsRemaining}s',
                                      'Subiri ${_secondsRemaining}s',
                                    ),
                            ),
                          ),
                        if (!_success && _step == 1) ...[
                          ElevatedButton.icon(
                            onPressed: auth.isLoading || !_canComplete
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
                              !_canComplete
                                  ? _copy(
                                      'Try again in ${_completeSecondsRemaining}s',
                                      'Jaribu tena baada ya ${_completeSecondsRemaining}s',
                                    )
                                  : _copy('Update password', 'Hifadhi nywila'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: auth.isLoading || !_canResend
                                ? null
                                : _requestOtp,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              _canResend
                                  ? _copy('Request new OTP', 'Omba OTP mpya')
                                  : _copy(
                                      'Resend in ${_secondsRemaining}s',
                                      'Subiri ${_secondsRemaining}s',
                                    ),
                            ),
                          ),
                        ],
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
