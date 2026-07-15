import type { TransactionMovementClassification, TransactionMovementClassifierInput } from './types.js';
import {
  cleanText,
  firstText,
  isOperatingWallet,
  makeClassification,
  transactionText,
  walletOwner,
} from './movementRules.js';

export class TransactionMovementClassifier {
  static classify(args: TransactionMovementClassifierInput): TransactionMovementClassification {
    const transaction = args.transaction || {};
    const metadata = transaction.metadata || {};
    const legs = args.legs || [];
    const walletMap = args.walletMap;

    const lookupWallet = (walletId: any): any => {
      const id = cleanText(walletId);
      if (!id) return null;
      if (walletMap instanceof Map) return walletMap.get(id);
      return walletMap?.[id];
    };

    const txText = transactionText(transaction);
    const sourceWallet = lookupWallet(transaction.walletId || transaction.wallet_id || transaction.source_wallet_id);
    const targetWallet = lookupWallet(transaction.toWalletId || transaction.to_wallet_id || transaction.destination_wallet_id);
    const debitLegs = legs.filter((leg: any) => cleanText(leg?.entry_side || leg?.entry_type).toUpperCase().includes('DEBIT'));
    const creditLegs = legs.filter((leg: any) => cleanText(leg?.entry_side || leg?.entry_type).toUpperCase().includes('CREDIT'));
    const operatingDebit = debitLegs.find((leg: any) => isOperatingWallet(lookupWallet(leg?.wallet_id)));
    const operatingCredit = creditLegs.find((leg: any) => isOperatingWallet(lookupWallet(leg?.wallet_id)));
    const sourceOwner = firstText([
      walletOwner(sourceWallet, operatingDebit),
      walletOwner(lookupWallet(operatingDebit?.wallet_id), operatingDebit),
      transaction.user_id,
    ]);
    const destinationOwner = firstText([
      walletOwner(targetWallet, operatingCredit),
      walletOwner(lookupWallet(operatingCredit?.wallet_id), operatingCredit),
      metadata.recipient_snapshot?.id,
      metadata.recipient_id,
    ]);

    if (metadata.shared_pot_id || /shared_pot|shared pot|fungu| pot_/.test(txText)) {
      const code = /withdraw|withdrawal|pot_w_|target_wallet_role/.test(txText)
        ? 'SS_SHARED_POT_WITHDRAWAL'
        : 'SS_SHARED_POT_CONTRIBUTION';
      return makeClassification('INTERNAL_SS', code, 'Internal self-service movement');
    }

    if (metadata.shared_budget_id || /shared_budget|shared budget|mezani/.test(txText)) {
      return makeClassification('INTERNAL_SS', 'SS_SHARED_BUDGET_MOVEMENT', 'Internal self-service movement');
    }

    if (sourceOwner && destinationOwner && sourceOwner !== destinationOwner) {
      return makeClassification('INTERNAL_P2P', 'P2P_TRANSFER', 'Internal P2P movement');
    }

    if (metadata.source_internal_vault_id || metadata.escrow_vault_id || /escrow|paysafe|pay safe/.test(txText)) {
      const code = /refund|refunded|reverse/.test(txText)
        ? 'SS_PAYSAFE_REFUND'
        : /release|settlement/.test(txText)
          ? 'SS_PAYSAFE_RELEASE'
          : 'SS_PAYSAFE_ESCROW';
      return makeClassification('INTERNAL_SS', code, 'Internal self-service movement');
    }

    if (/(external|bank|mobile_money|mobile money|card|cashout|cash out|provider|merchant_settlement)/.test(txText)) {
      return makeClassification(
        'EXTERNAL',
        /deposit|external_to_internal/.test(txText) ? 'EXTERNAL_DEPOSIT' : 'EXTERNAL_WITHDRAWAL',
        'External money movement',
      );
    }

    if (sourceOwner && destinationOwner && sourceOwner === destinationOwner) {
      return makeClassification('INTERNAL_SS', 'SS_INTERNAL_REALLOCATION', 'Internal self-service movement');
    }

    if (legs.length >= 2) {
      return makeClassification('INTERNAL_SS', 'SS_INTERNAL_MOVEMENT', 'Internal self-service movement');
    }

    return makeClassification('UNKNOWN', 'UNKNOWN_MOVEMENT', 'Unclassified movement');
  }
}
