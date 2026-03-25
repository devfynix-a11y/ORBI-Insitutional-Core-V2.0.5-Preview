
import { UUID } from '../services/utils.js';
import { getAdminSupabase, getSupabase } from '../services/supabaseClient.js';
import { Audit } from '../backend/security/audit.js';
import { ReconEngine } from '../backend/ledger/reconciliationService.js';
import { Treasury } from '../backend/enterprise/treasuryService.js';
import { RedisStreams } from '../backend/infrastructure/RedisStreams.js';

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
 * Implements a Redis Streams-first distributed job queue with PostgreSQL durability.
 */
class WorkerNodeService {
    private isRunning = false;
    private readonly MAX_ATTEMPTS = 3;
    private readonly CLAIM_BATCH_SIZE = 20;
    private readonly IDLE_POLL_MS = 2500;
    private readonly BUSY_POLL_MS = 150;
    private readonly STREAM_RECOVERY_BATCH_SIZE = 50;
    private readonly RETRY_BASE_MS = Number(process.env.ORBI_BG_JOB_RETRY_BASE_MS || 2000);

    private sleep(ms: number) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

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

        if (RedisStreams.isAvailable()) {
            try {
                const { stream } = RedisStreams.getBackgroundConfig();
                await RedisStreams.publish(stream, { job_id: jobId, type });
            } catch (streamError) {
                console.error('[InternalBroker] Failed to publish Redis stream job:', streamError);
            }
        }

        this.startProcessor();
        return jobId;
    }

    public async startProcessor() {
        if (this.isRunning) return;
        this.isRunning = true;

        setTimeout(async () => {
            if (RedisStreams.isAvailable()) {
                await this.startRedisProcessor();
                return;
            }

            await this.startDatabaseProcessor();
        }, 0);
    }

    private async startRedisProcessor() {
        const { stream, retrySet, deadLetterStream, group, consumer, blockMs, claimIdleMs } = RedisStreams.getBackgroundConfig();
        await RedisStreams.ensureGroup(stream, group);
        await this.recoverPendingJobsToStream();

        while (this.isRunning) {
            await this.drainScheduledRetries(retrySet, stream);

            const claimedStaleMessages = await RedisStreams.autoClaim(
                stream,
                group,
                consumer,
                claimIdleMs,
                this.CLAIM_BATCH_SIZE,
            );

            for (const message of claimedStaleMessages) {
                await this.processStreamJobMessage(stream, group, deadLetterStream, message.id, message.fields.job_id);
            }

            const messages = await RedisStreams.readGroup(
                stream,
                group,
                consumer,
                this.CLAIM_BATCH_SIZE,
                blockMs,
            );

            if (messages.length === 0) {
                await this.recoverPendingJobsToStream();
                continue;
            }

            for (const message of messages) {
                await this.processStreamJobMessage(stream, group, deadLetterStream, message.id, message.fields.job_id);
            }
        }
    }

    private async startDatabaseProcessor() {
        while (this.isRunning) {
            const claimedCount = await this.processDatabaseBatch();
            await this.sleep(claimedCount > 0 ? this.BUSY_POLL_MS : this.IDLE_POLL_MS);
        }
    }

    private async processDatabaseBatch(): Promise<number> {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase) {
            this.isRunning = false;
            return 0;
        }

        const { data: pendingJobs, error: fetchError } = await supabase
            .from('background_jobs')
            .select('id,type,payload,status,attempts,max_attempts,created_at,updated_at,processed_at,last_error')
            .in('status', ['PENDING', 'FAILED'])
            .lt('attempts', this.MAX_ATTEMPTS)
            .order('created_at', { ascending: true })
            .limit(this.CLAIM_BATCH_SIZE);

        if (fetchError || !pendingJobs || pendingJobs.length === 0) {
            return 0;
        }

        let claimedCount = 0;

        for (const pending of pendingJobs as Job[]) {
            const lockedJob = await this.claimJobById(pending.id);
            if (!lockedJob) {
                continue;
            }

            claimedCount += 1;
            await this.executeClaimedJob(lockedJob);
        }

        return claimedCount;
    }

    private async recoverPendingJobsToStream() {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase || !RedisStreams.isAvailable()) {
            return;
        }

        const { data: pendingJobs } = await supabase
            .from('background_jobs')
            .select('id,type,status,attempts,max_attempts,updated_at')
            .in('status', ['PENDING', 'FAILED', 'PROCESSING'])
            .order('created_at', { ascending: true })
            .limit(this.STREAM_RECOVERY_BATCH_SIZE);

        if (!pendingJobs || pendingJobs.length === 0) {
            return;
        }

        const { stream } = RedisStreams.getBackgroundConfig();
        for (const job of pendingJobs) {
            if (!this.isJobRecoverable(job as Job)) {
                continue;
            }

            try {
                await RedisStreams.publish(stream, {
                    job_id: String(job.id),
                    type: String(job.type),
                });
            } catch (error) {
                console.error('[InternalBroker] Failed to recover pending job into Redis stream:', error);
                break;
            }
        }
    }

    private async drainScheduledRetries(retrySet: string, stream: string) {
        const retries = await RedisStreams.drainDueRetries(retrySet, this.CLAIM_BATCH_SIZE);
        for (const retry of retries) {
            try {
                await RedisStreams.publish(stream, retry);
            } catch (error) {
                console.error('[InternalBroker] Failed to release scheduled retry into Redis stream:', error);
                await RedisStreams.scheduleRetry(retrySet, Date.now() + this.RETRY_BASE_MS, retry);
                break;
            }
        }
    }

    private async processStreamJobMessage(
        stream: string,
        group: string,
        deadLetterStream: string,
        streamId: string,
        jobId?: string,
    ) {
        try {
            if (!jobId) {
                return;
            }

            const lockedJob = await this.claimJobById(jobId);
            if (!lockedJob) {
                return;
            }

            await this.executeClaimedJob(lockedJob, deadLetterStream);
        } finally {
            await RedisStreams.ack(stream, group, streamId);
            await RedisStreams.del(stream, streamId);
        }
    }

    private async claimJobById(jobId: string): Promise<Job | null> {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase) {
            return null;
        }

        const { data: existingJob } = await supabase
            .from('background_jobs')
            .select('id,type,payload,status,attempts,max_attempts,created_at,updated_at,processed_at,last_error')
            .eq('id', jobId)
            .maybeSingle();

        if (!existingJob || !this.isJobRecoverable(existingJob as Job)) {
            return null;
        }

        const claimTimestamp = new Date().toISOString();
        const { data: lockedJob, error: lockError } = await supabase
            .from('background_jobs')
            .update({ status: 'PROCESSING', updated_at: claimTimestamp })
            .eq('id', jobId)
            .eq('status', existingJob.status)
            .select('id,type,payload,status,attempts,max_attempts,created_at,updated_at,processed_at,last_error')
            .maybeSingle();

        if (lockError || !lockedJob) {
            return null;
        }

        return lockedJob as Job;
    }

    private async executeClaimedJob(job: Job, deadLetterStream?: string) {
        const supabase = getAdminSupabase() || getSupabase();
        if (!supabase) {
            throw new Error('Supabase client unavailable while processing background job');
        }

        try {
            await this.execute(job);

            await supabase
                .from('background_jobs')
                .update({
                    status: 'COMPLETED',
                    updated_at: new Date().toISOString(),
                    processed_at: new Date().toISOString()
                })
                .eq('id', job.id);
        } catch (e: any) {
            const nextAttempts = job.attempts + 1;
            await supabase
                .from('background_jobs')
                .update({
                    status: 'FAILED',
                    attempts: nextAttempts,
                    last_error: e?.message || String(e),
                    updated_at: new Date().toISOString()
                })
                .eq('id', job.id);

            if (!RedisStreams.isAvailable()) {
                return;
            }

            if (nextAttempts < (job.max_attempts || this.MAX_ATTEMPTS)) {
                try {
                    const { retrySet } = RedisStreams.getBackgroundConfig();
                    await RedisStreams.scheduleRetry(
                        retrySet,
                        Date.now() + this.getRetryDelayMs(nextAttempts),
                        { job_id: job.id, type: job.type },
                    );
                } catch (streamError) {
                    console.error('[InternalBroker] Failed to schedule Redis retry for job:', streamError);
                }
                return;
            }

            if (deadLetterStream) {
                try {
                    await RedisStreams.publish(deadLetterStream, {
                        job_id: job.id,
                        type: job.type,
                        attempts: String(nextAttempts),
                        error: String(e?.message || e),
                        payload: JSON.stringify(job.payload ?? null),
                    });
                } catch (deadLetterError) {
                    console.error('[InternalBroker] Failed to publish dead-letter job:', deadLetterError);
                }
            }
        }
    }

    private isJobRecoverable(job: Job): boolean {
        if (job.status === 'PENDING') {
            return true;
        }

        if (job.status === 'FAILED') {
            return job.attempts < (job.max_attempts || this.MAX_ATTEMPTS) && this.isRetryWindowElapsed(job.attempts, job.updated_at);
        }

        if (job.status === 'PROCESSING') {
            const { claimIdleMs } = RedisStreams.getBackgroundConfig();
            return this.isTimestampOlderThan(job.updated_at, claimIdleMs);
        }

        return false;
    }

    private isRetryWindowElapsed(attempts: number, updatedAt?: string): boolean {
        return this.isTimestampOlderThan(updatedAt, this.getRetryDelayMs(attempts + 1));
    }

    private isTimestampOlderThan(timestamp: string | undefined, thresholdMs: number): boolean {
        if (!timestamp) {
            return true;
        }

        const value = Date.parse(timestamp);
        if (Number.isNaN(value)) {
            return true;
        }

        return Date.now() - value >= thresholdMs;
    }

    private getRetryDelayMs(attemptNumber: number): number {
        return this.RETRY_BASE_MS * Math.max(1, 2 ** Math.max(0, attemptNumber - 1));
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

        const countByStatus = async (status: Job['status']) => {
            const { count } = await supabase
                .from('background_jobs')
                .select('*', { count: 'exact', head: true })
                .eq('status', status);
            return count || 0;
        };

        try {
            const [pending, processing, completed, failed] = await Promise.all([
                countByStatus('PENDING'),
                countByStatus('PROCESSING'),
                countByStatus('COMPLETED'),
                countByStatus('FAILED'),
            ]);

            return {
                pending,
                processing,
                completed,
                failed,
                total_active: pending + processing + completed + failed,
            };
        } catch {
            return { pending: 0, processing: 0, completed: 0, failed: 0, total_active: 0 };
        }
    }
}

export const InternalBroker = new WorkerNodeService();
