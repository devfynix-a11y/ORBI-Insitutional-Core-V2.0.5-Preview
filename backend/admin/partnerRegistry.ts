import { getAdminSupabase } from '../supabaseClient.js';
import { FinancialPartner } from '../../types.js';

export class PartnerRegistry {
    private static sb = getAdminSupabase();

    public static async listPartners() {
        return await this.sb!.from('financial_partners').select('*');
    }

    public static async addPartner(partner: Omit<FinancialPartner, 'id' | 'created_at'>) {
        return await this.sb!.from('financial_partners').insert(partner);
    }

    public static async updatePartner(id: string, updates: Partial<FinancialPartner>) {
        return await this.sb!.from('financial_partners').update(updates).eq('id', id);
    }

    public static async deletePartner(id: string) {
        return await this.sb!.from('financial_partners').delete().eq('id', id);
    }
}
