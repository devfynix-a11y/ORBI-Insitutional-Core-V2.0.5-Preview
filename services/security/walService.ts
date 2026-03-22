import { EncryptionService } from './encryptionService.js';
import { getSupabase } from '../supabaseClient.js';

export class WALService {

    static async log(op: string, payload: any) {
        const db = getSupabase();
        if (!db) return;

        const enc = await EncryptionService.encrypt({ op, payload });

        await db.from('wal_logs').insert({
            data: enc,
            status: 'PENDING'
        });
    }
}
