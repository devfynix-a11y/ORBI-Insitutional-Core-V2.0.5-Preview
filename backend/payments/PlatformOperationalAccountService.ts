import { getAdminSupabase, getSupabase } from '../supabaseClient.js';
import { DataProtection } from '../security/DataProtection.js';
import { Audit } from '../security/audit.js';
import { TransactionService } from '../../ledger/transactionService.js';
import { UUID } from '../../services/utils.js';

export const PLATFORM_OPERATIONAL_ACCOUNT_ROLES = [
  'MAIN_COLLECTION',
  'FEE_COLLECTION',
  'TAX_COLLECTION',
  'SALARY',
  'PLATFORM_FUNDING',
  'REFUND_RESERVE',
  'CHARGEBACK_RESERVE',
  'PROVIDER_SETTLEMENT',
  'ESCROW_RESERVE',
  'OPERATING_RESERVE',
  'CUSTOM',
] as const;

export type PlatformOperationalAccountRole = (typeof PLATFORM_OPERATIONAL_ACCOUNT_ROLES)[number];

type OperationalAccountInput = {
  role?: PlatformOperationalAccountRole;
  name?: string;
  currency?: string;
  status?: 'active' | 'inactive' | 'locked';
  color?: string;
  icon?: string;
  metadata?: Record<string, unknown>;
};

type OperationalTransferInput = {
  sourceWalletId?: string;
  targetWalletId?: string;
  amount: number;
  currency: string;
  reason: string;
  originalTransactionId?: string;
  originalReferenceId?: string;
  idempotencyKey?: string;
  metadata?: Record<string, unknown>;
};

const OPERATIONAL_META_FLAG = 'is_platform_operational_account';

const normalizeCurrency = (value: unknown) => String(value || 'TZS').trim().toUpperCase();
const normalizeStatus = (value: unknown) => String(value || 'active').trim().toLowerCase();

const assertAmount = (amount: unknown) => {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    throw new Error('AMOUNT_INVALID: Operational ledger movement requires a positive amount.');
  }
  return Math.round(numeric * 10000) / 10000;
};

export class PlatformOperationalAccountService {
  private ledger = new TransactionService();

  private client() {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');
    return sb;
  }

  private async resolveInternalEntity(entityId: string) {
    const sb = this.client();
    const [walletResult, vaultResult] = await Promise.all([
      sb.from('wallets').select('id, user_id, name, balance, currency, status, is_locked, metadata').eq('id', entityId).maybeSingle(),
      sb.from('platform_vaults').select('id, user_id, vault_role, name, balance, currency, status, is_locked, metadata').eq('id', entityId).maybeSingle(),
    ]);

    const wallet = walletResult.data;
    const vault = vaultResult.data;
    if (wallet && vault) throw new Error('LEDGER_ENTITY_AMBIGUOUS');
    const record = wallet || vault;
    if (!record) throw new Error(`LEDGER_ENTITY_MISSING: ${entityId}`);
    if (record.is_locked || ['locked', 'frozen', 'blocked', 'suspended'].includes(normalizeStatus(record.status))) {
      throw new Error(`WALLET_LOCKED: ${entityId}`);
    }
    return {
      table: wallet ? 'wallets' : 'platform_vaults',
      record,
      currency: normalizeCurrency(record.currency),
      isOperational: Boolean(record.metadata?.[OPERATIONAL_META_FLAG]),
    };
  }

  private async requireOperationalAccount(accountId: string) {
    const sb = this.client();
    const { data, error } = await sb
      .from('platform_vaults')
      .select('id, user_id, vault_role, name, balance, currency, status, is_locked, metadata')
      .eq('id', accountId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data || data.metadata?.[OPERATIONAL_META_FLAG] !== true) {
      throw new Error('PLATFORM_OPERATIONAL_ACCOUNT_NOT_FOUND');
    }
    if (data.is_locked || ['locked', 'frozen', 'blocked', 'suspended'].includes(normalizeStatus(data.status))) {
      throw new Error(`OPERATIONAL_ACCOUNT_LOCKED: ${accountId}`);
    }
    return data;
  }

  async list(filters: Record<string, unknown> = {}) {
    const sb = this.client();
    let query = sb
      .from('platform_vaults')
      .select('*')
      .eq(`metadata->>${OPERATIONAL_META_FLAG}`, 'true')
      .order('created_at', { ascending: false });

    if (filters.role) query = query.eq('metadata->>operational_role', String(filters.role).toUpperCase());
    if (filters.status) query = query.eq('status', normalizeStatus(filters.status));
    if (filters.currency) query = query.eq('currency', normalizeCurrency(filters.currency));

    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async upsert(input: OperationalAccountInput, actorId: string, accountId?: string) {
    const sb = this.client();
    const existing = accountId
      ? await sb
          .from('platform_vaults')
          .select('id, vault_role, name, currency, status, color, icon, metadata')
          .eq('id', accountId)
          .eq(`metadata->>${OPERATIONAL_META_FLAG}`, 'true')
          .maybeSingle()
      : null;

    if (accountId && !existing?.data) {
      throw new Error('PLATFORM_OPERATIONAL_ACCOUNT_NOT_FOUND');
    }

    const existingRole = String(existing?.data?.metadata?.operational_role || existing?.data?.vault_role || '')
      .replace(/^PLATFORM_/, '')
      .trim()
      .toUpperCase();
    const role = String(input.role || existingRole || '').trim().toUpperCase() as PlatformOperationalAccountRole;
    if (!PLATFORM_OPERATIONAL_ACCOUNT_ROLES.includes(role)) {
      throw new Error('OPERATIONAL_ACCOUNT_ROLE_INVALID');
    }

    const metadata = {
      ...(existing?.data?.metadata || {}),
      ...(input.metadata || {}),
      [OPERATIONAL_META_FLAG]: true,
      operational_role: role,
      no_direct_balance_mutation: true,
      ledger_only: true,
      updated_by: actorId,
      updated_at: new Date().toISOString(),
    };

    const payload: Record<string, unknown> = {
      vault_role: `PLATFORM_${role}`,
      name: input.name || existing?.data?.name,
      currency: normalizeCurrency(input.currency || existing?.data?.currency),
      status: normalizeStatus(input.status || existing?.data?.status || 'active'),
      color: input.color || existing?.data?.color || '#22D3EE',
      icon: input.icon || existing?.data?.icon || 'building-2',
      metadata,
      updated_at: new Date().toISOString(),
    };

    if (!payload.name) {
      throw new Error('OPERATIONAL_ACCOUNT_NAME_REQUIRED');
    }

    if (accountId) {
      const { data, error } = await sb
        .from('platform_vaults')
        .update(payload)
        .eq('id', accountId)
        .eq(`metadata->>${OPERATIONAL_META_FLAG}`, 'true')
        .select('*')
        .single();
      if (error) throw new Error(error.message);
      await Audit.log('FINANCIAL', actorId, 'PLATFORM_OPERATIONAL_ACCOUNT_UPDATED', { accountId, role, name: payload.name });
      return data;
    }

    const encryptedZero = await DataProtection.encryptAmount(0);
    const { data, error } = await sb
      .from('platform_vaults')
      .insert({
        ...payload,
        user_id: null,
        balance: 0,
        encrypted_balance: encryptedZero,
        metadata: {
          ...metadata,
          created_by: actorId,
          created_at: new Date().toISOString(),
        },
      })
      .select('*')
      .single();
    if (error) throw new Error(error.message);
    await Audit.log('FINANCIAL', actorId, 'PLATFORM_OPERATIONAL_ACCOUNT_CREATED', { accountId: data.id, role, name: input.name });
    return data;
  }

  async history(accountId: string, limit = 100, offset = 0) {
    await this.requireOperationalAccount(accountId);
    return this.ledger.getWalletHistory(accountId, limit, offset);
  }

  async fund(accountId: string, input: OperationalTransferInput, actorId: string) {
    if (!input.sourceWalletId) throw new Error('SOURCE_WALLET_REQUIRED');
    const amount = assertAmount(input.amount);
    const currency = normalizeCurrency(input.currency);
    const source = await this.resolveInternalEntity(input.sourceWalletId);
    const target = await this.requireOperationalAccount(accountId);
    if (String(source.record.id) === String(target.id)) throw new Error('SOURCE_TARGET_WALLET_MATCH');
    if (source.currency !== currency || normalizeCurrency(target.currency) !== currency) {
      throw new Error('CURRENCY_MISMATCH: Source, operational account, and payload currency must match.');
    }

    const txId = UUID.generate();
    const referenceId = `OPA-FUND-${UUID.generateShortCode(10)}`;
    await this.ledger.postTransactionWithLedger({
      id: txId,
      walletId: input.sourceWalletId,
      toWalletId: accountId,
      amount,
      currency,
      description: input.reason,
      type: 'transfer',
      status: 'completed',
      referenceId,
      metadata: {
        ...(input.metadata || {}),
        platform_operation: 'OPERATIONAL_ACCOUNT_FUND',
        source_wallet_id: input.sourceWalletId,
        target_operational_account_id: accountId,
        operational_account_role: target.metadata?.operational_role || target.vault_role,
        original_transaction_id: input.originalTransactionId || null,
        original_reference_id: input.originalReferenceId || null,
        actor_id: actorId,
        closed_loop: true,
        no_direct_balance_mutation: true,
      },
    }, [
      { transactionId: txId, walletId: input.sourceWalletId, type: 'DEBIT', amount, currency, timestamp: new Date().toISOString(), description: input.reason },
      { transactionId: txId, walletId: accountId, type: 'CREDIT', amount, currency, timestamp: new Date().toISOString(), description: input.reason },
    ]);

    await Audit.log('FINANCIAL', actorId, 'PLATFORM_OPERATIONAL_ACCOUNT_FUNDED', {
      accountId,
      sourceWalletId: input.sourceWalletId,
      amount,
      currency,
      transactionId: txId,
      referenceId,
    }, txId);
    return { transactionId: txId, referenceId, accountId, amount, currency };
  }

  async payout(accountId: string, input: OperationalTransferInput, actorId: string, operation = 'OPERATIONAL_ACCOUNT_PAYOUT') {
    if (!input.targetWalletId) throw new Error('TARGET_WALLET_REQUIRED');
    const amount = assertAmount(input.amount);
    const currency = normalizeCurrency(input.currency);
    const source = await this.requireOperationalAccount(accountId);
    const target = await this.resolveInternalEntity(input.targetWalletId);
    if (String(source.id) === String(target.record.id)) throw new Error('SOURCE_TARGET_WALLET_MATCH');
    if (normalizeCurrency(source.currency) !== currency || target.currency !== currency) {
      throw new Error('CURRENCY_MISMATCH: Operational account, target wallet, and payload currency must match.');
    }

    const txId = UUID.generate();
    const referenceId = operation === 'OPERATIONAL_ACCOUNT_REFUND'
      ? `OPA-REFUND-${UUID.generateShortCode(10)}`
      : `OPA-PAYOUT-${UUID.generateShortCode(10)}`;
    await this.ledger.postTransactionWithLedger({
      id: txId,
      walletId: accountId,
      toWalletId: input.targetWalletId,
      amount,
      currency,
      description: input.reason,
      type: operation === 'OPERATIONAL_ACCOUNT_REFUND' ? 'refund' : 'transfer',
      status: 'completed',
      referenceId,
      metadata: {
        ...(input.metadata || {}),
        platform_operation: operation,
        source_operational_account_id: accountId,
        target_wallet_id: input.targetWalletId,
        operational_account_role: source.metadata?.operational_role || source.vault_role,
        original_transaction_id: input.originalTransactionId || null,
        original_reference_id: input.originalReferenceId || null,
        actor_id: actorId,
        closed_loop: true,
        no_direct_balance_mutation: true,
      },
    }, [
      { transactionId: txId, walletId: accountId, type: 'DEBIT', amount, currency, timestamp: new Date().toISOString(), description: input.reason },
      { transactionId: txId, walletId: input.targetWalletId, type: 'CREDIT', amount, currency, timestamp: new Date().toISOString(), description: input.reason },
    ]);

    await Audit.log('FINANCIAL', actorId, operation, {
      accountId,
      targetWalletId: input.targetWalletId,
      amount,
      currency,
      transactionId: txId,
      referenceId,
      originalTransactionId: input.originalTransactionId || null,
    }, txId);
    return { transactionId: txId, referenceId, accountId, amount, currency };
  }

  async refund(accountId: string, input: OperationalTransferInput, actorId: string) {
    if (!input.originalTransactionId && !input.originalReferenceId) {
      throw new Error('ORIGINAL_TRANSACTION_REQUIRED: Refunds must reference the original transaction or reference ID.');
    }
    return this.payout(accountId, input, actorId, 'OPERATIONAL_ACCOUNT_REFUND');
  }
}

export const platformOperationalAccountService = new PlatformOperationalAccountService();
