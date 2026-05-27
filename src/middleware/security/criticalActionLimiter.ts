import crypto from 'crypto';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { RedisManager } from '../../../backend/enterprise/infrastructure/RedisManager.js';
import { Audit } from '../../../backend/security/audit.js';

type LimitRule = {
  name: string;
  limit: number;
  windowMs: number;
  methods?: string[];
  match: (path: string, req: Request) => boolean;
};

type LimitRecord = {
  count: number;
  reset: number;
};

const memoryStore = new Map<string, LimitRecord>();

const minute = 60 * 1000;

const criticalRules: LimitRule[] = [
  {
    name: 'auth_login',
    limit: 5,
    windowMs: 5 * minute,
    methods: ['POST'],
    match: (path) => /^\/auth\/(login|pin-login|passkey\/login\/(?:start|finish)|biometric\/login\/(?:start|finish))$/.test(path),
  },
  {
    name: 'auth_bootstrap_or_signup',
    limit: 3,
    windowMs: 60 * minute,
    methods: ['POST'],
    match: (path) => /^\/auth\/(bootstrap-admin|signup)$/.test(path),
  },
  {
    name: 'auth_sensitive_verification',
    limit: 5,
    windowMs: 5 * minute,
    methods: ['POST'],
    match: (path) => /^\/auth\/(verify|otp\/initiate|password\/reset\/(?:initiate|complete))$/.test(path),
  },
  {
    name: 'financial_preview',
    limit: 60,
    windowMs: minute,
    methods: ['POST', 'GET'],
    match: (path) => (
      path === '/transactions/preview' ||
      path === '/external-funds/preview' ||
      path.endsWith('/spend/preview') ||
      path.includes('/payments/') && path.endsWith('/preview') ||
      path === '/fx/quote'
    ),
  },
  {
    name: 'financial_settlement',
    limit: 8,
    windowMs: minute,
    methods: ['POST'],
    match: (path) => (
      path === '/transactions/settle' ||
      path === '/transactions/secure-sign' ||
      path === '/external-funds/deposit-intents' ||
      path === '/external-funds/settle' ||
      /\/settle$/.test(path) ||
      /\/settlement\/payout$/.test(path) ||
      /\/gateway\/payment(?:\/[^/]+)?\/(?:initiate|settle|refund)$/.test(path)
    ),
  },
  {
    name: 'admin_config_commit',
    limit: 5,
    windowMs: 10 * minute,
    methods: ['POST', 'PATCH', 'PUT'],
    match: (path, req) => (
      path === '/admin/config/bootstrap' ||
      path === '/api/admin/config/bootstrap' ||
      path === '/config/bootstrap' ||
      /^\/api\/admin\/config\/(?:ledger|commissions|fx-rates)$/.test(path) ||
      /^\/admin\/config\/(?:ledger|commissions|fx-rates)$/.test(path) ||
      /^\/config\/(?:ledger|commissions|fx-rates)$/.test(path) ||
      path === '/admin/kms/rewrap' ||
      path === '/api/admin/kms/rewrap' ||
      path === '/kms/rewrap' ||
      (path.endsWith('/config/bootstrap') && String((req.body as any)?.mode || '').toLowerCase() === 'commit')
    ),
  },
  {
    name: 'admin_sensitive_mutation',
    limit: 20,
    windowMs: 10 * minute,
    methods: ['POST', 'PATCH', 'PUT', 'DELETE'],
    match: (path) => (
      /^\/admin\/transactions\/.*\/(?:lock|audit|approve|reverse)$/.test(path) ||
      path === '/admin/transactions/approve-audited' ||
      /^\/admin\/staff\/.*\/reset-password$/.test(path) ||
      /^\/admin\/(?:kyc\/review|documents\/.*\/verify|devices\/.*\/status)$/.test(path) ||
      /^\/admin\/users\/.*\/(?:status|profile)$/.test(path) ||
      /^\/admin\/service-access\/requests\/.*\/review$/.test(path) ||
      /^\/api\/admin\/(?:transactions\/.*\/(?:lock|audit|approve|reverse)|staff\/.*\/reset-password|kyc\/review|documents\/.*\/verify|devices\/.*\/status|users\/.*\/(?:status|profile)|service-access\/requests\/.*\/review)$/.test(path) ||
      path === '/admin/reconciliation/run' ||
      path === '/api/admin/reconciliation/run' ||
      /^\/(?:transactions\/.*\/(?:lock|audit|approve|reverse)|staff\/.*\/reset-password|kyc\/review|documents\/.*\/verify|devices\/.*\/status)$/.test(path)
    ),
  },
  {
    name: 'provider_webhook',
    limit: 120,
    windowMs: minute,
    methods: ['POST'],
    match: (path) => /^\/webhooks\/gateway\/[^/]+$/.test(path),
  },
  {
    name: 'monitor_mutation',
    limit: 30,
    windowMs: minute,
    methods: ['POST'],
    match: (path) => path === '/operational-metrics/snapshot' || path === '/api/admin/monitor/operational-metrics/snapshot',
  },
];

const normalizePath = (req: Request): string => {
  const baseUrl = String(req.baseUrl || '');
  const routePath = String(req.path || req.url || '/').split('?')[0] || '/';
  const full = `${baseUrl}${routePath}`.replace(/^\/(?:api\/v1|v1)/, '');
  return full.startsWith('/') ? full : `/${full}`;
};

const requestIp = (req: Request): string => {
  const forwardedFor = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwardedFor || req.ip || req.socket.remoteAddress || 'unknown-ip';
};

const stableHash = (value: unknown): string => {
  const text = String(value || '').trim().toLowerCase();
  if (!text) return '';
  return crypto.createHash('sha256').update(text).digest('hex').slice(0, 24);
};

const identityFromRequest = (req: Request): string => {
  const session = (req as any).session;
  const userId = session?.sub || session?.user?.id;
  if (userId) return `user:${userId}`;

  const body = (req.body || {}) as Record<string, unknown>;
  const loginHint =
    body.e ||
    body.email ||
    body.phone ||
    body.username ||
    body.userId ||
    body.customerId ||
    body.requestId;

  const deviceId = req.get('x-orbi-device-id') || req.get('x-orbi-fingerprint') || '';
  const appId = req.get('x-orbi-app-id') || 'unknown-app';
  return [
    `ip:${stableHash(requestIp(req))}`,
    `app:${stableHash(appId)}`,
    deviceId ? `device:${stableHash(deviceId)}` : '',
    loginHint ? `hint:${stableHash(loginHint)}` : '',
  ].filter(Boolean).join(':');
};

const getRecord = async (key: string): Promise<LimitRecord | null> => {
  try {
    const record = await RedisManager.get(key);
    if (record && typeof record === 'object') return record as LimitRecord;
  } catch {
    // Redis is optional for local/dev; fall through to process-local accounting.
  }
  return memoryStore.get(key) || null;
};

const setRecord = async (key: string, record: LimitRecord, ttlSeconds: number) => {
  try {
    await RedisManager.set(key, record, ttlSeconds);
    return;
  } catch {
    memoryStore.set(key, record);
  }
};

const logBreach = async (req: Request, rule: LimitRule, record: LimitRecord) => {
  const session = (req as any).session;
  const actorId = session?.sub || session?.user?.id || `anonymous:${stableHash(identityFromRequest(req))}`;
  const retryAfterSeconds = Math.max(1, Math.ceil((record.reset - Date.now()) / 1000));

  await Audit.log('SECURITY' as any, actorId, 'RATE_LIMIT_BREACH', {
    actor_name: 'ORBI Rate Limiter',
    rule: rule.name,
    route: normalizePath(req),
    method: req.method,
    count: record.count,
    limit: rule.limit,
    retryAfterSeconds,
    appId: req.get('x-orbi-app-id') || null,
    appOrigin: req.get('x-orbi-app-origin') || null,
    deviceIdHash: stableHash(req.get('x-orbi-device-id') || req.get('x-orbi-fingerprint') || ''),
    ipHash: stableHash(requestIp(req)),
    userAgentHash: stableHash(req.get('user-agent') || ''),
    traceId: req.get('x-orbi-trace') || null,
  }).catch(() => {});
};

export const createCriticalActionLimiter = (): RequestHandler => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const path = normalizePath(req);
    const method = req.method.toUpperCase();
    const rule = criticalRules.find((candidate) => {
      if (candidate.methods && !candidate.methods.includes(method)) return false;
      return candidate.match(path, req);
    });

    if (!rule) return next();

    const now = Date.now();
    const identity = identityFromRequest(req);
    const key = `orbi:critical-rate:${rule.name}:${identity}`;
    const ttlSeconds = Math.ceil(rule.windowMs / 1000);
    const current = await getRecord(key);
    const record: LimitRecord =
      !current || now > current.reset
        ? { count: 1, reset: now + rule.windowMs }
        : { ...current, count: current.count + 1 };

    await setRecord(key, record, Math.max(1, Math.ceil((record.reset - now) / 1000) || ttlSeconds));

    if (record.count > rule.limit) {
      const retryAfterSeconds = Math.max(1, Math.ceil((record.reset - now) / 1000));
      res.setHeader('Retry-After', String(retryAfterSeconds));
      await logBreach(req, rule, record);
      return res.status(429).json({
        success: false,
        error: 'RATE_LIMIT_EXCEEDED',
        code: 'CRITICAL_ACTION_RATE_LIMIT_EXCEEDED',
        rule: rule.name,
        retryAfterSeconds,
        message: 'Too many sensitive requests. Please wait before trying again.',
      });
    }

    next();
  };
};
