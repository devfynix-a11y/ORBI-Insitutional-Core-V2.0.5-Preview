
import { CONFIG } from '../../services/config.js';

interface CacheEntry<T> {
    data: T;
    expiry: number;
}

/**
 * ORBI INTERNAL HOT-STATE ENGINE (V2.5)
 * Hardened with Memory-Pressure Safeguards.
 */
class CacheManagerService {
    private store: Map<string, CacheEntry<any>> = new Map();
    private readonly MAX_ENTRIES = 5000; // Prevent runaway memory usage

    public async get<T>(key: string): Promise<T | null> {
        const entry = this.store.get(key);
        if (!entry) return null;
        
        if (Date.now() > entry.expiry) {
            this.store.delete(key);
            return null;
        }
        return entry.data as T;
    }

    public async set(key: string, data: any, ttlSeconds: number = 3600): Promise<void> {
        // Eviction Policy: If cache is full, clear oldest entries (FIFO-ish)
        if (this.store.size >= this.MAX_ENTRIES) {
            const firstKey = this.store.keys().next().value;
            if (firstKey) this.store.delete(firstKey);
        }

        this.store.set(key, {
            data,
            expiry: Date.now() + (ttlSeconds * 1000)
        });
    }

    public async invalidate(key: string): Promise<void> {
        this.store.delete(key);
    }

    public async clearClusterCache(): Promise<void> {
        this.store.clear();
    }

    public getMetrics() {
        return {
            size: this.store.size,
            utilization: `${((this.store.size / this.MAX_ENTRIES) * 100).toFixed(1)}%`,
            mode: 'SOVEREIGN_MEMORY_HARDENED'
        };
    }
}

export const CacheManager = new CacheManagerService();
