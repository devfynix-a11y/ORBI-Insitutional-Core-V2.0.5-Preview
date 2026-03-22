import crypto from "crypto";
import { getAdminSupabase } from "../../supabaseClient.js";

export interface DeviceData {
    model: string;
    os: string;
    screenResolution: string;
    timezone: string;
    language: string;
    appVersion: string;
}

export class FingerprintService {
    generateFingerprint(device: DeviceData): string {
        // Pick only stable fields to ensure the fingerprint doesn't change on every login
        const stableData = {
            model: device.model,
            os: device.os,
            screenResolution: device.screenResolution,
            timezone: device.timezone,
            language: device.language,
            appVersion: device.appVersion
        };
        const raw = JSON.stringify(stableData);
        return crypto
            .createHash("sha256")
            .update(raw)
            .digest("hex");
    }

    async validateDevice(userId: string, fingerprint: string): Promise<boolean> {
        const sb = getAdminSupabase();
        if (!sb) return true; // Default to "new" if DB is down for safety

        // 1. Check if device exists for this user
        const { data: device, error } = await sb
            .from('user_devices')
            .select('*')
            .eq('user_id', userId)
            .eq('device_fingerprint', fingerprint)
            .maybeSingle();

        if (error) {
            console.error("[Fingerprint] Error validating device:", error);
            return true; 
        }

        if (device) {
            // Update last active
            await sb.from('user_devices').update({ 
                last_active_at: new Date().toISOString() 
            }).eq('id', device.id);
            
            return false; // Not a new device
        } else {
            // 2. Register new device (initially untrusted)
            await sb.from('user_devices').insert({
                user_id: userId,
                device_fingerprint: fingerprint,
                is_trusted: false,
                status: 'active'
            });
            
            return true; // It is a new device
        }
    }
}

export const Fingerprint = new FingerprintService();
