import { getSupabase } from '../../supabaseClient.js';

/**
 * Enterprise Distributed Lock Manager
 * Prevents race conditions and double-spends during concurrent wallet mutations.
 * Uses PostgreSQL for durable locking.
 */
export class LockManager {
    
    /**
     * Acquires locks for multiple resources in a deterministic order to prevent deadlocks.
     * Includes a retry mechanism for high-concurrency environments.
     */
    public static async acquireLocks(resourceIds: string[], ttlSeconds: number = 10, retries: number = 3): Promise<boolean> {
        // Sort IDs to prevent deadlocks
        const sortedIds = [...resourceIds].sort();
        const sb = getSupabase();
        if (!sb) return false;
        
        for (let attempt = 0; attempt <= retries; attempt++) {
            const acquiredLocks: string[] = [];
            let allAcquired = true;

            for (const id of sortedIds) {
                const lockKey = `lock:wallet:${id}`;
                const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
                
                // Clean up expired lock first if any
                await sb.from('ent_locks')
                    .delete()
                    .eq('lock_key', lockKey)
                    .lt('expires_at', new Date().toISOString());

                // Try to acquire lock
                const { error } = await sb.from('ent_locks').insert({
                    lock_key: lockKey,
                    expires_at: expiresAt
                });
                
                if (error) {
                    allAcquired = false;
                    break;
                }
                acquiredLocks.push(id);
            }

            if (allAcquired) {
                return true;
            }

            // Rollback acquired locks if we fail to get all of them
            await this.releaseLocks(acquiredLocks);

            if (attempt < retries) {
                // Exponential backoff with jitter
                const delay = Math.pow(2, attempt) * 100 + Math.random() * 50;
                await new Promise(r => setTimeout(r, delay));
            }
        }

        return false;
    }

    /**
     * Releases locks for multiple resources.
     */
    public static async releaseLocks(resourceIds: string[]): Promise<void> {
        const sb = getSupabase();
        if (!sb) return;
        
        for (const id of resourceIds) {
            await sb.from('ent_locks').delete().eq('lock_key', `lock:wallet:${id}`);
        }
    }

    /**
     * Executes a callback within a distributed lock context.
     */
    public static async withLock<T>(resourceIds: string[], callback: () => Promise<T>): Promise<T> {
        const locked = await this.acquireLocks(resourceIds);
        if (!locked) {
            throw new Error("LOCK_TIMEOUT: Unable to acquire resources. System is under high load.");
        }

        try {
            return await callback();
        } finally {
            await this.releaseLocks(resourceIds);
        }
    }
}
