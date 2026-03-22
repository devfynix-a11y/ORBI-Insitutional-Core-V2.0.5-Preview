import { EncryptionService } from './encryptionService.js';
import { getSupabase } from '../supabaseClient.js';

export class SecretsVault {

    static async store(key: string, value: string) {
        const db = getSupabase();
        if (!db) throw new Error("Database not available");
        const enc = await EncryptionService.encrypt(value);

        await db.from('secrets').upsert({ key, value: enc });
    }

    static async get(key: string) {
        const db = getSupabase();
        if (!db) throw new Error("Database not available");
        const { data } = await db.from('secrets').select('*').eq('key', key).single();

        return data ? EncryptionService.decrypt(data.value) : null;
    }
}
