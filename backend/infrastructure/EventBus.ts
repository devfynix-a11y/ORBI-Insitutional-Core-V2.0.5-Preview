
import { EventEmitter } from 'events';
import { getAdminSupabase, getSupabase } from '../../services/supabaseClient.js';
import { RedisStreams } from './RedisStreams.js';

export type EventType = 
    | 'transaction:created'
    | 'transaction:authorized'
    | 'transaction:processing'
    | 'transaction:settled'
    | 'transaction:completed'
    | 'transaction:failed'
    | 'transaction:reversed'
    | 'transaction:refunded'
    | 'security:challenge'
    | 'security:block'
    | 'policy:violation'
    | 'user:kyc_updated'
    | 'system:alert'
    | 'alert:critical';

export class EventBus {
    private static instance: EventBus;
    private static readonly MAX_STREAM_PROCESSING_RETRIES = Number(process.env.ORBI_OUTBOX_MAX_STREAM_RETRIES || 3);
    private static readonly OUTBOX_RETRY_BASE_MS = Number(process.env.ORBI_OUTBOX_RETRY_BASE_MS || 5000);
    private static readonly OUTBOX_RETRY_COUNTER_TTL_SECONDS = Number(process.env.ORBI_OUTBOX_RETRY_COUNTER_TTL_SECONDS || 86400);
    private emitter: EventEmitter;
    private outboxTimer: NodeJS.Timeout | null = null;
    private outboxProcessing = false;
    private readonly OUTBOX_BATCH_SIZE = 25;
    private readonly OUTBOX_IDLE_POLL_MS = 5000;
    private readonly OUTBOX_BUSY_POLL_MS = 500;
    private readonly OUTBOX_RECOVERY_BATCH_SIZE = 50;

    private constructor() {
        this.emitter = new EventEmitter();
        // Increase max listeners for high-throughput
        this.emitter.setMaxListeners(100);
        this.startOutboxProcessor();
    }

    public static getInstance(): EventBus {
        if (!EventBus.instance) {
            EventBus.instance = new EventBus();
        }
        return EventBus.instance;
    }

    /**
     * Emits an event to the bus and saves it to the outbox for durability.
     */
    public async emit(event: EventType, payload: any): Promise<void> {
        console.log(`[EventBus] Persisting and dispatching: ${event}`, { ts: Date.now() });

        const sb = getAdminSupabase() || getSupabase();
        if (sb) {
            try {
                const { data: outboxRow, error } = await sb.from('outbox_events').insert({
                    event_type: event,
                    payload: payload,
                    status: 'PENDING'
                }).select('id').single();

                if (error) {
                    throw error;
                }

                if (RedisStreams.isAvailable() && outboxRow?.id) {
                    const { stream } = RedisStreams.getOutboxConfig();
                    await RedisStreams.publish(stream, {
                        event_id: String(outboxRow.id),
                        event_type: String(event),
                    });
                }
            } catch (e) {
                console.error("[EventBus] Failed to persist event", e);
                this.emitter.emit(event, payload);
            }
            return;
        }

        this.emitter.emit(event, payload);
    }

    /**
     * Background worker to process outbox events.
     *
     * Redis Streams is the primary broker when available. PostgreSQL remains the
     * durability and recovery source so pending events can be replayed after
     * broker or process faults. When Redis is unavailable, the legacy DB poller
     * remains active as a compatibility fallback.
     */
    private startOutboxProcessor() {
        if (RedisStreams.isAvailable()) {
            void this.startRedisOutboxProcessor();
            return;
        }

        void this.scheduleNextRun(0);
    }

    private async startRedisOutboxProcessor() {
        const { stream, retrySet, deadLetterStream, group, consumer, blockMs, claimIdleMs } = RedisStreams.getOutboxConfig();
        await RedisStreams.ensureGroup(stream, group);
        await this.recoverPendingEventsToStream();

        while (true) {
            await this.drainScheduledRetries(retrySet, stream);

            const claimedStaleEvents = await RedisStreams.autoClaim(
                stream,
                group,
                consumer,
                claimIdleMs,
                this.OUTBOX_BATCH_SIZE,
            );

            for (const event of claimedStaleEvents) {
                await this.processStreamEvent(stream, group, deadLetterStream, event.id, event.fields.event_id);
            }

            const events = await RedisStreams.readGroup(
                stream,
                group,
                consumer,
                this.OUTBOX_BATCH_SIZE,
                blockMs,
            );

            if (events.length === 0) {
                await this.recoverPendingEventsToStream();
                continue;
            }

            for (const event of events) {
                await this.processStreamEvent(stream, group, deadLetterStream, event.id, event.fields.event_id);
            }
        }
    }

    private async scheduleNextRun(delayMs: number): Promise<void> {
        if (this.outboxTimer) {
            clearTimeout(this.outboxTimer);
            this.outboxTimer = null;
        }

        this.outboxTimer = setTimeout(async () => {
            const nextDelay = await this.processOutbox();
            void this.scheduleNextRun(nextDelay);
        }, delayMs);
    }

    private async processOutbox(): Promise<number> {
        if (this.outboxProcessing) {
            return this.OUTBOX_BUSY_POLL_MS;
        }

        this.outboxProcessing = true;
        try {
            const sb = getAdminSupabase() || getSupabase();
            if (!sb) {
                return this.OUTBOX_IDLE_POLL_MS;
            }

            const { data: events } = await sb.from('outbox_events')
                .select('id,event_type,payload,status,created_at')
                .eq('status', 'PENDING')
                .order('created_at', { ascending: true })
                .limit(this.OUTBOX_BATCH_SIZE);

            if (!events || events.length === 0) {
                return this.OUTBOX_IDLE_POLL_MS;
            }

            let processedCount = 0;
            for (const evt of events) {
                const { data: lockedEvent, error: lockError } = await sb.from('outbox_events')
                    .update({ status: 'PROCESSING', processed_at: new Date().toISOString() })
                    .eq('id', evt.id)
                    .eq('status', 'PENDING')
                    .select('id,event_type,payload')
                    .maybeSingle();

                if (lockError || !lockedEvent) {
                    continue;
                }

                this.emitter.emit(lockedEvent.event_type as EventType, lockedEvent.payload);

                await sb.from('outbox_events')
                    .update({ status: 'PROCESSED', processed_at: new Date().toISOString() })
                    .eq('id', lockedEvent.id);

                processedCount += 1;
            }

            return processedCount > 0 ? this.OUTBOX_BUSY_POLL_MS : this.OUTBOX_IDLE_POLL_MS;
        } catch {
            return this.OUTBOX_IDLE_POLL_MS;
        } finally {
            this.outboxProcessing = false;
        }
    }

    private async recoverPendingEventsToStream() {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb || !RedisStreams.isAvailable()) {
            return;
        }

        const { data: events } = await sb.from('outbox_events')
            .select('id,event_type,status,processed_at')
            .in('status', ['PENDING', 'PROCESSING'])
            .order('created_at', { ascending: true })
            .limit(this.OUTBOX_RECOVERY_BATCH_SIZE);

        if (!events || events.length === 0) {
            return;
        }

        const { stream } = RedisStreams.getOutboxConfig();
        for (const event of events) {
            if (!this.isOutboxRecoverable(event as { status: string; processed_at?: string | null })) {
                continue;
            }

            try {
                await RedisStreams.publish(stream, {
                    event_id: String(event.id),
                    event_type: String(event.event_type),
                });
            } catch (error) {
                console.error('[EventBus] Failed to recover pending outbox event into Redis stream', error);
                break;
            }
        }
    }

    private async drainScheduledRetries(retrySet: string, stream: string) {
        const retries = await RedisStreams.drainDueRetries(retrySet, this.OUTBOX_BATCH_SIZE);
        for (const retry of retries) {
            try {
                await RedisStreams.publish(stream, retry);
            } catch (error) {
                console.error('[EventBus] Failed to release scheduled retry into Redis stream', error);
                await RedisStreams.scheduleRetry(retrySet, Date.now() + EventBus.OUTBOX_RETRY_BASE_MS, retry);
                break;
            }
        }
    }

    private async processStreamEvent(
        stream: string,
        group: string,
        deadLetterStream: string,
        streamId: string,
        outboxEventId?: string,
    ) {
        let lockedEvent: { id: string; event_type: string; payload: any } | null = null;
        try {
            if (!outboxEventId) {
                return;
            }

            lockedEvent = await this.claimOutboxEvent(outboxEventId);
            if (!lockedEvent) {
                return;
            }
            this.emitter.emit(lockedEvent.event_type as EventType, lockedEvent.payload);

            const sb = getAdminSupabase() || getSupabase();
            if (!sb) {
                throw new Error('Supabase client unavailable while finalizing outbox event');
            }

            await sb.from('outbox_events')
                .update({ status: 'PROCESSED', processed_at: new Date().toISOString() })
                .eq('id', lockedEvent.id);
            await RedisStreams.deleteKey(this.getOutboxRetryCounterKey(lockedEvent.id));
        } catch (error) {
            if (lockedEvent) {
                await this.handleOutboxFailure(lockedEvent, deadLetterStream, error);
            }
            console.error('[EventBus] Stream event processing failed', error);
        } finally {
            await RedisStreams.ack(stream, group, streamId);
            await RedisStreams.del(stream, streamId);
        }
    }

    private async claimOutboxEvent(outboxEventId: string) {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) {
            return null;
        }

        const { data: current } = await sb.from('outbox_events')
            .select('id,event_type,payload,status,processed_at')
            .eq('id', outboxEventId)
            .maybeSingle();

        if (!current || !this.isOutboxRecoverable(current)) {
            return null;
        }

        const { data: lockedEvent, error: lockError } = await sb.from('outbox_events')
            .update({ status: 'PROCESSING', processed_at: new Date().toISOString() })
            .eq('id', outboxEventId)
            .eq('status', current.status)
            .select('id,event_type,payload')
            .maybeSingle();

        if (lockError || !lockedEvent) {
            return null;
        }

        return lockedEvent;
    }

    private async handleOutboxFailure(
        lockedEvent: { id: string; event_type: string; payload: any },
        deadLetterStream: string,
        error: unknown,
    ) {
        const sb = getAdminSupabase() || getSupabase();
        const retryCount = await RedisStreams.incrementCounter(
            this.getOutboxRetryCounterKey(lockedEvent.id),
            EventBus.OUTBOX_RETRY_COUNTER_TTL_SECONDS,
        );

        if (retryCount >= EventBus.MAX_STREAM_PROCESSING_RETRIES) {
            if (sb) {
                await sb.from('outbox_events')
                    .update({ status: 'FAILED', processed_at: new Date().toISOString() })
                    .eq('id', lockedEvent.id);
            }

            await RedisStreams.publish(deadLetterStream, {
                event_id: lockedEvent.id,
                event_type: lockedEvent.event_type,
                retries: String(retryCount),
                error: String((error as any)?.message || error),
                payload: JSON.stringify(lockedEvent.payload ?? null),
            });
            return;
        }

        if (sb) {
            await sb.from('outbox_events')
                .update({ status: 'PENDING', processed_at: new Date().toISOString() })
                .eq('id', lockedEvent.id);
        }

        const { retrySet } = RedisStreams.getOutboxConfig();
        await RedisStreams.scheduleRetry(
            retrySet,
            Date.now() + this.getOutboxRetryDelayMs(retryCount),
            {
                event_id: lockedEvent.id,
                event_type: lockedEvent.event_type,
            },
        );
    }

    private isOutboxRecoverable(event: { status: string; processed_at?: string | null }): boolean {
        if (event.status === 'PENDING') {
            return !event.processed_at || this.isTimestampOlderThan(event.processed_at, EventBus.OUTBOX_RETRY_BASE_MS);
        }

        if (event.status === 'PROCESSING') {
            const { claimIdleMs } = RedisStreams.getOutboxConfig();
            return this.isTimestampOlderThan(event.processed_at, claimIdleMs);
        }

        return false;
    }

    private isTimestampOlderThan(timestamp: string | null | undefined, thresholdMs: number): boolean {
        if (!timestamp) {
            return true;
        }

        const value = Date.parse(timestamp);
        if (Number.isNaN(value)) {
            return true;
        }

        return Date.now() - value >= thresholdMs;
    }

    private getOutboxRetryCounterKey(outboxEventId: string): string {
        return `orbi:outbox:retry:${outboxEventId}`;
    }

    private getOutboxRetryDelayMs(retryCount: number): number {
        return EventBus.OUTBOX_RETRY_BASE_MS * Math.max(1, 2 ** Math.max(0, retryCount - 1));
    }

    /**
     * Subscribes to an event.
     */
    public on(event: EventType, callback: (payload: any) => void): void {
        this.emitter.on(event, callback);
    }

    /**
     * Subscribes to an event once.
     */
    public once(event: EventType, callback: (payload: any) => void): void {
        this.emitter.once(event, callback);
    }

    /**
     * Removes a listener.
     */
    public off(event: EventType, callback: (payload: any) => void): void {
        this.emitter.off(event, callback);
    }
}
