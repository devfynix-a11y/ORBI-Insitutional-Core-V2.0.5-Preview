import { type RequestHandler, type Router } from 'express';
import { z } from 'zod';
import { sessionHasAnyRole } from '../../middleware/auth/authorization.js';
import { operatorAlertService } from '../../../backend/infrastructure/OperatorAlertService.js';
import { RedisManager } from '../../../backend/enterprise/infrastructure/RedisManager.js';
import { Audit } from '../../../backend/security/audit.js';
import { getAdminSupabase, getSupabase } from '../../../backend/supabaseClient.js';
import {
  CONFIG_COMMISSION_VIEW_ROLES,
  CONFIG_FX_VIEW_ROLES,
  CONFIG_LEDGER_ADMIN_ROLES,
  RECONCILIATION_REPORT_ROLES,
  RECONCILIATION_RUN_ROLES,
  SUPER_ADMIN_AND_ADMIN_ROLES,
} from '../../middleware/auth/roles.js';

const TreasuryApprovalSchema = z.object({
  txId: z.string().min(1),
  reason: z.string().trim().min(5).max(500),
});

const ReconciliationRunSchema = z.object({
  reason: z.string().trim().min(5).max(500),
});

const BrokerNotificationConfigSchema = z.object({
  thresholdUsd: z.coerce.number().positive().max(1_000_000_000),
  email: z.object({
    enabled: z.boolean().default(false),
    recipients: z.array(z.string().trim().email()).max(20).default([]),
  }).default({ enabled: false, recipients: [] }),
  slack: z.object({
    enabled: z.boolean().default(false),
    channel: z.string().trim().min(1).max(120).default('#ops-security-feed'),
  }).default({ enabled: false, channel: '#ops-security-feed' }),
  autoFreeze: z.object({
    enabled: z.boolean().default(false),
    riskScoreThreshold: z.coerce.number().min(50).max(100).default(90),
    action: z.enum(['SUSPEND_USER', 'FREEZE_USER', 'REQUIRE_REVIEW']).default('SUSPEND_USER'),
  }).default({ enabled: false, riskScoreThreshold: 90, action: 'SUSPEND_USER' }),
  enabled: z.boolean().optional(),
});

const ApiGatewayLockReleaseSchema = z.object({
  reason: z.string().trim().min(5).max(500),
});

type Deps = {
  authenticate: RequestHandler;
  adminOnly: RequestHandler;
  requireSessionPermission: (permissions: string[], roles?: string[]) => RequestHandler;
  LogicCore: any;
  ConfigClient: any;
  KMS: any;
  DataProtection: any;
  TransactionSigning: any;
};

const API_GATEWAY_SECURITY_ROLES = ['SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT'];

const isUuidLike = (value: unknown) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || ''));

const enrichGatewayActors = async (rows: any[]) => {
  const sb = getAdminSupabase() || getSupabase();
  if (!sb || rows.length === 0) return new Map<string, any>();

  const actorIds = Array.from(new Set(
    rows
      .map((row) => row.actor_id || row.actorId || row.actor_ref || row.actorRef)
      .filter((value) => value && isUuidLike(value)),
  ));
  if (actorIds.length === 0) return new Map<string, any>();

  const actorMap = new Map<string, any>();
  const [{ data: users }, { data: staff }] = await Promise.all([
    sb.from('users')
      .select('id, full_name, email, phone, customer_id, account_status, status_reason, status_reason_code')
      .in('id', actorIds),
    sb.from('staff')
      .select('id, full_name, email, role, account_status, status_reason, status_reason_code')
      .in('id', actorIds),
  ]);

  for (const user of users || []) {
    actorMap.set(String(user.id), { registryType: 'USER', ...user });
  }
  for (const staffRow of staff || []) {
    actorMap.set(String(staffRow.id), { registryType: 'STAFF', ...staffRow });
  }
  return actorMap;
};

export const registerOperationsRoutes = (v1: Router, deps: Deps) => {
  const {
    authenticate,
    adminOnly,
    requireSessionPermission,
    LogicCore,
    ConfigClient,
    KMS,
    DataProtection,
    TransactionSigning,
  } = deps;

  v1.get('/enterprise/organizations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getOrganizations(session.sub);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/organizations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.createOrganization(req.body, session.sub);
      if (result.error) return res.status(400).json({ success: false, error: result.error });
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/enterprise/organizations/:id', authenticate as any, async (req, res) => {
    try {
      const result = await LogicCore.getOrganizationDetails(req.params.id);
      if (result.error) return res.status(404).json({ success: false, error: result.error });
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/users/link', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const { userId, organizationId, role } = req.body;
    try {
      const result = await LogicCore.linkUserToOrganization(userId, organizationId, role, session.sub);
      if (result.error) return res.status(400).json({ success: false, error: result.error });
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/users/invite', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const { email, organizationId, role } = req.body;
    try {
      const result = await LogicCore.inviteUserByEmail(email, organizationId, role, session.sub);
      if (result.error) return res.status(400).json({ success: false, error: result.error });
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/treasury/withdraw/request', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const { goalId, amount, destinationWalletId, reason } = req.body;
    try {
      const result = await LogicCore.requestTreasuryWithdrawal(session.sub, goalId, amount, destinationWalletId, reason);
      if (result.error) return res.status(400).json({ success: false, error: result.error });
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/treasury/withdraw/approve', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const { txId, reason } = TreasuryApprovalSchema.parse(req.body);
      const result = await LogicCore.approveTreasuryWithdrawal(session.sub, txId, reason);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.get('/enterprise/treasury/approvals', authenticate as any, async (req, res) => {
    const orgId = req.query.orgId as string;
    if (!orgId) return res.status(400).json({ success: false, error: 'MISSING_ORG_ID' });
    try {
      const result = await LogicCore.getPendingApprovals(orgId);
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/enterprise/treasury/autosweep', authenticate as any, async (req, res) => {
    const { goalId, enabled, threshold } = req.body;
    try {
      const result = await LogicCore.configureAutoSweep(goalId, enabled, threshold);
      res.json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/escrow', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getEscrows(session.sub);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/escrow/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getEscrow(req.params.id, session.sub);
      if (!result) return res.status(404).json({ success: false, error: 'ESCROW_NOT_FOUND' });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/escrow/create', authenticate as any, async (req, res) => {
    const { recipientCustomerId, amount, description, conditions } = req.body;
    const userId = (req as any).session.sub;
    try {
      const referenceId = await LogicCore.createEscrow(userId, recipientCustomerId, amount, description, conditions);
      res.json({ success: true, referenceId });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/escrow/release', authenticate as any, async (req, res) => {
    const { referenceId } = req.body;
    const userId = (req as any).session.sub;
    try {
      const success = await LogicCore.releaseEscrow(referenceId, userId);
      res.json({ success });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/escrow/dispute', authenticate as any, async (req, res) => {
    const { referenceId, reason } = req.body;
    const userId = (req as any).session.sub;
    try {
      await LogicCore.disputeEscrow(referenceId, userId, reason);
      res.json({ success: true });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/escrow/refund', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const { referenceId, reason } = req.body;
    const userId = session.sub;

    if (!sessionHasAnyRole(session, [...SUPER_ADMIN_AND_ADMIN_ROLES])) {
      return res.status(403).json({ success: false, error: 'UNAUTHORIZED_ADMIN_ONLY' });
    }

    try {
      await LogicCore.refundEscrow(referenceId, userId, reason);
      res.json({ success: true });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.get('/enterprise/budgets/alerts', authenticate as any, async (req, res) => {
    const orgId = req.query.orgId as string;
    if (!orgId) return res.status(400).json({ success: false, error: 'MISSING_ORG_ID' });
    try {
      const result = await LogicCore.getBudgetAlerts(orgId);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/reconciliation/run', authenticate as any, requireSessionPermission(['reconciliation.run'], [...RECONCILIATION_RUN_ROLES]), async (req, res) => {
    try {
      const { reason } = ReconciliationRunSchema.parse(req.body);
      const session = (req as any).session;
      await LogicCore.runFullReconciliation(session.sub, reason);
      res.json({ success: true, message: 'Full reconciliation cycle triggered.' });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/reconciliation/reports', authenticate as any, requireSessionPermission(['reconciliation.read', 'reconciliation.run'], [...RECONCILIATION_REPORT_ROLES]), async (req, res) => {
    const limit = Number(req.query.limit || 50);
    try {
      const result = await LogicCore.getReconciliationReports(limit);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/config/ledger', authenticate as any, requireSessionPermission(['config.ledger.read', 'config.ledger.write'], [...CONFIG_LEDGER_ADMIN_ROLES]), async (_req, res) => {
    try {
      const config = await ConfigClient.getRuleConfig(true);
      res.json({ success: true, data: config.transaction_limits });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/config/ledger', authenticate as any, requireSessionPermission(['config.ledger.write'], [...CONFIG_LEDGER_ADMIN_ROLES]), async (req, res) => {
    try {
      const currentConfig = await ConfigClient.getRuleConfig();
      const newLimits = req.body;
      const updatedConfig = {
        ...currentConfig,
        transaction_limits: {
          ...currentConfig.transaction_limits,
          ...newLimits,
        },
      };

      await ConfigClient.saveConfig(updatedConfig);
      res.json({ success: true, message: 'Ledger configuration updated successfully.' });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/risk/broker-notifications', authenticate as any, requireSessionPermission(['admin.audit.read', 'config.ledger.read'], [...CONFIG_LEDGER_ADMIN_ROLES, 'AUDIT', 'RISK_OFFICER', 'FRAUD']), async (_req, res) => {
    try {
      const currentConfig = await ConfigClient.getRuleConfig(true);
      const brokerNotifications = currentConfig.broker_notifications || currentConfig.rules?.broker_notifications || {};
      const autoFreeze = currentConfig.auto_freeze || currentConfig.rules?.auto_freeze || {};
      res.json({
        success: true,
        data: {
          enabled: brokerNotifications.enabled !== false,
          thresholdUsd: Number(brokerNotifications.thresholdUsd || 10000),
          email: {
            enabled: brokerNotifications.email?.enabled === true,
            recipients: Array.isArray(brokerNotifications.email?.recipients) ? brokerNotifications.email.recipients : [],
          },
          slack: {
            enabled: brokerNotifications.slack?.enabled === true,
            channel: brokerNotifications.slack?.channel || '#ops-security-feed',
            webhookConfigured: Boolean(process.env.ORBI_SLACK_WEBHOOK_URL || process.env.SLACK_WEBHOOK_URL),
          },
          autoFreeze: {
            enabled: autoFreeze.enabled === true,
            riskScoreThreshold: Number(autoFreeze.riskScoreThreshold || 90),
            action: autoFreeze.action || 'SUSPEND_USER',
          },
          eventCode: brokerNotifications.eventCode || 'DYNAMIC_BROKER_LIMIT_EXCEEDED',
          updatedAt: brokerNotifications.updatedAt || null,
        },
      });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/risk/broker-notifications', authenticate as any, requireSessionPermission(['config.ledger.write'], [...CONFIG_LEDGER_ADMIN_ROLES, 'RISK_OFFICER', 'FRAUD']), async (req, res) => {
    const session = (req as any).session;
    try {
      const parsed = BrokerNotificationConfigSchema.parse(req.body || {});
      const enabled = parsed.enabled ?? (parsed.email.enabled || parsed.slack.enabled);
      const brokerNotifications = {
        enabled,
        thresholdUsd: parsed.thresholdUsd,
        email: {
          enabled: parsed.email.enabled,
          recipients: parsed.email.recipients,
        },
        slack: {
          enabled: parsed.slack.enabled,
          channel: parsed.slack.channel,
        },
        eventCode: 'DYNAMIC_BROKER_LIMIT_EXCEEDED',
        updatedAt: new Date().toISOString(),
        updatedBy: session?.sub || 'unknown',
      };
      const autoFreeze = {
        enabled: parsed.autoFreeze.enabled,
        riskScoreThreshold: parsed.autoFreeze.riskScoreThreshold,
        action: parsed.autoFreeze.action,
        targetRoles: ['SUPER_ADMIN', 'ADMIN', 'RISK_OFFICER', 'FRAUD'],
        updatedAt: new Date().toISOString(),
        updatedBy: session?.sub || 'unknown',
      };

      const currentConfig = await ConfigClient.getRuleConfig();
      const updatedRules = {
        ...(currentConfig.rules || {}),
        broker_notifications: brokerNotifications,
        auto_freeze: autoFreeze,
      };
      const updatedConfig = {
        ...currentConfig,
        rules: updatedRules,
        broker_notifications: brokerNotifications,
        auto_freeze: autoFreeze,
      };

      await ConfigClient.saveConfig(updatedConfig);
      res.json({
        success: true,
        message: 'Dynamic broker notification rules updated.',
        data: {
          ...brokerNotifications,
          slack: {
            ...brokerNotifications.slack,
            webhookConfigured: Boolean(process.env.ORBI_SLACK_WEBHOOK_URL || process.env.SLACK_WEBHOOK_URL),
          },
          autoFreeze,
        },
      });
    } catch (e: any) {
      if (e?.name === 'ZodError') {
        return res.status(400).json({ success: false, error: 'VALIDATION_FAILED', issues: e.issues });
      }
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/operator-alerts', authenticate as any, requireSessionPermission(['admin.audit.read', 'transaction.view', 'user.read'], ['SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT', 'CUSTOMER_CARE']), async (req, res) => {
    const session = (req as any).session;
    try {
      const data = await operatorAlertService.list({
        role: session?.role || session?.user?.role,
        status: String(req.query.status || 'ALL'),
        limit: Number(req.query.limit || 50),
      });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/admin/operator-alerts/:id/read', authenticate as any, requireSessionPermission(['admin.audit.read', 'transaction.view', 'user.read'], ['SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT', 'CUSTOMER_CARE']), async (req, res) => {
    const session = (req as any).session;
    try {
      const data = await operatorAlertService.markRead(String(req.params.id), session?.sub || 'unknown');
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/admin/operator-alerts/:id/resolve', authenticate as any, requireSessionPermission(['admin.audit.read', 'transaction.view', 'user.read'], ['SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT', 'CUSTOMER_CARE']), async (req, res) => {
    const session = (req as any).session;
    try {
      const reason = String(req.body?.reason || '').trim();
      const data = await operatorAlertService.resolve(String(req.params.id), session?.sub || 'unknown', reason || undefined);
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/api-gateway/security/locks', authenticate as any, requireSessionPermission(['admin.audit.read', 'user.read'], API_GATEWAY_SECURITY_ROLES), async (req, res) => {
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const limit = Math.min(200, Math.max(1, Number(req.query.limit || 80)));
      const status = String(req.query.status || 'active').trim().toLowerCase();
      const includeReleased = status === 'all' || status === 'released';

      const { data: quarantineRows, error: quarantineError } = await sb
        .from('api_gateway_quarantines')
        .select('id, actor_id, actor_ref, route_group, scope_key, reason, status, expires_at, released_at, released_by, metadata, created_at')
        .in('status', includeReleased ? ['active', 'released'] : ['active'])
        .order('created_at', { ascending: false })
        .limit(limit);
      if (quarantineError) throw quarantineError;

      const { data: eventRows, error: eventError } = await sb
        .from('api_gateway_security_events')
        .select('id, actor_id, actor_ref, route, method, route_group, operation_class, action, risk_score, ip_hash, device_hash, app_id, trace_id, metadata, created_at')
        .in('action', ['API_GATEWAY_ATTEMPT_LOCKED', 'API_GATEWAY_QUARANTINED', 'API_GATEWAY_THROTTLED'])
        .order('created_at', { ascending: false })
        .limit(limit);
      if (eventError) throw eventError;

      const combined = [
        ...(quarantineRows || []).map((row: any) => ({
          id: row.id,
          recordType: 'quarantine',
          action: row.reason === 'API_GATEWAY_ATTEMPT_LOCK' ? 'API_GATEWAY_ATTEMPT_LOCKED' : 'API_GATEWAY_QUARANTINED',
          actorId: row.actor_id,
          actorRef: row.actor_ref,
          route: row.metadata?.route || null,
          method: row.metadata?.method || null,
          routeGroup: row.route_group,
          operationClass: row.metadata?.operationClass || null,
          riskScore: row.metadata?.score || null,
          ipHash: row.metadata?.ipHash || null,
          deviceHash: row.metadata?.deviceHash || null,
          appId: row.metadata?.appId || null,
          traceId: row.metadata?.traceId || null,
          scopeKey: row.scope_key,
          status: row.status,
          reason: row.reason,
          expiresAt: row.expires_at,
          releasedAt: row.released_at,
          releasedBy: row.released_by,
          metadata: row.metadata || {},
          createdAt: row.created_at,
        })),
        ...(eventRows || []).map((row: any) => ({
          id: row.id,
          recordType: 'event',
          action: row.action,
          actorId: row.actor_id,
          actorRef: row.actor_ref,
          route: row.route,
          method: row.method,
          routeGroup: row.route_group,
          operationClass: row.operation_class,
          riskScore: row.risk_score,
          ipHash: row.ip_hash,
          deviceHash: row.device_hash,
          appId: row.app_id,
          traceId: row.trace_id,
          scopeKey: row.metadata?.scopeKey || null,
          status: row.metadata?.expiresAt && new Date(row.metadata.expiresAt).getTime() < Date.now() ? 'expired' : 'active',
          reason: row.metadata?.reason || row.action,
          expiresAt: row.metadata?.expiresAt || null,
          releasedAt: null,
          releasedBy: null,
          metadata: row.metadata || {},
          createdAt: row.created_at,
        })),
      ]
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
        .slice(0, limit);

      const actorMap = await enrichGatewayActors(combined);
      const data = combined.map((row) => ({
        ...row,
        actor: actorMap.get(String(row.actorId || row.actorRef)) || {
          registryType: String(row.actorRef || '').startsWith('anonymous:') ? 'ANONYMOUS_SOURCE' : 'UNKNOWN',
          id: row.actorId || null,
          reference: row.actorRef || null,
        },
        canRelease: Boolean(row.scopeKey && row.status === 'active'),
      }));

      res.json({
        success: true,
        data,
        meta: {
          note: 'Use POST /v1/admin/api-gateway/security/locks/:id/release with a reason to clear a Redis lock/quarantine by scope key.',
        },
      });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/api-gateway/security/locks/:id/release', authenticate as any, requireSessionPermission(['admin.audit.read'], API_GATEWAY_SECURITY_ROLES), async (req, res) => {
    const session = (req as any).session;
    try {
      const parsed = ApiGatewayLockReleaseSchema.parse(req.body || {});
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const id = String(req.params.id || '').trim();
      let recordType: 'quarantine' | 'event' = 'quarantine';
      let record: any = null;

      const quarantineResult = await sb
        .from('api_gateway_quarantines')
        .select('id, actor_id, actor_ref, route_group, scope_key, reason, status, metadata, expires_at, created_at')
        .eq('id', id)
        .maybeSingle();

      if (quarantineResult.data) {
        record = quarantineResult.data;
      } else {
        const eventResult = await sb
          .from('api_gateway_security_events')
          .select('id, actor_id, actor_ref, route, method, route_group, operation_class, action, metadata, created_at')
          .eq('id', id)
          .maybeSingle();
        if (eventResult.error) throw eventResult.error;
        record = eventResult.data;
        recordType = 'event';
      }

      if (!record) return res.status(404).json({ success: false, error: 'API_GATEWAY_LOCK_NOT_FOUND' });

      const scopeKey = String(record.scope_key || record.metadata?.scopeKey || '').trim();
      if (!scopeKey) {
        return res.status(400).json({
          success: false,
          error: 'API_GATEWAY_SCOPE_KEY_MISSING',
          message: 'This historical lock record does not include a Redis scope key. It may predate resolvable gateway locks.',
        });
      }

      await RedisManager.delete(scopeKey);

      if (recordType === 'quarantine') {
        await sb
          .from('api_gateway_quarantines')
          .update({
            status: 'released',
            released_at: new Date().toISOString(),
            released_by: session?.sub || 'unknown',
            metadata: {
              ...(record.metadata || {}),
              releaseReason: parsed.reason,
              releasedByRole: session?.role || session?.user?.role || null,
            },
          })
          .eq('id', id);
      }

      await Audit.log('SECURITY', session?.sub || 'unknown', 'API_GATEWAY_LOCK_RELEASED', {
        actor_name: session?.email || session?.user?.email || 'ORBI Admin',
        targetRecordId: id,
        targetRecordType: recordType,
        targetActorRef: record.actor_ref || record.actor_id || null,
        routeGroup: record.route_group,
        scopeKey,
        reason: parsed.reason,
      }).catch(() => {});

      res.json({
        success: true,
        data: {
          released: true,
          id,
          recordType,
          scopeKey,
          reason: parsed.reason,
        },
      });
    } catch (e: any) {
      if (e?.name === 'ZodError') {
        return res.status(400).json({ success: false, error: 'VALIDATION_FAILED', issues: e.issues });
      }
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/config/commissions', authenticate as any, requireSessionPermission(['config.commissions.read', 'config.commissions.write'], [...CONFIG_COMMISSION_VIEW_ROLES]), async (_req, res) => {
    try {
      const config = await ConfigClient.getRuleConfig(true);
      res.json({ success: true, data: config.commission_programs || {} });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/config/commissions', authenticate as any, requireSessionPermission(['config.commissions.write'], [...CONFIG_LEDGER_ADMIN_ROLES]), async (req, res) => {
    try {
      const currentConfig = await ConfigClient.getRuleConfig();
      const updatedConfig = {
        ...currentConfig,
        commission_programs: {
          ...(currentConfig.commission_programs || {}),
          ...(req.body || {}),
        },
      };
      await ConfigClient.saveConfig(updatedConfig);
      res.json({ success: true, message: 'Commission configuration updated successfully.' });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/config/fx-rates', authenticate as any, requireSessionPermission(['config.fx.read', 'config.fx.write'], [...CONFIG_FX_VIEW_ROLES]), async (_req, res) => {
    try {
      const config = await ConfigClient.getRuleConfig(true);
      res.json({ success: true, data: config.exchange_rates });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/config/fx-rates', authenticate as any, requireSessionPermission(['config.fx.write'], [...CONFIG_LEDGER_ADMIN_ROLES]), async (req, res) => {
    try {
      const currentConfig = await ConfigClient.getRuleConfig();
      const newRates = req.body;

      const updatedConfig = {
        ...currentConfig,
        exchange_rates: {
          ...currentConfig.exchange_rates,
          ...newRates,
        },
      };

      await ConfigClient.saveConfig(updatedConfig);
      res.json({ success: true, message: 'Exchange rates updated successfully.' });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/admin/kms/rewrap', authenticate as any, adminOnly as any, async (req, res) => {
    try {
      const confirm = String(req.body?.confirm || '').trim().toUpperCase();
      if (confirm !== 'REWRAP_KEYS') {
        return res.status(400).json({
          success: false,
          error: 'CONFIRMATION_REQUIRED',
          message: 'Set confirm=REWRAP_KEYS to proceed.',
        });
      }

      const newMasterKey = String(req.body?.newMasterKey || '').trim();
      const resolvedMasterKey = newMasterKey || String(process.env.KMS_MASTER_KEY || '').trim();
      if (!resolvedMasterKey) {
        return res.status(400).json({
          success: false,
          error: 'KMS_MASTER_KEY_MISSING',
          message: 'No master key provided or configured.',
        });
      }

      await KMS.reWrapAllKeys(resolvedMasterKey);
      res.json({ success: true, message: 'KMS keys re-wrapped successfully.' });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/admin/kms/health', authenticate as any, adminOnly as any, async (_req, res) => {
    try {
      const probe = { ping: 'pong', ts: Date.now() };
      const cipher = await DataProtection.encryptValue(probe, { route: 'public_operations_probe' });
      const decoded = await DataProtection.decryptValue(cipher);
      const ok = decoded && typeof decoded === 'object' && (decoded as any).ping === 'pong';
      res.json({
        success: ok,
        data: {
          ok,
          ts: Date.now(),
        },
      });
    } catch (e: any) {
      res.status(500).json({
        success: false,
        error: e.message,
      });
    }
  });

  v1.post('/admin/kms/diagnose', authenticate as any, adminOnly as any, async (req, res) => {
    try {
      const masterKey = String(req.body?.masterKey || process.env.KMS_MASTER_KEY || '').trim();
      if (!masterKey) {
        return res.status(400).json({
          success: false,
          error: 'KMS_MASTER_KEY_MISSING',
        });
      }

      const configuredSalt = process.env.KMS_SALT || '';
      const defaultSalt = 'orbi-kms-wrapping-salt-v1';

      const matchConfigured = await KMS.testUnwrapWithSecret(masterKey, configuredSalt || undefined);
      const matchDefault = await KMS.testUnwrapWithSecret(masterKey, defaultSalt);

      res.json({
        success: true,
        data: {
          matchConfiguredSalt: matchConfigured,
          matchDefaultSalt: matchDefault,
          configuredSalt: configuredSalt ? 'SET' : 'EMPTY',
        },
      });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/sys/bootstrap', authenticate as any, async (req, res) => {
    const token = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.getBootstrapData(token);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/sys/metrics', authenticate as any, async (_req, res) => {
    try {
      const result = await LogicCore.getSystemMetrics();
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/transactions/secure-sign', authenticate as any, async (req, res) => {
    try {
      const { transactionPayload, signature, publicKey } = req.body;

      const hash = TransactionSigning.generateTransactionHash(transactionPayload);
      const isValid = TransactionSigning.verifySecureEnclaveSignature(hash, signature, publicKey);

      if (!isValid) {
        return res.status(403).json({ success: false, error: 'SECURE_ENCLAVE_SIGNATURE_INVALID' });
      }

      const result = await LogicCore.processSecurePayment(transactionPayload, (req as any).session.user);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });
};
