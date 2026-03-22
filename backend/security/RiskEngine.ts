
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { WAF } from './waf.js';
import { Sentinel } from './sentinel.js';
import { Audit } from './audit.js';

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

        // 2. Rate Behavior (Velocity Signals)
        const rateKey = `risk:rate:${context.ip}`;
        const rateCount = await RedisManager.get(rateKey) || 0;
        if (rateCount > 50) {
            signals.push({ type: 'HIGH_VELOCITY', score: 30, detail: `${rateCount} requests in window` });
            totalScore += 30;
        }

        // 3. Device Trust
        if (context && context.appId === 'anonymous-node') {
            signals.push({ type: 'UNKNOWN_DEVICE', score: 40, detail: 'Request from unregistered client' });
            totalScore += 40;
        }

        // 4. Sentinel AI Insight
        const sentinelReport = await Sentinel.inspectOperation(null, 'risk_audit', req.body);
        if (sentinelReport.riskScore > 0) {
            signals.push({ type: 'AI_ANOMALY', score: sentinelReport.riskScore, detail: sentinelReport.anomalies.join(', ') });
            totalScore += sentinelReport.riskScore;
        }

        // Cap score at 100
        const finalScore = Math.min(totalScore, 100);
        
        let action: 'ALLOW' | 'CHALLENGE' | 'BLOCK' = 'ALLOW';
        if (finalScore >= this.THRESHOLDS.TEMP_BLOCK) action = 'BLOCK';
        else if (finalScore >= this.THRESHOLDS.CHALLENGE) action = 'CHALLENGE';

        // Log Risk Event
        await this.logRiskEvent(context.userId || 'anonymous', context.ip, finalScore, signals, action);

        return { score: finalScore, action, signals };
    }

    private static async logRiskEvent(userId: string, ip: string, score: number, signals: RiskSignal[], action: string) {
        if (score > 10) {
            console.warn(`[RiskEngine] High Risk Detected: ${score} for ${userId}. Action: ${action}`);
            await Audit.log('SECURITY', userId, 'RISK_EVENT', { ip, score, signals, action });
        }
    }
}
