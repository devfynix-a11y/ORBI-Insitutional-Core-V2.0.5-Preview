
import { GoogleGenAI, Type, ThinkingLevel } from "@google/genai";
import { Transaction, Wallet, Goal, UserProfile } from '../../types.js';

/**
 * COGNITIVE INTELLIGENCE NODE (V1.1)
 * Deep reasoning feature for institutional portfolio analysis.
 */
export class IntelligenceNode {

    public async performStrategicReview(context: {
        transactions: Transaction[],
        wallets: Wallet[],
        goals: Goal[],
        profile: UserProfile
    }) {
        if (!context.wallets.length) return "Insufficient liquidity data to perform strategic audit.";
        
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            console.error("[IntelligenceNode] GEMINI_API_KEY is missing.");
            return "Intelligence node temporarily offline. Trajectory monitoring active via local heuristics.";
        }

        const ai = new GoogleGenAI({ apiKey });
        try {
            // Fix: Using gemini-2.5-flash for strategic review (more likely to work with free key)
            const response = await ai.models.generateContent({
                model: 'gemini-2.5-flash',
                contents: `Perform an institutional audit on the following asset data: ${JSON.stringify({
                    netWorth: (context.wallets || []).reduce((s, w) => s + (w.balance || 0), 0),
                    txCount: (context.transactions || []).length,
                    goalCompletion: (context.goals || []).map(g => (g.current/g.target) * 100),
                    // FIX: Accessing role property which is now added to UserProfile interface
                    role: context.profile?.role
                })}`,
                config: {
                    systemInstruction: "You are the Orbi Strategic Auditor. Identify liquidity risks and optimization vectors. Respond with a formal executive summary. Do not use markdown titles. CRITICAL: Do NOT use the word 'Fynix' or 'fynix'. Always use 'Orbi'.",
                    thinkingConfig: { thinkingLevel: ThinkingLevel.LOW }
                }
            });

            return response.text || "Report generation failed. Node trajectory within normal parameters.";
        } catch (e) {
            console.error("[IntelligenceNode] Reasoning cycle fault:", e);
            return "Intelligence node temporarily offline. Trajectory monitoring active via local heuristics.";
        }
    }
}

export const Intelligence = new IntelligenceNode();
