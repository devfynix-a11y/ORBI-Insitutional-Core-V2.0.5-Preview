
import { UUID } from '../services/utils.js';
import { getAdminSupabase, getSupabase } from '../services/supabaseClient.js';
import { Audit } from '../backend/security/audit.js';
import { ReconEngine } from '../backend/ledger/reconciliationService.js';
import { Treasury } from '../backend/enterprise/treasuryService.js';

export type JobType = 'AI_REPORT_GEN' | 'LEDGER_RECONCILE' | 'TAX_SETTLEMENT' | 'NOTIFICATION_FANOUT' | 'PARTNER_RECONCILE' | 'TREASURY_AUTO_SWEEP' | 'STUCK_TX_REAP';

interface Job {
    id: string;
    type: JobType;
    payload: any;
    status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
    attempts: number;
    max_attempts: number;
    last_error?: string;
    created_at: string;
    updated_at: string;
    processed_at?: string;
}

/**
 * ORBI INTERNAL WORKER NODE (V4.0 - Enterprise)
 * Implements a robust distributed job queue backed by PostgreSQL.
 */
class WorkerNodeService {
    private isRunning = false;
    private readonly MAX_ATTEMPTS = 3;

    public async push(type: JobType, payload: any) {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase) {
            console.warn('[InternalBroker] Supabase client not initialized, skipping job push');
            return null;
        }
        const jobId = UUID.generate();
        
        const { error } = await supabase
            .from('background_jobs')
            .insert({
                id: jobId,
                type,
                payload,
                status: 'PENDING',
                attempts: 0,
                max_attempts: this.MAX_ATTEMPTS
            });

        if (error) {
            console.error('[InternalBroker] Failed to push job:', error);
            throw new Error('Failed to enqueue background job');
        }

        this.startProcessor();
        return jobId;
    }

    public async startProcessor() {
        if (this.isRunning) return;
        this.isRunning = true;
        
        // Execute processor in next tick to ensure API responsiveness
        setTimeout(async () => {
            while (this.isRunning) {
                const supabase = getAdminSupabase() || getSupabase();
                if (!supabase) {
                    this.isRunning = false;
                    break;
                }
                
                // 1. Fetch next pending job using SKIP LOCKED to prevent concurrent processing
                // Note: Supabase JS client doesn't directly support SKIP LOCKED, so we use an RPC or optimistic locking.
                // For this implementation, we will use a simple optimistic lock approach by updating the status.
                const { data: pendingJobs, error: fetchError } = await supabase
                    .from('background_jobs')
                    .select('*')
                    .in('status', ['PENDING', 'FAILED'])
                    .lt('attempts', this.MAX_ATTEMPTS)
                    .order('created_at', { ascending: true })
                    .limit(1);

                if (fetchError || !pendingJobs || pendingJobs.length === 0) {
                    this.isRunning = false;
                    break;
                }

                const pending = pendingJobs[0] as Job;

                // 2. Optimistically lock the job
                const { data: lockedJob, error: lockError } = await supabase
                    .from('background_jobs')
                    .update({ status: 'PROCESSING', updated_at: new Date().toISOString() })
                    .eq('id', pending.id)
                    .in('status', ['PENDING', 'FAILED'])
                    .select()
                    .single();

                if (lockError || !lockedJob) {
                    // Another worker grabbed it, continue to next
                    continue;
                }

                try {
                    // 3. Execute job
                    await this.execute(lockedJob as Job);

                    // 4. Mark completed
                    await supabase
                        .from('background_jobs')
                        .update({ 
                            status: 'COMPLETED', 
                            updated_at: new Date().toISOString(),
                            processed_at: new Date().toISOString()
                        })
                        .eq('id', lockedJob.id);

                } catch (e: any) {
                    // 5. Mark failed
                    await supabase
                        .from('background_jobs')
                        .update({ 
                            status: 'FAILED', 
                            attempts: lockedJob.attempts + 1,
                            last_error: e.message || String(e),
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', lockedJob.id);
                } finally {
                    // Throttle to prevent CPU spikes
                    await new Promise(r => setTimeout(r, 1000)); 
                }
            }
        }, 0);
    }

    private async execute(job: Job) {
        switch(job.type) {
            case 'AI_REPORT_GEN':
                await new Promise(r => setTimeout(r, 4000));
                break;
            case 'LEDGER_RECONCILE':
                await Audit.log('ADMIN', 'system', 'BACKGROUND_RECONCILE_COMMIT', { jobId: job.id });
                break;
            case 'PARTNER_RECONCILE':
                await ReconEngine.reconcileVaultsAgainstPartners();
                break;
            case 'STUCK_TX_REAP':
                await ReconEngine.reapStuckTransactions();
                break;
            case 'TREASURY_AUTO_SWEEP':
                if (job.payload?.organizationId) {
                    await Treasury.executeAutoSweep(job.payload.organizationId);
                }
                break;
        }
    }

    public async getQueueStatus() {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase) {
            return { pending: 0, processing: 0, completed: 0, failed: 0, total_active: 0 };
        }
        const { data, error } = await supabase
            .from('background_jobs')
            .select('status');
            
        if (error || !data) {
            return { pending: 0, processing: 0, completed: 0, failed: 0, total_active: 0 };
        }

        return {
            pending: data.filter(j => j.status === 'PENDING').length,
            processing: data.filter(j => j.status === 'PROCESSING').length,
            completed: data.filter(j => j.status === 'COMPLETED').length,
            failed: data.filter(j => j.status === 'FAILED').length,
            total_active: data.length
        };
    }
}

export const InternalBroker = new WorkerNodeService();
