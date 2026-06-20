import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_theme.dart';
import 'payment_shared_widgets.dart';

class PaymentMerchantIdentityTile extends StatelessWidget {
  const PaymentMerchantIdentityTile({
    super.key,
    required this.ui,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final OrbiUiTokens ui;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.20),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.store_mall_directory_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '-' : title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty ? '-' : subtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'ORBI Pay',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentScanDetailTile extends StatelessWidget {
  const PaymentScanDetailTile({
    super.key,
    required this.label,
    required this.value,
    required this.ui,
  });

  final String label;
  final String value;
  final OrbiUiTokens ui;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ui.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentDetectedDraftCard extends StatelessWidget {
  const PaymentDetectedDraftCard({
    super.key,
    required this.ui,
    required this.draftAccent,
    required this.draftIcon,
    required this.headline,
    required this.subtitle,
    required this.sourceLabel,
    required this.confidenceColor,
    required this.confidenceLabel,
    required this.confidenceBadge,
    required this.showMerchantIdentity,
    required this.merchantIdentity,
    required this.draftLabel,
    required this.primaryAmount,
    required this.amountPendingLabel,
    required this.referenceText,
    required this.autoCreatedLabel,
    required this.detailTiles,
    required this.readyForPayment,
    required this.readyLabel,
    required this.needsReviewLabel,
  });

  final OrbiUiTokens ui;
  final Color draftAccent;
  final IconData draftIcon;
  final String headline;
  final String subtitle;
  final String sourceLabel;
  final Color confidenceColor;
  final String confidenceLabel;
  final Widget confidenceBadge;
  final bool showMerchantIdentity;
  final Widget? merchantIdentity;
  final String draftLabel;
  final String primaryAmount;
  final String amountPendingLabel;
  final String? referenceText;
  final String autoCreatedLabel;
  final List<Widget> detailTiles;
  final bool readyForPayment;
  final String readyLabel;
  final String needsReviewLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            draftAccent.withValues(alpha: 0.20),
            ui.card.withValues(alpha: 0.98),
            ui.cardMuted.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: draftAccent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: draftAccent.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: draftAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(draftIcon, color: draftAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: draftAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sourceLabel,
                  style: TextStyle(
                    color: draftAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              confidenceBadge,
            ],
          ),
          if (showMerchantIdentity && merchantIdentity != null) ...[
            const SizedBox(height: 14),
            merchantIdentity!,
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ui.card.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: draftAccent.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draftLabel,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        primaryAmount.isNotEmpty ? primaryAmount : amountPendingLabel,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: primaryAmount.isNotEmpty ? 24 : 18,
                        ),
                      ),
                      if ((referenceText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          referenceText!,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (readyForPayment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: draftAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: draftAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          autoCreatedLabel,
                          style: TextStyle(
                            color: draftAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (detailTiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: detailTiles),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: readyForPayment
                  ? ui.cardMuted.withValues(alpha: 0.72)
                  : ui.warningSoft.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  readyForPayment ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: readyForPayment ? ui.success : ui.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    readyForPayment ? readyLabel : needsReviewLabel,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentInvalidScanCard extends StatelessWidget {
  const PaymentInvalidScanCard({
    super.key,
    required this.ui,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onFallback,
  });

  final OrbiUiTokens ui;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.warningSoft.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.warning.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ui.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.qr_code_2_rounded, color: ui.warning),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onFallback,
            icon: const Icon(Icons.dialpad_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class PaymentScanResultCard extends StatelessWidget {
  const PaymentScanResultCard({
    super.key,
    required this.extractedDetailsLabel,
    required this.merchantLabel,
    required this.amountLabel,
    required this.dateLabel,
    required this.merchantValue,
    required this.amountValue,
    required this.dateValue,
    this.draftCard,
  });

  final String extractedDetailsLabel;
  final String merchantLabel;
  final String amountLabel;
  final String dateLabel;
  final String merchantValue;
  final String amountValue;
  final String dateValue;
  final Widget? draftCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (draftCard != null) ...[
          draftCard!,
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extractedDetailsLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                PaymentResultRow(label: merchantLabel, value: merchantValue),
                PaymentResultRow(
                  label: amountLabel,
                  value: amountValue,
                  moneyValue: true,
                ),
                PaymentResultRow(label: dateLabel, value: dateValue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PaymentScannerErrorView extends StatelessWidget {
  const PaymentScannerErrorView({
    super.key,
    required this.ui,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.permissionDenied,
    required this.openSettingsLabel,
    required this.onOpenSettings,
  });

  final OrbiUiTokens ui;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final bool permissionDenied;
  final String openSettingsLabel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ui.danger.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.camera_alt_outlined, color: ui.danger, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
                label: Text(retryLabel),
              ),
              if (permissionDenied)
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: ui.accent,
                    foregroundColor: Colors.white,
                  ),
                  label: Text(openSettingsLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
