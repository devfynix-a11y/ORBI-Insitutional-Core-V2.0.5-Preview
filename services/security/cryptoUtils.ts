export class CryptoUtils {

    static toBase64(buffer: ArrayBuffer | Uint8Array): string {
        const bytes = new Uint8Array(buffer);
        let binary = '';
        for (let i = 0; i < bytes.byteLength; i++) {
            binary += String.fromCharCode(bytes[i]);
        }
        return btoa(binary);
    }

    static fromBase64(b64: string): Uint8Array {
        // Handle base64url format
        const normalized = b64.replace(/-/g, '+').replace(/_/g, '/');
        const binary = atob(normalized);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes;
    }

    static randomBytes(length: number): Uint8Array {
        const arr = new Uint8Array(length);
        crypto.getRandomValues(arr);
        return arr;
    }
}
