
import { getSupabase } from '../../services/supabaseClient.js';
import { UUID } from '../../services/utils.js';
import { InfraSnapshot } from '../../types.js';
import { Storage } from '../storage.js';

/**
 * INFRASTRUCTURE PERSISTENCE NODE (V1.1)
 * Sovereign storage for cluster metrics and system topology snapshots.
 */
export class InfraPersistenceService {
    private readonly STORAGE_KEY = 'dps_infra_history';
    
    /**
     * COMMIT CLUSTER SNAPSHOT
     * Persists the current state of pods, circuits, and catalog.
     */
    public async saveSnapshot(actorId: string, data: any): Promise<InfraSnapshot> {
        const id = UUID.generate();
        const snapshot: InfraSnapshot = {
            id,
            actor_id: actorId,
            snapshot_data: data,
            created_at: new Date().toISOString()
        };

        const sb = getSupabase();
        if (sb) {
            try {
                await sb.from('infra_snapshots').insert({
                    id: snapshot.id,
                    actor_id: snapshot.actor_id,
                    snapshot_data: snapshot.snapshot_data,
                    created_at: snapshot.created_at
                });
            } catch (e) {
                console.warn("[InfraPersistence] Cloud insert failed. Retaining local copy.");
            }
        }

        const history = this.getLocalHistory();
        history.unshift(snapshot);
        Storage.setItem(this.STORAGE_KEY, JSON.stringify(history.slice(0, 50)));

        return snapshot;
    }

    /**
     * RETRIEVE SNAPSHOT HISTORY
     */
    public async getHistory(): Promise<InfraSnapshot[]> {
        const sb = getSupabase();
        if (sb) {
            try {
                const { data } = await sb.from('infra_snapshots')
                    .select('*')
                    .order('created_at', { ascending: false })
                    .limit(50);
                return data || [];
            } catch (e) {}
        }
        return this.getLocalHistory();
    }

    private getLocalHistory(): InfraSnapshot[] {
        try {
            const raw = Storage.getItem(this.STORAGE_KEY);
            return raw ? JSON.parse(raw) : [];
        } catch (e) { return []; }
    }
}

export const InfraPersistence = new InfraPersistenceService();
