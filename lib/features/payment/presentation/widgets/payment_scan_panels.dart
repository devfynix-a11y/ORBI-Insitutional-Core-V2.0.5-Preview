import 'dart:io';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/theme/orbi_theme.dart';

class PaymentQrScannerPanel extends StatelessWidget {
  const PaymentQrScannerPanel({
    super.key,
    required this.ui,
    required this.l10n,
    required this.scannerView,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.statusIcon,
    required this.statusColor,
    required this.flashOn,
    required this.onToggleTorch,
    required this.onResumeScan,
    this.draftCard,
    this.primaryAction,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final Widget scannerView;
  final String statusTitle;
  final String statusSubtitle;
  final IconData statusIcon;
  final Color statusColor;
  final bool flashOn;
  final VoidCallback onToggleTorch;
  final VoidCallback onResumeScan;
  final Widget? draftCard;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ui.card.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ui.accent.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              scannerView,
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ui.cardMuted.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ui.border.withValues(alpha: 0.72)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ui.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleTorch,
                icon: Icon(
                  flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                label: Text(flashOn ? l10n.paymentFlashOn : l10n.paymentFlashOff),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onResumeScan,
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: Text(l10n.actionScanAgain),
              ),
            ),
          ],
        ),
        if (draftCard != null) ...[
          const SizedBox(height: 14),
          draftCard!,
        ],
        if (primaryAction != null) ...[
          const SizedBox(height: 12),
          primaryAction!,
        ],
      ],
    );
  }
}

class PaymentReceiptScannerPanel extends StatelessWidget {
  const PaymentReceiptScannerPanel({
    super.key,
    required this.ui,
    required this.l10n,
    required this.selectedFile,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onAnalyze,
    required this.analyzeEnabled,
    this.filePathText,
    this.resultCard,
    this.primaryAction,
  });

  final OrbiUiTokens ui;
  final AppLocalizations l10n;
  final File? selectedFile;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onAnalyze;
  final bool analyzeEnabled;
  final String? filePathText;
  final Widget? resultCard;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ui.card.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ui.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1.15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: ui.cardMuted.withValues(alpha: 0.78),
                child: selectedFile == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: ui.cardMuted,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: ui.accent,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.paymentNoReceiptSelected,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Image.file(selectedFile!, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.actionFromGallery),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPickCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(l10n.actionCapture),
              ),
            ),
          ],
        ),
        if (selectedFile != null) ...[
          if ((filePathText ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              filePathText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: analyzeEnabled ? onAnalyze : null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(l10n.paymentAnalyzeReceipt),
          ),
          if (resultCard != null) ...[
            const SizedBox(height: 12),
            resultCard!,
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: 10),
            primaryAction!,
          ],
        ],
      ],
    );
  }
}
