import fs from 'fs/promises';
import { EncryptionService } from './encryptionService.js';

export class BackupService {

    static async backup(data: any, path: string) {
        const enc = await EncryptionService.encrypt(data);
        await fs.writeFile(path, JSON.stringify(enc));
    }

    static async restore(path: string) {
        const file = await fs.readFile(path, 'utf-8');
        return EncryptionService.decrypt(JSON.parse(file));
    }
}
