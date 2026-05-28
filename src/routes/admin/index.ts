import type { Express, RequestHandler, Router } from 'express';
import { z } from 'zod';
import { getAdminSupabase, getSupabase } from '../../../backend/supabaseClient.js';
import { PartnerRegistry } from '../../../backend/admin/partnerRegistry.js';
import { AdminConfigBootstrapService } from '../../../backend/admin/AdminConfigBootstrapService.js';
import { TransactionService } from '../../../ledger/transactionService.js';
import { Server as LogicCore } from '../../../backend/server.js';
import {
  PLATFORM_OPERATIONAL_ACCOUNT_ROLES,
  platformOperationalAccountService,
} from '../../../backend/payments/PlatformOperationalAccountService.js';
import { createAdminActivityAudit } from '../../middleware/audit/adminActivityAudit.js';
import { createCriticalActionLimiter } from '../../middleware/security/criticalActionLimiter.js';
import { requireSessionPermission } from '../../middleware/auth/sessionAuth.js';

const InstitutionalAccountSchema = z.object({
  role: z.enum(['MAIN_COLLECTION', 'FEE_COLLECTION', 'TAX_COLLECTION', 'TRANSFER_SAVINGS']),
  providerId: z.string().uuid().optional(),
  bankName: z.string().min(1),
  accountName: z.string().min(1),
  accountNumber: z.string().min(1),
  currency: z.string().length(3).optional(),
  countryCode: z.string().min(2).max(3).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
  isPrimary: z.boolean().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const PlatformOperationalAccountSchema = z.object({
  role: z.enum(PLATFORM_OPERATIONAL_ACCOUNT_ROLES),
  name: z.string().trim().min(2).max(120),
  currency: z.string().trim().length(3).optional(),
  status: z.enum(['active', 'inactive', 'locked']).optional(),
  color: z.string().trim().max(32).optional(),
  icon: z.string().trim().max(64).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const PlatformOperationalTransferSchema = z.object({
  sourceWalletId: z.string().uuid().optional(),
  targetWalletId: z.string().uuid().optional(),
  amount: z.coerce.number().positive(),
  currency: z.string().trim().length(3),
  reason: z.string().trim().min(5).max(500),
  originalTransactionId: z.string().uuid().optional(),
  originalReferenceId: z.string().trim().min(3).max(120).optional(),
  idempotencyKey: z.string().trim().min(8).max(160).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const ProviderRoutingRuleSchema = z.object({
  rail: z.enum(['MOBILE_MONEY', 'BANK', 'CARD_GATEWAY', 'CRYPTO', 'WALLET']),
  countryCode: z.string().min(2).max(3).optional(),
  currency: z.string().length(3).optional(),
  operationCode: z.enum([
    'AUTH',
    'ACCOUNT_LOOKUP',
    'COLLECTION_REQUEST',
    'COLLECTION_STATUS',
    'DISBURSEMENT_REQUEST',
    'DISBURSEMENT_STATUS',
    'PAYOUT_REQUEST',
    'PAYOUT_STATUS',
    'REVERSAL_REQUEST',
    'REVERSAL_STATUS',
    'BALANCE_INQUIRY',
    'TRANSACTION_LOOKUP',
    'WEBHOOK_VERIFY',
    'BENEFICIARY_VALIDATE',
  ]),
  providerId: z.string().uuid(),
  priority: z.coerce.number().int().min(1).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
  conditions: z.record(z.string(), z.unknown()).optional(),
});

const PlatformFeeConfigSchema = z.object({
  name: z.string().min(1),
  flowCode: z.enum([
    'CORE_TRANSACTION',
    'INTERNAL_TRANSFER',
    'EXTERNAL_PAYMENT',
    'WITHDRAWAL',
    'DEPOSIT',
    'EXTERNAL_TO_INTERNAL',
    'INTERNAL_TO_EXTERNAL',
    'EXTERNAL_TO_EXTERNAL',
    'CARD_SETTLEMENT',
    'GATEWAY_SETTLEMENT',
    'FX_CONVERSION',
    'TENANT_SETTLEMENT_PAYOUT',
    'MERCHANT_PAYMENT',
    'AGENT_CASH_DEPOSIT',
    'AGENT_CASH_WITHDRAWAL',
    'AGENT_REFERRAL_COMMISSION',
    'AGENT_CASH_COMMISSION',
    'SYSTEM_OPERATION',
  ]),
  transactionModel: z.string().optional(),
  categoryCode: z.string().optional(),
  categoryId: z.string().optional(),
  transactionType: z.string().optional(),
  operationType: z.string().optional(),
  direction: z.string().optional(),
  rail: z.enum(['MOBILE_MONEY', 'BANK', 'CARD_GATEWAY', 'CRYPTO', 'WALLET']).optional(),
  channel: z.string().optional(),
  providerId: z.string().uuid().optional(),
  currency: z.string().length(3).optional(),
  countryCode: z.string().min(2).max(3).optional(),
  percentageRate: z.coerce.number().min(0).optional(),
  fixedAmount: z.coerce.number().min(0).optional(),
  minimumFee: z.coerce.number().min(0).optional(),
  maximumFee: z.coerce.number().min(0).optional(),
  taxRate: z.coerce.number().min(0).optional(),
  govFeeRate: z.coerce.number().min(0).optional(),
  stampDutyFixed: z.coerce.number().min(0).optional(),
  priority: z.coerce.number().int().min(0).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const queryStringValue = (value: unknown) => {
  if (Array.isArray(value)) {
    return value.length ? String(value[0]) : undefined;
  }
  if (typeof value === 'string') {
    return value;
  }
  return undefined;
};

export const registerAdminRoutes = (admin: Router, authenticate: RequestHandler) => {
  admin.use(createCriticalActionLimiter());
  admin.use(createAdminActivityAudit());
  admin.use(authenticate);

  admin.get('/partners', requireSessionPermission(['provider.read', 'provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (_req, res) => {
    try {
      const { data, error } = await PartnerRegistry.listPartners();
      if (error) return res.status(500).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] List Partners Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.post('/partners', requireSessionPermission(['provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const session = (req as any).session;
      const auditMetadata = { updated_by: session.sub, updated_at: new Date().toISOString() };
      const payload = {
        ...req.body,
        provider_metadata: {
          ...(req.body?.provider_metadata || {}),
          admin_audit: {
            ...((req.body?.provider_metadata || {}).admin_audit || {}),
            ...auditMetadata,
          },
        },
      };
      const { data, error } = await PartnerRegistry.addPartner(payload);
      if (error) return res.status(500).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] Add Partner Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.put('/partners/:id', requireSessionPermission(['provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const partnerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const session = (req as any).session;
      const auditMetadata = { updated_by: session.sub, updated_at: new Date().toISOString() };
      const payload = {
        ...req.body,
        provider_metadata: {
          ...(req.body?.provider_metadata || {}),
          admin_audit: {
            ...((req.body?.provider_metadata || {}).admin_audit || {}),
            ...auditMetadata,
          },
        },
      };
      const { data, error } = await PartnerRegistry.updatePartner(partnerId, payload);
      if (error) return res.status(500).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] Update Partner Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.delete('/partners/:id', requireSessionPermission(['provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const partnerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const { error } = await PartnerRegistry.deletePartner(partnerId);
      if (error) return res.status(500).json({ success: false, error: error.message });
      res.json({ success: true });
    } catch (e: any) {
      console.error(`[Admin] Delete Partner Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.post('/config/bootstrap', requireSessionPermission(
    ['provider.write', 'provider_routing.write', 'platform_fee.write', 'infra_config.write'],
    ['ADMIN', 'SUPER_ADMIN', 'IT'],
  ), async (req, res) => {
    try {
      const session = (req as any).session;
      const data = await AdminConfigBootstrapService.apply(req.body, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Config Bootstrap Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/fees', async (req, res) => {
    try {
      const feeType = req.query.feeType as string;
      const service = new TransactionService();
      const data = await service.getFeeTransactions(feeType);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] Get Fees Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.get('/balances', async (_req, res) => {
    try {
      const service = new TransactionService();
      const data = await service.getAggregatedWalletBalances(['Orbi', 'PaySafe']);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] Get Balances Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });

  admin.get('/institutional-payment-accounts', requireSessionPermission(['institutional_account.read', 'institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const data = await LogicCore.getInstitutionalPaymentAccounts({
        role: queryStringValue(req.query.role),
        status: queryStringValue(req.query.status),
        providerId: queryStringValue(req.query.providerId || req.query.provider_id),
        currency: queryStringValue(req.query.currency),
      });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] List Institutional Accounts Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  admin.post('/institutional-payment-accounts', requireSessionPermission(['institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = InstitutionalAccountSchema.parse(req.body);
      const session = (req as any).session;
      const data = await LogicCore.upsertInstitutionalPaymentAccount(payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Create Institutional Account Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.patch('/institutional-payment-accounts/:id', requireSessionPermission(['institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = InstitutionalAccountSchema.partial().parse(req.body);
      const session = (req as any).session;
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await LogicCore.upsertInstitutionalPaymentAccount(payload, session.sub, accountId);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Update Institutional Account Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/platform-operational-accounts', requireSessionPermission(['institutional_account.read', 'institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT', 'ACCOUNTANT', 'AUDIT']), async (req, res) => {
    try {
      const data = await platformOperationalAccountService.list({
        role: queryStringValue(req.query.role),
        status: queryStringValue(req.query.status),
        currency: queryStringValue(req.query.currency),
      });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] List Platform Operational Accounts Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  admin.post('/platform-operational-accounts', requireSessionPermission(['institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = PlatformOperationalAccountSchema.parse(req.body);
      const session = (req as any).session;
      const data = await platformOperationalAccountService.upsert(payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Create Platform Operational Account Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.patch('/platform-operational-accounts/:id', requireSessionPermission(['institutional_account.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = PlatformOperationalAccountSchema.partial().parse(req.body);
      const session = (req as any).session;
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await platformOperationalAccountService.upsert(payload as any, session.sub, accountId);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Update Platform Operational Account Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/platform-operational-accounts/:id/ledger', requireSessionPermission(['institutional_account.read', 'ledger.read'], ['ADMIN', 'SUPER_ADMIN', 'IT', 'ACCOUNTANT', 'AUDIT']), async (req, res) => {
    try {
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await platformOperationalAccountService.history(
        accountId,
        Number(req.query.limit || 100),
        Number(req.query.offset || 0),
      );
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Platform Operational Account Ledger Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.post('/platform-operational-accounts/:id/fund', requireSessionPermission(['ledger.write', 'institutional_account.write'], ['ADMIN', 'SUPER_ADMIN']), async (req, res) => {
    try {
      const payload = PlatformOperationalTransferSchema.required({ sourceWalletId: true }).parse(req.body);
      const session = (req as any).session;
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await platformOperationalAccountService.fund(accountId, payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Platform Operational Account Fund Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.post('/platform-operational-accounts/:id/payout', requireSessionPermission(['ledger.write', 'institutional_account.write'], ['ADMIN', 'SUPER_ADMIN']), async (req, res) => {
    try {
      const payload = PlatformOperationalTransferSchema.required({ targetWalletId: true }).parse(req.body);
      const session = (req as any).session;
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await platformOperationalAccountService.payout(accountId, payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Platform Operational Account Payout Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.post('/platform-operational-accounts/:id/refund', requireSessionPermission(['ledger.write', 'transaction.reverse', 'institutional_account.write'], ['ADMIN', 'SUPER_ADMIN']), async (req, res) => {
    try {
      const payload = PlatformOperationalTransferSchema.required({ targetWalletId: true }).parse(req.body);
      const session = (req as any).session;
      const accountId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await platformOperationalAccountService.refund(accountId, payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Platform Operational Account Refund Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/platform-fees', requireSessionPermission(['config.commissions.read', 'config.commissions.write', 'provider.read'], ['ADMIN', 'SUPER_ADMIN', 'IT', 'ACCOUNTANT', 'AUDIT']), async (req, res) => {
    try {
      const data = await LogicCore.getPlatformFeeConfigs({
        flowCode: req.query.flowCode || req.query.flow_code,
        status: req.query.status,
        providerId: req.query.providerId || req.query.provider_id,
        currency: req.query.currency,
        countryCode: req.query.countryCode || req.query.country_code,
        rail: req.query.rail,
        transactionModel: req.query.transactionModel || req.query.transaction_model,
        categoryCode: req.query.categoryCode || req.query.category_code,
        categoryId: req.query.categoryId || req.query.category_id,
      });
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] List Platform Fees Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  admin.post('/platform-fees', requireSessionPermission(['config.commissions.write', 'provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = PlatformFeeConfigSchema.parse(req.body);
      const session = (req as any).session;
      const data = await LogicCore.upsertPlatformFeeConfig(payload, session.sub);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Create Platform Fee Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.patch('/platform-fees/:id', requireSessionPermission(['config.commissions.write', 'provider.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = PlatformFeeConfigSchema.partial().parse(req.body);
      const session = (req as any).session;
      const configId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await LogicCore.upsertPlatformFeeConfig(payload, session.sub, configId);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error('[Admin] Update Platform Fee Error:', e);
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/provider-routing-rules', requireSessionPermission(['provider_routing.read', 'provider_routing.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (_req, res) => {
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('provider_routing_rules')
        .select('*, financial_partners(id, name, type, provider_metadata)')
        .order('priority', { ascending: true })
        .order('created_at', { ascending: false });
      if (error) return res.status(500).json({ success: false, error: error.message });
      res.json({ success: true, data: data || [] });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  admin.post('/provider-routing-rules', requireSessionPermission(['provider_routing.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = ProviderRoutingRuleSchema.parse(req.body);
      const session = (req as any).session;
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('provider_routing_rules')
        .insert({
          rail: payload.rail,
          country_code: payload.countryCode || null,
          currency: payload.currency?.toUpperCase() || null,
          operation_code: payload.operationCode,
          provider_id: payload.providerId,
          priority: payload.priority ?? 100,
          conditions: {
            ...(payload.conditions || {}),
            admin_audit: {
              ...(((payload.conditions || {}).admin_audit) || {}),
              updated_by: session.sub,
              updated_at: new Date().toISOString(),
            },
          },
          status: payload.status || 'ACTIVE',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.patch('/provider-routing-rules/:id', requireSessionPermission(['provider_routing.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const payload = ProviderRoutingRuleSchema.partial().parse(req.body);
      const session = (req as any).session;
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('provider_routing_rules')
        .update({
          rail: payload.rail,
          country_code: payload.countryCode,
          currency: payload.currency?.toUpperCase(),
          operation_code: payload.operationCode,
          provider_id: payload.providerId,
          priority: payload.priority,
          conditions: payload.conditions === undefined
            ? undefined
            : {
                ...(payload.conditions || {}),
                admin_audit: {
                  ...(((payload.conditions || {}).admin_audit) || {}),
                  updated_by: session.sub,
                  updated_at: new Date().toISOString(),
                },
              },
          status: payload.status,
          updated_at: new Date().toISOString(),
        })
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.delete('/provider-routing-rules/:id', requireSessionPermission(['provider_routing.write'], ['ADMIN', 'SUPER_ADMIN', 'IT']), async (req, res) => {
    try {
      const ruleId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { error } = await sb.from('provider_routing_rules').delete().eq('id', ruleId);
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  admin.get('/metrics/daily-movements', async (req, res) => {
    try {
      const { startDate, endDate } = req.query;
      if (!startDate || !endDate) {
        return res.status(400).json({ success: false, error: 'MISSING_DATE_RANGE' });
      }
      const service = new TransactionService();
      const data = await service.getDailyNetMovements(startDate as string, endDate as string);
      res.json({ success: true, data });
    } catch (e: any) {
      console.error(`[Admin] Get Daily Movements Error:`, e);
      res.status(500).json({ success: false, error: 'INTERNAL_SERVER_ERROR', message: e.message });
    }
  });
};

export const mountAdminRoutes = (app: Express, admin: Router) => {
  app.use('/api/admin', admin);
};
