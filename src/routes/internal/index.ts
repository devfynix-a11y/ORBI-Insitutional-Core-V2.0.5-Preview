import type { Express, NextFunction, Request, Response, Router } from 'express';
import { z } from 'zod';
import { getAdminSupabase, getSupabase } from '../../../backend/supabaseClient.js';
import { BankingEngineService } from '../../../backend/ledger/transactionEngine.js';
import { Audit } from '../../../backend/security/audit.js';
import { Server as LogicCore } from '../../../backend/server.js';
import { Webhooks } from '../../../backend/payments/webhookHandler.js';
import {
  createInternalWorkerMiddleware,
  getInternalAuditMetadata,
  workerHasRequiredScopes,
} from '../../middleware/auth/authorization.js';

const requireWorkerScope = (requiredScopes: string[]) =>
  (req: Request, res: Response, next: NextFunction) => {
    const worker = (req as any).internalWorker || null;
    if (!workerHasRequiredScopes(worker, requiredScopes)) {
      return res.status(403).json({
        success: false,
        error: 'WORKER_SCOPE_REQUIRED',
        message: `Missing required worker scope: ${requiredScopes.join(', ')}`,
      });
    }
    return next();
  };

const TrustedGatewayEventSchema = z.object({
  providerId: z.string().min(1),
  reference: z.string().min(1),
  status: z.enum(['completed', 'failed', 'processing', 'pending']),
  message: z.string().min(1).max(1000),
  providerEventId: z.string().min(1).optional(),
  rawStatus: z.string().min(1).optional(),
  payload: z.record(z.string(), z.unknown()).optional(),
});

const flattenHeaders = (headers: Request['headers']): Record<string, string | undefined> =>
  Object.fromEntries(
    Object.entries(headers).map(([key, value]) => [
      key,
      Array.isArray(value) ? value.join(',') : value === undefined ? undefined : String(value),
    ]),
  );

export const registerInternalRoutes = (internal: Router) => {
  internal.use(createInternalWorkerMiddleware());

  internal.post('/transactions/claim', requireWorkerScope(['transactions:claim']), async (req, res) => {
    const limit = req.body.limit || 100;
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) return res.status(500).json({ success: false, error: 'DB_OFFLINE' });

    try {
      const { data, error } = await sb
        .from('transactions')
        .update({ status: 'processing', updated_at: new Date().toISOString() })
        .eq('status', 'pending')
        .order('created_at', { ascending: true })
        .limit(limit)
        .select();

      if (error) throw error;
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.put('/transactions/:id/resolve', requireWorkerScope(['transactions:resolve']), async (req, res) => {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { status } = req.body;
    const workerId = String((req as any).internalWorker?.id || req.get('x-worker-id') || `internal-route:${id}`);

    try {
      const engine = new BankingEngineService();
      if (status === 'completed') {
        const success = await engine.completeSettlement(id, undefined, workerId);
        res.json({ success });
      } else {
        const sb = getAdminSupabase() || getSupabase();
        const { error } = await sb!.from('transactions').update({ status: 'failed' }).eq('id', id);
        res.json({ success: !error });
      }
    } catch (e: any) {
      const message = String(e?.message || e || '');
      const statusCode = message.includes('CONCURRENCY_CONFLICT')
        ? 409
        : message.includes('INVALID_SETTLEMENT_STATE')
          ? 409
          : 500;
      res.status(statusCode).json({ success: false, error: message });
    }
  });

  internal.get('/transactions/reversible', requireWorkerScope(['transactions:read']), async (_req, res) => {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) return res.status(500).json({ success: false, error: 'DB_OFFLINE' });

    const fifteenMinsAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString();

    try {
      const { data, error } = await sb
        .from('transactions')
        .select('*')
        .or(`status.eq.failed,and(status.eq.processing,updated_at.lt.${fifteenMinsAgo})`);

      if (error) throw error;
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.post('/transactions/:id/reverse', requireWorkerScope(['transactions:reverse']), async (req, res) => {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { reason } = req.body;

    try {
      const sb = getAdminSupabase() || getSupabase();
      const { data: tx } = await sb!.from('transactions').select('*').eq('id', id).single();
      if (!tx) return res.status(404).json({ success: false, error: 'NOT_FOUND' });

      const { error } = await sb!
        .from('transactions')
        .update({
          status: 'reversed',
          metadata: { ...tx.metadata, reversal_reason: reason, reversed_at: new Date().toISOString() },
        })
        .eq('id', id);

      if (error) throw error;

      await Audit.log('FINANCIAL', tx.user_id, 'TRANSACTION_REVERSED', {
        txId: id,
        reason,
        ...getInternalAuditMetadata(req),
      });
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.get('/transactions/recent', requireWorkerScope(['transactions:read']), async (req, res) => {
    const minutes = parseInt(req.query.minutes as string) || 5;
    const sb = getAdminSupabase() || getSupabase();
    const startTime = new Date(Date.now() - minutes * 60 * 1000).toISOString();

    try {
      const { data, error } = await sb!.from('transactions').select('*').gte('created_at', startTime);
      if (error) throw error;
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.post('/security/anomalies', requireWorkerScope(['security:anomalies:write']), async (req, res) => {
    const { transactionId, severity, description } = req.body;
    try {
      const sb = getAdminSupabase() || getSupabase();
      const { data: tx } = await sb!.from('transactions').select('*').eq('id', transactionId).single();

      await Audit.log('FRAUD', tx?.user_id || 'SYSTEM', 'WORKER_ANOMALY_REPORTED', {
        transactionId,
        severity,
        description,
        ...getInternalAuditMetadata(req),
      });

      if (sb) {
        await sb.from('provider_anomalies').insert({
          transaction_id: transactionId,
          risk_score: severity === 'high' ? 90 : 50,
          detection_flags: ['WORKER_REPORTED'],
          status: 'OPEN',
          metadata: { description },
        });
      }
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.get('/tasks/pending', requireWorkerScope(['tasks:read']), async (_req, res) => {
    const sb = getAdminSupabase() || getSupabase();
    try {
      const { data, error } = await sb!.from('tasks').select('*').eq('status', 'pending');
      if (error) throw error;
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.put('/tasks/:id/status', requireWorkerScope(['tasks:write']), async (req, res) => {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { status, result } = req.body;
    try {
      const sb = getAdminSupabase() || getSupabase();
      const { error } = await sb!
        .from('tasks')
        .update({
          status,
          metadata: result ? { result } : undefined,
          updated_at: new Date().toISOString(),
        })
        .eq('id', id);
      if (error) throw error;
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.get('/messages/queued', requireWorkerScope(['messages:read']), async (_req, res) => {
    const sb = getAdminSupabase() || getSupabase();
    try {
      const { data, error } = await sb!.from('user_messages').select('*').eq('status', 'queued');
      if (error) throw error;
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.post('/offline/requests', requireWorkerScope(['offline:requests:write']), async (req, res) => {
    try {
      const result = await LogicCore.processOfflineGatewayRequest(req.body);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  internal.post('/offline/confirmations', requireWorkerScope(['offline:confirmations:write']), async (req, res) => {
    try {
      const result = await LogicCore.processOfflineGatewayConfirmation(req.body);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  internal.post('/gateway/provider-events', requireWorkerScope(['gateway:events:write']), async (req, res) => {
    const parsed = TrustedGatewayEventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'TRUSTED_GATEWAY_EVENT_INVALID',
        issues: parsed.error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      });
    }

    const workerId = String((req as any).internalWorker?.id || req.get('x-worker-id') || 'payment-gateway');

    try {
      const result = await Webhooks.handleTrustedGatewayEvent({
        ...parsed.data,
        sourceIp: req.ip,
        headers: flattenHeaders(req.headers),
      });

      await Audit.log('FINANCIAL', workerId, 'TRUSTED_GATEWAY_EVENT_RECEIVED', {
        providerId: parsed.data.providerId,
        reference: parsed.data.reference,
        status: parsed.data.status,
        providerEventId: parsed.data.providerEventId || null,
        rawStatus: parsed.data.rawStatus || null,
        ...getInternalAuditMetadata(req),
      });

      return res.json({ success: true, data: result });
    } catch (e: any) {
      const message = String(e?.message || e || 'TRUSTED_GATEWAY_EVENT_FAILED');
      const statusCode = message === 'PROVIDER_NOT_FOUND' ? 404 : message === 'DB_OFFLINE' ? 503 : 500;
      await Audit.log('FINANCIAL', workerId, 'TRUSTED_GATEWAY_EVENT_FAILED', {
        providerId: parsed.data.providerId,
        reference: parsed.data.reference,
        status: parsed.data.status,
        error: message,
        ...getInternalAuditMetadata(req),
      });
      return res.status(statusCode).json({ success: false, error: message });
    }
  });

  internal.put('/messages/:id/status', requireWorkerScope(['messages:write']), async (req, res) => {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { status } = req.body;
    try {
      const sb = getAdminSupabase() || getSupabase();
      const { error } = await sb!
        .from('user_messages')
        .update({
          status,
          sent_at: status === 'sent' ? new Date().toISOString() : undefined,
        })
        .eq('id', id);
      if (error) throw error;
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  internal.post('/email/test', requireWorkerScope(['email:test']), async (req, res) => {
    const to = String(req.body?.to || '').trim();
    if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) {
      return res.status(400).json({
        success: false,
        error: 'EMAIL_RECIPIENT_INVALID',
      });
    }

    try {
      const result = await LogicCore.testEmail(to);
      return res.status(result.success ? 200 : 502).json(result);
    } catch (e: any) {
      return res.status(500).json({ success: false, error: e.message || 'EMAIL_TEST_FAILED' });
    }
  });

  internal.get('/email/verify', requireWorkerScope(['email:verify']), async (_req, res) => {
    try {
      const result = await LogicCore.verifyEmailConfig();
      return res.status(result.success ? 200 : 503).json(result);
    } catch (e: any) {
      return res.status(500).json({ success: false, error: e.message || 'EMAIL_VERIFY_FAILED' });
    }
  });
};

export const mountInternalRoutes = (app: Express, internal: Router) => {
  app.use('/api/internal', internal);
};
