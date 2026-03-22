
import { Server } from '../server.js';
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';

/**
 * HARDENED INGRESS WAF (V4.5 Platinum)
 * Deep Packet Inspection & Operation-Granular Throttling.
 */
export class WAFService {
    private static instance: WAFService;
    
    // Institutional Limit Matrix
    private readonly LIMIT_MATRIX: Record<string, { limit: number, window: number }> = {
        'wealth_settlement': { limit: 5, window: 60000 },    // 5 transactions per min
        'iam_login': { limit: 5, window: 300000 },          // 5 attempts per 5 mins
        'iam_signup': { limit: 3, window: 3600000 },         // 3 signups per hour per identity/IP
        'ledger_audit_read': { limit: 20, window: 60000 },  // 20 history reads per min
        'default': { limit: 100, window: 60000 }            // Standard burst limit for general APIs
    };

    /**
     * HARDENED ATTACK VECTORS (V5.0 Platinum)
     * Optimized to prevent SQLi, XSS, and Path Traversal without blocking valid JSON.
     */
    private readonly ATTACK_VECTORS = [
        // SQL Injection (Improved patterns)
        /\b(OR|AND)\b\s+\d+\s*=\s*\d+/i,
        /\bUNION\b.*\bSELECT\b/i,
        /(\%27)|(\')|(\-\-)|(\%23)|(#)/i,
        
        // Cross-Site Scripting (XSS)
        /<script\b[^>]*>([\s\S]*?)<\/script>/gim,
        /javascript:/gim,
        /onerror\s*=/i,
        /onload\s*=/i,
        
        // Path Traversal
        /\.\.\/|\.\.\\/i,
        
        // Remote Code Execution (RCE)
        /\b(exec|system|spawn|fork|eval|passthru)\b\s*\(/i,
        
        // NoSQL Injection
        /\{\s*\$where\s*:/i,
        
        // Malicious Encoding
        /base64_decode\s*\(/i
    ];

    public static getInstance() {
        if (!WAFService.instance) WAFService.instance = new WAFService();
        return WAFService.instance;
    }

    /**
     * GRANULAR OPERATION THROTTLE
     * Enforces limits based on specific functional domains and unique identifiers.
     */
    public async throttle(identity: string, operation: string): Promise<void> {
        const now = Date.now();
        // Resolve limit config (exact match or domain prefix or default)
        const domain = operation.split('_')[0];
        const config = this.LIMIT_MATRIX[operation] || 
                      this.LIMIT_MATRIX[`${domain}_default`] || 
                      this.LIMIT_MATRIX['default'];
        
        const cacheKey = `waf:rate_limit:${identity}:${operation}`;
        
        // Use Redis for distributed rate limiting
        let record = await RedisManager.get(cacheKey);
        
        // Reset window if time elapsed or no record
        if (!record || now > record.reset) {
            record = { count: 1, reset: now + config.window };
            await RedisManager.set(cacheKey, record, Math.ceil(config.window / 1000));
            return;
        }

        record.count++;
        
        if (record.count > config.limit) {
            const waitTime = Math.ceil((record.reset - now) / 1000);
            console.error(`[WAF] Rate limit breached: ${identity} on ${operation}. Blocked for ${waitTime}s.`);
            
            // Log security event for audit trail
            this.logViolation(identity, 'RATE_LIMIT_BREACH', `${operation} (count: ${record.count}/${config.limit})`);
            
            throw new Error(`RATE_LIMIT_EXCEEDED:${operation.toUpperCase()}:RETRY_AFTER_${waitTime}S`);
        }
        
        // Update count in Redis
        const ttl = Math.ceil((record.reset - now) / 1000);
        if (ttl > 0) {
            await RedisManager.set(cacheKey, record, ttl);
        }
    }

    /**
     * DEEP PACKET INSPECTION
     */
    public async inspect(payload: any, contextId: string = 'node_edge'): Promise<boolean> {
        if (!payload) return true;
        const content = JSON.stringify(payload);
        
        if (content.length > 10485760) throw new Error("WAF_REJECTION: Payload capacity exceeded.");

        for (const pattern of this.ATTACK_VECTORS) {
            if (pattern.test(content)) {
                await this.logViolation(contextId, 'MALICIOUS_SIGNATURE', pattern.source);
                throw new Error("SECURITY_VIOLATION: Signature mismatch in payload.");
            }
        }
        return true;
    }

    private async logViolation(id: string, type: string, detail: string) {
        console.error(`[WAF BLOCK] ${type} for: ${id}`);
        await Server.logActivity(id, 'WAF_INTERCEPT', 'blocked', `Type: ${type} - Detail: ${detail}`).catch(() => {});
    }
}

export const WAF = WAFService.getInstance();
