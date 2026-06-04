import crypto from 'crypto';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { getAdminSupabase } from '../supabaseClient.js';
import { RedisClusterFactory } from '../infrastructure/RedisClusterFactory.js';
import { operatorAlertService } from '../infrastructure/OperatorAlertService.js';
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { Audit } from './audit.js';
import { SecurityOperationsEngine, type SecurityOperationClass } from './SecurityOperationsEngine.js';
import { buildScoringInput, createSecurityScoringAdapter, type SecurityScoringAdapter } from './SecurityScoringAdapter.js';

type GatewayRouteGroup = 'auth' | 'financial' | 'admin' | 'provider_webhook' | 'monitor_internal' | 'general';
type GatewayDecisionAction = 'ALLOW' | 'THROTTLE' | 'LOCK' | 'QUARANTINE';

type GatewayPolicy = {
  group: GatewayRouteGroup;
  class: SecurityOperationClass | 'PROVIDER_WEBHOOK' | 'MONITOR_INTERNAL';
  baseLimit: number;
  lockLimit: number;
  quarantineLimit: number;
  windowMs: number;
  lockTtlSeconds: number;
  quarantineTtlSeconds: number;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  sensitive: boolean;
};

type GatewayRecord = {
  count: number;
  reset: number;
};

const minute = 60 * 1000;

const boolEnv = (key: string, fallback: boolean) => {
  const value = process.env[key];
  if (value === undefined) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
};

const stableHash = (value: unknown) => {
  const text = String(value || '').trim().toLowerCase();
  if (!text) return '';
  return crypto.createHash('sha256').update(text).digest('hex').slice(0, 24);
};

const requestIp = (req: Request) => {
  const forwardedFor = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwardedFor || req.ip || req.socket.remoteAddress || 'unknown-ip';
};

const normalizePath = (req: Request) => {
  const baseUrl = String(req.baseUrl || '');
  const routePath = String(req.path || req.url || '/').split('?')[0] || '/';
  const full = `${baseUrl}${routePath}`.replace(/^\/(?:api\/v1|v1)/, '').replace(/\/+/g, '/');
  return full.startsWith('/') ? full : `/${full}`;
};

const isRead = (method: string) => ['GET', 'HEAD', 'OPTIONS'].includes(method);

const authMatcher = (route: string) =>
  /^\/auth\/(?:login|pin-login|signup|bootstrap-admin|otp\/initiate|verify|password\/reset\/(?:initiate|complete)|account\/confirmation\/(?:initiate|complete)|passkey\/login\/(?:start|finish)|biometric\/login\/(?:start|finish))$/.test(route);

const financialMatcher = (route: string) =>
  route === '/transactions/preview' ||
  route === '/transactions/settle' ||
  route === '/transactions/secure-sign' ||
  route === '/external-funds/preview' ||
  route === '/external-funds/deposit-intents' ||
  route === '/external-funds/settle' ||
  route.startsWith('/escrow') ||
  /\/wallets\/[^/]+\/(?:lock|unlock)$/.test(route) ||
  route.endsWith('/spend/preview') ||
  /\/settle$/.test(route) ||
  /\/payments\/.*\/preview$/.test(route) ||
  /^\/admin\/platform-operational-accounts(?:\/[^/]+)?(?:\/(?:fund|payout|refund))?$/.test(route);

const adminMatcher = (route: string) =>
  route.startsWith('/admin/') ||
  route.startsWith('/config/') ||
  route.startsWith('/kms/');

const providerWebhookMatcher = (route: string) => /^\/webhooks\/gateway\/[^/]+$/.test(route);

const monitorMatcher = (route: string) =>
  route.startsWith('/operational-metrics') ||
  route.startsWith('/admin/monitor') ||
  route.startsWith('/monitor');

const buildPolicy = (route: string, method: string): GatewayPolicy => {
  const operationProfile = SecurityOperationsEngine.classify({ path: route, baseUrl: '', url: route, method } as Request);

  if (authMatcher(route)) {
    return {
      group: 'auth',
      class: 'AUTH',
      baseLimit: 10,
      lockLimit: 16,
      quarantineLimit: 28,
      windowMs: 10 * minute,
      lockTtlSeconds: 15 * 60,
      quarantineTtlSeconds: 60 * 60,
      severity: 'HIGH',
      sensitive: true,
    };
  }

  if (providerWebhookMatcher(route)) {
    return {
      group: 'provider_webhook',
      class: 'PROVIDER_WEBHOOK',
      baseLimit: 180,
      lockLimit: 260,
      quarantineLimit: 400,
      windowMs: minute,
      lockTtlSeconds: 5 * 60,
      quarantineTtlSeconds: 20 * 60,
      severity: 'HIGH',
      sensitive: true,
    };
  }

  if (financialMatcher(route)) {
    return {
      group: 'financial',
      class: operationProfile.class === 'GENERAL_MUTATION' ? 'FINANCIAL_COMMIT' : operationProfile.class,
      baseLimit: isRead(method) ? 90 : 20,
      lockLimit: isRead(method) ? 140 : 35,
      quarantineLimit: isRead(method) ? 220 : 60,
      windowMs: 5 * minute,
      lockTtlSeconds: 10 * 60,
      quarantineTtlSeconds: 45 * 60,
      severity: 'CRITICAL',
      sensitive: true,
    };
  }

  if (adminMatcher(route)) {
    return {
      group: 'admin',
      class: operationProfile.class === 'GENERAL_MUTATION' ? 'ADMIN_SENSITIVE' : operationProfile.class,
      baseLimit: isRead(method) ? 140 : 35,
      lockLimit: isRead(method) ? 220 : 55,
      quarantineLimit: isRead(method) ? 360 : 90,
      windowMs: 10 * minute,
      lockTtlSeconds: 20 * 60,
      quarantineTtlSeconds: 60 * 60,
      severity: 'CRITICAL',
      sensitive: true,
    };
  }

  if (monitorMatcher(route)) {
    return {
      group: 'monitor_internal',
      class: 'MONITOR_INTERNAL',
      baseLimit: 120,
      lockLimit: 180,
      quarantineLimit: 300,
      windowMs: minute,
      lockTtlSeconds: 5 * 60,
      quarantineTtlSeconds: 20 * 60,
      severity: 'HIGH',
      sensitive: true,
    };
  }

  return {
    group: 'general',
    class: operationProfile.class,
    baseLimit: isRead(method) ? 600 : 120,
    lockLimit: isRead(method) ? 900 : 180,
    quarantineLimit: isRead(method) ? 1400 : 280,
    windowMs: minute,
    lockTtlSeconds: 5 * 60,
    quarantineTtlSeconds: 15 * 60,
    severity: 'MEDIUM',
    sensitive: false,
  };
};

export class ApiGatewaySecurityService {
  constructor(private readonly scoringAdapter: SecurityScoringAdapter = createSecurityScoringAdapter()) {}

  middleware(): RequestHandler {
    return async (req: Request, res: Response, next: NextFunction) => {
      if (!this.enabled()) return next();
      if (this.isBypassed(req)) return next();

      const method = String(req.method || 'GET').toUpperCase();
      const route = normalizePath(req);
      const policy = buildPolicy(route, method);

      try {
        if (this.redisRequiredButUnavailable()) {
          return res.status(503).json({
            success: false,
            error: 'API_GATEWAY_REDIS_REQUIRED',
            message: 'ORBI API Gateway requires Redis-backed security state in production.',
          });
        }

        const identity = SecurityOperationsEngine.identity(req);
        const lockKey = this.lockKey(policy, identity.actorId, identity.ipHash, identity.deviceHash);
        const quarantineKey = this.quarantineKey(policy, identity.actorId, identity.ipHash, identity.deviceHash);
        const activeQuarantine = await RedisManager.get(quarantineKey);
        if (activeQuarantine) {
          await this.recordDecision(req, policy, 'QUARANTINE', activeQuarantine, 100);
          return this.reject(res, 403, 'API_GATEWAY_QUARANTINED', 'Request source is temporarily quarantined by ORBI API Gateway.', activeQuarantine);
        }

        const activeLock = await RedisManager.get(lockKey);
        if (activeLock) {
          await this.recordDecision(req, policy, 'LOCK', activeLock, 80);
          return this.reject(res, 423, 'API_GATEWAY_ATTEMPT_LOCKED', 'Request source is temporarily locked after repeated risky attempts.', activeLock);
        }

        const velocity = await this.recordVelocity(policy, identity.actorId, identity.ipHash, identity.deviceHash);
        const scoring = await this.scoringAdapter.score(buildScoringInput(req, {
          route,
          routeClass: policy.class,
          velocityScore: this.velocityScore(policy, velocity.count),
          velocityCount: velocity.count,
        }));

        if (scoring.score > 0 || scoring.signals.length > 0) {
          await this.recordAudit(req, 'API_GATEWAY_AI_SCORE_APPLIED', policy, {
            score: scoring.score,
            action: scoring.action,
            confidence: scoring.confidence,
            modelVersion: scoring.modelVersion,
            signals: scoring.signals,
          });
        }

        if (velocity.count > policy.quarantineLimit || scoring.score >= 95) {
          const reason = {
            reason: 'API_GATEWAY_QUARANTINE',
            route,
            routeGroup: policy.group,
            count: velocity.count,
            score: scoring.score,
            expiresAt: new Date(Date.now() + policy.quarantineTtlSeconds * 1000).toISOString(),
          };
          await RedisManager.set(quarantineKey, reason, policy.quarantineTtlSeconds);
          await this.persistQuarantine(req, policy, quarantineKey, reason);
          await this.createAlert(req, policy, 'API_GATEWAY_QUARANTINED', reason);
          await this.recordDecision(req, policy, 'QUARANTINE', reason, scoring.score);
          return this.reject(res, 403, 'API_GATEWAY_QUARANTINED', 'Request source is temporarily quarantined by ORBI API Gateway.', reason);
        }

        if (velocity.count > policy.lockLimit || (policy.sensitive && scoring.action === 'BLOCK')) {
          const reason = {
            reason: 'API_GATEWAY_ATTEMPT_LOCK',
            route,
            routeGroup: policy.group,
            count: velocity.count,
            score: scoring.score,
            expiresAt: new Date(Date.now() + policy.lockTtlSeconds * 1000).toISOString(),
          };
          await RedisManager.set(lockKey, reason, policy.lockTtlSeconds);
          await this.createAlert(req, policy, 'API_GATEWAY_ATTEMPT_LOCKED', reason);
          await this.recordDecision(req, policy, 'LOCK', reason, scoring.score);
          return this.reject(res, 423, 'API_GATEWAY_ATTEMPT_LOCKED', 'Request source is temporarily locked after repeated risky attempts.', reason);
        }

        if (velocity.count > policy.baseLimit || scoring.action === 'CHALLENGE') {
          const retryAfterSeconds = Math.max(1, Math.ceil((velocity.reset - Date.now()) / 1000));
          res.setHeader('Retry-After', String(retryAfterSeconds));
          const reason = {
            reason: 'API_GATEWAY_THROTTLE',
            route,
            routeGroup: policy.group,
            count: velocity.count,
            score: scoring.score,
            retryAfterSeconds,
          };
          await this.recordDecision(req, policy, 'THROTTLE', reason, scoring.score);
          return this.reject(res, 429, 'API_GATEWAY_THROTTLED', 'Too many requests through ORBI API Gateway. Please retry later.', reason);
        }

        if (policy.sensitive) {
          await this.recordDecision(req, policy, 'ALLOW', { count: velocity.count, score: scoring.score }, scoring.score);
        }

        next();
      } catch (error: any) {
        if (boolEnv('ORBI_API_GATEWAY_FAIL_CLOSED', process.env.NODE_ENV === 'production')) {
          await this.recordAudit(req, 'API_GATEWAY_QUARANTINED', policy, {
            reason: 'API_GATEWAY_FAULT_FAIL_CLOSED',
            message: error?.message || String(error),
          }).catch(() => {});
          return res.status(503).json({
            success: false,
            error: 'API_GATEWAY_UNAVAILABLE',
            message: 'ORBI API Gateway security check failed closed.',
          });
        }
        next();
      }
    };
  }

  classifyForTest(route: string, method = 'GET') {
    return buildPolicy(route, method.toUpperCase());
  }

  private enabled() {
    return boolEnv('ORBI_API_GATEWAY_ENABLED', true);
  }

  private isBypassed(req: Request) {
    const route = normalizePath(req);
    return route === '/health' || route === '/ready' || route === '/health/deep' || req.method.toUpperCase() === 'OPTIONS';
  }

  private redisRequiredButUnavailable() {
    return process.env.NODE_ENV === 'production' &&
      boolEnv('ORBI_API_GATEWAY_REDIS_REQUIRED', true) &&
      !RedisClusterFactory.isAvailable();
  }

  private velocityKey(policy: GatewayPolicy, actorId: string, ipHash: string, deviceHash: string) {
    return `orbi:api-gateway:velocity:${policy.group}:${stableHash(actorId)}:${ipHash}:${deviceHash || 'no-device'}`;
  }

  private lockKey(policy: GatewayPolicy, actorId: string, ipHash: string, deviceHash: string) {
    return `orbi:api-gateway:lock:${policy.group}:${stableHash(actorId)}:${ipHash}:${deviceHash || 'no-device'}`;
  }

  private quarantineKey(policy: GatewayPolicy, actorId: string, ipHash: string, deviceHash: string) {
    return `orbi:api-gateway:quarantine:${policy.group}:${stableHash(actorId)}:${ipHash}:${deviceHash || 'no-device'}`;
  }

  private async recordVelocity(policy: GatewayPolicy, actorId: string, ipHash: string, deviceHash: string) {
    const now = Date.now();
    const key = this.velocityKey(policy, actorId, ipHash, deviceHash);
    const current = await RedisManager.get(key).catch(() => null) as GatewayRecord | null;
    const record: GatewayRecord = !current || now > current.reset
      ? { count: 1, reset: now + policy.windowMs }
      : { count: Number(current.count || 0) + 1, reset: Number(current.reset || now + policy.windowMs) };
    await RedisManager.set(key, record, Math.max(1, Math.ceil((record.reset - now) / 1000))).catch(() => {});
    return record;
  }

  private velocityScore(policy: GatewayPolicy, count: number) {
    if (count <= policy.baseLimit) return 0;
    const overage = count - policy.baseLimit;
    const multiplier = policy.severity === 'CRITICAL' ? 4 : policy.severity === 'HIGH' ? 3 : 2;
    return Math.min(80, Math.ceil(overage * multiplier));
  }

  private async recordDecision(req: Request, policy: GatewayPolicy, action: GatewayDecisionAction, details: Record<string, any>, score: number) {
    const event = action === 'ALLOW' ? 'API_GATEWAY_ALLOWED'
      : action === 'THROTTLE' ? 'API_GATEWAY_THROTTLED'
        : action === 'LOCK' ? 'API_GATEWAY_ATTEMPT_LOCKED'
          : 'API_GATEWAY_QUARANTINED';
    await this.recordAudit(req, event, policy, { ...details, score });
    if (action !== 'ALLOW') {
      await this.persistEvent(req, policy, event, details, score);
    }
  }

  private async recordAudit(req: Request, action: string, policy: GatewayPolicy, metadata: Record<string, any>) {
    const identity = SecurityOperationsEngine.identity(req);
    await Audit.log('SECURITY', identity.actorId, action, {
      actor_name: 'ORBI API Gateway',
      route: normalizePath(req),
      method: req.method,
      routeGroup: policy.group,
      operationClass: policy.class,
      severity: policy.severity,
      ipHash: identity.ipHash,
      deviceHash: identity.deviceHash || null,
      appId: identity.appId,
      traceId: req.get('x-orbi-trace') || null,
      ...metadata,
    }).catch(() => {});
  }

  private async persistEvent(req: Request, policy: GatewayPolicy, action: string, details: Record<string, any>, score: number) {
    const sb = getAdminSupabase();
    if (!sb) return;
    const identity = SecurityOperationsEngine.identity(req);
    try {
      await sb.from('api_gateway_security_events').insert({
        actor_id: identity.actorId.startsWith('anonymous:') ? null : identity.actorId,
        actor_ref: identity.actorId,
        route: normalizePath(req),
        method: req.method,
        route_group: policy.group,
        operation_class: policy.class,
        action,
        risk_score: score,
        ip_hash: identity.ipHash,
        device_hash: identity.deviceHash || null,
        app_id: identity.appId,
        trace_id: req.get('x-orbi-trace') || null,
        metadata: details,
      });
    } catch {
      // Security decisions still stand even if durable event persistence is temporarily unavailable.
    }
  }

  private async persistQuarantine(req: Request, policy: GatewayPolicy, quarantineKey: string, details: Record<string, any>) {
    const sb = getAdminSupabase();
    if (!sb) return;
    const identity = SecurityOperationsEngine.identity(req);
    try {
      await sb.from('api_gateway_quarantines').insert({
        actor_id: identity.actorId.startsWith('anonymous:') ? null : identity.actorId,
        actor_ref: identity.actorId,
        route_group: policy.group,
        scope_key: quarantineKey,
        reason: details.reason || 'API_GATEWAY_QUARANTINE',
        status: 'active',
        expires_at: details.expiresAt,
        metadata: details,
      });
    } catch {
      // Redis quarantine remains authoritative during transient database write failures.
    }
  }

  private async createAlert(req: Request, policy: GatewayPolicy, eventCode: string, details: Record<string, any>) {
    const identity = SecurityOperationsEngine.identity(req);
    await operatorAlertService.create({
      title: eventCode === 'API_GATEWAY_QUARANTINED' ? 'API Gateway quarantine active' : 'API Gateway attempt lock active',
      body: `${policy.group} traffic was restricted on ${req.method} ${normalizePath(req)}. Reason: ${details.reason}.`,
      severity: eventCode === 'API_GATEWAY_QUARANTINED' ? 'CRITICAL' : 'HIGH',
      eventCode,
      actorId: identity.actorId,
      resourceType: 'api_gateway_security',
      resourceId: normalizePath(req),
      metadata: details,
      actions: [
        { id: 'open-risk', label: 'Open risk dashboard', type: 'navigate', target: 'risk' },
        { id: 'open-audit', label: 'Review audit trail', type: 'navigate', target: 'logs' },
      ],
    }).catch(() => {});
  }

  private reject(res: Response, status: number, code: string, message: string, details: Record<string, any>) {
    return res.status(status).json({
      success: false,
      error: code,
      code,
      message,
      details,
    });
  }
}

export const apiGatewaySecurityService = new ApiGatewaySecurityService();
