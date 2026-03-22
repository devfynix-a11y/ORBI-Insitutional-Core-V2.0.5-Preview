import { getAdminSupabase } from '../services/supabaseClient.js';

export class DeviceService {
    /**
     * Register a new device for a user.
     */
    static async registerDevice(userId: string, data: {
        device_fingerprint: string;
        device_name?: string;
        device_type?: string;
        user_agent?: string;
    }) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        // Check if device already exists
        const { data: existing } = await sb.from('user_devices')
            .select('*')
            .eq('user_id', userId)
            .eq('device_fingerprint', data.device_fingerprint)
            .single();

        if (existing) {
            // Update last active
            const { data: updated, error } = await sb.from('user_devices')
                .update({ last_active_at: new Date().toISOString() })
                .eq('id', existing.id)
                .select()
                .single();
            if (error) throw new Error(error.message);
            return updated;
        }

        // Insert new device
        const { data: newDevice, error } = await sb.from('user_devices').insert({
            user_id: userId,
            ...data,
            status: 'active',
            is_trusted: false
        }).select().single();

        if (error) throw new Error(error.message);
        return newDevice;
    }

    /**
     * Get all devices for a user.
     */
    static async getUserDevices(userId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data, error } = await sb.from('user_devices')
            .select('*')
            .eq('user_id', userId)
            .order('last_active_at', { ascending: false });

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Remove a device.
     */
    static async removeDevice(userId: string, deviceId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { error } = await sb.from('user_devices')
            .delete()
            .eq('id', deviceId)
            .eq('user_id', userId);

        if (error) throw new Error(error.message);
        return { success: true };
    }

    /**
     * Admin: Get all devices (paginated)
     */
    static async getAllDevices(limit: number = 50, offset: number = 0) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data, count, error } = await sb.from('user_devices')
            .select('*', { count: 'exact' })
            .range(offset, offset + limit - 1)
            .order('created_at', { ascending: false });

        if (error) throw new Error(error.message);
        return { devices: data, total: count };
    }

    /**
     * Admin: Update device trust status
     */
    static async updateDeviceStatus(deviceId: string, data: { is_trusted?: boolean, status?: string }) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data: updated, error } = await sb.from('user_devices')
            .update(data)
            .eq('id', deviceId)
            .select()
            .single();

        if (error) throw new Error(error.message);
        return updated;
    }
}
