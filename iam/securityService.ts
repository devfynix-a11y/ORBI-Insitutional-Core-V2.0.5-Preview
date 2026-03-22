
import { UserActivity } from '../types.js';
import { Storage, STORAGE_KEYS } from '../backend/storage.js'; 
import { UUID } from '../services/utils.js';
import { getSupabase } from '../services/supabaseClient.js';
import { Audit, AuditEventType } from '../backend/security/audit.js';

import { SocketRegistry } from '../backend/infrastructure/SocketRegistry.js';

export class SecurityService {
    private readonly STORAGE_KEY_ACTIVITY = 'orbi_user_activity';

    /**
     * UNIFIED SECURITY LOGGER
     * Commits events to local storage and the Immutable Audit Trail.
     */
    async logActivity(userId: string, type: string, status: string, details: string = '', actorName?: string, fingerprint?: string) {
        const log: UserActivity = {
            id: UUID.generate(),
            user_id: userId,
            activity_type: type as any,
            status: status as any,
            device_info: typeof navigator !== 'undefined' ? navigator.userAgent : 'Server',
            ip_address: '127.0.0.1', 
            location: 'Unknown',
            created_at: new Date().toISOString(),
            fingerprint: fingerprint
        };

        // 0. Real-Time Nexus Push
        SocketRegistry.send(userId, {
            type: 'ACTIVITY_LOG',
            payload: log
        });

        // 1. Local Persistence
        let activities = Storage.getFromDB<UserActivity>(this.STORAGE_KEY_ACTIVITY) || [];
        activities.unshift(log);
        if (activities.length > 200) activities = activities.slice(0, 200);
        Storage.saveToDB(this.STORAGE_KEY_ACTIVITY, activities);

        // 2. Cryptographic Ledger
        (async () => {
            let auditType: AuditEventType = 'SECURITY';
            if (['login', 'logout', 'biometric_login', 'password_change'].includes(type)) auditType = 'IDENTITY';
            if (['security_update', 'profile_update', 'settings_change', 'GOVERNANCE_STATUS_UPDATE', 'GOVERNANCE_ROLE_ELEVATION', 'REGULATORY_MATRIX_UPDATE'].includes(type)) auditType = 'ADMIN';
            if (type.includes('attack') || type.includes('denied') || type.includes('fail')) auditType = 'SECURITY';
            if (type.includes('transfer') || type.includes('deposit') || type.includes('SETTLEMENT')) auditType = 'FINANCIAL';

            try {
                await Audit.log(auditType, userId, type, { 
                    status, 
                    details, 
                    device: log.device_info,
                    ip: log.ip_address,
                    actor_name: actorName || 'Authorized Agent',
                    fingerprint: fingerprint,
                    v: '3.6'
                });
            } catch (e) {
                // Buffer handles failure
            }
        })();
        
        return log;
    }

    async getUserActivity(userId: string): Promise<UserActivity[]> {
        const sb = getSupabase();
        if (sb) {
            try {
                const { data, error } = await Promise.race([
                    sb.from('audit_trail')
                      .select('*')
                      .eq('actor_id', userId)
                      .order('timestamp', { ascending: false })
                      .limit(50),
                    new Promise<any>((_, r) => setTimeout(() => r(new Error("TIMEOUT")), 3000))
                ]);
                
                if (error) throw error;

                if (data && data.length > 0) {
                    return data.map((d: any) => ({
                        id: d.id,
                        user_id: d.actor_id,
                        activity_type: d.action || d.event_type,
                        status: d.metadata?.status || 'info',
                        device_info: d.metadata?.device || d.metadata?.ip || 'Verified Node',
                        ip_address: d.metadata?.ip || '0.0.0.0',
                        location: 'Secure Cloud',
                        created_at: d.timestamp,
                        fingerprint: d.metadata?.fingerprint
                    }));
                }
            } catch (e: any) {
                console.warn("[Security] Audit sync timeout. Utilizing local vault.");
            }
        }

        const activities = Storage.getFromDB<UserActivity>(this.STORAGE_KEY_ACTIVITY) || [];
        return activities.filter(a => a.user_id === userId);
    }
}
