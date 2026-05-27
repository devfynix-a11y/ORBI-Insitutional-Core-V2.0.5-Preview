import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { Audit } from '../../../backend/security/audit.js';
import { resolveSessionRegistryType, resolveSessionRole } from '../auth/authorization.js';

const SENSITIVE_KEY = /(secret|token|password|pin|otp|key|authorization|credential|private|signature)/i;
const MAX_VALUE_LENGTH = 80;

const redactValue = (key: string, value: unknown): unknown => {
  if (SENSITIVE_KEY.test(key)) return '[REDACTED]';
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.slice(0, 10).map((item, index) => redactValue(`${key}_${index}`, item));
  if (typeof value === 'object') return redactRecord(value as Record<string, unknown>);

  const text = String(value);
  if (text.includes('@')) {
    const [name, domain] = text.split('@');
    return `${name.slice(0, 2)}***@${domain || '***'}`;
  }
  if (/^\+?\d{7,}$/.test(text)) {
    return `${text.slice(0, 3)}***${text.slice(-2)}`;
  }
  return text.length > MAX_VALUE_LENGTH ? `${text.slice(0, MAX_VALUE_LENGTH)}...` : text;
};

const redactRecord = (record: Record<string, unknown> = {}) => {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(record)) {
    result[key] = redactValue(key, value);
  }
  return result;
};

const summarizeBody = (body: unknown) => {
  if (!body || typeof body !== 'object' || Buffer.isBuffer(body)) return undefined;
  const record = body as Record<string, unknown>;
  return {
    keys: Object.keys(record).sort(),
  };
};

const resolveAction = (req: Request) => {
  const path = req.originalUrl || req.path;
  if (path.includes('/admin/audit-trail')) return 'ADMIN_AUDIT_ACCESS';
  if (path.includes('/staff/') && path.includes('/activity')) return 'ADMIN_STAFF_ACTIVITY_ACCESS';
  if (path.includes('/admin/monitor/')) return 'ADMIN_MONITOR_ACCESS';
  if (path.includes('/risk/alerts')) return 'ADMIN_RISK_ACCESS';

  switch (req.method.toUpperCase()) {
    case 'GET':
    case 'HEAD':
    case 'OPTIONS':
      return 'ADMIN_ACCESS_READ';
    case 'POST':
      return 'ADMIN_ACCESS_CREATE';
    case 'PUT':
    case 'PATCH':
      return 'ADMIN_ACCESS_UPDATE';
    case 'DELETE':
      return 'ADMIN_ACCESS_DELETE';
    default:
      return 'ADMIN_ACCESS';
  }
};

const resolveTarget = (req: Request) => {
  const path = (req.baseUrl + req.path).replace(/\/+/g, '/');
  const parts = path.split('/').filter(Boolean);
  const adminIndex = parts.findIndex((part) => part === 'admin');
  const resourceParts = adminIndex >= 0 ? parts.slice(adminIndex + 1) : parts;
  const resource = resourceParts[0] || 'unknown';
  const targetId = req.params?.id || req.params?.walletId || req.params?.providerId || req.params?.transactionId || null;
  return { resource, targetId };
};

const getClientIp = (req: Request) => {
  const forwarded = String(req.get('x-forwarded-for') || '').split(',')[0]?.trim();
  return forwarded || req.ip || req.socket.remoteAddress || undefined;
};

export const createAdminActivityAudit = (): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction) => {
    const startedAt = Date.now();

    res.once('finish', () => {
      const session = (req as any).session;
      const isMonitorRoute = (req.originalUrl || req.path).includes('/api/admin/monitor/');
      const actorId = session?.sub || session?.user?.id || (isMonitorRoute ? 'MONITOR_API_CLIENT' : 'UNKNOWN_ADMIN_ACTOR');
      const role = session ? resolveSessionRole(session) : undefined;
      const registryType = session ? resolveSessionRegistryType(session) : undefined;
      const { resource, targetId } = resolveTarget(req);

      const metadata = {
        method: req.method,
        path: req.originalUrl || req.path,
        base_url: req.baseUrl,
        resource,
        target_id: targetId,
        status_code: res.statusCode,
        success: res.statusCode < 400,
        duration_ms: Date.now() - startedAt,
        role,
        registry_type: registryType,
        query: redactRecord(req.query as Record<string, unknown>),
        params: redactRecord(req.params as Record<string, unknown>),
        body: summarizeBody(req.body),
        trace_id: (req as any).traceId || req.get('x-orbi-trace') || req.get('x-trace-id') || req.get('x-request-id') || undefined,
        correlation_id: (req as any).correlationId || req.get('x-correlation-id') || undefined,
        app_id: req.get('x-orbi-app-id') || undefined,
        app_origin: req.get('x-orbi-app-origin') || undefined,
        device_id: req.get('x-orbi-device-id') || undefined,
        ip: getClientIp(req),
        user_agent: req.get('user-agent') || undefined,
      };

      void Audit.log('ADMIN', actorId, resolveAction(req), metadata).catch((error) => {
        console.error('[AdminActivityAudit] Failed to record admin activity', error);
      });
    });

    next();
  };
};
