import { getSupabase } from '../../supabaseClient.js';

/**
 * Enterprise Idempotency Layer
 * Prevents duplicate transactions, double-charges, and network replay attacks.
 * Uses PostgreSQL for durability and coordination.
 */
export class IdempotencyLayer {
    
    /**
     * Checks if a request has already been processed.
     * Returns the cached response if it exists, otherwise registers the key.
     */
    public static async checkOrRegister(idempotencyKey: string, clientId: string, path: string): Promise<{ isDuplicate: boolean, cachedResponse?: any }> {
        if (!idempotencyKey) {
            throw new Error("IDEMPOTENCY_KEY_REQUIRED: Enterprise API requires an Idempotency-Key header.");
        }

        const compositeKey = `${clientId}:${path}:${idempotencyKey}`;
        const sb = getSupabase();
        if (!sb) {
            throw new Error("DB_OFFLINE: Cannot verify idempotency.");
        }

        // 1. Try to insert the key. If it fails, it already exists.
        const { error } = await sb.from('ent_idempotency_keys').insert({
            key: compositeKey,
            client_id: clientId,
            request_path: path,
            status: 'PROCESSING'
        });

        if (error) {
            // 2. It exists. Fetch it.
            const { data } = await sb.from('ent_idempotency_keys')
                .select('*')
                .eq('key', compositeKey)
                .single();
                
            if (data) {
                if (data.status === 'PROCESSING') {
                    throw new Error("CONCURRENT_REQUEST: This request is currently being processed by another node.");
                }
                return { isDuplicate: true, cachedResponse: data.response_body };
            }
        }

        return { isDuplicate: false };
    }

    /**
     * Saves the final response against the idempotency key.
     */
    public static async saveResponse(idempotencyKey: string, clientId: string, path: string, statusCode: number, responseBody: any): Promise<void> {
        const compositeKey = `${clientId}:${path}:${idempotencyKey}`;
        const sb = getSupabase();
        
        if (sb) {
            await sb.from('ent_idempotency_keys')
                .update({ 
                    status: 'COMPLETED',
                    response_status: statusCode, 
                    response_body: responseBody 
                })
                .eq('key', compositeKey);
        }
    }

    /**
     * Clears an idempotency key to allow retries (e.g., after a transient failure).
     */
    public static async clearKey(idempotencyKey: string, clientId: string, path: string): Promise<void> {
        const compositeKey = `${clientId}:${path}:${idempotencyKey}`;
        const sb = getSupabase();
        
        if (sb) {
            await sb.from('ent_idempotency_keys')
                .delete()
                .eq('key', compositeKey);
        }
    }
}
