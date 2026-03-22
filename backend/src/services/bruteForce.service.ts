import { RedisClusterFactory } from '../../infrastructure/RedisClusterFactory.js';

export class BruteForceService {
    private redis = RedisClusterFactory.getClient('monitor');

    async isLocked(userId: string): Promise<{ locked: boolean, reason?: string, retryAfter?: number }> {
        if (!this.redis) return { locked: false };
        const lockStatus = await this.redis.get(`lock_status:${userId}`);
        if (lockStatus) {
            const ttl = await this.redis.ttl(`lock_status:${userId}`);
            return { locked: true, reason: lockStatus, retryAfter: ttl };
        }
        return { locked: false };
    }

    async recordFailedAttempt(userId: string): Promise<{ locked: boolean, lockDuration?: number }> {
        if (!this.redis) return { locked: false };
        const attemptsKey = `login_attempts:${userId}`;
        const attempts = await this.redis.incr(attemptsKey);
        
        if (attempts === 1) {
            await this.redis.expire(attemptsKey, 60); // 1 minute window
        }

        if (attempts >= 5) {
            const lockStatus = await this.redis.get(`lock_status:${userId}`);
            
            if (lockStatus === '15min') {
                // Escalate to 24h
                await this.redis.set(`lock_status:${userId}`, '24h', 'PX', 24 * 60 * 60 * 1000);
                await this.redis.del(attemptsKey);
                return { locked: true, lockDuration: 24 * 60 * 60 * 1000 };
            } else {
                // First lock (15min)
                await this.redis.set(`lock_status:${userId}`, '15min', 'PX', 15 * 60 * 1000);
                await this.redis.del(attemptsKey);
                return { locked: true, lockDuration: 15 * 60 * 1000 };
            }
        }
        return { locked: false };
    }

    async clearAttempts(userId: string): Promise<void> {
        if (!this.redis) return;
        await this.redis.del(`login_attempts:${userId}`);
    }
}
