import { getSupabase } from '../supabaseClient.js';
import { UUID } from '../../services/utils.js';

export class FinancialCoreEngineService {
    
    /**
     * Create a new Tenant (Individual, Merchant, Marketplace, Partner)
     */
    async createTenant(userId: string, data: { name: string, type: 'individual' | 'merchant' | 'marketplace' | 'partner' }) {
        const sb = getSupabase();
        if (!sb) throw new Error("Database not connected");

        // 1. Create Tenant
        const { data: tenant, error: tenantError } = await sb
            .from('tenants')
            .insert({
                name: data.name,
                type: data.type,
                status: 'ACTIVE'
            })
            .select()
            .single();

        if (tenantError || !tenant) {
            throw new Error(`Failed to create tenant: ${tenantError?.message}`);
        }

        // 2. Link User to Tenant as 'owner'
        const { error: linkError } = await sb
            .from('tenant_users')
            .insert({
                tenant_id: tenant.id,
                user_id: userId,
                role: 'owner'
            });

        if (linkError) {
            console.error("Failed to link user to tenant", linkError);
        }

        // 3. Create Default Tenant Wallet
        const { error: walletError } = await sb
            .from('wallets')
            .insert({
                user_id: userId, // Legacy compatibility
                tenant_id: tenant.id,
                owner_type: data.type === 'individual' ? 'user' : 'merchant',
                name: `${data.name} Primary Wallet`,
                currency: 'TZS',
                balance: 0,
                status: 'active'
            });

        if (walletError) {
            console.error("Failed to create tenant wallet", walletError);
        }

        return tenant;
    }

    /**
     * Get all tenants for a user
     */
    async getUserTenants(userId: string) {
        const sb = getSupabase();
        if (!sb) return [];

        const { data, error } = await sb
            .from('tenant_users')
            .select('role, tenants(*)')
            .eq('user_id', userId);

        if (error) throw new Error(error.message);
        return data.map(d => ({ ...d.tenants, role: d.role }));
    }

    /**
     * Generate API Keys for a Tenant
     */
    async generateApiKeys(userId: string, tenantId: string, type: 'test' | 'live' = 'live') {
        const sb = getSupabase();
        if (!sb) throw new Error("Database not connected");

        // Verify user is owner or admin
        const { data: link } = await sb
            .from('tenant_users')
            .select('role')
            .eq('tenant_id', tenantId)
            .eq('user_id', userId)
            .single();

        if (!link || !['owner', 'admin'].includes(link.role)) {
            throw new Error("Unauthorized to generate API keys for this tenant");
        }

        const publicKey = `pk_${type}_${UUID.generate().replace(/-/g, '')}`;
        const secretKey = `sk_${type}_${UUID.generate().replace(/-/g, '')}${UUID.generate().replace(/-/g, '')}`;

        const { data: keys, error } = await sb
            .from('api_keys')
            .insert({
                tenant_id: tenantId,
                public_key: publicKey,
                secret_key: secretKey
            })
            .select()
            .single();

        if (error) throw new Error(error.message);
        return keys;
    }

    /**
     * Get API Keys for a Tenant
     */
    async getApiKeys(userId: string, tenantId: string) {
        const sb = getSupabase();
        if (!sb) return [];

        // Verify access (owner/admin only)
        const { data: link } = await sb
            .from('tenant_users')
            .select('role')
            .eq('tenant_id', tenantId)
            .eq('user_id', userId)
            .single();

        if (!link || !['owner', 'admin'].includes(link.role)) {
            throw new Error("Unauthorized to view API keys for this tenant");
        }

        const { data, error } = await sb
            .from('api_keys')
            .select('id, public_key, status, created_at, expires_at')
            .eq('tenant_id', tenantId);

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Revoke an API Key
     */
    async revokeApiKey(userId: string, tenantId: string, apiKeyId: string) {
        const sb = getSupabase();
        if (!sb) throw new Error("Database not connected");

        // Verify access (owner/admin only)
        const { data: link } = await sb
            .from('tenant_users')
            .select('role')
            .eq('tenant_id', tenantId)
            .eq('user_id', userId)
            .single();

        if (!link || !['owner', 'admin'].includes(link.role)) {
            throw new Error("Unauthorized to revoke API keys for this tenant");
        }

        const { error } = await sb
            .from('api_keys')
            .update({ status: 'REVOKED' })
            .eq('id', apiKeyId)
            .eq('tenant_id', tenantId);

        if (error) throw new Error(error.message);
        return { success: true };
    }

    /**
     * Validate an API Key (Middleware usage)
     */
    async validateApiKey(secretKey: string) {
        const sb = getSupabase();
        if (!sb) throw new Error("Database not connected");

        const { data, error } = await sb
            .from('api_keys')
            .select('tenant_id, status')
            .eq('secret_key', secretKey)
            .single();

        if (error || !data || data.status !== 'ACTIVE') {
            return null;
        }

        return data.tenant_id;
    }

    /**
     * Get Tenant Wallets
     */
    async getTenantWallets(userId: string, tenantId: string) {
        const sb = getSupabase();
        if (!sb) return [];

        // Verify access
        const { data: link } = await sb
            .from('tenant_users')
            .select('role')
            .eq('tenant_id', tenantId)
            .eq('user_id', userId)
            .single();

        if (!link) throw new Error("Unauthorized");

        const { data, error } = await sb
            .from('wallets')
            .select('*')
            .eq('tenant_id', tenantId);

        if (error) throw new Error(error.message);
        return data;
    }
}

export const FinancialCore = new FinancialCoreEngineService();
