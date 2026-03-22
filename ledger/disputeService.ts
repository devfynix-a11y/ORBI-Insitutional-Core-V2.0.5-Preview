
import { UUID } from '../services/utils.js';
import { Storage } from '../backend/storage.js';
import { Audit } from '../backend/security/audit.js';
import { VaultAuditor } from '../backend/security/vaultAuditor.js';
import { TransactionService } from './transactionService.js';
import { DisputeCase, LegalHold } from '../types.js';

class DisputeResolutionService {
    private readonly STORAGE_KEY = 'dps_dispute_registry';
    private txService = new TransactionService();

    public async createDispute(userId: string, txId: string, reason: string, amount: number): Promise<DisputeCase> {
        const id = `DSP-${UUID.generate().substring(0, 8).toUpperCase()}`;
        const dispute: DisputeCase = {
            id,
            transactionId: txId,
            userId,
            userName: 'Pending Resolution',
            amount,
            reason,
            status: 'OPEN',
            priority: amount > 1000 ? 'HIGH' : 'MEDIUM',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        // Automatic Forensic Protection: Apply a legal hold on the contested asset
        await VaultAuditor.applyHold('TRANSACTION', txId, `Dispute ${id} initiated: ${reason}`, 'SYSTEM_PILOT');

        const cases = this.getAllCases();
        cases.unshift(dispute);
        Storage.setItem(this.STORAGE_KEY, JSON.stringify(cases));

        await Audit.log('ADMIN', userId, 'DISPUTE_FILED', { disputeId: id, txId });
        return dispute;
    }

    public async resolveCase(caseId: string, action: 'RESOLVED' | 'REJECTED', notes: string, actorId: string): Promise<boolean> {
        const cases = this.getAllCases();
        const idx = cases.findIndex(c => c.id === caseId);
        if (idx === -1) return false;

        const current = cases[idx];
        
        // 1. Perform Reversal if action is RESOLVED
        if (action === 'RESOLVED') {
            try {
                await this.txService.reverseTransaction(current.transactionId, actorId);
                console.info(`[DisputeCenter] Reversal protocol finished for ${caseId}`);
            } catch (e: any) {
                console.error(`[DisputeCenter] Reversal Failed: ${e.message}`);
                throw new Error(`REVERSAL_PROTOCOL_FAULT: ${e.message}`);
            }
        }

        // 2. Update Status
        current.status = action;
        current.resolutionNotes = notes;
        current.updatedAt = new Date().toISOString();

        // 3. Release the forensic hold
        const holds = await VaultAuditor.getActiveHolds();
        const matchingHold = holds.find(h => h.targetId === current.transactionId);
        if (matchingHold) {
            await VaultAuditor.releaseHold(matchingHold.id, actorId);
        }

        Storage.setItem(this.STORAGE_KEY, JSON.stringify(cases));
        await Audit.log('ADMIN', actorId, 'DISPUTE_RESOLVED', { caseId, action, notes });
        return true;
    }

    public getAllCases(): DisputeCase[] {
        try {
            const raw = Storage.getItem(this.STORAGE_KEY);
            return raw ? JSON.parse(raw) : [];
        } catch (e) { return []; }
    }
}

export const DisputeService = new DisputeResolutionService();
