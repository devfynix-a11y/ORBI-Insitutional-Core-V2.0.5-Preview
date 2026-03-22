
import { EventBus } from './EventBus.js';
import { Messaging } from '../features/MessagingService.js';
import { getAdminSupabase } from '../../services/supabaseClient.js';
import { SocketRegistry } from './SocketRegistry.js';

/**
 * NotificationSubscriber
 * Listens to EventBus events and triggers external notifications (SMS, Email, Push).
 */
export class NotificationSubscriber {
    public static init() {
        const eventBus = EventBus.getInstance();

        // Listen for completed transactions
        eventBus.on('transaction:completed', async (payload) => {
            const { txId, metadata } = payload;
            console.log(`[NotificationSubscriber] Handling transaction:completed for ${txId}`);
            
            // In a real system, we would fetch transaction details and notify users
            // For now, we log the event
        });

        // Listen for failed transactions
        eventBus.on('transaction:failed', async (payload) => {
            const { txId, metadata } = payload;
            console.warn(`[NotificationSubscriber] ALERT: Transaction failed for ${txId}`, metadata);
        });

        // Listen for security blocks
        eventBus.on('security:block', async (payload) => {
            const { userId, reason } = payload;
            const sb = getAdminSupabase();
            let language = 'en';
            if (sb) {
                const { data: user } = await sb.from('users').select('language').eq('id', userId).maybeSingle();
                language = user?.language || 'en';
            }
            const subject = language === 'sw' ? 'Tahadhari ya Usalama' : 'Security Alert';
            const body = language === 'sw' 
                ? `Akaunti yako imezuiwa kwa muda kutokana na: ${reason}` 
                : `Your account has been temporarily restricted due to: ${reason}`;

            await Messaging.dispatch(userId, 'security', subject, body, { sms: true, email: true });
        });

        console.info('[NotificationSubscriber] Initialized and listening for events.');
    }
}
