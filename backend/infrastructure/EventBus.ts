
import { EventEmitter } from 'events';
import { getAdminSupabase, getSupabase } from '../../services/supabaseClient.js';

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
    private emitter: EventEmitter;
    private outboxTimer: any | null = null;

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
        console.log(`[EventBus] Emitting locally and saving to outbox: ${event}`, { ts: Date.now() });
        
        // 1. Emit locally immediately for fast in-memory processing
        this.emitter.emit(event, payload);

        // 2. Save to Outbox for durability (guaranteed delivery)
        const sb = getAdminSupabase() || getSupabase();
        if (sb) {
            try {
                await sb.from('outbox_events').insert({
                    event_type: event,
                    payload: payload,
                    status: 'PENDING'
                });
            } catch (e) {
                console.error("[EventBus] Failed to save to outbox", e);
            }
        }
    }

    /**
     * Background worker to process outbox events (simulating a message broker).
     * 
     * NOTE: For true microservice eventing, high-throughput asynchronous processing,
     * and guaranteed ordered delivery across multiple consumer groups, an external
     * message broker like Kafka or RabbitMQ is necessary. This database-backed
     * outbox pattern is robust for single-monolith or simple distributed setups,
     * but will face contention at extreme scale.
     */
    private startOutboxProcessor() {
        // Poll outbox every 5 seconds for missed/pending events
        this.outboxTimer = setInterval(async () => {
            const sb = getAdminSupabase() || getSupabase();
            if (!sb) return;

            try {
                // Fetch pending events
                const { data: events } = await sb.from('outbox_events')
                    .select('*')
                    .eq('status', 'PENDING')
                    .order('created_at', { ascending: true })
                    .limit(10);

                if (events && events.length > 0) {
                    for (const evt of events) {
                        // Optimistically lock the event
                        const { data: lockedEvent, error: lockError } = await sb.from('outbox_events')
                            .update({ status: 'PROCESSING' })
                            .eq('id', evt.id)
                            .eq('status', 'PENDING')
                            .select()
                            .single();

                        if (lockError || !lockedEvent) {
                            // Another instance grabbed it
                            continue;
                        }

                        // Re-emit event for any subscribers that missed it (e.g., after crash)
                        // In a real distributed system, this would push to Kafka/RabbitMQ
                        this.emitter.emit(evt.event_type as EventType, evt.payload);
                        
                        // Mark as processed
                        await sb.from('outbox_events')
                            .update({ status: 'PROCESSED', processed_at: new Date().toISOString() })
                            .eq('id', evt.id);
                    }
                }
            } catch (e) {
                // Silent catch for background worker
            }
        }, 5000);
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
