import { RedisClusterFactory } from '../../infrastructure/RedisClusterFactory.js';

/**
 * Enterprise Redis Manager
 * Provides a unified interface for distributed caching, locking, and idempotency.
 * Includes an in-memory fallback for environments without Redis.
 */
export class RedisManager {
    private static memoryStore = new Map<string, any>();
    private static locks = new Set<string>();

    private static getClient() {
        return RedisClusterFactory.getClient('session');
    }

    public static async get(key: string): Promise<any> {
        const client = this.getClient();
        if (client) {
            try {
                const val = await client.get(key);
                if (val) {
                    try {
                        return JSON.parse(val);
                    } catch (e) {
                        return val;
                    }
                }
                return null;
            } catch (e) {
                console.warn('[RedisManager] Redis get failed, falling back to memory', e);
            }
        }
        return this.memoryStore.get(key);
    }

    public static async set(key: string, value: any, ttlSeconds?: number): Promise<void> {
        const client = this.getClient();
        if (client) {
            try {
                const strValue = typeof value === 'string' ? value : JSON.stringify(value);
                if (ttlSeconds) {
                    await client.set(key, strValue, 'EX', ttlSeconds);
                } else {
                    await client.set(key, strValue);
                }
                return;
            } catch (e) {
                console.warn('[RedisManager] Redis set failed, falling back to memory', e);
            }
        }
        
        this.memoryStore.set(key, value);
        if (ttlSeconds) {
            setTimeout(() => this.memoryStore.delete(key), ttlSeconds * 1000);
        }
    }

    public static async delete(key: string): Promise<void> {
        const client = this.getClient();
        if (client) {
            try {
                await client.del(key);
                return;
            } catch (e) {
                console.warn('[RedisManager] Redis delete failed, falling back to memory', e);
            }
        }
        this.memoryStore.delete(key);
    }

    public static async acquireLock(key: string, ttlSeconds: number = 10): Promise<boolean> {
        const client = this.getClient();
        if (client) {
            try {
                // Using Redis SET NX (Not eXists) for distributed locking
                const result = await client.set(key, 'LOCKED', 'EX', ttlSeconds, 'NX');
                return result === 'OK';
            } catch (e) {
                console.warn('[RedisManager] Redis acquireLock failed, falling back to memory', e);
            }
        }

        if (this.locks.has(key)) return false;
        this.locks.add(key);
        setTimeout(() => this.locks.delete(key), ttlSeconds * 1000);
        return true;
    }

    public static async releaseLock(key: string): Promise<void> {
        const client = this.getClient();
        if (client) {
            try {
                await client.del(key);
                return;
            } catch (e) {
                console.warn('[RedisManager] Redis releaseLock failed, falling back to memory', e);
            }
        }
        this.locks.delete(key);
    }
}
