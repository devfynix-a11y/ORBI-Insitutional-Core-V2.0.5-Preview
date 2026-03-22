import { getSupabase } from '../../supabaseClient.js';

/**
 * Enterprise Vault Registry
 * Dynamically resolves system wallets to eliminate hardcoded IDs.
 */
export class VaultRegistry {
    private static cache = new Map<string, string>();
    private static cacheExpiry = 0;

    /**
     * Retrieves the Wallet ID for a specific system vault purpose.
     */
    public static async getVaultId(purpose: 'OPERATING' | 'TAX' | 'REVENUE' | 'SETTLEMENT'): Promise<string> {
        // 1. Check Cache (Valid for 5 minutes)
        if (Date.now() < this.cacheExpiry && this.cache.has(purpose)) {
            return this.cache.get(purpose)!;
        }

        // 2. Fetch from Database
        const sb = getSupabase();
        if (!sb) throw new Error("DB_OFFLINE");

        const { data, error } = await sb.from('ent_system_vaults')
            .select('wallet_id')
            .eq('vault_purpose', purpose)
            .eq('is_active', true)
            .single();

        if (error || !data) {
            // Fallback to legacy hardcoded IDs if registry is not yet populated
            console.warn(`[VaultRegistry] Vault '${purpose}' not found in registry. Using legacy fallback.`);
            return this.getLegacyFallback(purpose);
        }

        // Update Cache
        this.cache.set(purpose, data.wallet_id);
        this.cacheExpiry = Date.now() + (5 * 60 * 1000);

        return data.wallet_id;
    }

    private static getLegacyFallback(purpose: string): string {
        switch (purpose) {
            case 'OPERATING': return '00000000-0000-0000-0000-000000000000';
            case 'TAX': return '11111111-1111-1111-1111-111111111111';
            case 'REVENUE': return '22222222-2222-2222-2222-222222222222';
            default: throw new Error(`CRITICAL: No fallback available for vault purpose: ${purpose}`);
        }
    }
}
