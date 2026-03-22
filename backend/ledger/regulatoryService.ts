
import { RegulatoryConfig, User } from '../../types.js';
import { getSupabase } from '../../services/supabaseClient.js';

/**
 * ORBI REGULATORY & COMPLIANCE NODE (V8.2)
 * -----------------------------------------
 * Manages tax jurisdictions, reporting thresholds, and system vault mapping.
 */
export class RegulatoryServiceNode {
    
    public async getActiveConfig(): Promise<RegulatoryConfig> {
        const sb = getSupabase();
        if (sb) {
            const { data } = await sb.from('regulatory_config').select('*').eq('is_active', true).maybeSingle();
            if (data) return data;
        }

        return {
            id: 'reg-default-01',
            vat_rate: 0.05,
            service_fee_rate: 0.01,
            gov_fee_rate: 0.005,
            stamp_duty_fixed: 1.0,
            is_active: true,
            updated_at: new Date().toISOString()
        };
    }

    /**
     * RESOLVE SYSTEM NODE
     * Maps logical system roles (like ESCROW) to physical wallet/vault IDs.
     */
    public async resolveSystemNode(role: 'ESCROW_VAULT' | 'FEE_COLLECTOR' | 'TAX_RESERVE' | 'FX_CLEARING'): Promise<string> {
        const sb = getSupabase();
        
        // Fallback to deterministic IDs for local simulation
        const fallbacks = {
            ESCROW_VAULT: '00000000-0000-0000-0000-000000000001',
            FEE_COLLECTOR: '00000000-0000-0000-0000-000000000003',
            TAX_RESERVE: '00000000-0000-0000-0000-000000000004',
            FX_CLEARING: '00000000-0000-0000-0000-000000000005'
        };

        if (sb) {
            try {
                const { data } = await sb.from('system_nodes').select('vault_id').eq('node_type', role).maybeSingle();
                if (data) return data.vault_id;
            } catch (e) {
                // Fallback to platform_vaults if system_nodes fails
                const { data: vault } = await sb.from('platform_vaults').select('id').eq('vault_role', role).maybeSingle();
                if (vault) return vault.id;
            }
        }
        
        return fallbacks[role];
    }

    public async calculateFees(amount: number, type: string): Promise<{ vat: number, fee: number, gov_fee: number, total: number, rate: number }> {
        const config = await this.getActiveConfig();
        
        const vat = amount * config.vat_rate;
        const serviceFee = amount * config.service_fee_rate;
        const govFee = (type === 'EXTERNAL_PAYMENT' || type === 'WITHDRAWAL') ? (amount * config.gov_fee_rate) : 0;
        const stampDuty = config.stamp_duty_fixed;

        const totalFees = vat + serviceFee + govFee + stampDuty;

        return {
            vat,
            fee: serviceFee + stampDuty,
            gov_fee: govFee,
            total: totalFees,
            rate: config.vat_rate
        };
    }
}

export const RegulatoryService = new RegulatoryServiceNode();
