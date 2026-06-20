import 'package:flutter/material.dart';

import 'send_money_screen.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SendMoneyScreen(
      startInExternalMode: true,
      externalOnly: true,
      titleOverride: 'Transfer',
      iconAssetPath: 'assets/icons/transfer.svg',
      externalExperience: ExternalExperience.transfer,
    );
  }
}
