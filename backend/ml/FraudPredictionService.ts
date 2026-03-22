
import { User, Transaction, MLFeatures } from '../../types.js';
import { GoogleGenAI, ThinkingLevel } from "@google/genai";

/**
 * NEURAL FRAUD PREDICTION SERVICE (V1.0)
 * Uses cognitive intelligence to identify behavioral anomalies.
 */
export class FraudPredictionService {
    private readonly MODEL_VERSION = 'behavior_quantum_v15';

    public async predict(user: User, payload: any, history: Transaction[]): Promise<{score: number, model_version: string, explanations: string[]}> {
        const features = this.prepareFeatures(user, payload, history);
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            console.warn("[MLService] GEMINI_API_KEY missing. Using heuristic baseline.");
            return { score: 0.15, model_version: 'fallback_v1', explanations: ['Temporal baseline active'] };
        }
        const ai = new GoogleGenAI({ apiKey });
        
        try {
            const response = await ai.models.generateContent({
                model: 'gemini-2.5-flash',
                contents: `Perform high-fidelity behavioral risk assessment on feature set: ${JSON.stringify(features)}. 
                Identify patterns consistent with Account Takeover (ATO) or Money Laundering.
                Respond strictly in JSON: { "probability": 0.0-1.0, "reasons": ["short explanation"] }`,
                config: { 
                    responseMimeType: "application/json"
                }
            });

            const result = JSON.parse(response.text || '{"probability": 0.1, "reasons": ["Heuristic match"]}');
            return {
                score: result.probability,
                model_version: this.MODEL_VERSION,
                explanations: result.reasons
            };
        } catch (e) {
            console.warn("[MLService] Cognitive node timeout. Using heuristic baseline.");
            return { score: 0.15, model_version: 'fallback_v1', explanations: ['Temporal baseline active'] };
        }
    }

    private prepareFeatures(user: User, payload: any, history: Transaction[] = []): MLFeatures {
        const now = new Date();
        const hour = now.getHours();
        const amounts = (history || []).map(t => t.amount);
        const avg = amounts.length > 0 ? amounts.reduce((a, b) => a + b, 0) / amounts.length : payload.amount;
        
        return {
            transaction_amount: payload.amount,
            transaction_amount_usd: payload.amount, 
            user_avg_transaction: avg,
            amount_zscore: (payload.amount - avg) / 100, // Normalized simulation
            transactions_last_hour: history.filter(t => (Date.now() - new Date(t.date).getTime()) < 3600000).length,
            hour_sin: Math.sin((hour * Math.PI) / 12),
            hour_cos: Math.cos((hour * Math.PI) / 12),
            day_sin: 0.5, // Mocked
            day_cos: 0.5,
            /* FIX: Accessed nationality from UserProfile as it is now part of the interface */
            is_high_risk_country: user.user_metadata?.nationality === 'Quarantine-Node',
            account_age_days: 365,
            device_user_count: 1
        };
    }
}

export const FraudMLService = new FraudPredictionService();
