import { getSupabase } from '../supabaseClient.js';

export class AuditService {

    static async log(action: string, meta: any) {
        const db = getSupabase();
        if (!db) return;

        await db.from('audit_logs').insert({
            action,
            meta,
            created_at: new Date().toISOString()
        });
    }
}
