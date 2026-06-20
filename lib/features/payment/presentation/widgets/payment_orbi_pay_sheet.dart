import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/widgets/orbi_amount_field.dart';
import 'payment_shared_widgets.dart';

class PaymentOrbiPaySheet extends StatefulWidget {
  const PaymentOrbiPaySheet({
    super.key,
    required this.ui,
    required this.l10n,
    required this.isSwahili,
    required this.merchantRef,
    required this.merchantDisplayName,
    required this.sourceWallets,
    required this.initialSelectedWalletId,
    required this.initialCurrency,
    required this.initialAmount,
    required this.initialNote,
    required this.walletIdOf,
    required this.walletCurrencyOf,
    required this.walletDisplayName,
    required this.previewAmountValue,
    required this.previewValue,
    required this.onPreview,
    required this.onSettle,
    required this.onCompleted,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final bool isSwahili;
  final String merchantRef;
  final String? merchantDisplayName;
  final List<Map<String, dynamic>> sourceWallets;
  final String initialSelectedWalletId;
  final String initialCurrency;
  final String initialAmount;
  final String initialNote;
  final String Function(Map<String, dynamic>) walletIdOf;
  final String Function(Map<String, dynamic>) walletCurrencyOf;
  final String Function(Map<String, dynamic>) walletDisplayName;
  final String Function(Map<String, dynamic>?) previewAmountValue;
  final String Function(Map<String, dynamic>?, List<String>) previewValue;
  final Future<Map<String, dynamic>> Function(
    String walletId,
    String currency,
    double amount,
    String note,
  )
  onPreview;
  final Future<Map<String, dynamic>> Function(
    String walletId,
    String currency,
    double amount,
    String note,
    Map<String, dynamic>? preview,
  )
  onSettle;
  final VoidCallback onCompleted;

  @override
  State<PaymentOrbiPaySheet> createState() => _PaymentOrbiPaySheetState();
}

class _PaymentOrbiPaySheetState extends State<PaymentOrbiPaySheet> {
  late String _selectedWalletId;
  late String _currency;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  Map<String, dynamic>? _preview;
  bool _busy = false;

  String _t(String en, String sw) => widget.isSwahili ? sw : en;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialSelectedWalletId;
    _currency = widget.initialCurrency;
    _amountController = TextEditingController(
      text: AmountInputFormatter.format(widget.initialAmount),
    );
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _previewPayment() async {
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.paymentOrbiPayAmountValidation)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      _preview = await widget.onPreview(
        _selectedWalletId,
        _currency,
        amount,
        _noteController.text.trim(),
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settlePayment() async {
    final amount = AmountInputFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    setState(() => _busy = true);
    try {
      await widget.onSettle(
        _selectedWalletId,
        _currency,
        amount,
        _noteController.text.trim(),
        _preview,
      );
      if (!mounted) return;
      widget.onCompleted();
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantAmountLabel = _t('Amount to pay', 'Kiasi cha kulipa');
    final merchantAmountHint = _t(
      'Enter the amount you want to pay this merchant.',
      'Weka kiasi unachotaka kumlipa mfanyabiashara huyu.',
    );
    final merchantNoteLabel = _t('Payment note', 'Maelezo ya malipo');
    final merchantNoteHint = _t(
      'Add a short note for this merchant payment if needed.',
      'Ongeza maelezo mafupi kwa malipo haya ya mfanyabiashara ikiwa yanahitajika.',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.ui.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.ui.accent.withValues(alpha: 0.16),
                      widget.ui.card.withValues(alpha: 0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: widget.ui.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.ui.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.bolt_rounded, color: widget.ui.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.l10n.paymentOrbiPayTitle,
                            style: TextStyle(
                              color: widget.ui.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.merchantDisplayName?.trim().isNotEmpty ==
                                    true
                                ? widget.merchantDisplayName!.trim()
                                : widget.merchantRef,
                            style: TextStyle(
                              color: widget.ui.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedWalletId,
                decoration: InputDecoration(
                  labelText: widget.l10n.goalsSourceWalletLabel,
                  helperText: _t('Choose wallet.', 'Chagua wallet.'),
                ),
                items: widget.sourceWallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: widget.walletIdOf(wallet),
                        child: Text(widget.walletDisplayName(wallet)),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null || value.isEmpty) return;
                        final wallet = widget.sourceWallets.firstWhere(
                          (item) => widget.walletIdOf(item) == value,
                          orElse: () => widget.sourceWallets.first,
                        );
                        setState(() {
                          _selectedWalletId = value;
                          _currency = widget.walletCurrencyOf(wallet);
                        });
                      },
              ),
              const SizedBox(height: 12),
              OrbiAmountField(
                controller: _amountController,
                inputFormatters: [AmountInputFormatter()],
                label: merchantAmountLabel,
                hint: merchantAmountHint,
                currency: _currency,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: merchantNoteLabel,
                  hintText: merchantNoteHint,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _preview == null
                    ? Container(
                        key: const ValueKey('preview-empty'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.ui.cardMuted.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.ui.border.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.ui.accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.visibility_rounded,
                                color: widget.ui.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.l10n.paymentOrbiPayPreviewTitle,
                                style: TextStyle(
                                  color: widget.ui.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('preview-ready'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.ui.cardMuted.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: widget.ui.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.l10n.paymentOrbiPayPreviewTitle,
                              style: TextStyle(
                                color: widget.ui.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            PaymentResultRow(
                              label: widget.l10n.paymentAmountLabel,
                              value: widget.previewAmountValue(_preview),
                              moneyValue: true,
                            ),
                            PaymentResultRow(
                              label: widget.l10n.paymentScanDetailReference,
                              value: widget.previewValue(_preview, [
                                'reference',
                                'merchantReference',
                                'paymentReference',
                              ]),
                            ),
                            PaymentResultRow(
                              label: widget.l10n.paymentNoteLabel,
                              value: widget.previewValue(_preview, [
                                'description',
                                'note',
                                'narration',
                              ]),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _previewPayment,
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.ui.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: widget.ui.borderStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: Text(widget.l10n.paymentOrbiPayPreviewAction),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || _preview == null
                          ? null
                          : _settlePayment,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payments_rounded),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.ui.iconMuted,
                        foregroundColor: const Color(0xFF151617),
                        disabledBackgroundColor: widget.ui.cardStrong,
                        disabledForegroundColor: widget.ui.textSoft,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: Text(widget.l10n.paymentOrbiPayConfirmAction),
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
}
