
import { getAdminSupabase, getSupabase } from '../../services/supabaseClient.js';
import { EnvUtils } from '../../services/utils.js';
import { Audit } from '../security/audit.js';
import { ImageObjectStorage } from '../storage/ImageObjectStorage.js';
import { mkdir, unlink, writeFile } from 'fs/promises';
import { randomUUID } from 'crypto';
import path from 'path';

const allowedLocalImageTypes = new Map<string, { extension: string; signatures: number[][] }>([
    ['image/jpeg', { extension: 'jpg', signatures: [[0xff, 0xd8, 0xff]] }],
    ['image/jpg', { extension: 'jpg', signatures: [[0xff, 0xd8, 0xff]] }],
    ['image/png', { extension: 'png', signatures: [[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]] }],
    ['image/webp', { extension: 'webp', signatures: [[0x52, 0x49, 0x46, 0x46]] }],
]);

const hasSignature = (file: Buffer, signatures: number[][]) =>
    signatures.some((signature) =>
        signature.every((byte, index) => file[index] === byte),
    );

const validateLocalImage = (file: Buffer, contentType?: string) => {
    const normalizedType = String(contentType || '').split(';')[0].trim().toLowerCase();
    const allowed = allowedLocalImageTypes.get(normalizedType);
    if (!allowed) {
        throw new Error('UNSUPPORTED_IMAGE_TYPE: Only JPEG, PNG, and WEBP images are accepted.');
    }

    const maxBytes = Number(process.env.ORBI_IMAGE_MAX_BYTES || 5 * 1024 * 1024);
    if (!file.length || file.length > maxBytes) {
        throw new Error(`INVALID_IMAGE_SIZE: Image must be between 1 byte and ${maxBytes} bytes.`);
    }

    const validSignature =
        normalizedType === 'image/webp'
            ? file.length >= 12 &&
              file.subarray(0, 4).toString('ascii') === 'RIFF' &&
              file.subarray(8, 12).toString('ascii') === 'WEBP'
            : hasSignature(file, allowed.signatures);
    if (!validSignature) {
        throw new Error('IMAGE_SIGNATURE_MISMATCH');
    }

    return {
        contentType: normalizedType === 'image/jpg' ? 'image/jpeg' : normalizedType,
        extension: allowed.extension,
    };
};

/**
 * ASSET LIFECYCLE MANAGEMENT (V2.0)
 * Institutional-grade binary orchestration for profile metadata.
 */
export class AssetLifecycleManager {
    private bucketName: string;
    private r2Storage: ImageObjectStorage | null = null;

    constructor() {
        this.bucketName = EnvUtils.get('VITE_AVATAR_BUCKET') || 'orbi-users-profile-picture';
    }

    private usesR2(): boolean {
        return String(process.env.ORBI_IMAGE_STORAGE_PROVIDER || '').trim().toLowerCase() === 'r2';
    }

    private getR2Storage(): ImageObjectStorage {
        this.r2Storage ||= new ImageObjectStorage();
        return this.r2Storage;
    }

    private publicBaseUrl(): string {
        return String(
            process.env.ORBI_IMAGE_PUBLIC_BASE_URL ||
            process.env.BACKEND_URL ||
            process.env.ORBI_PRIMARY_CORE_BASE_URL ||
            'http://localhost:3000',
        ).trim().replace(/\/+$/, '');
    }

    private async commitLocal(userId: string, file: Buffer, contentType?: string): Promise<string> {
        const validated = validateLocalImage(file, contentType);
        const relativeDir = path.posix.join('uploads', 'avatars', userId);
        const fileName = `${Date.now()}-${randomUUID()}.${validated.extension}`;
        const absoluteDir = path.join(process.cwd(), 'public', 'uploads', 'avatars', userId);
        await mkdir(absoluteDir, { recursive: true });
        await writeFile(path.join(absoluteDir, fileName), file);
        return `${this.publicBaseUrl()}/${relativeDir}/${fileName}`;
    }

    /**
     * TERMINATION PROTOCOL
     * Securely removes binary assets from cloud nodes.
     */
    public async decommission(url: string | undefined, actorId: string = 'system'): Promise<boolean> {
        if (this.usesR2()) {
            if (!url) return true;
            try {
                const removed = await this.getR2Storage().deletePublicUrl(url);
                if (removed) {
                    await Audit.log('SECURITY', actorId, 'ASSET_DECOMMISSION', {
                        asset_url: url,
                        provider: 'cloudflare_r2',
                        reason: 'Single Active Avatar Policy Enforcement',
                    });
                }
                return removed;
            } catch (error) {
                console.error('[Lifecycle] R2 asset decommission failed:', error);
                return false;
            }
        }

        if (url && url.includes('/uploads/avatars/')) {
            try {
                const urlObj = new URL(url);
                const marker = '/uploads/avatars/';
                const markerIndex = urlObj.pathname.indexOf(marker);
                if (markerIndex === -1) return true;
                const relativePath = decodeURIComponent(urlObj.pathname.slice(markerIndex + 1));
                const normalizedPath = path.normalize(relativePath);
                if (!normalizedPath.startsWith(path.normalize('uploads/avatars/'))) return false;
                await unlink(path.join(process.cwd(), 'public', normalizedPath)).catch(() => {});
                return true;
            } catch (e) {
                console.error("[Lifecycle] Local asset termination failure:", e);
                return false;
            }
        }

        if (!url || !url.includes(this.bucketName)) return true;

        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return false;

        try {
            const urlObj = new URL(url);
            const pathParts = urlObj.pathname.split(`${this.bucketName}/`);
            if (pathParts.length <= 1) return false;
            const relativePath = decodeURIComponent(pathParts[1]);
            
            const { error } = await sb.storage.from(this.bucketName).remove([relativePath]);
            
            if (!error) {
                await Audit.log('SECURITY', actorId, 'ASSET_DECOMMISSION', { 
                    asset_url: url, 
                    bucket: this.bucketName,
                    path: relativePath,
                    reason: 'Single Active Avatar Policy Enforcement'
                });
            }

            return !error;
        } catch (e) {
            console.error("[Lifecycle] Forensic termination failure:", e);
            return false;
        }
    }

    /**
     * COMMIT PROTOCOL
     * Synchronizes institutional assets with the cloud storage cluster.
     */
    public async commit(userId: string, file: any, contentType?: string): Promise<string | null> {
        if (this.usesR2()) {
            if (!Buffer.isBuffer(file)) throw new Error('INVALID_IMAGE_BUFFER');
            return this.getR2Storage().uploadAvatar(userId, file, contentType);
        }

        if (!Buffer.isBuffer(file)) throw new Error('INVALID_IMAGE_BUFFER');

        const sb = getAdminSupabase() || getSupabase();
        if (!sb?.storage) return this.commitLocal(userId, file, contentType);

        const validated = validateLocalImage(file, contentType);
        const ext = validated.extension;
        const fileName = `${userId}/${Date.now()}.${ext}`;
        const filePath = `staff_avatars/${fileName}`;

        let uploadError: any = null;
        try {
            const uploadResult = await sb.storage.from(this.bucketName).upload(filePath, file, {
                cacheControl: '3600',
                upsert: true,
                contentType: validated.contentType,
            });
            uploadError = uploadResult.error;
        } catch (error) {
            uploadError = error;
        }

        if (uploadError) {
            const message = String(uploadError?.message || uploadError || '');
            if (message.includes('storage.buckets') || message.includes('schema cache') || message.toLowerCase().includes('bucket')) {
                return this.commitLocal(userId, file, contentType);
            }
            console.error("[Lifecycle] COMMIT_FAULT:", message);
            throw new Error(`STORAGE_COMMIT_FAILED: ${message}`);
        }

        const { data } = sb.storage.from(this.bucketName).getPublicUrl(filePath);
        return data.publicUrl;
    }
}

export const AssetLifecycle = new AssetLifecycleManager();
