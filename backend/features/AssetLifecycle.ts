
import { getAdminSupabase, getSupabase } from '../../services/supabaseClient.js';
import { EnvUtils } from '../../services/utils.js';
import { Audit } from '../security/audit.js';
import { ImageObjectStorage } from '../storage/ImageObjectStorage.js';

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

        const sb = getAdminSupabase() || getSupabase();
        if (!sb) throw new Error("CLOUD_NODE_OFFLINE");

        const ext = contentType === 'image/jpeg' ? 'jpg' : contentType === 'image/webp' ? 'webp' : 'png';
        const fileName = `${userId}/${Date.now()}.${ext}`;
        const filePath = `staff_avatars/${fileName}`;

        const { error: uploadError } = await sb.storage.from(this.bucketName).upload(filePath, file, {
            cacheControl: '3600',
            upsert: true,
            contentType: contentType || 'image/png'
        });

        if (uploadError) {
            console.error("[Lifecycle] COMMIT_FAULT:", uploadError.message);
            throw new Error(`STORAGE_COMMIT_FAILED: ${uploadError.message}`);
        }

        const { data } = sb.storage.from(this.bucketName).getPublicUrl(filePath);
        return data.publicUrl;
    }
}

export const AssetLifecycle = new AssetLifecycleManager();
