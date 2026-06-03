import crypto from 'crypto';
import type { Request } from 'express';
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { operatorAlertService } from '../infrastructure/OperatorAlertService.js';
import { Audit } from './audit.js';

export type SecurityOperationClass =
    | 'SAFE_READ'
    | 'AUTH'
    | 'FINANCIAL_PREVIEW'
    | 'FINANCIAL_COMMIT'
    | 'WALLET_GOVERNANCE'
    | 'ACCOUNT_GOVERNANCE'
    | 'ADMIN_SENSITIVE'
    | 'CONFIG_COMMIT'
    | 'WEBHOOK'
    | 'MONITOR'
    | 'GENERAL_MUTATION';

export type SecurityOperationProfile = {
    route: string;
    method: string;
    class: SecurityOperationClass;
    failClosed: boolean;
    severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
    requiresReason: boolean;
    requiresIdempotency: boolean;
};

type VelocityRecord = {
    count: number;
    reset: number;
};

const minute = 60 * 1000;

const stableHash = (value: unknown): string => {
    const text = String(value || '').trim().toLowerCase();
    if (!text) return '';
    return crypto.createHash('sha256').update(text).digest('hex').slice(0, 24);
};

const normalizePath = (req: Request): string => {
    const baseUrl = String(req.baseUrl || '');
    const routePath = String(req.path || req.url || '/').split('?')[0] || '/';
    const full = `${baseUrl}${routePath}`
        .replace(/^\/(?:api\/v1|v1)/, '')
        .replace(/\/+/g, '/');
    return full.startsWith('/') ? full : `/${full}`;
};

const requestIp = (req: Request): string => {
    const headers = (req as any).headers || {};
    const forwardedFor = String(headers['x-forwarded-for'] || '').split(',')[0].trim();
    return forwardedFor || (req as any).ip || (req as any).socket?.remoteAddress || 'unknown-ip';
};

export class SecurityOperationsEngine {
    static classify(req: Request): SecurityOperationProfile {
        const route = normalizePath(req);
        const method = String((req as any).method || 'POST').toUpperCase();
        const isMutation = !['GET', 'HEAD', 'OPTIONS'].includes(method);
        const bodyMode = String((req.body as any)?.mode || '').trim().toLowerCase();

        if (!isMutation) {
            return { route, method, class: 'SAFE_READ', failClosed: false, severity: 'LOW', requiresReason: false, requiresIdempotency: false };
        }

        if (/^\/auth\/(?:login|signup|bootstrap-admin|otp\/initiate|verify|password\/reset\/(?:initiate|complete)|account\/confirmation\/(?:initiate|complete))$/.test(route)) {
            return { route, method, class: 'AUTH', failClosed: true, severity: 'HIGH', requiresReason: false, requiresIdempotency: false };
        }

        if (route === '/transactions/preview' || route === '/external-funds/preview' || route.endsWith('/spend/preview') || route.endsWith('/preview')) {
            return { route, method, class: 'FINANCIAL_PREVIEW', failClosed: true, severity: 'MEDIUM', requiresReason: false, requiresIdempotency: false };
        }

        if (
            route === '/transactions/settle' ||
            route === '/external-funds/deposit-intents' ||
            route === '/external-funds/settle' ||
            /\/settle$/.test(route) ||
            /\/gateway\/payment(?:\/[^/]+)?\/(?:initiate|settle|refund)$/.test(route)
        ) {
            return { route, method, class: 'FINANCIAL_COMMIT', failClosed: true, severity: 'CRITICAL', requiresReason: false, requiresIdempotency: true };
        }

        if (/\/wallets\/[^/]+\/(?:lock|unlock)$/.test(route)) {
            return { route, method, class: 'WALLET_GOVERNANCE', failClosed: true, severity: 'CRITICAL', requiresReason: true, requiresIdempotency: false };
        }

        if (/\/admin\/users\/[^/]+\/(?:status|profile)$/.test(route)) {
            return { route, method, class: 'ACCOUNT_GOVERNANCE', failClosed: true, severity: 'CRITICAL', requiresReason: true, requiresIdempotency: false };
        }

        if (
            route === '/admin/config/bootstrap' ||
            route === '/config/bootstrap' ||
            route === '/admin/kms/rewrap' ||
            route === '/kms/rewrap' ||
            (route.endsWith('/config/bootstrap') && bodyMode === 'commit') ||
            /^\/(?:admin\/)?config\/(?:ledger|commissions|fx-rates)$/.test(route)
        ) {
            return { route, method, class: 'CONFIG_COMMIT', failClosed: true, severity: 'CRITICAL', requiresReason: bodyMode === 'commit', requiresIdempotency: false };
        }

        if (route === '/admin/b2b/merchant-settlement-reports/generate') {
            return { route, method, class: 'ADMIN_SENSITIVE', failClosed: true, severity: 'HIGH', requiresReason: false, requiresIdempotency: false };
        }

        if (
            /^\/admin\/b2b\/(?:agent-float-controls|commission-disputes(?:\/[^/]+)?|organization-limits)$/.test(route)
        ) {
            return { route, method, class: 'ADMIN_SENSITIVE', failClosed: true, severity: 'CRITICAL', requiresReason: true, requiresIdempotency: false };
        }

        if (
            /^\/admin\/transactions\/.*\/(?:lock|audit|approve|reverse)$/.test(route) ||
            /^\/transactions\/.*\/(?:lock|audit|approve|reverse)$/.test(route) ||
            route === '/admin/transactions/approve-audited' ||
            /^\/admin\/(?:kyc\/review|documents\/.*\/verify|devices\/.*\/status|service-access\/requests\/.*\/review)$/.test(route) ||
            /^\/admin\/staff\/.*\/reset-password$/.test(route) ||
            /^\/admin\/platform-operational-accounts(?:\/[^/]+)?(?:\/(?:fund|payout|refund))?$/.test(route) ||
            route === '/admin/reconciliation/run'
        ) {
            return { route, method, class: 'ADMIN_SENSITIVE', failClosed: true, severity: 'CRITICAL', requiresReason: true, requiresIdempotency: false };
        }

        if (/^\/webhooks\/gateway\/[^/]+$/.test(route)) {
            return { route, method, class: 'WEBHOOK', failClosed: true, severity: 'HIGH', requiresReason: false, requiresIdempotency: false };
        }

        if (route.startsWith('/operational-metrics') || route.startsWith('/api/admin/monitor')) {
            return { route, method, class: 'MONITOR', failClosed: true, severity: 'HIGH', requiresReason: false, requiresIdempotency: false };
        }

        return { route, method, class: 'GENERAL_MUTATION', failClosed: false, severity: 'MEDIUM', requiresReason: false, requiresIdempotency: false };
    }

    static identity(req: Request) {
        const session = (req as any).session;
        const userId = session?.sub || session?.user?.id;
        const getHeader = typeof (req as any).get === 'function'
            ? (name: string) => (req as any).get(name)
            : (name: string) => ((req as any).headers || {})[name.toLowerCase()];
        const deviceId = getHeader('x-orbi-device-id') || getHeader('x-orbi-fingerprint') || '';
        const appId = getHeader('x-orbi-app-id') || 'unknown-app';
        return {
            actorId: userId || `anonymous:${stableHash(requestIp(req))}`,
            ipHash: stableHash(requestIp(req)),
            appHash: stableHash(appId),
            deviceHash: stableHash(deviceId),
            appId,
        };
    }

    static async recordVelocity(req: Request, profile: SecurityOperationProfile) {
        const identity = this.identity(req);
        const windowMs = profile.severity === 'CRITICAL' ? 5 * minute : minute;
        const now = Date.now();
        const key = `orbi:security-velocity:${profile.class}:${identity.actorId}:${identity.ipHash}:${identity.deviceHash || 'no-device'}`;
        const current = (await RedisManager.get(key).catch(() => null)) as VelocityRecord | null;
        const record: VelocityRecord = !current || now > current.reset
            ? { count: 1, reset: now + windowMs }
            : { ...current, count: Number(current.count || 0) + 1 };

        await RedisManager.set(key, record, Math.max(1, Math.ceil((record.reset - now) / 1000))).catch(() => {});
        return {
            count: record.count,
            resetAt: new Date(record.reset).toISOString(),
            score: this.velocityScore(profile, record.count),
        };
    }

    static velocityScore(profile: SecurityOperationProfile, count: number) {
        const baseline = profile.class === 'FINANCIAL_COMMIT' ? 4
            : profile.class === 'ACCOUNT_GOVERNANCE' || profile.class === 'WALLET_GOVERNANCE' ? 6
                : profile.class === 'AUTH' ? 8
                    : profile.severity === 'CRITICAL' ? 10
                        : 30;
        if (count <= baseline) return 0;
        return Math.min(35, Math.ceil((count - baseline) * (profile.severity === 'CRITICAL' ? 8 : 4)));
    }

    static hasRequiredReason(req: Request, profile: SecurityOperationProfile) {
        if (!profile.requiresReason) return true;
        const reason = String(
            (req.body as any)?.reason ||
            (req.body as any)?.status_reason ||
            (req.body as any)?.resolutionNote ||
            (req.body as any)?.notes ||
            '',
        ).trim();
        return reason.length >= 5;
    }

    static async alertSecurityBlock(req: Request, profile: SecurityOperationProfile, details: Record<string, any>) {
        const identity = this.identity(req);
        const getHeader = typeof (req as any).get === 'function'
            ? (name: string) => (req as any).get(name)
            : (name: string) => ((req as any).headers || {})[name.toLowerCase()];
        await Audit.log('SECURITY', identity.actorId, 'SECURITY_OPERATION_BLOCKED', {
            ...details,
            route: profile.route,
            method: profile.method,
            operationClass: profile.class,
            severity: profile.severity,
            appId: identity.appId,
            ipHash: identity.ipHash,
            deviceHash: identity.deviceHash || null,
            traceId: getHeader('x-orbi-trace') || null,
        }).catch(() => {});

        if (profile.severity === 'CRITICAL' || details.reason === 'RISK_ENGINE_FAULT') {
            await operatorAlertService.create({
                title: `Security operation blocked: ${profile.class}`,
                body: `ORBI blocked ${profile.method} ${profile.route}. Reason: ${details.reason || 'SECURITY_POLICY'}.`,
                severity: profile.severity === 'CRITICAL' ? 'CRITICAL' : 'HIGH',
                eventCode: 'SECURITY_OPERATION_BLOCKED',
                actorId: identity.actorId,
                resourceType: 'security_operation',
                resourceId: profile.route,
                metadata: details,
                actions: [
                    { id: 'open-risk', label: 'Open risk dashboard', type: 'navigate', target: 'risk' },
                    { id: 'open-audit', label: 'Review audit trail', type: 'navigate', target: 'logs' },
                ],
            }).catch(() => {});
        }
    }
}
