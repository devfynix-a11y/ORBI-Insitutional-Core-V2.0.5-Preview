
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { Audit } from '../security/audit.js';
import { CONFIG } from '../../services/config.js';
import { ConfigClient } from '../infrastructure/RulesConfigClient.js';
import { FXEngine } from './FXEngine.js';

export interface TransactionPolicy {
    id: string;
    name: string;
    type: 'TX_LIMIT' | 'DAILY_LIMIT' | 'VELOCITY' | 'WITHDRAWAL_LIMIT';
    limitValue: number;
    currency: string;
}

/**
 * ORBI TRANSACTION GUARD / POLICY ENGINE (V1.0)
 * -------------------------------------------
 * Enforces financial rules and limits before ledger execution.
 */
export class PolicyEngine {
    
    /**
     * Evaluates if a transaction complies with all active policies.
     * Normalizes all amounts to USD for global limit enforcement.
     */
    public static async evaluateTransaction(userId: string, amount: number, currency: string, type: string): Promise<{
        allowed: boolean;
        reason?: string;
    }> {
        // Fetch dynamic config from RulesConfigClient (with caching)
        const config = await ConfigClient.getRuleConfig();
        const limits = config.transaction_limits;

        // Normalize amount to USD for global policy enforcement
        const amountInUSD = await FXEngine.convertToUSD(amount, currency);

        // 1. Check Individual Transaction Limit (Enforced in USD)
        const txLimit = limits.max_per_transaction || CONFIG.LEDGER.TX_LIMIT;
        if (amountInUSD > txLimit) {
            return { allowed: false, reason: `TRANSACTION_LIMIT_EXCEEDED: Max ${txLimit} USD (Requested: ${amountInUSD.toFixed(2)} USD)` };
        }

        // 2. Check Daily Cumulative Limit (Enforced in USD)
        const dailyLimit = limits.max_daily_total || CONFIG.LEDGER.DAILY_LIMIT;
        const dailyKey = `policy:daily_total:${userId}:${new Date().toISOString().split('T')[0]}`;
        const currentDailyTotal = (await RedisManager.get(dailyKey)) || 0;
        
        if (currentDailyTotal + amountInUSD > dailyLimit) {
            return { allowed: false, reason: `DAILY_LIMIT_EXCEEDED: Max ${dailyLimit} USD per day` };
        }

        // 3. Check Velocity (Transactions per hour)
        const velocityKey = `policy:velocity:${userId}:${new Date().getHours()}`;
        const txCount = (await RedisManager.get(velocityKey)) || 0;
        const velocityLimit = limits.category_limits?.velocity_limit || CONFIG.LEDGER.VELOCITY_LIMIT;

        if (txCount > velocityLimit) {
            return { allowed: false, reason: 'VELOCITY_LIMIT_EXCEEDED: Too many transactions in a short period' };
        }

        // 4. Check Account Status (Freeze Check)
        const isFrozen = await RedisManager.get(`account:status:${userId}:frozen`);
        if (isFrozen) {
            return { allowed: false, reason: 'ACCOUNT_FROZEN: Security hold active' };
        }

        return { allowed: true };
    }

    /**
     * Updates metrics after a successful transaction.
     * Normalizes amount to USD before committing to metrics.
     */
    public static async commitMetrics(userId: string, amount: number, currency: string) {
        const amountInUSD = await FXEngine.convertToUSD(amount, currency);
        const today = new Date().toISOString().split('T')[0];
        const hour = new Date().getHours();

        const dailyKey = `policy:daily_total:${userId}:${today}`;
        const velocityKey = `policy:velocity:${userId}:${hour}`;

        const currentDaily = (await RedisManager.get(dailyKey)) || 0;
        const currentVelocity = (await RedisManager.get(velocityKey)) || 0;

        await RedisManager.set(dailyKey, currentDaily + amountInUSD, CONFIG.LEDGER.DAILY_TTL); // 24h TTL
        await RedisManager.set(velocityKey, currentVelocity + 1, CONFIG.LEDGER.VELOCITY_TTL); // 1h TTL
    }

    /**
     * Freezes an account due to policy violation
     */
    public static async freezeAccount(userId: string, reason: string) {
        const config = await ConfigClient.getRuleConfig();
        const freezeDuration = config.transaction_limits?.category_limits?.freeze_duration || CONFIG.LEDGER.FREEZE_DURATION;
        
        await RedisManager.set(`account:status:${userId}:frozen`, true, freezeDuration); // Dynamic freeze
        await Audit.log('SECURITY', userId, 'ACCOUNT_AUTO_FREEZE', { reason });
        console.error(`[PolicyEngine] Account ${userId} frozen: ${reason}`);
    }
}
