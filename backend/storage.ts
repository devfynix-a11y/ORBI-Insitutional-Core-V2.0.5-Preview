
import { getSupabase } from '../services/supabaseClient.js';
import { CONFIG } from '../services/config.js';

export const STORAGE_KEYS = {
    TRANSACTIONS: 'orbi_transactions',
    CATEGORIES: 'orbi_categories',
    GOALS: 'orbi_goals',
    WALLETS: 'orbi_wallets',
    TASKS: 'orbi_tasks',
    USER_PROFILE: 'orbi_user_profile',
    GOAL_ALLOCATIONS: 'orbi_goal_allocations',
    CUSTOM_USERS: 'orbi_custom_users',
    USER_SESSION: 'orbi_user_session',
    KYC_REQUESTS: 'orbi_kyc_requests',
    JOB_QUEUE: 'orbi_internal_jobs',
    PERSISTENCE_STATUS: 'fnx_sync_state'
};

/**
 * ORBI HYBRID PERSISTENCE ENGINE (V4.2)
 * Hardened for Headless/Browser Interoperability.
 */
class PersistenceEngine {
    private memStore = new Map<string, string>();

    private isBrowser(): boolean {
        return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
    }

    public getSyncStatus(): 'SYNCHRONIZED' | 'VOLATILE' {
        return CONFIG.PROVISIONING.IS_HYDRATED ? 'SYNCHRONIZED' : 'VOLATILE';
    }

    async commitToCloud(table: string, data: any, conflictId: string = 'id') {
        const sb = getSupabase();
        if (!sb) return { error: 'OFFLINE' };
        try {
            const { error } = await sb.from(table).upsert(data, { onConflict: conflictId });
            return { error };
        } catch (e: any) { return { error: e }; }
    }

    cacheSet(key: string, value: any) { 
        this.setItem(key, JSON.stringify(value)); 
    }

    cacheGet<T>(key: string): T | null {
        try {
            const raw = this.getItem(key);
            return raw ? JSON.parse(raw) : null;
        } catch { return null; }
    }

    getFromDB<T>(key: string): T[] { 
        return this.cacheGet<T[]>(key) || []; 
    }

    saveToDB(key: string, data: any): void { 
        this.cacheSet(key, data); 
    }

    getItem(key: string): string | null { 
        if (this.isBrowser()) {
            return window.localStorage.getItem(key);
        }
        return this.memStore.get(key) || null;
    }

    setItem(key: string, value: string): void { 
        if (this.isBrowser()) {
            window.localStorage.setItem(key, value);
        }
        this.memStore.set(key, value);
    }

    removeItem(key: string): void { 
        if (this.isBrowser()) {
            window.localStorage.removeItem(key);
        }
        this.memStore.delete(key);
    }
}

export const Storage = new PersistenceEngine();
