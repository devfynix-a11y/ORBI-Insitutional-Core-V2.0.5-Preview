import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/amount_input_formatter.dart';
import '../../../../core/widgets/orbi_amount_field.dart';
import 'payment_shared_widgets.dart';

enum PaymentBillFundingMode { reserve, wallet, sharedBudget }

class PaymentBillPaySheet extends StatefulWidget {
  const PaymentBillPaySheet({
    super.key,
    required this.ui,
    required this.l10n,
    required this.isSwahili,
    required this.provider,
    required this.categoryLabel,
    required this.providerAccent,
    required this.providerIcon,
    required this.providerAssets,
    this.providerLogoUrl,
    required this.sourceWallets,
    required this.sharedBudgets,
    required this.matchingReserve,
    required this.strongReserveMatch,
    required this.initialFundingMode,
    required this.initialSelectedWalletId,
    required this.initialCurrency,
    required this.initialSelectedSharedBudgetId,
    required this.initialAmount,
    required this.initialReference,
    required this.initialNote,
    required this.walletIdOf,
    required this.walletCurrencyOf,
    required this.walletDisplayName,
    required this.previewAmountValue,
    required this.previewValue,
    required this.onPreviewWallet,
    required this.onPreviewReserve,
    required this.onPreviewSharedBudget,
    required this.onSettleWallet,
    required this.onSettleReserve,
    required this.onSettleSharedBudget,
    required this.onCompleted,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final bool isSwahili;
  final String provider;
  final String categoryLabel;
  final Color providerAccent;
  final IconData providerIcon;
  final List<String> providerAssets;
  final String? providerLogoUrl;
  final List<Map<String, dynamic>> sourceWallets;
  final List<Map<String, dynamic>> sharedBudgets;
  final Map<String, dynamic>? matchingReserve;
  final bool strongReserveMatch;
  final PaymentBillFundingMode initialFundingMode;
  final String initialSelectedWalletId;
  final String initialCurrency;
  final String initialSelectedSharedBudgetId;
  final String initialAmount;
  final String initialReference;
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
    String reference,
    String note,
  )
  onPreviewWallet;
  final Future<Map<String, dynamic>> Function(
    String currency,
    double amount,
    String reference,
    String note,
  )
  onPreviewReserve;
  final Future<Map<String, dynamic>> Function(
    String sharedBudgetId,
    double amount,
    String reference,
    String note,
  )
  onPreviewSharedBudget;
  final Future<void> Function(
    String walletId,
    String currency,
    double amount,
    String reference,
    String note,
    Map<String, dynamic>? preview,
  )
  onSettleWallet;
  final Future<void> Function(
    String currency,
    double amount,
    String reference,
    String note,
    Map<String, dynamic>? preview,
  )
  onSettleReserve;
  final Future<void> Function(
    String sharedBudgetId,
    double amount,
    String reference,
    String note,
  )
  onSettleSharedBudget;
  final void Function(PaymentBillFundingMode mode) onCompleted;

  @override
  State<PaymentBillPaySheet> createState() => _PaymentBillPaySheetState();
}

class _PaymentBillPaySheetState extends State<PaymentBillPaySheet> {
  late PaymentBillFundingMode _fundingMode;
  late String _selectedWalletId;
  late String _currency;
  late String _selectedSharedBudgetId;
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _noteController;
  Map<String, dynamic>? _preview;
  bool _busy = false;

  String _t(String en, String sw) => widget.isSwahili ? sw : en;

  @override
  void initState() {
    super.initState();
    _fundingMode = widget.initialFundingMode;
    _selectedWalletId = widget.initialSelectedWalletId;
    _currency = widget.initialCurrency;
    _selectedSharedBudgetId = widget.initialSelectedSharedBudgetId;
    _amountController = TextEditingController(
      text: AmountInputFormatter.format(widget.initialAmount),
    );
    _referenceController = TextEditingController(text: widget.initialReference);
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
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
      _preview = _fundingMode == PaymentBillFundingMode.sharedBudget
          ? await widget.onPreviewSharedBudget(
              _selectedSharedBudgetId,
              amount,
              _referenceController.text.trim(),
              _noteController.text.trim(),
            )
          : _fundingMode == PaymentBillFundingMode.reserve
          ? await widget.onPreviewReserve(
              _currency,
              amount,
              _referenceController.text.trim(),
              _noteController.text.trim(),
            )
          : await widget.onPreviewWallet(
              _selectedWalletId,
              _currency,
              amount,
              _referenceController.text.trim(),
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
      if (_fundingMode == PaymentBillFundingMode.sharedBudget) {
        await widget.onSettleSharedBudget(
          _selectedSharedBudgetId,
          amount,
          _referenceController.text.trim(),
          _noteController.text.trim(),
        );
      } else if (_fundingMode == PaymentBillFundingMode.reserve) {
        await widget.onSettleReserve(
          _currency,
          amount,
          _referenceController.text.trim(),
          _noteController.text.trim(),
          _preview,
        );
      } else {
        await widget.onSettleWallet(
          _selectedWalletId,
          _currency,
          amount,
          _referenceController.text.trim(),
          _noteController.text.trim(),
          _preview,
        );
      }
      if (!mounted) return;
      widget.onCompleted(_fundingMode);
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAmountLabel = _fundingMode == PaymentBillFundingMode.reserve
        ? _t('Amount to pay from reserve', 'Kiasi cha kulipa kutoka reserve')
        : _fundingMode == PaymentBillFundingMode.sharedBudget
        ? _t(
            'Amount to charge to shared budget',
            'Kiasi cha kutumia kwenye shared budget',
          )
        : _t('Bill amount', 'Kiasi cha bili');
    final billAmountHint = _fundingMode == PaymentBillFundingMode.reserve
        ? _t(
            'Enter the bill amount covered by this reserve',
            'Weka kiasi cha bili kitakacholipwa na reserve hii',
          )
        : _fundingMode == PaymentBillFundingMode.sharedBudget
        ? _t(
            'Enter the bill amount for this shared budget payment',
            'Weka kiasi cha bili kwa malipo haya ya shared budget',
          )
        : _t('Enter the bill amount to pay', 'Weka kiasi cha bili kulipa');
    final categoryLower = widget.categoryLabel.toLowerCase();
    final billReferenceLabel = categoryLower.contains('school')
        ? _t('Student / invoice reference', 'Rejea ya mwanafunzi / invoice')
        : categoryLower.contains('government')
        ? _t('Control / service reference', 'Rejea ya control / huduma')
        : _t('Bill reference', 'Rejea ya bili');
    final billReferenceHint = categoryLower.contains('school')
        ? _t(
            'Enter student number, invoice, or fee reference',
            'Weka namba ya mwanafunzi, invoice, au rejea ya ada',
          )
        : categoryLower.contains('government')
        ? _t(
            'Enter control number, NIDA, TRA, or service reference',
            'Weka control number, NIDA, TRA, au rejea ya huduma',
          )
        : widget.l10n.paymentBillReferenceHint;
    final billNoteLabel = _t('Payment note', 'Maelezo ya malipo');
    final billNoteHint = _t(
      'Add a short note for this bill payment if needed.',
      'Ongeza maelezo mafupi kwa malipo haya ya bili ikiwa yanahitajika.',
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
                      widget.providerAccent.withValues(alpha: 0.16),
                      widget.ui.card.withValues(alpha: 0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: widget.providerAccent.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.providerAccent.withValues(alpha: 0.20),
                        ),
                      ),
                      child: PaymentProviderAvatar(
                        assetCandidates: widget.providerAssets,
                        logoUrl: widget.providerLogoUrl,
                        icon: widget.providerIcon,
                        color: widget.providerAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.l10n.paymentBillPayTitle,
                            style: TextStyle(
                              color: widget.ui.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.provider} • ${widget.categoryLabel}',
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
              if (widget.matchingReserve != null ||
                  widget.sharedBudgets.isNotEmpty ||
                  widget.sourceWallets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SegmentedButton<PaymentBillFundingMode>(
                    segments: <ButtonSegment<PaymentBillFundingMode>>[
                      if (widget.matchingReserve != null)
                        ButtonSegment<PaymentBillFundingMode>(
                          value: PaymentBillFundingMode.reserve,
                          label: Text(widget.l10n.paymentBillFundingReserve),
                          icon: const Icon(Icons.lock_clock_rounded),
                        ),
                      if (widget.sourceWallets.isNotEmpty)
                        ButtonSegment<PaymentBillFundingMode>(
                          value: PaymentBillFundingMode.wallet,
                          label: Text(widget.l10n.paymentBillFundingWallet),
                          icon: const Icon(
                            Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      if (widget.sharedBudgets.isNotEmpty)
                        ButtonSegment<PaymentBillFundingMode>(
                          value: PaymentBillFundingMode.sharedBudget,
                          label: Text(
                            widget.l10n.paymentBillFundingSharedBudget,
                          ),
                          icon: const Icon(Icons.groups_rounded),
                        ),
                    ],
                    selected: <PaymentBillFundingMode>{_fundingMode},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) {
                            if (selection.isEmpty) return;
                            setState(() {
                              _fundingMode = selection.first;
                              _preview = null;
                            });
                          },
                  ),
                ),
              if (widget.matchingReserve != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.providerAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.providerAccent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fundingMode == PaymentBillFundingMode.reserve
                              ? widget.l10n.paymentBillReserveUsingTitle
                              : widget.l10n.paymentBillReserveMatchedTitle,
                          style: TextStyle(
                            color: widget.ui.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.strongReserveMatch
                                ? widget.ui.success.withValues(alpha: 0.12)
                                : widget.ui.iconMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: widget.strongReserveMatch
                                  ? widget.ui.success.withValues(alpha: 0.24)
                                  : widget.providerAccent.withValues(
                                      alpha: 0.20,
                                    ),
                            ),
                          ),
                          child: Text(
                            widget.strongReserveMatch
                                ? widget.l10n.paymentBillReserveStrongMatch
                                : widget.l10n.paymentBillReservePossibleMatch,
                            style: TextStyle(
                              color: widget.strongReserveMatch
                                  ? widget.ui.success
                                  : widget.ui.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fundingMode == PaymentBillFundingMode.reserve
                              ? widget.l10n.paymentBillReserveUsingMessage(
                                  widget.provider,
                                  (widget.matchingReserve!['locked_balance'] ??
                                          widget
                                              .matchingReserve!['reserve_amount'] ??
                                          '-')
                                      .toString(),
                                )
                              : widget.l10n.paymentBillReserveMatchedMessage(
                                  widget.provider,
                                  (widget.matchingReserve!['locked_balance'] ??
                                          widget
                                              .matchingReserve!['reserve_amount'] ??
                                          '-')
                                      .toString(),
                                ),
                          style: TextStyle(
                            color: widget.ui.textMuted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_fundingMode == PaymentBillFundingMode.wallet ||
                  _fundingMode == PaymentBillFundingMode.reserve) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: InputDecoration(
                    labelText: widget.l10n.goalsSourceWalletLabel,
                    helperText: _fundingMode == PaymentBillFundingMode.reserve
                        ? widget.l10n.paymentBillReserveHelper
                        : widget.l10n.paymentBillWalletHelper,
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
                            _preview = null;
                          });
                        },
                ),
              ] else if (widget.sharedBudgets.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedSharedBudgetId.isEmpty
                      ? null
                      : _selectedSharedBudgetId,
                  decoration: InputDecoration(
                    labelText: widget.l10n.paymentBillFundingSharedBudget,
                    helperText: widget.l10n.paymentBillSharedBudgetHelper,
                  ),
                  items: widget.sharedBudgets
                      .map(
                        (budget) => DropdownMenuItem<String>(
                          value: (budget['id'] ?? '').toString(),
                          child: Text(
                            (budget['name'] ??
                                    budget['purpose'] ??
                                    'Shared budget')
                                .toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null || value.isEmpty) return;
                          setState(() {
                            _selectedSharedBudgetId = value;
                            _preview = null;
                          });
                        },
                ),
              ],
              const SizedBox(height: 12),
              OrbiAmountField(
                controller: _amountController,
                inputFormatters: [AmountInputFormatter()],
                label: billAmountLabel,
                hint: billAmountHint,
                currency: _currency,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: billReferenceLabel,
                  hintText: billReferenceHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: billNoteLabel,
                  hintText: billNoteHint,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _preview == null
                    ? Container(
                        key: const ValueKey('bill-preview-empty'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.ui.cardMuted.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.providerAccent.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.providerAccent.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: widget.providerAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.l10n.paymentBillPreviewTitle,
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
                        key: const ValueKey('bill-preview-ready'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.ui.cardMuted.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.providerAccent.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.l10n.paymentBillPreviewTitle,
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
                              value: widget.previewValue(_preview, const [
                                'reference',
                                'bill_reference',
                                'paymentReference',
                              ]),
                            ),
                            PaymentResultRow(
                              label: widget.l10n.paymentNoteLabel,
                              value: widget.previewValue(_preview, const [
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
                        foregroundColor: widget.providerAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: widget.providerAccent.withValues(alpha: 0.28),
                        ),
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
                        backgroundColor: widget.providerAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: widget.ui.cardStrong,
                        disabledForegroundColor: widget.ui.textSoft,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: Text(widget.l10n.paymentBillPayConfirmAction),
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
