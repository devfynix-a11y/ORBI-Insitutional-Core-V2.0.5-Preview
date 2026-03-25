import { CloudEvent } from '../EnterpriseTypes.js';
import { UUID } from '../../../services/utils.js';
import { getAdminSupabase } from '../../../services/supabaseClient.js';
import { RedisStreams } from '../../infrastructure/RedisStreams.js';

/**
 * Enterprise Event Bus
 * Implements the Outbox Pattern / PubSub for decoupled asynchronous processing.
 */
export class EventBus {
    
    /**
     * Publishes a standardized CloudEvent to the message broker.
     */
    public static async publish(type: string, source: string, data: any): Promise<void> {
        const event: CloudEvent = {
            specversion: "1.0",
            type,
            source,
            id: `evt-${UUID.generate()}`,
            time: new Date().toISOString(),
            datacontenttype: "application/json",
            data
        };

        console.log(`[EventBus] 📢 Publishing Event: ${type}`, event.id);
        
        // 1. Save to outbox for durability, then fan out via Redis Streams when available.
        const sb = getAdminSupabase();
        if (sb) {
            try {
                const { data: outboxRow, error } = await sb.from('outbox_events').insert({
                    event_type: type,
                    payload: event,
                    status: 'PENDING'
                }).select('id').single();

                if (error) {
                    throw error;
                }

                if (RedisStreams.isAvailable() && outboxRow?.id) {
                    const { stream } = RedisStreams.getOutboxConfig();
                    await RedisStreams.publish(stream, {
                        event_id: String(outboxRow.id),
                        event_type: String(type),
                    });
                }
            } catch (e) {
                console.error("[EventBus] Failed to save to outbox", e);
            }
        }

        // 2. Preview-only local simulation remains for enterprise sidecar consumers.
        this.simulateAsyncConsumers(event);
    }

    private static simulateAsyncConsumers(event: CloudEvent) {
        setTimeout(() => {
            if (event.type === 'fintech.transaction.settled') {
                console.log(`[Consumer:Notifications] Sending receipt for TX: ${event.data.transactionId}`);
                console.log(`[Consumer:FraudML] Updating behavioral baseline for wallets.`);
                console.log(`[Consumer:Reconciliation] Logging entry for EOD settlement.`);
            }
        }, 100);
    }
}
