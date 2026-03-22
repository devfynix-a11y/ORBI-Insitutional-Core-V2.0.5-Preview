
import { Storage } from '../backend/storage.js';
import { Audit } from '../backend/security/audit.js';
import { UUID } from '../services/utils.js';

export interface PricingRule {
    id: string;
    method: string;
    feePercentage: number;
    fixedFee: number;
    fxMargin: number;
    status: 'ACTIVE' | 'BETA' | 'ALPHA' | 'DEPRECATED';
    tier: 'INSTITUTIONAL' | 'RETAIL';
    updatedAt: string;
}

class RevenueOrchestrator {
    private readonly STORAGE_KEY = 'dps_revenue_pricing_v1';

    private defaultRules: PricingRule[] = [
        { id: 'R-01', method: 'Mobile Money', feePercentage: 0.01, fixedFee: 0, fxMargin: 0.002, status: 'ACTIVE', tier: 'RETAIL', updatedAt: new Date().toISOString() },
        { id: 'R-02', method: 'RTGS Local', feePercentage: 0, fixedFee: 25.00, fxMargin: 0, status: 'ACTIVE', tier: 'INSTITUTIONAL', updatedAt: new Date().toISOString() },
        { id: 'R-03', method: 'Cross-Border', feePercentage: 0.025, fixedFee: 10.00, fxMargin: 0.008, status: 'BETA', tier: 'RETAIL', updatedAt: new Date().toISOString() }
    ];

    public getRules(): PricingRule[] {
        const stored = Storage.getItem(this.STORAGE_KEY);
        return stored ? JSON.parse(stored) : this.defaultRules;
    }

    public async rotateRule(id: string, updates: Partial<PricingRule>, actorId: string): Promise<void> {
        const rules = this.getRules();
        const idx = rules.findIndex(r => r.id === id);
        if (idx !== -1) {
            rules[idx] = { ...rules[idx], ...updates, updatedAt: new Date().toISOString() };
            Storage.setItem(this.STORAGE_KEY, JSON.stringify(rules));
            await Audit.log('ADMIN', actorId, 'PRICING_RULE_ROTATED', { ruleId: id, updates });
        }
    }

    public calculateFee(method: string, amount: number): { fee: number, fx: number } {
        const rules = this.getRules();
        const rule = rules.find(r => r.method.toLowerCase().includes(method.toLowerCase())) || rules[0];
        
        const fee = (amount * rule.feePercentage) + rule.fixedFee;
        const fx = amount * rule.fxMargin;
        
        return { fee, fx };
    }
}

export const RevenueService = new RevenueOrchestrator();
