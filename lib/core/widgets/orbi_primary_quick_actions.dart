import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import 'orbi_quick_action_row.dart';

class OrbiPrimaryQuickActions extends StatelessWidget {
  const OrbiPrimaryQuickActions({
    super.key,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSend,
    required this.onScan,
  });

  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSend;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    return OrbiQuickActionRow(
      compact: true,
      items: [
        OrbiQuickActionRowItem(
          icon: Icons.download_for_offline_rounded,
          label: sw ? 'Amana' : 'Deposit',
          onTap: onDeposit,
        ),
        OrbiQuickActionRowItem(
          icon: Icons.upload_rounded,
          label: sw ? 'Toa' : 'Withdraw',
          onTap: onWithdraw,
          assetPath: 'assets/icons/withdraw.svg',
        ),
        OrbiQuickActionRowItem(
          icon: Icons.send_rounded,
          label: sw ? 'Tuma' : 'Send',
          onTap: onSend,
          assetPath: 'assets/icons/send.svg',
        ),
        OrbiQuickActionRowItem(
          icon: Icons.qr_code_scanner_rounded,
          label: l10n.shellActionScanPay,
          onTap: onScan,
        ),
      ],
    );
  }
}
