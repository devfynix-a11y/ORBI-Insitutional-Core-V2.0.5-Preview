
import { User, Transaction } from '../../types.js';
import { getAdminSupabase } from '../../services/supabaseClient.js';
import { UUID } from '../../services/utils.js';

export interface FraudDecision {
    passed: boolean;
    riskScore: number;
    decision: 'PASS' | 'HOLD' | 'BLOCK';
    reason?: string;
    flags: string[];
}

/**
 * ORBI FRAUD SENTINEL (V6.0 Enterprise)
 * -------------------------------------
 * Real-time AML and Fraud screening engine with durable DB checks.
 */
export class FraudSentinelService {
    
    public async screen(user: User, payload: any, history: Transaction[]): Promise<FraudDecision> {
        const flags: string[] = [];
        let riskScore = 0;
        const sb = getAdminSupabase();

        // 1. Basic AML Thresholds (Normalized to USD ideally, but using raw amount for now)
        if (payload.amount > 10000) {
            riskScore += 30;
            flags.push('HIGH_VALUE_TX');
        }

        // 2. Velocity Checks (Database-backed)
        if (sb && user.id) {
            try {
                const oneHourAgo = new Date(Date.now() - 3600000).toISOString();
                const { data: recentTxs, error } = await sb
                    .from('transactions')
                    .select('id, amount')
                    .eq('user_id', user.id)
                    .gte('created_at', oneHourAgo);

                if (!error && recentTxs && recentTxs.length > 5) {
                    riskScore += 40;
                    flags.push('VELOCITY_BURST');
                }
            } catch (e) {
                console.error("[FraudSentinel] Velocity check failed:", e);
                // Fallback to provided history if DB fails
                const recentTxs = history.filter(t => (Date.now() - new Date(t.date).getTime()) < 3600000);
                if (recentTxs.length > 5) {
                    riskScore += 40;
                    flags.push('VELOCITY_BURST_FALLBACK');
                }
            }
        }

        // 3. New Beneficiary Check
        if (sb && user.id && payload.targetWalletId) {
            try {
                const { data: priorTxs, error } = await sb
                    .from('transactions')
                    .select('id')
                    .eq('user_id', user.id)
                    .eq('to_wallet_id', payload.targetWalletId)
                    .limit(1);

                if (!error && (!priorTxs || priorTxs.length === 0)) {
                    riskScore += 15;
                    flags.push('NEW_BENEFICIARY');
                }
            } catch (e) {
                console.error("[FraudSentinel] Beneficiary check failed:", e);
            }
        }

        // 4. Decision Logic
        let decision: 'PASS' | 'HOLD' | 'BLOCK' = 'PASS';
        if (riskScore >= 80) decision = 'BLOCK';
        else if (riskScore >= 40) decision = 'HOLD';

        const result: FraudDecision = {
            passed: decision !== 'BLOCK',
            riskScore,
            decision,
            reason: flags.length > 0 ? `Flagged: ${flags.join(', ')}` : undefined,
            flags
        };

        // 5. Persist Fraud Check Audit
        if (sb && user.id) {
            try {
                await sb.from('fraud_checks').insert({
                    id: UUID.generate(),
                    user_id: user.id,
                    payload: payload,
                    risk_score: riskScore,
                    decision: decision,
                    flags: flags,
                    created_at: new Date().toISOString()
                });
            } catch (e) {
                console.error("[FraudSentinel] Failed to persist fraud check:", e);
            }
        }

        return result;
    }
}

export const FraudSentinel = new FraudSentinelService();
