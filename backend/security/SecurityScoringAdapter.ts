import type { Request } from 'express';
import { SecurityOperationsEngine, type SecurityOperationClass } from './SecurityOperationsEngine.js';

export type SecurityScoringAction = 'ALLOW' | 'CHALLENGE' | 'BLOCK';

export type SecurityScoringSignal = {
  type: string;
  score: number;
  detail: string;
};

export type SecurityScoringInput = {
  route: string;
  method: string;
  routeClass: SecurityOperationClass | 'PROVIDER_WEBHOOK' | 'MONITOR_INTERNAL';
  actorId: string;
  ipHash: string;
  deviceHash: string | null;
  appId: string;
  velocityScore: number;
  velocityCount: number;
  redactedPayloadFeatures: Record<string, unknown>;
};

export type SecurityScoringResult = {
  score: number;
  action: SecurityScoringAction;
  signals: SecurityScoringSignal[];
  modelVersion: string;
  confidence: number;
};

export interface SecurityScoringAdapter {
  score(input: SecurityScoringInput): Promise<SecurityScoringResult>;
}

const clampScore = (score: number) => Math.max(0, Math.min(100, Math.round(score)));

const safeFeatureValue = (value: unknown) => {
  if (value === null || value === undefined) return value;
  if (typeof value === 'number' || typeof value === 'boolean') return value;
  if (typeof value === 'string') return value.length > 96 ? `${value.slice(0, 96)}...` : value;
  if (Array.isArray(value)) return { type: 'array', count: value.length };
  if (typeof value === 'object') return { type: 'object', keys: Object.keys(value as Record<string, unknown>).slice(0, 20) };
  return String(value);
};

const SECRET_KEY_PATTERN = /(password|passcode|pin|otp|token|secret|authorization|card|cvv|pan|key|credential|biometric|attestation)/i;

export const buildRedactedPayloadFeatures = (req: Request): Record<string, unknown> => {
  const body = req.body && typeof req.body === 'object' ? req.body as Record<string, unknown> : {};
  const query = req.query && typeof req.query === 'object' ? req.query as Record<string, unknown> : {};
  const bodyKeys = Object.keys(body);
  const queryKeys = Object.keys(query);

  return {
    bodyKeyCount: bodyKeys.length,
    bodyKeys: bodyKeys.filter((key) => !SECRET_KEY_PATTERN.test(key)).slice(0, 40),
    sensitiveBodyKeyCount: bodyKeys.filter((key) => SECRET_KEY_PATTERN.test(key)).length,
    queryKeyCount: queryKeys.length,
    queryKeys: queryKeys.filter((key) => !SECRET_KEY_PATTERN.test(key)).slice(0, 40),
    selected: Object.fromEntries(
      Object.entries({ ...query, ...body })
        .filter(([key]) => !SECRET_KEY_PATTERN.test(key))
        .slice(0, 20)
        .map(([key, value]) => [key, safeFeatureValue(value)]),
    ),
  };
};

export class DeterministicSecurityScoringAdapter implements SecurityScoringAdapter {
  async score(input: SecurityScoringInput): Promise<SecurityScoringResult> {
    const signals: SecurityScoringSignal[] = [];
    let score = input.velocityScore;

    if (input.velocityScore > 0) {
      signals.push({
        type: 'VELOCITY',
        score: input.velocityScore,
        detail: `${input.velocityCount} requests in current gateway window`,
      });
    }

    if (!input.deviceHash && ['FINANCIAL_COMMIT', 'ADMIN_SENSITIVE', 'CONFIG_COMMIT'].includes(input.routeClass)) {
      signals.push({ type: 'MISSING_DEVICE_IDENTITY', score: 15, detail: 'Sensitive operation lacks device identity.' });
      score += 15;
    }

    if (input.routeClass === 'FINANCIAL_COMMIT') score += 10;
    if (input.routeClass === 'CONFIG_COMMIT') score += 15;

    const finalScore = clampScore(score);
    return {
      score: finalScore,
      action: finalScore >= 80 ? 'BLOCK' : finalScore >= 60 ? 'CHALLENGE' : 'ALLOW',
      signals,
      modelVersion: 'orbi-deterministic-gateway-v1',
      confidence: 0.72,
    };
  }
}

export class HttpSecurityScoringAdapter implements SecurityScoringAdapter {
  constructor(
    private readonly url: string,
    private readonly timeoutMs: number,
    private readonly fallback: SecurityScoringAdapter,
  ) {}

  async score(input: SecurityScoringInput): Promise<SecurityScoringResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await fetch(this.url.replace(/\/+$/, '') + '/v1/security/score', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(input),
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`AI_SCORER_${response.status}`);
      const payload = await response.json() as Partial<SecurityScoringResult>;
      return {
        score: clampScore(Number(payload.score || 0)),
        action: payload.action === 'BLOCK' || payload.action === 'CHALLENGE' ? payload.action : 'ALLOW',
        signals: Array.isArray(payload.signals) ? payload.signals as SecurityScoringSignal[] : [],
        modelVersion: String(payload.modelVersion || 'python-security-scorer'),
        confidence: Math.max(0, Math.min(1, Number(payload.confidence || 0.5))),
      };
    } catch {
      const fallbackResult = await this.fallback.score(input);
      return {
        ...fallbackResult,
        signals: [
          ...fallbackResult.signals,
          { type: 'AI_SCORER_FALLBACK', score: 0, detail: 'Python security scorer unavailable; deterministic adapter used.' },
        ],
      };
    } finally {
      clearTimeout(timer);
    }
  }
}

export const createSecurityScoringAdapter = (): SecurityScoringAdapter => {
  const deterministic = new DeterministicSecurityScoringAdapter();
  const mode = String(process.env.ORBI_API_GATEWAY_AI_MODE || 'adapter').trim().toLowerCase();
  const scorerUrl = String(process.env.ORBI_AI_SECURITY_SCORER_URL || '').trim();
  const timeoutMs = Math.max(100, Number(process.env.ORBI_AI_SECURITY_SCORER_TIMEOUT_MS || 750));
  if (mode === 'python' && scorerUrl) {
    return new HttpSecurityScoringAdapter(scorerUrl, timeoutMs, deterministic);
  }
  return deterministic;
};

export const buildScoringInput = (
  req: Request,
  params: {
    route: string;
    routeClass: SecurityScoringInput['routeClass'];
    velocityScore: number;
    velocityCount: number;
  },
): SecurityScoringInput => {
  const identity = SecurityOperationsEngine.identity(req);
  return {
    route: params.route,
    method: String(req.method || 'GET').toUpperCase(),
    routeClass: params.routeClass,
    actorId: identity.actorId,
    ipHash: identity.ipHash,
    deviceHash: identity.deviceHash || null,
    appId: identity.appId,
    velocityScore: params.velocityScore,
    velocityCount: params.velocityCount,
    redactedPayloadFeatures: buildRedactedPayloadFeatures(req),
  };
};
