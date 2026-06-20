import 'package:flutter/material.dart';

import 'send_money_screen.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SendMoneyScreen(
      startInExternalMode: true,
      externalOnly: true,
      titleOverride: 'Withdraw',
      iconAssetPath: 'assets/icons/withdraw.svg',
      externalExperience: ExternalExperience.withdraw,
    );
  }
}
