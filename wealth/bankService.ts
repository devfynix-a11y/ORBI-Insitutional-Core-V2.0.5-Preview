import { getAdminSupabase } from '../services/supabaseClient.js';
import crypto from 'crypto';

export class BankService {
    static async createLinkToken(userId: string) {
        // Mock Plaid link token generation
        const linkToken = `link-sandbox-${crypto.randomUUID()}`;
        return { link_token: linkToken, expiration: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString() };
    }

    static async exchangePublicToken(userId: string, publicToken: string, accountId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("DATABASE_UNAVAILABLE");

        // Mock exchanging public token for access token
        const accessToken = `access-sandbox-${crypto.randomUUID()}`;
        const itemId = `item-sandbox-${crypto.randomUUID()}`;

        // Save linked bank account to the database
        const { data, error } = await sb.from('linked_banks').insert({
            user_id: userId,
            access_token: accessToken,
            item_id: itemId,
            account_id: accountId,
            bank_name: 'Mock Bank Inc.',
            mask: Math.floor(1000 + Math.random() * 9000).toString(),
            status: 'active'
        }).select().single();

        if (error) {
            console.error("[BankService] Error linking bank:", error);
            throw new Error("BANK_LINK_FAILED");
        }

        return data;
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
