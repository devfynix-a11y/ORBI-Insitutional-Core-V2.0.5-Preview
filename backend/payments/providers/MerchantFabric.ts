
import { FinancialPartner, DigitalMerchant } from '../../../types.js';
import { getSupabase } from '../../../services/supabaseClient.js';
import { DataVault } from '../../security/encryption.js';
import { UUID } from '../../../services/utils.js';

/**
 * ORBI MERCHANT FABRIC (V2.1)
 * ----------------------------
 * Central registry for external liquidity nodes.
 * Implements "Zero-Visibility Persistence" for all node secrets.
 */
class MerchantFabricService {
    
    public async registerPartner(payload: Partial<FinancialPartner>): Promise<FinancialPartner> {
        const sb = getSupabase();
        if (!sb) throw new Error("VAULT_OFFLINE");

        // PROTOCOL: Immediate Cryptographic Hardening
        // Data is encrypted at the application edge before hitting the DB driver.
        const encryptedSecret = payload.client_secret 
            ? await DataVault.encrypt(payload.client_secret, { domain: 'PARTNER_SECRET', node: payload.name }) 
            : '';
        
        const partner: FinancialPartner = {
            id: UUID.generate(),
            name: payload.name || 'Unknown Node',
            type: payload.type || 'mobile_money',
            icon: payload.icon || 'university',
            color: payload.color || '#4361EE',
            client_id: payload.client_id,
            client_secret: encryptedSecret, // Persistent ciphertext only
            api_base_url: payload.api_base_url,
            status: 'ACTIVE',
            created_at: new Date().toISOString(),
            logic_type: payload.logic_type || 'SPECIALIZED',
            mapping_config: payload.mapping_config
        };

        const { error } = await sb.from('financial_partners').insert(partner);
        if (error) throw error;
        
        return partner;
    }

    /**
     * SECURE RETRIEVAL
     * Explicitly selects only non-sensitive columns.
     * The 'client_secret' and 'connection_secret' columns are NEVER returned to the UI.
     */
    public async getPartners(): Promise<FinancialPartner[]> {
        const sb = getSupabase();
        if (!sb) return [];
        
        const { data } = await sb.from('financial_partners')
            .select(`
                id, 
                name, 
                type, 
                icon, 
                color, 
                api_base_url, 
                status, 
                logic_type, 
                created_at,
                mapping_config
            `)
            .eq('status', 'ACTIVE');
            
        return data || [];
    }

    public async updatePartnerToken(id: string, token: string, expiresIn: number): Promise<void> {
        const sb = getSupabase();
        if (!sb) return;
        const expiry = Date.now() + (expiresIn * 1000);
        
        // Tokens are also encrypted at rest
        const encryptedToken = await DataVault.encrypt(token);
        
        await sb.from('financial_partners').update({
            token_cache: encryptedToken,
            token_expiry: expiry
        }).eq('id', id);
    }
}

export const MerchantFabric = new MerchantFabricService();
