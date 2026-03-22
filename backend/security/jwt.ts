
import { KMS } from './kms.js';
import { getSupabase } from '../supabaseClient.js';

export class JWTNode {
    // In-memory blocklist for fast lookups. Hydrated from DB.
    private static blocklist: Set<string> = new Set();
    private static blocklistHydrated = false;

    private static base64UrlEncode(str: string): string {
        return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    }

    private static base64UrlDecode(str: string): string {
        let decodedStr = str.replace(/-/g, '+').replace(/_/g, '/');
        while (decodedStr.length % 4) decodedStr += '=';
        return atob(decodedStr);
    }

    public static async sign(payload: any, expiresInSeconds: number = 900): Promise<string> {
        await KMS.waitReady();
        const key = await KMS.getActiveKey('AUTH');
        if (!key) throw new Error("AUTH_KEY_OFFLINE");
        const header = { alg: 'HS256', typ: 'JWT' };
        const encodedHeader = this.base64UrlEncode(JSON.stringify(header));
        
        const now = Math.floor(Date.now() / 1000);
        const jwtPayload = {
            ...payload,
            iat: now,
            exp: now + expiresInSeconds,
            jti: crypto.randomUUID() // Unique JWT ID for revocation
        };
        
        const encodedPayload = this.base64UrlEncode(JSON.stringify(jwtPayload));
        const data = new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`);
        const sig = await crypto.subtle.sign({ name: 'HMAC' }, key, data);
        const encodedSig = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
        return `${encodedHeader}.${encodedPayload}.${encodedSig}`;
    }

    private static async hydrateBlocklist() {
        const sb = getSupabase();
        if (sb) {
            try {
                const { data } = await sb.from('revoked_tokens').select('jti');
                if (data) {
                    data.forEach(row => this.blocklist.add(row.jti));
                }
                this.blocklistHydrated = true;
            } catch (e) {
                console.error("[JWT] Failed to hydrate blocklist", e);
            }
        }
    }

    public static async verify<T>(token: string): Promise<T | null> {
        try {
            const parts = token.split('.');
            if (parts.length !== 3) return null;
            
            await KMS.waitReady();
            const key = await KMS.getActiveKey('AUTH');
            if (!key) return null;
            
            const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
            const sig = Uint8Array.from(this.base64UrlDecode(parts[2]), c => c.charCodeAt(0));
            const isValid = await crypto.subtle.verify({ name: 'HMAC' }, key, sig, data);
            
            if (!isValid) return null;
            
            const payload = JSON.parse(this.base64UrlDecode(parts[1]));
            
            // 1. Check Expiration
            if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
                return null; // Token expired
            }
            
            // 2. Check Blocklist (Revocation)
            if (payload.jti) {
                if (!this.blocklistHydrated) {
                    await this.hydrateBlocklist();
                }
                if (this.blocklist.has(payload.jti)) {
                    console.warn(`[JWT] Attempted use of revoked token: ${payload.jti}`);
                    return null; // Token revoked
                }
            }
            
            return payload;
        } catch (e) { return null; }
    }

    /**
     * Revokes a token by adding its JTI to the blocklist.
     */
    public static async revoke(jti: string): Promise<void> {
        this.blocklist.add(jti);
        console.info(`[JWT] Token revoked: ${jti}`);
        
        // Persist to DB for distributed revocation
        const sb = getSupabase();
        if (sb) {
            try {
                await sb.from('revoked_tokens').insert({ jti });
            } catch (e) {
                console.error("[JWT] Failed to persist revoked token", e);
            }
        }
    }
}
