import { type RequestHandler, type Router } from 'express';
import {
  requireIdempotencyKey,
  resolveIdempotencyHeader,
} from '../../middleware/security/idempotency.js';

type Deps = {
  authenticate: RequestHandler;
  authenticateApiKey: RequestHandler;
  validate: (schema: any) => RequestHandler;
  requireRole: (session: any, roles: string[]) => boolean;
  LogicCore: any;
  getSupabase: () => any;
  PolicyEngine: any;
  FXEngine: any;
  TransactionService: any;
  WalletCreateSchema: any;
  WalletLockSchema: any;
  WalletUnlockSchema: any;
  PaymentIntentSchema: any;
  TransactionIssueSchema: any;
};

const quoteErrorStatus = (message: string) => {
  if (/DB_OFFLINE|UNAVAILABLE/i.test(message)) return 503;
  if (/PLATFORM_FEE_CONFIG_REQUIRED|PROVIDER_ROUTE_NOT_FOUND|NOT_CONFIGURED/i.test(message)) return 409;
  if (/NOT_FOUND|REQUIRED|ACCESS_DENIED|INSUFFICIENT|BLOCK/i.test(message)) return 400;
  return 500;
};

const quoteErrorPayload = (error: any, context: string) => {
  const message = String(error?.message || error || 'TRANSACTION_PREVIEW_FAILED');
  const code = message.split(':')[0] || 'TRANSACTION_PREVIEW_FAILED';
  return {
    success: false,
    error: code,
    message,
    context,
    retryable: quoteErrorStatus(message) >= 500,
  };
};

const firstHeaderValue = (value: unknown): string | undefined => {
  const raw = Array.isArray(value) ? value[0] : value;
  if (typeof raw !== 'string') return undefined;
  const trimmed = raw.trim();
  return trimmed || undefined;
};

const ipGeoFromRequest = (req: any) => {
  const countryCode = firstHeaderValue(req.headers['cf-ipcountry']) ||
    firstHeaderValue(req.headers['x-vercel-ip-country']) ||
    firstHeaderValue(req.headers['x-orbi-ip-country']);
  const region = firstHeaderValue(req.headers['x-vercel-ip-country-region']) ||
    firstHeaderValue(req.headers['x-orbi-ip-region']);
  const city = firstHeaderValue(req.headers['x-vercel-ip-city']) ||
    firstHeaderValue(req.headers['x-orbi-ip-city']);
  const latitude = firstHeaderValue(req.headers['x-vercel-ip-latitude']) ||
    firstHeaderValue(req.headers['x-orbi-ip-latitude']);
  const longitude = firstHeaderValue(req.headers['x-vercel-ip-longitude']) ||
    firstHeaderValue(req.headers['x-orbi-ip-longitude']);

  if (!countryCode && !region && !city && !latitude && !longitude) return null;
  return {
    countryCode: countryCode?.toUpperCase(),
    region,
    city,
    latitude: latitude ? Number(latitude) : undefined,
    longitude: longitude ? Number(longitude) : undefined,
    source: 'ip_geo',
    capturedAt: new Date().toISOString(),
    ipHashAvailable: Boolean(req.ip || req.headers['x-forwarded-for']),
  };
};

const enrichTransactionGeoMetadata = (req: any) => {
  const payload = req.body && typeof req.body === 'object' ? req.body : {};
  const metadata = payload.metadata && typeof payload.metadata === 'object' ? payload.metadata : {};
  const ipGeo = ipGeoFromRequest(req);
  if (!ipGeo || metadata.ipGeo || metadata.ip_geo) return payload;
  req.body = {
    ...payload,
    metadata: {
      ...metadata,
      ipGeo,
    },
  };
  return req.body;
};

type ReportRangeKey = 'week' | 'month' | 'year';

const toMoneyNumber = (value: any): number => {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
};

const resolveReportRange = (raw: unknown): { key: ReportRangeKey; start: Date; end: Date } => {
  const key = String(Array.isArray(raw) ? raw[0] : raw || 'month').toLowerCase() as ReportRangeKey;
  const safeKey: ReportRangeKey = ['week', 'month', 'year'].includes(key) ? key : 'month';
  const end = new Date();
  const start = new Date(end);

  if (safeKey === 'week') {
    const day = start.getDay();
    const mondayOffset = day === 0 ? -6 : 1 - day;
    start.setDate(start.getDate() + mondayOffset);
    start.setHours(0, 0, 0, 0);
  } else if (safeKey === 'year') {
    start.setMonth(0, 1);
    start.setHours(0, 0, 0, 0);
  } else {
    start.setDate(1);
    start.setHours(0, 0, 0, 0);
  }

  return { key: safeKey, start, end };
};

const transactionTimestamp = (transaction: any): Date | null => {
  const raw = transaction?.created_at || transaction?.createdAt || transaction?.date;
  if (!raw) return null;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const isCreditLike = (transaction: any): boolean => {
  const type = String(transaction?.type || transaction?.direction || '').toUpperCase();
  const side = String(transaction?.entry_side || '').toUpperCase();
  return ['CREDIT', 'INCOMING', 'DEPOSIT', 'RECEIVED'].some((marker) => type.includes(marker) || side.includes(marker));
};

const transactionSearchText = (transaction: any): string => {
  const metadata = transaction?.metadata && typeof transaction.metadata === 'object' ? transaction.metadata : {};
  return [
    transaction?.type,
    transaction?.direction,
    transaction?.entry_side,
    transaction?.entry_type,
    transaction?.money_state,
    transaction?.moneyState,
    transaction?.allocation_source,
    transaction?.source_wallet_name,
    transaction?.destination_wallet_name,
    transaction?.activity_label,
    transaction?.description,
    metadata?.settlement_path,
    metadata?.rail,
    metadata?.provider,
    metadata?.provider_name,
    metadata?.wallet_type,
    metadata?.money_state,
  ].map((value) => String(value || '').toLowerCase()).join(' ');
};

const isExternalMoneyMovement = (transaction: any): boolean => {
  const text = transactionSearchText(transaction);
  return [
    'external_routing',
    'external routing',
    'external_destination',
    'external destination',
    'withdraw',
    'cashout',
    'cash out',
    'bank',
    'mobile_money',
    'mobile money',
    'card',
    'merchant_settlement',
  ].some((marker) => text.includes(marker));
};

const isInternalMoneyMovement = (transaction: any): boolean => {
  if (isExternalMoneyMovement(transaction)) return false;
  if (Array.isArray(transaction?.ledger_legs) && transaction.ledger_legs.length >= 2) return true;
  const text = transactionSearchText(transaction);
  return [
    'internal',
    'orbi',
    'wallet',
    'escrow',
    'paysafe',
    'pay safe',
    'shared_pot',
    'shared pot',
    'fungu',
    'pot',
    'shared_budget',
    'shared budget',
    'mezani',
    'budget',
    'goal',
    'saving',
    'allocated',
    'locked',
  ].some((marker) => text.includes(marker));
};

const buildTransactionReport = (transactions: any[], range: ReturnType<typeof resolveReportRange>) => {
  const scoped = (transactions || []).filter((transaction: any) => {
    const timestamp = transactionTimestamp(transaction);
    return timestamp ? timestamp >= range.start && timestamp <= range.end : false;
  });

  const summary = scoped.reduce((acc: any, transaction: any) => {
    const amount = toMoneyNumber(transaction?.amount);
    if (isInternalMoneyMovement(transaction)) {
      acc.internal_movements += amount;
      acc.internal_movement_count += 1;
    } else if (isCreditLike(transaction)) {
      acc.total_in += amount;
      acc.money_in += amount;
      acc.external_in += amount;
    } else {
      acc.total_out += amount;
      acc.money_out += amount;
      acc.external_out += amount;
    }
    acc.net = acc.total_in - acc.total_out;
    acc.gross_movement += amount;
    acc.transaction_count += 1;
    const currency = String(transaction?.currency || 'TZS').toUpperCase();
    acc.currency = acc.currency || currency;
    acc.currencies[currency] = (acc.currencies[currency] || 0) + amount;
    const status = String(transaction?.status || 'UNKNOWN').toUpperCase();
    acc.statuses[status] = (acc.statuses[status] || 0) + 1;
    return acc;
  }, {
    currency: 'TZS',
    total_in: 0,
    total_out: 0,
    money_in: 0,
    money_out: 0,
    external_in: 0,
    external_out: 0,
    internal_movements: 0,
    internal_movement_count: 0,
    gross_movement: 0,
    net: 0,
    transaction_count: 0,
    currencies: {},
    statuses: {},
  });

  return {
    report_type: 'TRANSACTION_HISTORY',
    range: {
      key: range.key,
      start: range.start.toISOString(),
      end: range.end.toISOString(),
    },
    summary,
    transactions: scoped,
    generatedAt: new Date().toISOString(),
    issuer: 'ORBI FINANCIAL TECHNOLOGIES',
  };
};

const sumRows = (rows: any[], fields: string[], currency?: string): number => rows.reduce((total, row) => {
  if (currency && String(row?.currency || currency).toUpperCase() !== currency.toUpperCase()) return total;
  const value = fields.map((field) => row?.[field]).find((item) => item !== undefined && item !== null);
  return total + toMoneyNumber(value);
}, 0);

const safeRows = async (label: string, query: any): Promise<any[]> => {
  try {
    const { data, error } = await query;
    if (error) {
      console.warn(`[Transactions Report] ${label} snapshot skipped:`, error.message);
      return [];
    }
    return Array.isArray(data) ? data : [];
  } catch (error: any) {
    console.warn(`[Transactions Report] ${label} snapshot failed:`, error?.message || error);
    return [];
  }
};

const activeEscrowStatuses = new Set([
  'PENDING',
  'ACCEPTED',
  'HELD',
  'FUNDS_HELD',
  'IN_PROGRESS',
  'DISPUTED',
]);

const buildBalanceSnapshot = async (sb: any, userId: string, currency = 'TZS') => {
  const safeCurrency = String(currency || 'TZS').toUpperCase();
  const wallets = await safeRows(
    'wallets',
    sb.from('wallets')
      .select('id,name,wallet_name,type,wallet_type,bucket_type,balance,available_balance,currency,user_id')
      .eq('user_id', userId),
  );
  const vaults = await safeRows(
    'platform_vaults',
    sb.from('platform_vaults')
      .select('id,name,vault_name,vault_role,balance,available_balance,currency,user_id')
      .eq('user_id', userId),
  );
  const goals = await safeRows(
    'goals',
    sb.from('goals')
      .select('id,name,current,current_amount,balance,currency,status,user_id')
      .eq('user_id', userId),
  );
  const escrows = await safeRows(
    'escrow_agreements',
    sb.from('escrow_agreements')
      .select('id,amount,currency,status,sender_id,receiver_id')
      .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`),
  );
  const potMembers = await safeRows(
    'shared_pot_members',
    sb.from('shared_pot_members').select('pot_id').eq('user_id', userId),
  );
  const potIds = potMembers.map((row) => String(row?.pot_id || '').trim()).filter(Boolean);
  const potsQuery = potIds.length
    ? sb.from('shared_pots')
      .select('id,name,current_amount,balance,currency,status,owner_user_id')
      .or(`owner_user_id.eq.${userId},id.in.(${potIds.join(',')})`)
    : sb.from('shared_pots')
      .select('id,name,current_amount,balance,currency,status,owner_user_id')
      .eq('owner_user_id', userId);
  const pots = await safeRows('shared_pots', potsQuery);
  const budgetMembers = await safeRows(
    'shared_budget_members',
    sb.from('shared_budget_members').select('budget_id').eq('user_id', userId),
  );
  const budgetIds = budgetMembers.map((row) => String(row?.budget_id || '').trim()).filter(Boolean);
  const budgetsQuery = budgetIds.length
    ? sb.from('shared_budgets')
      .select('id,name,budget_limit,spent_amount,current_amount,balance,currency,status,owner_user_id')
      .or(`owner_user_id.eq.${userId},id.in.(${budgetIds.join(',')})`)
    : sb.from('shared_budgets')
      .select('id,name,budget_limit,spent_amount,current_amount,balance,currency,status,owner_user_id')
      .eq('owner_user_id', userId);
  const budgets = await safeRows('shared_budgets', budgetsQuery);

  const allWalletLike = [...wallets, ...vaults];
  const restrictedMarker = /(escrow|paysafe|pay safe|budget|goal|pot|fungu|reserve|bill)/i;
  const availableRows = allWalletLike.filter((row) => !restrictedMarker.test([
    row?.name,
    row?.wallet_name,
    row?.vault_name,
    row?.vault_role,
    row?.type,
    row?.wallet_type,
    row?.bucket_type,
  ].join(' ')));
  const availableBalance = sumRows(availableRows, ['available_balance', 'balance'], safeCurrency);
  const walletRestrictedBalance = sumRows(
    allWalletLike.filter((row) => restrictedMarker.test([
      row?.name,
      row?.wallet_name,
      row?.vault_name,
      row?.vault_role,
      row?.type,
      row?.wallet_type,
      row?.bucket_type,
    ].join(' '))),
    ['available_balance', 'balance'],
    safeCurrency,
  );
  const paysafeBalance = sumRows(
    escrows.filter((row) => activeEscrowStatuses.has(String(row?.status || '').toUpperCase())),
    ['amount'],
    safeCurrency,
  );
  const goalsBalance = sumRows(goals, ['current_amount', 'current', 'balance'], safeCurrency);
  const potsBalance = sumRows(pots, ['current_amount', 'balance'], safeCurrency);
  const budgetsBalance = budgets.reduce((total, row) => {
    if (String(row?.currency || safeCurrency).toUpperCase() !== safeCurrency) return total;
    const current = toMoneyNumber(row?.current_amount ?? row?.balance);
    if (current > 0) return total + current;
    const limit = toMoneyNumber(row?.budget_limit);
    const spent = toMoneyNumber(row?.spent_amount);
    return total + Math.max(limit - spent, 0);
  }, 0);
  const insideOrbiTotal = availableBalance + walletRestrictedBalance + paysafeBalance + goalsBalance + potsBalance + budgetsBalance;

  return {
    captured_at: new Date().toISOString(),
    currency: safeCurrency,
    main_balance: insideOrbiTotal,
    available_balance: availableBalance,
    inside_orbi_total: insideOrbiTotal,
    paysafe_balance: paysafeBalance,
    escrow_balance: paysafeBalance,
    goals_balance: goalsBalance,
    shared_pots_balance: potsBalance,
    shared_budgets_balance: budgetsBalance,
    other_internal_balance: walletRestrictedBalance,
    breakdown: [
      { key: 'available_balance', label_en: 'Available balance', label_sw: 'Salio linalotumika', amount: availableBalance, currency: safeCurrency },
      { key: 'paysafe_balance', label_en: 'PaySafe / escrow', label_sw: 'PaySafe / escrow', amount: paysafeBalance, currency: safeCurrency },
      { key: 'shared_pots_balance', label_en: 'Fungu pots', label_sw: 'Vifungu', amount: potsBalance, currency: safeCurrency },
      { key: 'shared_budgets_balance', label_en: 'Mezani budgets', label_sw: 'Mezani', amount: budgetsBalance, currency: safeCurrency },
      { key: 'goals_balance', label_en: 'Goals', label_sw: 'Malengo', amount: goalsBalance, currency: safeCurrency },
      { key: 'other_internal_balance', label_en: 'Other internal holds', label_sw: 'Mizania mingine ya ndani', amount: walletRestrictedBalance, currency: safeCurrency },
    ],
  };
};

const transactionIdentity = (transaction: any): string | null => {
  const raw = transaction?.internalId ||
    transaction?.internal_id ||
    transaction?.transaction_id ||
    transaction?.transactionId ||
    transaction?.id ||
    transaction?.reference ||
    transaction?.referenceId ||
    transaction?.transaction_reference;
  const id = String(raw || '').trim();
  return id || null;
};

const firstText = (values: any[]): string | undefined => {
  for (const value of values) {
    const text = String(value || '').trim();
    if (text && text.toLowerCase() !== 'null') return text;
  }
  return undefined;
};

const normalizeWalletName = (wallet: any, fallback?: string): string | undefined => firstText([
  wallet?.wallet_name,
  wallet?.name,
  wallet?.display_name,
  fallback,
]);

const enrichTransactionsForReport = async (
  sb: any,
  userId: string,
  transactions: any[],
): Promise<any[]> => {
  const ids = Array.from(new Set(
    transactions
      .map(transactionIdentity)
      .filter((id): id is string => Boolean(id)),
  ));
  if (!ids.length) return transactions;

  try {
    const { data: ledgerRows, error: ledgerError } = await sb
      .from('financial_ledger')
      .select('id,transaction_id,user_id,wallet_id,entry_side,entry_type,amount,balance_after,description,created_at')
      .in('transaction_id', ids);

    if (ledgerError || !Array.isArray(ledgerRows) || ledgerRows.length === 0) {
      if (ledgerError) console.warn('[Transactions Report] ledger enrichment skipped:', ledgerError.message);
      return transactions;
    }

    const walletIds = Array.from(new Set(
      ledgerRows
        .map((row: any) => String(row?.wallet_id || '').trim())
        .filter(Boolean),
    ));

    const walletById = new Map<string, any>();
    if (walletIds.length) {
      const { data: wallets, error: walletError } = await sb
        .from('wallets')
        .select('id,name,wallet_name,type,wallet_type,bucket_type,user_id')
        .in('id', walletIds);
      if (!walletError && Array.isArray(wallets)) {
        wallets.forEach((wallet: any) => walletById.set(String(wallet.id), wallet));
      } else if (walletError) {
        console.warn('[Transactions Report] wallet enrichment skipped:', walletError.message);
      }
    }

    const legsByTransaction = new Map<string, any[]>();
    ledgerRows.forEach((row: any) => {
      const txId = String(row?.transaction_id || '').trim();
      if (!txId) return;
      const existing = legsByTransaction.get(txId) || [];
      existing.push(row);
      legsByTransaction.set(txId, existing);
    });

    const userIds = Array.from(new Set([
      ...ledgerRows.map((row: any) => String(row?.user_id || '').trim()),
      ...Array.from(walletById.values()).map((wallet: any) => String(wallet?.user_id || '').trim()),
    ].filter(Boolean)));
    const userById = new Map<string, any>();
    if (userIds.length) {
      const { data: users, error: userError } = await sb
        .from('users')
        .select('id,full_name,customer_id')
        .in('id', userIds);
      if (!userError && Array.isArray(users)) {
        users.forEach((user: any) => userById.set(String(user.id), user));
      } else if (userError) {
        console.warn('[Transactions Report] user enrichment skipped:', userError.message);
      }
    }

    return transactions.map((transaction: any) => {
      const txId = transactionIdentity(transaction);
      const legs = txId ? (legsByTransaction.get(txId) || []) : [];
      if (!legs.length) return transaction;

      const userLeg = legs.find((leg: any) => String(leg?.user_id || '') === String(userId)) || legs[0];
      const debitLeg = legs.find((leg: any) => String(leg?.entry_side || leg?.entry_type || '').toUpperCase().includes('DEBIT'));
      const creditLeg = legs.find((leg: any) => String(leg?.entry_side || leg?.entry_type || '').toUpperCase().includes('CREDIT'));
      const sourceWallet = walletById.get(String((debitLeg || userLeg)?.wallet_id || ''));
      const destinationWallet = walletById.get(String((creditLeg || userLeg)?.wallet_id || ''));
      const sourceUser = userById.get(String(debitLeg?.user_id || sourceWallet?.user_id || ''));
      const destinationUser = userById.get(String(creditLeg?.user_id || destinationWallet?.user_id || ''));
      const sourceContext = transaction?.source_wallet_context || transaction?.source_wallet_details || transaction?.source_wallet || {};
      const destinationContext = transaction?.destination_wallet_context || transaction?.destination_wallet_details || transaction?.destination_wallet || {};
      const sourceWalletName = normalizeWalletName(
        sourceWallet,
        firstText([
          transaction?.source_wallet_name,
          transaction?.sourceWalletName,
          transaction?.metadata?.source_wallet_name,
          transaction?.metadata?.source_wallet_context?.wallet_name,
          sourceContext?.wallet_name,
          sourceContext?.name,
        ]),
      );
      const destinationWalletName = normalizeWalletName(
        destinationWallet,
        firstText([
          transaction?.destination_wallet_name,
          transaction?.targetWalletName,
          transaction?.metadata?.destination_wallet_name,
          transaction?.metadata?.destination_wallet_context?.wallet_name,
          destinationContext?.wallet_name,
          destinationContext?.name,
        ]),
      );
      const sourceDisplayName = firstText([
        sourceWalletName,
        transaction?.source_display_name,
        transaction?.from_display_name,
        sourceUser?.full_name,
        'Orbi',
      ]);
      const destinationDisplayName = firstText([
        destinationWalletName,
        transaction?.metadata?.recipient_snapshot?.name,
        transaction?.destination_display_name,
        transaction?.to_display_name,
        destinationUser?.full_name,
        'External Destination',
      ]);
      const balanceAfter = firstText([
        userLeg?.balance_after,
        transaction?.balance_after,
        transaction?.balanceAfter,
      ]);

      return {
        ...transaction,
        ledger_entry_id: userLeg?.id || transaction?.ledger_entry_id,
        balance_after: balanceAfter,
        running_balance: balanceAfter,
        from_display_name: sourceDisplayName,
        to_display_name: destinationDisplayName,
        source_display_name: sourceDisplayName,
        destination_display_name: destinationDisplayName,
        source_wallet_id: (debitLeg || userLeg)?.wallet_id || transaction?.source_wallet_id,
        destination_wallet_id: (creditLeg || userLeg)?.wallet_id || transaction?.destination_wallet_id,
        source_wallet_name: sourceWalletName,
        destination_wallet_name: destinationWalletName,
        ledger: {
          ...(transaction?.ledger || {}),
          id: userLeg?.id,
          balance_after: balanceAfter,
          entry_side: userLeg?.entry_side,
          entry_type: userLeg?.entry_type,
          wallet_id: userLeg?.wallet_id,
        },
      };
    });
  } catch (error: any) {
    console.warn('[Transactions Report] enrichment failed:', error?.message || error);
    return transactions;
  }
};

export const registerCoreFinanceRoutes = (v1: Router, deps: Deps) => {
  const {
    authenticate,
    authenticateApiKey,
    validate,
    requireRole,
    LogicCore,
    getSupabase,
    PolicyEngine,
    FXEngine,
    TransactionService,
    WalletCreateSchema,
    WalletLockSchema,
    WalletUnlockSchema,
    PaymentIntentSchema,
    TransactionIssueSchema,
  } = deps;

  v1.post('/core/tenants', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.createTenant(session.sub, req.body);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/my', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getUserTenants(session.sub);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(quoteErrorStatus(e.message)).json({ success: false, error: e.message });
    }
  });

  v1.post('/core/tenants/:id/api-keys', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.generateTenantApiKeys(session.sub, req.params.id, req.body.type);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/:id/api-keys', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getTenantApiKeys(session.sub, req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/core/tenants/:id/api-keys/:keyId', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.revokeTenantApiKey(session.sub, req.params.id, req.params.keyId);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/:id/wallets', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getTenantWallets(session.sub, req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/external/wallets', authenticateApiKey as any, async (req, res) => {
    const tenantId = (req as any).tenantId;
    try {
      const sb = getSupabase();
      if (!sb) throw new Error('Database not connected');

      const { data, error } = await sb.from('wallets').select('*').eq('tenant_id', tenantId);

      if (error) throw new Error(error.message);
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/:id/settlement/config', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getTenantSettlementConfig(session.sub, req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/core/tenants/:id/settlement/config', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.updateTenantSettlementConfig(session.sub, req.params.id, req.body);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/:id/settlement/pending', authenticate as any, async (req, res) => {
    try {
      const result = await LogicCore.getTenantPendingSettlement(req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/core/tenants/:id/settlement/payout', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.triggerTenantPayout(session.sub, req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/core/tenants/:id/settlement/history', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getTenantPayoutHistory(session.sub, req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/wallets/linked', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const allWallets = await LogicCore.getWallets(session.sub);
      const linked = allWallets.filter((w: any) => w.management_tier === 'linked');
      res.json({ success: true, data: linked });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/wallets/sovereign', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const allWallets = await LogicCore.getWallets(session.sub);
      const sovereign = allWallets.filter((w: any) => w.management_tier === 'sovereign');
      res.json({ success: true, data: sovereign });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/user/dashboard', authenticate as any, async (req, res) => {
    const token = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.getBootstrapData(token);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/dashboard', authenticate as any, async (req, res) => {
    const token = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.getBootstrapData(token);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/wallets', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getWallets(session.sub);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/wallets', authenticate as any, validate(WalletCreateSchema), async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.postWallet({ ...req.body, userId: session.sub });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/wallets/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const walletId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      await LogicCore.deleteWallet(session.sub, walletId);
      res.json({ success: true });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wallets/:id/lock', authenticate as any, validate(WalletLockSchema), async (req, res) => {
    const session = (req as any).session;
    const isAdmin = requireRole(session, ['ADMIN', 'SUPER_ADMIN', 'IT', 'STAFF']);
    try {
      const walletId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const result = await LogicCore.lockWallet(session.sub, walletId, {
        reason: req.body.reason,
        pin: req.body.pin,
        force: req.body.force,
        isAdmin,
      });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wallets/:id/unlock', authenticate as any, validate(WalletUnlockSchema), async (req, res) => {
    const session = (req as any).session;
    const isAdmin = requireRole(session, ['ADMIN', 'SUPER_ADMIN', 'IT', 'STAFF']);
    if (!isAdmin && !req.body.pin) {
      return res.status(400).json({ success: false, error: 'PIN_REQUIRED' });
    }
    try {
      const walletId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const result = await LogicCore.unlockWallet(session.sub, walletId, {
        reason: req.body.reason,
        pin: req.body.pin,
        force: req.body.force,
        isAdmin,
      });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/transactions/settle', authenticate as any, validate(PaymentIntentSchema), requireIdempotencyKey, async (req, res) => {
    const session = (req as any).session;
    const idempotencyKey = resolveIdempotencyHeader(req);

    try {
      enrichTransactionGeoMetadata(req);
      const binding = await LogicCore.bindSettlementQuote(
        session.sub,
        req.body,
        String(idempotencyKey).trim(),
      );
      const settlementPayload = {
        ...binding.payload,
        idempotencyKey: String(idempotencyKey).trim(),
      };

      const kycStatus = session.user.user_metadata?.kyc_status || 'unverified';
      const amount = settlementPayload.amount || 0;
      const currency = settlementPayload.currency || 'TZS';

      const policyResult = await PolicyEngine.evaluateTransaction(session.sub, amount, currency, 'settlement');
      if (!policyResult.allowed) {
        return res.status(403).json({
          success: false,
          error: 'POLICY_VIOLATION',
          message: policyResult.reason,
        });
      }

      if (kycStatus !== 'verified' && amount > 1000000) {
        return res.status(403).json({
          success: false,
          error: 'KYC_LIMIT_EXCEEDED',
          message: 'Unverified accounts are limited to 1,000,000 TZS per transaction. Please complete KYC.',
        });
      }

      const result = await LogicCore.processSecurePayment(settlementPayload, session.user);
      await LogicCore.markSettlementQuoteResult(session.sub, binding.quoteId, result);

      if (!result.success) {
        if (result.error === 'SECURITY_CHALLENGE') {
          return res.status(403).json(result);
        }

        const isTransient =
          result.error?.includes('LOCK_TIMEOUT') ||
          result.error?.includes('LEDGER_COMMIT_FAILED') ||
          result.error?.includes('LEDGER_FAULT') ||
          result.error?.includes('INFRASTRUCTURE_ERROR');

        const statusCode = isTransient ? 500 : 400;
        return res.status(statusCode).json(result);
      }

      await PolicyEngine.commitMetrics(session.sub, amount, currency);
      res.json({ success: true, data: result });
    } catch (e: any) {
      console.error(`[Transaction] Settle Error: ${e.message}`);
      const statusCode = quoteErrorStatus(String(e.message || ''));
      res.status(statusCode).json(quoteErrorPayload(e, 'transaction_confirmation'));
    }
  });

  v1.post('/transactions/preview', authenticate as any, validate(PaymentIntentSchema), async (req, res) => {
    const session = (req as any).session;
    try {
      enrichTransactionGeoMetadata(req);
      const result = await LogicCore.getTransactionPreview(session.sub, req.body);
      if (!result.success) {
        return res.status(400).json(result);
      }
      res.json({ success: true, data: result });
    } catch (e: any) {
      const statusCode = quoteErrorStatus(String(e.message || ''));
      res.status(statusCode).json(quoteErrorPayload(e, 'transaction_preview'));
    }
  });

  v1.get('/fx/quote', authenticate as any, async (req, res) => {
    const { from, to, amount } = req.query;
    if (!from || !to || !amount) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: from, to, amount' });
    }

    try {
      const result = await FXEngine.processConversion(Number(amount), String(from), String(to));
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/transactions', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const limit = Number(req.query.limit || 50);
    const offset = Number(req.query.offset || 0);
    try {
      const result = await LogicCore.getTransactionsPaginated(session.sub, limit, offset);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/transactions/report', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const range = resolveReportRange(req.query.range);
    const limit = Math.min(Math.max(Number(req.query.limit || 500), 1), 1000);
    try {
      const result = await LogicCore.getTransactionsPaginated(session.sub, limit, 0);
      const transactions = Array.isArray(result) ? result : (result?.items || result?.transactions || result?.data || []);
      const enrichedTransactions = await enrichTransactionsForReport(
        getSupabase(),
        session.sub,
        transactions,
      );
      const report = buildTransactionReport(enrichedTransactions, range);
      const balances = await buildBalanceSnapshot(
        getSupabase(),
        session.sub,
        report.summary?.currency || 'TZS',
      );
      res.json({
        success: true,
        data: {
          ...report,
          balances,
          balance_snapshot: balances,
        },
      });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/transactions/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const transactionId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const transaction = await LogicCore.getTransactionForUser(session.sub, transactionId);
      if (!transaction) {
        return res.status(404).json({ success: false, error: 'TRANSACTION_NOT_FOUND' });
      }
      res.json({ success: true, data: transaction });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/transactions/:id/lock', authenticate as any, validate(TransactionIssueSchema), async (req, res) => {
    const session = (req as any).session;
    try {
      const transactionId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const result = await LogicCore.requestTransactionRecall(session.sub, transactionId, req.body.reason);
      res.json({
        success: true,
        data: {
          ...result,
          advisory: 'Transaction recall requested. Funds remain under review and may take up to 24 hours to reflect back to your operating wallet.',
        },
      });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.get('/transactions/:id/receipt', authenticate as any, async (req, res) => {
    const { id } = req.params;
    const session = (req as any).session;

    try {
      const service = new TransactionService();
      const transactions = await service.getLatestTransactions(session.sub, 100, 0);
      const tx = transactions.find((t: any) => t.internalId === id || t.referenceId === id || t.id === id);

      if (!tx) {
        return res.status(404).json({ success: false, error: 'TRANSACTION_NOT_FOUND' });
      }

      res.json({
        success: true,
        data: {
          ...tx,
          generatedAt: new Date().toISOString(),
          issuer: 'ORBI FINANCIAL TECHNOLOGIES',
        },
      });
    } catch (e: any) {
      console.error(`[Receipt Data] Fetch failed for ${id}:`, e);
      res.status(500).json({ success: false, error: 'RECEIPT_DATA_FAULT', message: e.message });
    }
  });
};
