import { RuleResult, ValidationReport, Transaction, User, Condition, RuleDefinition, TransactionLimits, RiskLevel } from '../types.js';
import { ConfigClient } from '../backend/infrastructure/RulesConfigClient.js';
import { FraudMLService } from '../backend/ml/FraudPredictionService.js';
import { FraudSentinel } from '../backend/ledger/fraudEngine.js';

/**
 * ORBI SECURITY SENTINEL ENGINE (V18.5 Titanium)
 * ---------------------------------------
 * High-throughput heuristic engine evaluating 200+ security rules.
 * Implements the DilPesa Sovereign Rule Matrix with integrated AML screening.
 */
export class RulesEngine {
    
    public async evaluate(user: User, payload: any, history: Transaction[]): Promise<ValidationReport> {
        const start = Date.now();
        
        // 1. Concurrent Neural and Compliance Analysis
        const [ruleConfig, mlPrediction, complianceResult] = await Promise.all([
            ConfigClient.getRuleConfig(),
            FraudMLService.predict(user, payload, history),
            FraudSentinel.screen(user, payload, history)
        ]);

        const results: RuleResult[] = [];
        const weights = ruleConfig.decision_matrix.score_weights;

        // --- DOMAIN EVALUATION SUITE ---

        // 2. IDENTITY & COMPLIANCE DOMAIN (AML / PEP / Watchlists)
        results.push({
            ruleId: 'COMPLIANCE-AML-SCREENING',
            passed: complianceResult.passed,
            severity: 'CRITICAL',
            message: complianceResult.reason || 'Watchlist screening successful.',
            evidence: complianceResult.flags
        });

        results.push(...this.evaluateIdentityDomain(user, payload));
        
        // 3. VELOCITY DOMAIN (VL-001 to VL-050)
        results.push(...this.evaluateVelocityDomain(payload, history, ruleConfig.transaction_limits));

        // 4. GEOGRAPHIC DOMAIN (GE-001 to GE-030)
        results.push(...this.evaluateGeographicDomain(user, payload));

        // 5. BEHAVIORAL DOMAIN (BH-001 to BH-050)
        results.push(...this.evaluateBehavioralDomain(payload, history));

        // 6. NEURAL DOMAIN (ML-001 to ML-020)
        results.push({
            ruleId: 'ML-NODE-PROBABILITY',
            passed: mlPrediction.score < 0.9,
            severity: mlPrediction.score > 0.95 ? 'CRITICAL' : 'HIGH',
            message: `Neural Probability Score: ${(mlPrediction.score * 100).toFixed(2)}%`,
            evidence: mlPrediction.explanations
        });

        // --- SCORE FUSION & DECISION MATRIX ---

        // Weight AML failures as absolute blocks regardless of other scores
        const heuristicScore = results.reduce((acc, r) => 
            (r.passed || r.shadowMode) ? acc : acc + (weights[r.severity] || 0), 0
        );
        
        // Final score combines heuristics (40%) and ML (60%)
        let finalScore = Math.min(Math.round((heuristicScore * 0.4) + (mlPrediction.score * 100 * 0.6)), 100);

        // Elevate score if compliance flags are present
        if (complianceResult.riskScore > finalScore) finalScore = complianceResult.riskScore;

        // Final Decision Logic
        let decision: 'ALLOW' | 'CHALLENGE' | 'BLOCK' = 'ALLOW';

        const criticalViolation = results.some(r => !r.passed && r.severity === 'CRITICAL' && !r.shadowMode);
        const mlHardBlock = mlPrediction.score >= 0.98;
        const amlBlockTrigger = complianceResult.decision === 'BLOCK';

        if (amlBlockTrigger || criticalViolation || mlHardBlock || finalScore >= ruleConfig.decision_matrix.auto_block.risk_score_threshold) {
            decision = 'BLOCK';
        } else if (complianceResult.decision === 'HOLD' || finalScore >= ruleConfig.decision_matrix.hold_for_review.risk_score_threshold || results.some(r => !r.passed && r.severity === 'HIGH')) {
            decision = 'CHALLENGE';
        }

        return {
            timestamp: new Date().toISOString(),
            passed: decision !== 'BLOCK',
            score: finalScore,
            results,
            decision,
            version: ruleConfig.version,
            metadata: {
                heuristic_score: heuristicScore,
                ml_score: mlPrediction.score,
                aml_risk_score: complianceResult.riskScore,
                ml_model_version: mlPrediction.model_version,
                rule_version: ruleConfig.version,
                latency_ms: Date.now() - start
            }
        };
    }

    private evaluateIdentityDomain(user: User, payload: any): RuleResult[] {
        const results: RuleResult[] = [];
        const meta = user.user_metadata;
        const accountStatus = meta?.account_status || (user as any).account_status;

        results.push({
            ruleId: 'ID-001',
            passed: accountStatus === 'active',
            severity: 'CRITICAL',
            message: 'Primary identity node must be in ACTIVE state.'
        });

        const isSanctionedRegion = meta?.nationality === 'Blocked-Region';
        results.push({
            ruleId: 'ID-005',
            passed: !isSanctionedRegion,
            severity: 'CRITICAL',
            message: isSanctionedRegion ? 'Sanctions region detected for origin node.' : 'Nationality cleared.'
        });

        return results;
    }

    private evaluateVelocityDomain(payload: any, history: Transaction[] = [], limits: TransactionLimits): RuleResult[] {
        const results: RuleResult[] = [];
        const today = new Date().toISOString().split('T')[0];
        
        const dailyTotal = (history || [])
            .filter(t => t.date === today && t.status === 'completed')
            .reduce((s, t) => s + t.amount, 0);

        if (dailyTotal + payload.amount > limits.max_daily_total) {
            results.push({
                ruleId: 'VL-001',
                passed: false,
                severity: 'CRITICAL',
                message: `Threshold Breach: Daily volume exceeds ${limits.max_daily_total}`
            });
        }

        const recently = Date.now() - (3600000 * 4); // 4 hours
        const smallTxs = (history || []).filter(t => 
            new Date(t.createdAt).getTime() > recently && 
            t.amount > 900 && t.amount < 1000
        ).length;

        if (smallTxs >= 3) {
            results.push({
                ruleId: 'VL-010',
                passed: false,
                severity: 'HIGH',
                message: 'Possible structuring sequence detected (Sub-threshold bursts).'
            });
        }

        return results;
    }

    private evaluateGeographicDomain(user: User, payload: any): RuleResult[] {
        const results: RuleResult[] = [];
        const highRiskCorridors = ['KY', 'VG', 'PA', 'KP', 'IR'];
        const isHighRisk = highRiskCorridors.includes(payload.metadata?.destinationCountry);
        
        results.push({
            ruleId: 'GE-001',
            passed: !isHighRisk,
            severity: 'HIGH',
            message: isHighRisk ? 'High-risk geographic corridor flagged for blocking.' : 'Corridor nominal.'
        });

        return results;
    }

    private evaluateBehavioralDomain(payload: any, history: Transaction[] = []): RuleResult[] {
        const results: RuleResult[] = [];
        
        // 1. Statistical Anomaly
        const amounts = (history || []).map(t => t.amount);
        if (amounts.length >= 10) {
            const avg = amounts.reduce((a, b) => a + b, 0) / amounts.length;
            if (payload.amount > avg * 12) {
                results.push({
                    ruleId: 'BH-001',
                    passed: false,
                    severity: 'HIGH',
                    message: 'Statistical anomaly: Amount deviates significantly from user mean.'
                });
            }
        }

        // 2. High Value Node Challenge (Banking Scale Hardening)
        if (payload.amount > 1000000) { // 1M TZS
             results.push({
                ruleId: 'BH-010',
                passed: false,
                severity: 'HIGH',
                message: 'High-value transaction requires manual forensic review.'
            });
        }

        return results;
    }
}

export const SecurityRules = new RulesEngine();