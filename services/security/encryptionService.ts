import { KMS } from './kmsService.js';
import { CryptoUtils } from './cryptoUtils.js';

export class EncryptionService {

    static async encrypt(data: any) {

        await KMS.waitReady();

        const text = typeof data === 'string'
            ? data
            : JSON.stringify(data);

        const dek = await crypto.subtle.generateKey(
            { name: 'AES-GCM', length: 256 },
            true,
            ['encrypt', 'decrypt']
        );

        const iv = CryptoUtils.randomBytes(12);

        const ciphertext = await crypto.subtle.encrypt(
            { name: 'AES-GCM', iv: iv as any },
            dek,
            new TextEncoder().encode(text)
        );

        const kmsKey = await KMS.getActiveKey('ENCRYPTION');
        const version = KMS.getActiveVersion('ENCRYPTION');

        const dekIv = CryptoUtils.randomBytes(12);

        const wrapped = await crypto.subtle.wrapKey(
            'raw',
            dek,
            kmsKey!,
            { name: 'AES-GCM', iv: dekIv as any }
        );

        return {
            v: 1,
            kv: version,
            iv: CryptoUtils.toBase64(iv),
            dek: CryptoUtils.toBase64(new Uint8Array([...dekIv, ...new Uint8Array(wrapped)])),
            ct: CryptoUtils.toBase64(ciphertext)
        };
    }

    static async decrypt(payload: any) {

        await KMS.waitReady();

        const dekBytes = CryptoUtils.fromBase64(payload.dek);
        const dekIv = dekBytes.slice(0, 12);
        const wrapped = dekBytes.slice(12);

        const kmsKey = await KMS.getKeyByVersion('ENCRYPTION', payload.kv);

        const dek = await crypto.subtle.unwrapKey(
            'raw',
            wrapped,
            kmsKey!,
            { name: 'AES-GCM', iv: dekIv as any },
            { name: 'AES-GCM', length: 256 },
            true,
            ['decrypt']
        );

        const decrypted = await crypto.subtle.decrypt(
            { name: 'AES-GCM', iv: CryptoUtils.fromBase64(payload.iv) as any },
            dek,
            CryptoUtils.fromBase64(payload.ct) as any
        );

        const text = new TextDecoder().decode(decrypted);

        try { return JSON.parse(text); } catch { return text; }
    }
}
