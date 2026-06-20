import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../l10n/app_localizations.dart';
import '../theme/orbi_theme.dart';
import '../utils/otp_autofill.dart';

Future<String?> showSecurityCodeDialog({
  required BuildContext context,
  required String title,
  required String helperText,
  required String fieldLabel,
  required String confirmLabel,
  required String cancelLabel,
  int maxLength = 8,
  int? minLength,
  bool obscureText = false,
  bool digitsOnly = true,
  TextInputType keyboardType = TextInputType.number,
  TextInputAction textInputAction = TextInputAction.done,
  Future<void> Function(void Function(String code) onCode)? startListening,
  Future<void> Function()? stopListening,
  bool autoSubmitOnFill = false,
  Iterable<String>? autofillHints,
}) async {
  if (!context.mounted) return null;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SecurityCodeDialog(
      title: title,
      helperText: helperText,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      maxLength: maxLength,
      minLength: minLength,
      obscureText: obscureText,
      digitsOnly: digitsOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      startListening: startListening,
      stopListening: stopListening,
      autoSubmitOnFill: autoSubmitOnFill,
      autofillHints: autofillHints,
    ),
  );

  final normalized = result?.trim() ?? '';
  if (normalized.isEmpty) return null;
  return normalized;
}

Future<String?> showSecurityOtpDialog({
  required BuildContext context,
  required String title,
  required String helperText,
  int attempt = 1,
  int codeLength = 6,
  Future<void> Function(void Function(String code) onCode)? startListening,
  Future<void> Function()? stopListening,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showSecurityCodeDialog(
    context: context,
    title: title,
    helperText: attempt <= 1
        ? helperText
        : l10n.otpAttemptHelper(helperText, attempt),
    fieldLabel: l10n.otpEnterCodeLabel,
    confirmLabel: l10n.actionVerify,
    cancelLabel: l10n.actionCancel,
    maxLength: codeLength,
    minLength: codeLength,
    digitsOnly: true,
    keyboardType: TextInputType.number,
    startListening: startListening,
    stopListening: stopListening,
    autoSubmitOnFill: true,
    autofillHints: const [AutofillHints.oneTimeCode],
  );
}

class _SecurityCodeDialog extends StatefulWidget {
  const _SecurityCodeDialog({
    required this.title,
    required this.helperText,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.maxLength,
    required this.minLength,
    required this.obscureText,
    required this.digitsOnly,
    required this.keyboardType,
    required this.textInputAction,
    this.startListening,
    this.stopListening,
    required this.autoSubmitOnFill,
    this.autofillHints,
  });

  final String title;
  final String helperText;
  final String fieldLabel;
  final String confirmLabel;
  final String cancelLabel;
  final int maxLength;
  final int? minLength;
  final bool obscureText;
  final bool digitsOnly;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Future<void> Function(void Function(String code) onCode)?
  startListening;
  final Future<void> Function()? stopListening;
  final bool autoSubmitOnFill;
  final Iterable<String>? autofillHints;

  @override
  State<_SecurityCodeDialog> createState() => _SecurityCodeDialogState();
}

class _SecurityCodeDialogState extends State<_SecurityCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OtpAutoFillService _fallbackOtpAutoFill = OtpAutoFillService();
  bool _isClosing = false;
  bool _startedFallbackOtpListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
    if (widget.startListening != null) {
      unawaited(
        widget.startListening!.call((code) {
          _applyAutoFilledCode(code);
        }),
      );
    } else if (_shouldUseFallbackOtpListener) {
      _startedFallbackOtpListening = true;
      unawaited(
        _fallbackOtpAutoFill.startListening(onCode: (code) {
          _applyAutoFilledCode(code);
        }),
      );
    }
  }

  @override
  void dispose() {
    TextInput.finishAutofillContext(shouldSave: false);
    _focusNode.dispose();
    _controller.dispose();
    if (widget.stopListening != null) {
      unawaited(widget.stopListening!.call());
    }
    if (_startedFallbackOtpListening) {
      unawaited(_fallbackOtpAutoFill.stopListening());
    }
    super.dispose();
  }

  bool get _shouldUseFallbackOtpListener =>
      widget.startListening == null &&
      widget.digitsOnly &&
      widget.autoSubmitOnFill &&
      (widget.autofillHints?.contains(AutofillHints.oneTimeCode) ?? false);

  bool get _usesOtpPinField =>
      widget.digitsOnly &&
      !widget.obscureText &&
      (widget.autofillHints?.contains(AutofillHints.oneTimeCode) ?? false);

  void _applyAutoFilledCode(String code) {
    if (!mounted || _isClosing) return;
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    final minLength = widget.minLength ?? 0;
    if (widget.autoSubmitOnFill && code.trim().length >= minLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _close(code.trim());
        }
      });
    }
  }

  void _close([String? value]) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    _focusNode.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final formatters = <TextInputFormatter>[
      if (widget.digitsOnly) FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(widget.maxLength),
    ];

    return PopScope(
      canPop: false,
      child: AnimatedPadding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets.bottom + 20),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: screenHeight * 0.88,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.actionClose,
                                onPressed: () => _close(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: ui.iconMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.helperText,
                            style: TextStyle(
                              fontSize: 13,
                              color: ui.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _usesOtpPinField
                              ? PinFieldAutoFill(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autoFocus: false,
                                  codeLength: widget.maxLength,
                                  keyboardType: widget.keyboardType,
                                  textInputAction: widget.textInputAction,
                                  inputFormatters: formatters,
                                  currentCode: _controller.text,
                                  decoration: UnderlineDecoration(
                                    colorBuilder: FixedColorBuilder(ui.border),
                                    textStyle: TextStyle(
                                      color: ui.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onCodeChanged: (code) {
                                    final normalized = code?.trim() ?? '';
                                    final minLength = widget.minLength ?? 0;
                                    if (widget.autoSubmitOnFill &&
                                        normalized.length >= minLength) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) _close(normalized);
                                      });
                                    }
                                  },
                                  onCodeSubmitted: (code) {
                                    final normalized = code.trim();
                                    final minLength = widget.minLength ?? 0;
                                    if (normalized.length >= minLength) {
                                      _close(normalized);
                                    }
                                  },
                                )
                              : TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  style: TextStyle(color: ui.textPrimary),
                                  keyboardType: widget.keyboardType,
                                  textInputAction: widget.textInputAction,
                                  obscureText: widget.obscureText,
                                  inputFormatters: formatters,
                                  maxLength: widget.maxLength,
                                  autofocus: false,
                                  autofillHints: widget.autofillHints,
                                  enableSuggestions: !widget.digitsOnly,
                                  autocorrect: false,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  decoration: InputDecoration(
                                    labelText: widget.fieldLabel,
                                    counterText: '',
                                    labelStyle: TextStyle(color: ui.textMuted),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: ui.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: ui.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: ui.border),
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    final value = _controller.text.trim();
                                    final minLength = widget.minLength ?? 0;
                                    if (value.length >= minLength) {
                                      _close(value);
                                    }
                                  },
                                ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _close(),
                                  child: Text(widget.cancelLabel),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _close(_controller.text.trim()),
                                  child: Text(widget.confirmLabel),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
