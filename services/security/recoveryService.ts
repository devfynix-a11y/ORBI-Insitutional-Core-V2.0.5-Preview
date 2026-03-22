import { getSupabase } from '../supabaseClient.js';
import { EncryptionService } from './encryptionService.js';

export class RecoveryService {

    static async recover() {
        const db = getSupabase();
        if (!db) return;

        const { data } = await db
            .from('wal_logs')
            .select('*')
            .eq('status', 'PENDING');

        if (!data) return;

        for (const log of data) {
            const payload = await EncryptionService.decrypt(log.data);

            console.log("Recovering:", payload.op);

            await db.from('wal_logs')
                .update({ status: 'DONE' })
                .eq('id', log.id);
        }
    }
}
