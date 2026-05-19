import { getAdminSupabase } from '../services/supabaseClient.js';

export class BankService {
    private static assertBankLinkProviderConfigured() {
        throw new Error('BANK_LINK_PROVIDER_NOT_CONFIGURED');
    }

    static async createLinkToken(userId: string) {
        this.assertBankLinkProviderConfigured();
    }

    static async exchangePublicToken(userId: string, publicToken: string, accountId: string) {
        this.assertBankLinkProviderConfigured();
    }

    static async getLinkedBanks(userId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("DATABASE_UNAVAILABLE");

        const { data, error } = await sb.from('linked_banks')
            .select('id, bank_name, mask, status, created_at')
            .eq('user_id', userId);

        if (error) {
            console.error("[BankService] Error fetching linked banks:", error);
            throw new Error("FETCH_BANKS_FAILED");
        }

        return data || [];
    }

    static async unlinkBank(userId: string, bankId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("DATABASE_UNAVAILABLE");

        const { error } = await sb.from('linked_banks')
            .delete()
            .eq('id', bankId)
            .eq('user_id', userId);

        if (error) {
            console.error("[BankService] Error unlinking bank:", error);
            throw new Error("BANK_UNLINK_FAILED");
        }

        return { success: true };
    }
}
