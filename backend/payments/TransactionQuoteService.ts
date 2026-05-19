import { User, MoneyOperation, RailType } from '../../types.js';
import { UUID } from '../../services/utils.js';
import { getAdminSupabase, getSupabase } from '../supabaseClient.js';
import { SecurityRules } from '../../ledger/rulesEngine.js';
import { TransactionService } from '../../ledger/transactionService.js';
import { platformFeeService } from './PlatformFeeService.js';
import { providerRoutingService } from './ProviderRoutingService.js';
import { FXEngine } from '../ledger/FXEngine.js';
import { transactionFeeClassifier } from './TransactionFeeClassifier.js';

type QuoteInput = {
  userId: string;
  payload: any;
};

type WalletSnapshot = {
  id: string;
  table: 'wallets' | 'platform_vaults';
  currency: string;
  balance: number;
  name?: string | null;
  userId?: string | null;
  role?: string | null;
  status?: string | null;
  isPrimary?: boolean;
};

const DEBIT_TYPES = new Set([
  'INTERNAL_TRANSFER',
  'PEER_TRANSFER',
  'EXTERNAL_PAYMENT',
  'BILL_PAYMENT',
  'WITHDRAWAL',
  'MERCHANT_PAYMENT',
]);

const EXTERNAL_TYPES = new Set([
  'EXTERNAL_PAYMENT',
  'BILL_PAYMENT',
  'WITHDRAWAL',
  'DEPOSIT',
  'MERCHANT_PAYMENT',
]);

export class TransactionQuoteService {
  private rules = SecurityRules;

  async quote({ userId, payload }: QuoteInput) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const amount = this.parseAmount(payload.amount);
    const currency = this.normalizeCurrency(payload.currency);
    const type = this.normalizeType(payload.type || 'INTERNAL_TRANSFER');
    const metadata = payload.metadata && typeof payload.metadata === 'object' ? payload.metadata : {};
    const sourceWalletId = this.extractWalletId(payload, metadata, [
      'sourceWalletId',
      'source_wallet_id',
      'walletId',
      'wallet_id',
      'fromWalletId',
      'from_wallet_id',
    ]);
    const targetWalletId = this.extractWalletId(payload, metadata, [
      'targetWalletId',
      'target_wallet_id',
      'toWalletId',
      'to_wallet_id',
      'recipientWalletId',
      'recipient_wallet_id',
    ]);

    if (amount <= 0) throw new Error('QUOTE_AMOUNT_REQUIRED');
    if (!currency) throw new Error('QUOTE_CURRENCY_REQUIRED');

    const classification = transactionFeeClassifier.classify({
      type,
      category: payload.category,
      categoryId: payload.categoryId,
      metadata,
      channel: payload.channel,
    });
    const user = await this.resolveUser(sb, userId);
    const { sourceWallet, targetWallet } = await this.resolveTransactionWallets({
      sb,
      userId,
      type,
      currency,
      payload,
      metadata,
      sourceWalletId,
      targetWalletId,
    });

    const sourceCurrency = sourceWallet?.currency || currency;
    const targetCurrency = targetWallet?.currency || currency;
    const provider = await this.resolveProviderIfRequired(type, currency, metadata, classification);
    const fee = await platformFeeService.resolveFee({
      flowCode: classification.flowCode,
      amount,
      currency,
      providerId: provider?.providerId,
      countryCode: metadata.countryCode || metadata.country_code,
      rail: provider?.rail || classification.rail,
      channel: classification.channel,
      direction: classification.direction,
      transactionModel: classification.transactionModel,
      categoryCode: classification.categoryCode,
      categoryId: classification.categoryId,
      operationType: classification.operationType,
      transactionType: classification.transactionType,
      metadata,
    });

    const fx = sourceCurrency !== targetCurrency
      ? await FXEngine.processConversion(amount, sourceCurrency, targetCurrency)
      : null;

    const totalDebit = this.round(amount + fee.totalFee);
    const balance = await this.resolveBalance(userId, sourceWallet, type);
    const risk = await this.rules.evaluate(user as any, {
      ...payload,
      type,
      classification,
      amount,
      currency,
      metadata: {
        ...metadata,
        quote_only: true,
      },
    }, []);

    const quoteId = `qt_${UUID.generate()}`;
    const expiresAt = new Date(Date.now() + this.resolveQuoteTtlMs()).toISOString();

    return {
      success: true,
      quoteId,
      expiresAt,
      status: risk.decision === 'BLOCK' ? 'blocked' : 'ready',
      amount,
      currency,
      type,
      sourceWallet: sourceWallet ? this.formatWallet(sourceWallet) : null,
      targetWallet: targetWallet ? this.formatWallet(targetWallet) : null,
      provider: provider ? {
        providerId: provider.providerId,
        providerCode: provider.providerCode,
        providerName: provider.providerName,
        rail: provider.rail,
        operation: provider.operation,
        routingDecision: provider.routingDecision || null,
      } : null,
      fees: {
        flowCode: fee.flowCode,
        configId: fee.configId,
        serviceFee: fee.serviceFee,
        taxAmount: fee.taxAmount,
        govFeeAmount: fee.govFeeAmount,
        stampDutyFixed: fee.stampDutyFixed,
        totalFee: fee.totalFee,
      },
      fx,
      debit: {
        amount,
        fee: fee.totalFee,
        total: totalDebit,
        currency,
      },
      balance: {
        available: balance,
        required: this.requiresDebit(type) ? totalDebit : 0,
        sufficient: !this.requiresDebit(type) || balance >= totalDebit,
        sourceOfTruth: 'ledger',
      },
      risk: {
        decision: risk.decision,
        score: risk.score,
        passed: risk.passed,
        challengeRequired: risk.decision === 'CHALLENGE',
        blocked: risk.decision === 'BLOCK',
      },
      warnings: this.buildWarnings(type, balance, totalDebit, risk.decision),
    };
  }

  private async resolveUser(sb: any, userId: string): Promise<User> {
    const { data: authUser, error } = await sb.auth.admin.getUserById(userId);
    if (error || !authUser?.user) throw new Error('IDENTITY_NOT_FOUND');

    const { data: profile } = await sb
      .from('users')
      .select('account_status, kyc_status, currency, language, full_name')
      .eq('id', userId)
      .maybeSingle();

    const user = authUser.user;
    user.user_metadata = {
      ...(user.user_metadata || {}),
      ...(profile || {}),
    };
    return user as any;
  }

  private async resolveWallet(sb: any, walletId: string): Promise<WalletSnapshot> {
    const { data: wallet } = await sb
      .from('wallets')
      .select('id, name, currency, balance, user_id, type, status, is_primary, management_tier')
      .eq('id', walletId)
      .maybeSingle();

    if (wallet) {
      return {
        id: wallet.id,
        table: 'wallets',
        name: wallet.name,
        userId: wallet.user_id,
        currency: this.normalizeCurrency(wallet.currency) || 'USD',
        balance: Number(wallet.balance || 0),
        role: wallet.type || wallet.management_tier || null,
        status: wallet.status || null,
        isPrimary: wallet.is_primary === true,
      };
    }

    const { data: vault } = await sb
      .from('platform_vaults')
      .select('id, name, currency, balance, user_id, vault_role, status')
      .eq('id', walletId)
      .maybeSingle();

    if (vault) {
      return {
        id: vault.id,
        table: 'platform_vaults',
        name: vault.name,
        userId: vault.user_id,
        currency: this.normalizeCurrency(vault.currency) || 'USD',
        balance: Number(vault.balance || 0),
        role: vault.vault_role || null,
        status: vault.status || null,
      };
    }

    throw new Error(`WALLET_NOT_FOUND:${walletId}`);
  }

  private async resolveTransactionWallets(args: {
    sb: any;
    userId: string;
    type: string;
    currency: string;
    payload: any;
    metadata: Record<string, any>;
    sourceWalletId: string | null;
    targetWalletId: string | null;
  }): Promise<{ sourceWallet: WalletSnapshot | null; targetWallet: WalletSnapshot | null }> {
    const {
      sb,
      userId,
      type,
      currency,
      payload,
      metadata,
      sourceWalletId,
      targetWalletId,
    } = args;

    const [explicitSource, explicitTarget] = await Promise.all([
      sourceWalletId ? this.resolveWallet(sb, sourceWalletId) : Promise.resolve(null),
      targetWalletId ? this.resolveWallet(sb, targetWalletId) : Promise.resolve(null),
    ]);

    if (explicitSource?.userId && String(explicitSource.userId) !== String(userId)) {
      throw new Error('SOURCE_WALLET_ACCESS_DENIED');
    }

    let sourceWallet = explicitSource;
    let targetWallet = explicitTarget;

    if (!sourceWallet && this.requiresDebit(type)) {
      sourceWallet = await this.resolveUserOperatingWallet(sb, userId, currency, 'SOURCE');
    }

    if (!targetWallet && (type === 'INTERNAL_TRANSFER' || type === 'PEER_TRANSFER')) {
      const recipientUserId = await this.resolveRecipientUserId(sb, payload, metadata);
      if (!recipientUserId) {
        throw new Error('RECIPIENT_REQUIRED_FOR_QUOTE');
      }
      targetWallet = await this.resolveUserOperatingWallet(sb, recipientUserId, currency, 'TARGET');
    }

    if (!targetWallet && type === 'DEPOSIT') {
      targetWallet = await this.resolveUserOperatingWallet(sb, userId, currency, 'TARGET');
    }

    return { sourceWallet, targetWallet };
  }

  private async resolveUserOperatingWallet(
    sb: any,
    userId: string,
    currency: string,
    purpose: 'SOURCE' | 'TARGET',
  ): Promise<WalletSnapshot> {
    const normalizedCurrency = this.normalizeCurrency(currency);
    const { data: vaults, error: vaultError } = await sb
      .from('platform_vaults')
      .select('id, name, currency, balance, user_id, vault_role, status')
      .eq('user_id', userId);

    if (vaultError) throw new Error(vaultError.message);

    const vaultCandidates = (vaults || []).map((vault: any) => ({
      id: vault.id,
      table: 'platform_vaults' as const,
      name: vault.name,
      userId: vault.user_id,
      currency: this.normalizeCurrency(vault.currency) || normalizedCurrency || 'USD',
      balance: Number(vault.balance || 0),
      role: vault.vault_role || null,
      status: vault.status || null,
      isPrimary: false,
    }));

    const preferredVault = this.pickBestWallet(vaultCandidates, normalizedCurrency, [
      'OPERATING',
      'PRIMARY',
      'MAIN',
    ]);
    if (preferredVault) return preferredVault;

    const { data: wallets, error: walletError } = await sb
      .from('wallets')
      .select('id, name, currency, balance, user_id, type, status, is_primary, management_tier')
      .eq('user_id', userId);

    if (walletError) throw new Error(walletError.message);

    const walletCandidates = (wallets || []).map((wallet: any) => ({
      id: wallet.id,
      table: 'wallets' as const,
      name: wallet.name,
      userId: wallet.user_id,
      currency: this.normalizeCurrency(wallet.currency) || normalizedCurrency || 'USD',
      balance: Number(wallet.balance || 0),
      role: wallet.type || wallet.management_tier || null,
      status: wallet.status || null,
      isPrimary: wallet.is_primary === true,
    }));

    const preferredWallet = this.pickBestWallet(walletCandidates, normalizedCurrency, [
      'OPERATING',
      'PRIMARY',
      'MAIN',
      'LINKED',
    ]);
    if (preferredWallet) return preferredWallet;

    throw new Error(`${purpose}_WALLET_REQUIRED_FOR_QUOTE:${normalizedCurrency || 'ANY'}`);
  }

  private pickBestWallet(
    wallets: WalletSnapshot[],
    currency: string,
    preferredRoles: string[],
  ): WalletSnapshot | null {
    const active = wallets.filter((wallet) => !this.isInactiveWallet(wallet));
    const candidates = active.length > 0 ? active : wallets;
    const sameCurrency = candidates.filter((wallet) => !currency || wallet.currency === currency);
    const pool = sameCurrency.length > 0 ? sameCurrency : candidates;
    if (pool.length === 0) return null;

    const roleRank = (wallet: WalletSnapshot) => {
      const role = String(wallet.role || wallet.name || '').trim().toUpperCase();
      const direct = preferredRoles.findIndex((preferred) => role === preferred);
      if (direct >= 0) return direct;
      const contains = preferredRoles.findIndex((preferred) => role.includes(preferred));
      if (contains >= 0) return contains + 10;
      if (wallet.isPrimary) return 20;
      return 100;
    };

    return [...pool].sort((a, b) => {
      const rankDelta = roleRank(a) - roleRank(b);
      if (rankDelta !== 0) return rankDelta;
      return Number(b.balance || 0) - Number(a.balance || 0);
    })[0] || null;
  }

  private async resolveRecipientUserId(sb: any, payload: any, metadata: Record<string, any>) {
    const explicit = this.normalizeNullable(
      payload.recipientId ||
      payload.recipient_id ||
      metadata.recipientId ||
      metadata.recipient_id,
    );
    if (explicit && this.looksLikeUuid(explicit)) return explicit;

    const lookup = this.normalizeNullable(
      payload.recipient_customer_id ||
      payload.recipientCustomerId ||
      payload.recipient ||
      metadata.recipient_customer_id ||
      metadata.recipientCustomerId ||
      explicit,
    );
    if (!lookup) return null;

    const lookups = [
      { column: 'customer_id', operator: 'ilike' },
      { column: 'phone', operator: 'eq' },
      { column: 'email', operator: 'ilike' },
    ];
    for (const item of lookups) {
      const query = sb.from('users').select('id');
      const { data: user, error } = item.operator === 'ilike'
        ? await query.ilike(item.column, lookup).maybeSingle()
        : await query.eq(item.column, lookup).maybeSingle();

      if (error) throw new Error(error.message);
      if (user?.id) return user.id;
    }

    return null;
  }

  private async resolveBalance(userId: string, wallet: WalletSnapshot | null, type: string) {
    if (!this.requiresDebit(type)) return Number.MAX_SAFE_INTEGER;
    if (!wallet?.id) throw new Error(`SOURCE_WALLET_REQUIRED_FOR_QUOTE:${type}`);

    const txService = new TransactionService();
    return txService.getLatestBalance(userId, wallet.id);
  }

  private async resolveProviderIfRequired(type: string, currency: string, metadata: Record<string, any>, classification: ReturnType<typeof transactionFeeClassifier.classify>) {
    if (!EXTERNAL_TYPES.has(type)) return null;

    return providerRoutingService.resolveProvider({
      rail: classification.rail as any,
      operation: transactionFeeClassifier.resolveProviderOperation(classification),
      currency,
      countryCode: metadata.countryCode || metadata.country_code,
      preferredProviderCode:
        metadata.providerCode ||
        metadata.provider_code ||
        metadata.provider ||
        metadata.bill_provider ||
        metadata.payment_provider,
      preferredProviderId: metadata.providerId || metadata.provider_id,
    });
  }

  private buildWarnings(type: string, balance: number, totalDebit: number, decision: string) {
    return [
      this.requiresDebit(type) && balance < totalDebit ? 'INSUFFICIENT_FUNDS_IF_SUBMITTED' : '',
      decision === 'CHALLENGE' ? 'SECURITY_CHALLENGE_REQUIRED_IF_SUBMITTED' : '',
      decision === 'BLOCK' ? 'SECURITY_BLOCK_IF_SUBMITTED' : '',
    ].filter(Boolean);
  }

  private formatWallet(wallet: WalletSnapshot) {
    return {
      id: wallet.id,
      type: wallet.table,
      name: wallet.name || null,
      currency: wallet.currency,
    };
  }

  private requiresDebit(type: string) {
    return DEBIT_TYPES.has(type);
  }

  private normalizeType(value: string) {
    const normalized = String(value || '').trim().toUpperCase();
    if (normalized === 'INTERNAL') return 'INTERNAL_TRANSFER';
    if (normalized === 'EXTERNAL') return 'EXTERNAL_PAYMENT';
    return normalized;
  }

  private normalizeCurrency(value: any) {
    return String(value || '').trim().toUpperCase();
  }

  private normalizeNullable(value: any) {
    const text = String(value || '').trim();
    return text || null;
  }

  private extractWalletId(payload: any, metadata: Record<string, any>, keys: string[]) {
    for (const key of keys) {
      const direct = this.normalizeNullable(payload?.[key]);
      if (direct) return direct;
      const nested = this.normalizeNullable(metadata?.[key]);
      if (nested) return nested;
    }
    return null;
  }

  private isInactiveWallet(wallet: WalletSnapshot) {
    const status = String(wallet.status || '').trim().toLowerCase();
    return ['blocked', 'disabled', 'inactive', 'suspended', 'closed'].includes(status);
  }

  private looksLikeUuid(value: string) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }

  private parseAmount(value: any) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return 0;
    return this.round(parsed);
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }

  private resolveQuoteTtlMs() {
    const configured = Number(process.env.ORBI_TRANSACTION_QUOTE_TTL_SECONDS || 120);
    return Math.max(30, configured) * 1000;
  }
}

export const transactionQuoteService = new TransactionQuoteService();
