
import { Server } from './server.js';

interface RateLimitStore {
    [ip: string]: {
        count: number;
        lastRequest: number;
    };
}

export class WAFService {
    private static instance: WAFService;
    private rateLimits: RateLimitStore = {};
    private readonly RATE_LIMIT_WINDOW = 60000; // 1 minute
    private readonly MAX_REQUESTS = 60; // 60 requests per minute
    
    private readonly SQL_INJECTION_PATTERNS = [
        new RegExp("(\\%27)|(\\')|(\\-\\-)|(\\%23)|(#)", "i"),
        new RegExp("((\\%3D)|(=))[^\\n]*((\\%27)|(\\'))((\\%6F)|o|(\\%4F))((\\%72)|r|(\\%52))", "i"),
        new RegExp("\\w*((\\%27)|(\\'))((\\%6F)|o|(\\%4F))((\\%72)|r|(\\%52))", "i"),
        new RegExp("((\\%27)|(\\'))union", "i"),
        new RegExp("exec(\\s|\\+)+(s|x)p\\w+", "i"),
        new RegExp("DROP\\s+TABLE", "i"),
        new RegExp("SELECT\\s.*\\sFROM", "i"),
        new RegExp("INSERT\\sINTO", "i")
    ];

    private readonly XSS_PATTERNS = [
        new RegExp("<script\\b[^>]*>([\\s\\S]*?)<\\/" + "script>", "gim"),
        new RegExp("javascript:", "gim"),
        new RegExp("on\\w+\\s*=", "gim"), 
        new RegExp("<iframe", "gim"),
        new RegExp("<object", "gim")
    ];

    private constructor() {}

    public static getInstance(): WAFService {
        if (!WAFService.instance) {
            WAFService.instance = new WAFService();
        }
        return WAFService.instance;
    }

    public async inspect(payload: any, userId: string = 'guest'): Promise<boolean> {
        if (this.isRateLimited('127.0.0.1')) {
            console.warn(`[WAF] Rate limit exceeded for ${userId}`);
            return false;
        }

        const strPayload = JSON.stringify(payload);
        if (!payload || strPayload.length < 5) return true;

        for (const pattern of this.SQL_INJECTION_PATTERNS) {
            if (pattern.test(strPayload)) {
                await this.logThreat(userId, 'SQL Injection Detected', strPayload);
                throw new Error("WAF: Malicious SQL pattern detected.");
            }
        }

        for (const pattern of this.XSS_PATTERNS) {
            if (pattern.test(strPayload)) {
                await this.logThreat(userId, 'XSS Attack Detected', strPayload);
                throw new Error("WAF: Cross-Site Scripting (XSS) pattern detected.");
            }
        }

        return true;
    }

    private isRateLimited(ip: string): boolean {
        const now = Date.now();
        const record = this.rateLimits[ip];
        if (!record) {
            this.rateLimits[ip] = { count: 1, lastRequest: now };
            return false;
        }
        if (now - record.lastRequest > this.RATE_LIMIT_WINDOW) {
            this.rateLimits[ip] = { count: 1, lastRequest: now };
            return false;
        }
        record.count++;
        return record.count > this.MAX_REQUESTS;
    }

    private async logThreat(userId: string, type: string, payload: string) {
        console.error(`[WAF BLOCK] ${type} from ${userId}`);
        // Fixed: Server now exposes logActivity to correctly handle WAF logging
        await Server.logActivity(userId, 'network_attack_blocked', 'failed', `${type}`);
    }
}

export const WAF = WAFService.getInstance();
