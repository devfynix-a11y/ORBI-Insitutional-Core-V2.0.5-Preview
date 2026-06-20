import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';

class WalletGrid extends StatelessWidget {
  final List<Map<String, dynamic>> wallets;

  const WalletGrid({super.key, required this.wallets});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: wallets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        final currency = (wallet['currency'] ?? wallet['wallet_currency'] ?? 'TZS')
            .toString()
            .trim();
        final balance = double.tryParse(
              (wallet['balance'] ??
                      wallet['available_balance'] ??
                      wallet['ledger_balance'] ??
                      0)
                  .toString(),
            ) ??
            0;
        final balanceText = formatCompactMoney(
          balance,
          currency,
          compactFrom: kLargeCardCompactThreshold,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet['name'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                MoneyText(
                  value: balanceText,
                  mainFontSize: 22,
                  sideFontSize: 12,
                  fitToWidth: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
