
import { LegalHold, ForensicReport } from '../../types.js';
import { getSupabase } from '../supabaseClient.js';
import { UUID } from '../../services/utils.js';
import { Audit } from './audit.js';
import { Storage } from '../storage.js';

/**
 * ORBI VAULT AUDITOR (V1.1)
 * Handles Forensic Data Preservation and Legal Holds.
 */
class VaultAuditorService {
    private readonly STORAGE_KEY = 'orbi_legal_holds';

    public async applyHold(targetType: 'TRANSACTION' | 'USER' | 'WALLET', targetId: string, reason: string, actorId: string): Promise<LegalHold> {
        const hold: LegalHold = {
            id: UUID.generate(),
            targetType,
            targetId,
            reason,
            active: true,
            issuedBy: actorId,
            issuedAt: new Date().toISOString()
        };

        const sb = getSupabase();
        if (sb) {
            await sb.from('legal_holds').insert({
                id: hold.id,
                target_type: hold.targetType,
                target_id: hold.targetId, // Postgres expects UUID
                reason: hold.reason,
                active: true,
                issued_by: hold.issuedBy,
                issued_at: hold.issuedAt
            });
        } else {
            const holds = this.getLocalHolds();
            holds.push(hold);
            Storage.setItem(this.STORAGE_KEY, JSON.stringify(holds));
        }

        await Audit.log('ADMIN', actorId, 'LEGAL_HOLD_APPLIED', { holdId: hold.id, targetId, type: targetType });
        return hold;
    }

    public async releaseHold(holdId: string, actorId: string): Promise<boolean> {
        const releasedAt = new Date().toISOString();
        const sb = getSupabase();
        
        if (sb) {
            const { error } = await sb.from('legal_holds')
                .update({ active: false, released_at: releasedAt })
                .eq('id', holdId);
            if (error) return false;
        } else {
            const holds = this.getLocalHolds();
            const idx = holds.findIndex(h => h.id === holdId);
            if (idx === -1) return false;
            holds[idx].active = false;
            holds[idx].releasedAt = releasedAt;
            Storage.setItem(this.STORAGE_KEY, JSON.stringify(holds));
        }

        await Audit.log('ADMIN', actorId, 'LEGAL_HOLD_RELEASED', { holdId });
        return true;
    }

    public async isHeld(targetType: 'TRANSACTION' | 'USER' | 'WALLET', targetId: string): Promise<boolean> {
        const sb = getSupabase();
        if (sb) {
            const { data } = await sb.from('legal_holds')
                .select('id')
                .eq('target_type', targetType)
                .eq('target_id', targetId)
                .eq('active', true)
                .limit(1);
            return !!data && data.length > 0;
        }

        const holds = this.getLocalHolds();
        return holds.some(h => h.active && h.targetType === targetType && h.targetId === targetId);
    }

    public async getForensicReport(): Promise<ForensicReport> {
        const auditStatus = await Audit.verifyIntegrity();
        const activeHolds = await this.getActiveHolds();

        return {
            timestamp: new Date().toISOString(),
            holds: activeHolds,
            anomalyCount: auditStatus.report.failures.length,
            integrityStatus: auditStatus.valid ? 'VALID' : 'TAMPERED'
        };
    }

    public async getActiveHolds(): Promise<LegalHold[]> {
        const sb = getSupabase();
        if (sb) {
            const { data } = await sb.from('legal_holds').select('*').eq('active', true);
            return (data || []).map(d => ({
                id: d.id,
                targetType: d.target_type,
                targetId: d.target_id,
                reason: d.reason,
                active: d.active,
                issuedBy: d.issued_by,
                issuedAt: d.issued_at
            }));
        }
        return this.getLocalHolds().filter(h => h.active);
    }

    private getLocalHolds(): LegalHold[] {
        try {
            const raw = Storage.getItem(this.STORAGE_KEY);
            return raw ? JSON.parse(raw) : [];
        } catch (e) { return []; }
    }
}

export const VaultAuditor = new VaultAuditorService();
