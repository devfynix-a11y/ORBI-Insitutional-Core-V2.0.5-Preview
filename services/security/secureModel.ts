import { EncryptionService } from './encryptionService.js';

export class SecureModel {

    static async encryptFields(data: any, fields: string[]) {
        for (const f of fields) {
            if (data[f]) data[f] = await EncryptionService.encrypt(data[f]);
        }
        return data;
    }

    static async decryptFields(data: any, fields: string[]) {
        for (const f of fields) {
            if (data[f]) data[f] = await EncryptionService.decrypt(data[f]);
        }
        return data;
    }
}
