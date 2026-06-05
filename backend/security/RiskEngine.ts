
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { WAF } from './waf.js';
import { Sentinel } from './sentinel.js';
import { Audit } from './audit.js';
import { SecurityOperationsEngine } from './SecurityOperationsEngine.js';

export interface RiskSignal {
    type: string;
    score: number;
    detail: string;
}

/**
 * ORBI RISK SCORING ENGINE (V1.0)
 * ------------------------------
 * Calculates real-time risk scores based on multi-dimensional signals.
 */
export class RiskEngine {
    private static readonly THRESHOLDS = {
        ALLOW: 30,
        CHALLENGE: 60,
        TEMP_BLOCK: 80,
        HARD_BLOCK: 100
    };

    /**
     * Evaluates the risk of a request
     */
    public static async evaluateRequest(req: any, context: { userId?: string, ip: string, appId: string }): Promise<{
        score: number;
        action: 'ALLOW' | 'CHALLENGE' | 'BLOCK';
        signals: RiskSignal[];
    }> {
        const signals: RiskSignal[] = [];
        let totalScore = 0;

        // 1. Input Analysis (WAF Signals)
        try {
            await WAF.inspect(req.body, context.ip);
        } catch (e: any) {
            signals.push({ type: 'MALICIOUS_INPUT', score: 50, detail: e.message });
            totalScore += 50;
        }

        const operationProfile = SecurityOperationsEngine.classify(req);
        const velocity = await SecurityOperationsEngine.recordVelocity(req, operationProfile);

        // 2. Rate Behavior (Velocity Signals)
        if (velocity.score > 0) {
            signals.push({
                type: 'HIGH_VELOCITY',
                score: velocity.score,
                detail: `${velocity.count} ${operationProfile.class} requests in current window`,
            });
            totalScore += velocity.score;
        }

        // 3. Device Trust
        if (context && context.appId === 'anonymous-node') {
            signals.push({ type: 'UNKNOWN_DEVICE', score: 40, detail: 'Request from unregistered client' });
            totalScore += 40;
        }

        if (operationProfile.requiresIdempotency) {
            const idempotencyKey = req.get?.('Idempotency-Key') || req.get?.('x-idempotency-key') || req.headers?.['idempotency-key'] || req.headers?.['x-idempotency-key'];
            if (!idempotencyKey) {
                signals.push({ type: 'MISSING_IDEMPOTENCY_KEY', score: 65, detail: `${operationProfile.class} requires an idempotency key.` });
                totalScore += 65;
            }
        }

        // 4. Sentinel AI Insight
        const sentinelReport = await Sentinel.inspectOperation(null, 'risk_audit', req.body);
        const sentinelScore = operationProfile.class === 'CONFIG_COMMIT'
            ? (sentinelReport.riskScore >= 40 ? sentinelReport.riskScore : 0)
            : sentinelReport.riskScore;
        if (sentinelScore > 0) {
            signals.push({ type: 'AI_ANOMALY', score: sentinelScore, detail: sentinelReport.anomalies.join(', ') });
            totalScore += sentinelScore;
        }

        // Cap score at 100
        const finalScore = Math.min(totalScore, 100);
        
        let action: 'ALLOW' | 'CHALLENGE' | 'BLOCK' = 'ALLOW';
        if (finalScore >= this.THRESHOLDS.TEMP_BLOCK) action = 'BLOCK';
        else if (finalScore >= this.THRESHOLDS.CHALLENGE) action = 'CHALLENGE';

        if (action === 'CHALLENGE' && operationProfile.failClosed) {
            signals.push({ type: 'FAIL_CLOSED_OPERATION', score: 0, detail: `${operationProfile.class} cannot proceed on challenge state.` });
            action = 'BLOCK';
        }

        // Log Risk Event
        await this.logRiskEvent(context.userId || 'anonymous', context.ip, finalScore, signals, action);
        if (action === 'BLOCK') {
            await SecurityOperationsEngine.alertSecurityBlock(req, operationProfile, {
                reason: 'RISK_SCORE_BLOCK',
                score: finalScore,
                signals,
            }).catch(() => {});
        }

        return { score: finalScore, action, signals };
    }

    private static async logRiskEvent(userId: string, ip: string, score: number, signals: RiskSignal[], action: string) {
        if (score > 10) {
            console.warn(`[RiskEngine] High Risk Detected: ${score} for ${userId}. Action: ${action}`);
            await Audit.log('SECURITY', userId, 'RISK_EVENT', { ip, score, signals, action });
        }
    }
}
