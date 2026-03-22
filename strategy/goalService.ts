
import { Goal } from '../types.js';
import { Storage, STORAGE_KEYS } from '../backend/storage.js';
import { getSupabase } from '../services/supabaseClient.js';
import { DataVault } from '../backend/security/encryption.js';

import { UUID } from '../services/utils.js';

export class GoalService {
    async getFromDBLocal(): Promise<Goal[]> {
        const raw = Storage.getFromDB(STORAGE_KEYS.GOALS) as any[];
        return this.hydrateGoals(raw);
    }

    async fetchForUser(userId: string): Promise<Goal[]> {
        const sb = getSupabase();
        if (!sb) return this.getFromDBLocal();

        const { data, error } = await sb.from('goals').select('*').eq('user_id', userId);
        if (error || !data) return [];

        return this.hydrateGoals(data);
    }

    private async hydrateGoals(raw: any[]): Promise<Goal[]> {
        return await Promise.all(raw.map(async g => ({
            ...g,
            target: typeof g.target === 'string' ? Number(await DataVault.decrypt(g.target)) : g.target,
            current: typeof g.current === 'string' ? Number(await DataVault.decrypt(g.current)) : g.current,
            fundingStrategy: g.funding_strategy || 'manual',
            autoAllocationEnabled: g.auto_allocation_enabled || false
        })));
    }

    async postGoal(g: Goal) { 
        const encryptedTarget = await DataVault.encrypt(g.target);
        const encryptedCurrent = await DataVault.encrypt(g.current);

        const sb = getSupabase();
        if (sb) {
            const isUUID = (str: any) => typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);
            const goalId = isUUID(g.id) ? g.id : UUID.generate();
            
            const payload: any = {
                id: goalId,
                user_id: g.user_id,
                name: g.name,
                target: g.target,
                current: g.current || 0,
                deadline: g.deadline === '' ? null : g.deadline,
                color: g.color,
                icon: g.icon,
                funding_strategy: g.fundingStrategy || 'manual',
                auto_allocation_enabled: g.autoAllocationEnabled || false
            };
            
            // Remove undefined fields
            Object.keys(payload).forEach(key => payload[key] === undefined && delete payload[key]);

            const { data, error } = await sb.from('goals').upsert(payload).select().single();
            if (error) {
                console.error("[GoalService] Upsert error:", error);
                throw new Error(error.message);
            } else if (data) {
                g.id = data.id;
            }
        } else {
            if (!g.id) g.id = UUID.generate();
        }

        let items = Storage.getFromDB<any>(STORAGE_KEYS.GOALS); 
        items.push({ ...g, target: encryptedTarget, current: encryptedCurrent }); 
        Storage.saveToDB(STORAGE_KEYS.GOALS, items); 
        return { data: g, error: null }; 
    }

    async allocateFunds(goalId: string, amount: number, sourceWalletId: string) {
        // In a real implementation, this would trigger a transaction
        // For now, we update the goal current amount
        const sb = getSupabase();
        
        // 1. Fetch current goal
        let currentAmount = 0;
        if (sb) {
            const { data } = await sb.from('goals').select('current').eq('id', goalId).single();
            if (data) {
                currentAmount = Number(await DataVault.decrypt(data.current));
            }
        } else {
            const goals = await this.getFromDBLocal();
            const goal = goals.find(g => String(g.id) === String(goalId));
            if (goal) currentAmount = goal.current;
        }

        const newAmount = currentAmount + amount;
        const encryptedCurrent = await DataVault.encrypt(newAmount);

        if (sb) {
            await sb.from('goals').update({ current: newAmount }).eq('id', goalId);
        }

        // Update local storage
        let items = Storage.getFromDB<any>(STORAGE_KEYS.GOALS);
        const index = items.findIndex(i => String(i.id) === String(goalId));
        if (index !== -1) {
            items[index].current = encryptedCurrent;
            Storage.saveToDB(STORAGE_KEYS.GOALS, items);
        }

        return { success: true, newAmount };
    }

    async deleteGoal(id: string) { 
        const sb = getSupabase();
        if (sb) await sb.from('goals').delete().eq('id', id);
        let items = Storage.getFromDB<Goal>(STORAGE_KEYS.GOALS); 
        items = items.filter(i => String(i.id) !== String(id)); 
        Storage.saveToDB(STORAGE_KEYS.GOALS, items); 
        return { error: null }; 
    }
}
