import type { TransactionMovementClassification, TransactionMovementFamily } from './types.js';

export const cleanText = (value: any): string => String(value || '').trim();

export const lowerText = (value: any): string => cleanText(value).toLowerCase();

export const firstText = (values: any[]): string | undefined => {
  for (const value of values) {
    const candidate = cleanText(value);
    if (candidate && candidate.toLowerCase() !== 'null' && candidate !== 'N/A') return candidate;
  }
  return undefined;
};

export const walletOwner = (wallet: any, leg: any): string => cleanText(wallet?.user_id || leg?.user_id);

export const walletRoleText = (wallet: any): string => [
  wallet?.name,
  wallet?.wallet_name,
  wallet?.display_name,
  wallet?.type,
  wallet?.wallet_type,
  wallet?.bucket_type,
  wallet?.vault_role,
  wallet?.role,
  wallet?.management_tier,
].map(lowerText).join(' ');

export const isOperatingWallet = (wallet: any): boolean => {
  const roleText = walletRoleText(wallet);
  if (/(escrow|paysafe|pay safe|goal|saving|budget|mezani|pot|fungu|reserve|bill)/.test(roleText)) return false;
  return /(operating|main|internal vault|default|dilpesa|spendable|available)/.test(roleText);
};

export const transactionText = (transaction: any): string => {
  const metadata = transaction?.metadata || {};
  return [
    transaction?.type,
    transaction?.transaction_type,
    transaction?.description,
    transaction?.note,
    transaction?.status,
    metadata.service_context,
    metadata.escrow_status,
    metadata.shared_pot_id,
    metadata.shared_budget_id,
    metadata.source_internal_vault_id,
    metadata.source_internal_vault_name,
    metadata.destination_wallet_name,
    metadata.recipient_name,
    metadata.recipient_snapshot?.name,
  ].map(lowerText).join(' ');
};

export const makeClassification = (
  family: TransactionMovementFamily,
  code: string,
  group: string,
): TransactionMovementClassification => ({
  movement_family: family,
  movement_code: code,
  movement_group: group,
  source_context: family === 'EXTERNAL' ? 'EXTERNAL' : 'ORBI',
  destination_context: family,
  is_internal: family === 'INTERNAL_P2P' || family === 'INTERNAL_SS',
  is_self_service: family === 'INTERNAL_SS',
  is_p2p: family === 'INTERNAL_P2P',
  is_external: family === 'EXTERNAL',
});
