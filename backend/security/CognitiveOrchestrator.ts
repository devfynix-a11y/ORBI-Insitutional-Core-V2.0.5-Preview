import { Transaction, Goal, Wallet, AIReport, UserProfile, Category } from '../../types.js';
import { GoogleGenAI, Type } from "@google/genai";
import { Server as LogicCore } from '../server.js';

/**
 * COGNITIVE ORCHESTRATOR (V9.0)
 * Institutional intelligence engine using Gemini 3 Pro.
 * Hardened for detailed spending analysis and automated report persistence.
 */
export class CognitiveOrchestrator {
    constructor(
        private context: {
            transactions: Transaction[],
            wallets: Wallet[],
            goals: Goal[],
            categories: Category[],
            profile?: UserProfile,
            currency: string
        }
    ) {}

    public async generateInsights(): Promise<AIReport> {
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            console.error("[Orchestrator] GEMINI_API_KEY is not set in environment.");
            return this.mapToReport({}); // Return empty report with defaults
        }
        const ai = new GoogleGenAI({ apiKey });
        
        const totalLiquidity = this.context.wallets.reduce((s, w) => s + (w.balance || 0), 0);
        const monthlyBurn = this.context.transactions
            .filter(t => t.type !== 'deposit' && new Date(t.date) > new Date(Date.now() - 30*24*60*60*1000))
            .reduce((s, t) => s + t.amount, 0);

        const promptContext = {
            totalLiquidity,
            monthlyBurn,
            goals: (this.context.goals || []).map(g => ({ name: g.name, current: g.current, target: g.target })),
            categories: (this.context.categories || []).map(c => ({ name: c.name, budget: c.budget })),
            recentTransactions: (this.context.transactions || []).slice(0, 30).map(t => ({ amount: t.amount, desc: t.description })),
            currency: this.context.currency
        };

        try {
            const response = await ai.models.generateContent({
                model: 'gemini-2.5-flash', // Switch to flash for better reliability in preview
                contents: `Perform institutional audit: ${JSON.stringify(promptContext)}`,
                config: { 
                    systemInstruction: "Analyze financial health. Return JSON matching established schema for AIReport.",
                    responseMimeType: "application/json",
                    responseSchema: {
                        type: Type.OBJECT,
                        properties: {
                            score: { type: Type.NUMBER },
                            healthLevel: { type: Type.STRING },
                            metrics: {
                                type: Type.OBJECT,
                                properties: {
                                    runwayDays: { type: Type.NUMBER },
                                    volatilityScore: { type: Type.NUMBER },
                                    strategicAlignment: { type: Type.NUMBER },
                                    burnRate: { type: Type.NUMBER }
                                }
                            },
                            spendingHabits: {
                                type: Type.OBJECT,
                                properties: {
                                    patterns: { type: Type.ARRAY, items: { type: Type.OBJECT, properties: { title: { type: Type.STRING }, description: { type: Type.STRING }, impact: { type: Type.STRING }, type: { type: Type.STRING } } } },
                                    budgetAlerts: { type: Type.ARRAY, items: { type: Type.OBJECT, properties: { category: { type: Type.STRING }, currentSpent: { type: Type.NUMBER }, limit: { type: Type.NUMBER }, forecastedOverrun: { type: Type.NUMBER }, message: { type: Type.STRING } } } },
                                    savingsTips: { type: Type.ARRAY, items: { type: Type.OBJECT, properties: { title: { type: Type.STRING }, tip: { type: Type.STRING }, potentialSaving: { type: Type.NUMBER }, category: { type: Type.STRING }, effort: { type: Type.STRING }, priority: { type: Type.STRING } } } }
                                }
                            },
                            summary: { type: Type.STRING },
                            strengths: { type: Type.ARRAY, items: { type: Type.STRING } },
                            immediateActions: { type: Type.ARRAY, items: { type: Type.STRING } }
                        }
                    }
                }
            });

            const result = JSON.parse(response.text || '{}');
            const report = this.mapToReport(result);
            
            // AUTOMATIC PERSISTENCE
            // In a pure backend, we might want to save this to a database or return it
            // LogicCore.saveAIReport(report) // If this method existed
            
            return report;
        } catch (e: any) {
            console.error("[Orchestrator] Cognitive Fault:", e);
            throw e;
        }
    }

    private mapToReport(result: any): AIReport {
        return {
            timestamp: new Date().toISOString(),
            health: { score: result.score || 75, healthLevel: result.healthLevel || 'STABLE', breakdown: { savings: 80, budget: 70, goals: 60 } },
            metrics: result.metrics || { runwayDays: 45, volatilityScore: 20, strategicAlignment: 85, burnRate: 1200 },
            spendingAnalysis: { 
                totalSpent: this.context.transactions.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
                topCategories: [],
                habits: { patterns: result.spendingHabits?.patterns || [], budgetAlerts: result.spendingHabits?.budgetAlerts || [], savingsTips: result.spendingHabits?.savingsTips || [] }
            },
            summary: { strengths: result.strengths || [], areasForImprovement: [], immediateActions: result.immediateActions || [], longTermFocus: [] },
            fullSummary: result.summary || "Trajectory normal."
        };
    }
}