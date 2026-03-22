
import { KMS } from './kms.js';
import { EncryptedData } from '../../types.js';

export enum VaultError {
    INTEGRITY_FAIL = "[Security Integrity Error]",
    HEALING_REQUIRED = "SENTINEL_HEALING_REQUIRED",
    DECRYPTION_FAILED = "DECRYPTION_FAILED",
    KMS_OFFLINE = "KMS_NODE_OFFLINE"
}

/**
 * ORBI INSTITUTIONAL ENCRYPTION ENGINE (V13.0)
 */
export const DataVault = {
    toBase64: (d: ArrayBuffer | Uint8Array) => {
        try {
            return Buffer.from(new Uint8Array(d)).toString('base64');
        } catch (e) {
            return '';
        }
    },
    
    fromBase64: (s: string) => {
        try {
            return new Uint8Array(Buffer.from(s, 'base64'));
        } catch (e) {
            return new Uint8Array(0);
        }
    },

    /**
     * ENCRYPT SENSITIVE NODE
     */
    encrypt: async (value: any, context: Record<string, any> = {}): Promise<string> => {
        if (value === null || value === undefined) return '';
        if (typeof value === 'string' && value.startsWith('enc_v2_')) return value;

        try {
            await KMS.waitReady();
            const key = await KMS.getActiveKey('ENCRYPTION');
            
            if (!key) {
                throw new Error(VaultError.KMS_OFFLINE);
            }

            const iv = crypto.getRandomValues(new Uint8Array(12));
            const encoder = new TextEncoder();
            
            const data = encoder.encode(JSON.stringify({
                v: value,
                ts: Date.now(),
                ctx: context
            }));

            const anonymous_aad = encoder.encode(JSON.stringify({
              v: KMS.getActiveVersion('ENCRYPTION'),
              origin: "ORBI_V3_CORE"
            }));

            const encrypted = await crypto.subtle.encrypt(
                { name: 'AES-GCM', iv, additionalData: anonymous_aad, tagLength: 128 },
                key,
                data
            );

            const combined = new Uint8Array(encrypted);
            const ciphertext = combined.slice(0, combined.byteLength - 16);
            const tag = combined.slice(combined.byteLength - 16);

            const payload: EncryptedData = {
                version: KMS.getActiveVersion('ENCRYPTION'),
                iv: DataVault.toBase64(iv),
                ciphertext: DataVault.toBase64(ciphertext),
                tag: DataVault.toBase64(tag),
                timestamp: Date.now(),
                keyId: 'p-node-active',
                algorithm: 'AES-GCM-256',
                aad: DataVault.toBase64(anonymous_aad)
            };

            return `enc_v2_${Buffer.from(JSON.stringify(payload)).toString('base64')}`;
        } catch (e: any) {
            console.error("[Vault] Encryption protocol failure:", e);
            throw e; 
        }
    },

    /**
     * DECRYPT WITH SELF-HEALING PROTOCOL
     */
    decrypt: async (cipher: string): Promise<any> => {
        if (!cipher || typeof cipher !== 'string' || !cipher.startsWith('enc_v')) return cipher;

        try {
            await KMS.waitReady();
            const rawPayload = cipher.replace('enc_v2_', '').replace('enc_v1_', '');
            
            let payload: EncryptedData;
            try {
                payload = JSON.parse(Buffer.from(rawPayload, 'base64').toString('utf-8'));
            } catch (e) {
                console.error("[Vault] Decryption JSON parse failure:", e);
                return VaultError.INTEGRITY_FAIL;
            }

            const key = await KMS.getKeyByVersion('ENCRYPTION', payload.version);
            if (!key) {
                console.error(`[Vault] Decryption key not found for version: ${payload.version}. This data is currently inaccessible.`);
                return VaultError.HEALING_REQUIRED;
            }

            // Detect stale keys for potential re-encryption
            const activeVersion = KMS.getActiveVersion('ENCRYPTION');
            if (payload.version < activeVersion) {
                console.info(`[Vault] Stale key detected (v${payload.version} < v${activeVersion}). Re-encryption recommended.`);
            }

            const iv = DataVault.fromBase64(payload.iv);
            const ciphertext = DataVault.fromBase64(payload.ciphertext);
            const tag = DataVault.fromBase64(payload.tag || '');
            const aad = payload.aad ? DataVault.fromBase64(payload.aad) : undefined;

            const encrypted = new Uint8Array(ciphertext.length + tag.length);
            encrypted.set(ciphertext);
            encrypted.set(tag, ciphertext.length);

            const decrypted = await crypto.subtle.decrypt(
                { name: 'AES-GCM', iv, additionalData: aad, tagLength: 128 },
                key,
                encrypted
            ).catch(async (e) => {
                // Fallback 1: Try without AAD
                if (aad) {
                    try {
                        return await crypto.subtle.decrypt(
                            { name: 'AES-GCM', iv, tagLength: 128 },
                            key,
                            encrypted
                        );
                    } catch (e2) {}
                }
                // Fallback 2: Try with ciphertext only (if tag was already appended)
                if (tag.length > 0) {
                    try {
                        return await crypto.subtle.decrypt(
                            { name: 'AES-GCM', iv, additionalData: aad, tagLength: 128 },
                            key,
                            ciphertext
                        );
                    } catch (e3) {}
                    
                    // Fallback 3: Try with ciphertext only and without AAD
                    if (aad) {
                        try {
                            return await crypto.subtle.decrypt(
                                { name: 'AES-GCM', iv, tagLength: 128 },
                                key,
                                ciphertext
                            );
                        } catch (e4) {}
                    }
                }
                throw e;
            });

            const packet = JSON.parse(new TextDecoder().decode(decrypted));
            return packet.v;
        } catch (e) {
            console.error("[Vault] Decryption integrity failure:", e);
            return VaultError.INTEGRITY_FAIL;
        }
    },

    /**
     * RE-KEY DATA TO LATEST VERSION
     */
    reKey: async (cipher: string): Promise<string> => {
        if (!cipher || !cipher.startsWith('enc_v')) return cipher;
        
        const decrypted = await DataVault.decrypt(cipher);
        if (decrypted === VaultError.INTEGRITY_FAIL || decrypted === VaultError.HEALING_REQUIRED) {
            return cipher; // Cannot re-key what we can't decrypt
        }
        
        // Re-encrypting will use the latest active key
        return await DataVault.encrypt(decrypted);
    },

    /**
     * RECURSIVE TRANSLATION ENGINE
     */
    translate: async (input: any): Promise<any> => {
        if (input === null || input === undefined) return input;
        
        if (typeof input === 'string' && input.startsWith('enc_v')) {
            return await DataVault.decrypt(input);
        }
        
        if (Array.isArray(input)) {
            return await Promise.all(input.map(item => DataVault.translate(item)));
        }
        
        if (typeof input === 'object') {
            const keys = Object.keys(input);
            const values = await Promise.all(keys.map(k => DataVault.translate(input[k])));
            
            const res: any = {};
            for (let i = 0; i < keys.length; i++) {
                const k = keys[i];
                const val = values[i];
                
                // ORBI TRANSLATION MAPPING: Snake to Camel for UI consistency
                let mappedKey = k;
                if (k === 'wallet_id') mappedKey = 'walletId';
                else if (k === 'to_wallet_id') mappedKey = 'toWalletId';
                else if (k === 'category_id') mappedKey = 'categoryId';
                else if (k === 'created_at') mappedKey = 'createdAt';
                else if (k === 'updated_at') mappedKey = 'updatedAt';
                else if (k === 'status_notes') mappedKey = 'statusNotes';

                const isNumeric = /amount|balance|target|current|budget|vat|fee|rate/i.test(k);
                if (val === VaultError.INTEGRITY_FAIL || val === VaultError.HEALING_REQUIRED) {
                    res[mappedKey] = isNumeric ? 0 : "🔒 Protected Node";
                } else {
                    res[mappedKey] = val;
                }
            }
            return res;
        }
        return input;
    }
};
