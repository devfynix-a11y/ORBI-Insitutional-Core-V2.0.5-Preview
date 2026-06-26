import { WebSocket } from 'ws';
import type { Cluster, Redis } from 'ioredis';
import { getAdminSupabase } from '../../services/supabaseClient.js';
import { logger } from './logger.js';
import { RedisClusterFactory } from './RedisClusterFactory.js';

const socketLogger = logger.child({ component: 'socket_registry' });
const broadcastTopic = 'orbi:realtime:user-notifications';

class SocketRegistryService {
    private clients: Map<string, Set<WebSocket>> = new Map();
    private isListening = false;
    private broadcastChannel: ReturnType<NonNullable<ReturnType<typeof getAdminSupabase>>['channel']> | null = null;
    private broadcastChannelReady: Promise<void> | null = null;
    private valkeyPublisher: Cluster | Redis | null = null;
    private valkeySubscriber: Cluster | Redis | null = null;

    constructor() {
        this.setupRealtime();
    }

    private setupRealtime() {
        if (this.broadcastChannelReady) return;
        const usesLocalData =
            String(process.env.ORBI_DATA_PROVIDER || '').trim().toLowerCase() === 'local';
        if (usesLocalData) {
            this.setupValkeyRealtime();
            return;
        }

        const sb = getAdminSupabase();
        if (!sb) {
            socketLogger.warn('socket_registry.supabase_unavailable');
            return;
        }

        const channel = sb.channel('system_broadcasts');
        this.broadcastChannel = channel;
        this.broadcastChannelReady = new Promise((resolve) => {
            channel
            .on('broadcast', { event: 'user_notification' }, (payload) => {
                const { userId, message } = payload.payload;
                this.sendLocal(userId, message);
            })
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    this.isListening = true;
                    socketLogger.info('socket_registry.realtime_subscribed');
                    resolve();
                }
            });
        });
    }

    private setupValkeyRealtime() {
        const client = RedisClusterFactory.getClient('monitor');
        if (!client) {
            socketLogger.warn('socket_registry.valkey_unavailable');
            return;
        }

        this.valkeyPublisher = client;
        this.valkeySubscriber = client.duplicate();
        this.broadcastChannelReady = new Promise((resolve) => {
            const subscriber = this.valkeySubscriber!;
            subscriber.on('message', (channel, rawPayload) => {
                if (channel !== broadcastTopic) return;
                try {
                    const payload = JSON.parse(rawPayload);
                    if (payload?.userId) this.sendLocal(payload.userId, payload.message);
                } catch (error) {
                    socketLogger.error('socket_registry.valkey_payload_invalid', undefined, error);
                }
            });
            subscriber.subscribe(broadcastTopic)
                .then(() => {
                    this.isListening = true;
                    socketLogger.info('socket_registry.valkey_subscribed');
                    resolve();
                })
                .catch((error) => {
                    socketLogger.error('socket_registry.valkey_subscribe_failed', undefined, error);
                    this.broadcastChannelReady = null;
                });
        });
    }

    public register(userId: string, ws: WebSocket) {
        const existing = this.clients.get(userId) || new Set<WebSocket>();
        existing.add(ws);
        this.clients.set(userId, existing);
        socketLogger.info('socket_registry.client_registered', { actor_id: userId, connection_count: existing.size });
    }

    public remove(userId: string, ws?: WebSocket) {
        const existing = this.clients.get(userId);
        if (!existing) return;

        if (ws) {
            existing.delete(ws);
            if (existing.size > 0) {
                socketLogger.info('socket_registry.client_removed', { actor_id: userId, connection_count: existing.size });
                return;
            }
        }

        this.clients.delete(userId);
        socketLogger.info('socket_registry.client_registry_removed', { actor_id: userId });
    }

    /**
     * Sends a message to a user. If the user is connected locally, it sends directly.
     * Otherwise, it broadcasts via Supabase Realtime to reach other nodes.
     */
    public async send(userId: string, payload: any) {
        // Try local first
        if (this.sendLocal(userId, payload)) {
            return true;
        }

        // If not local, broadcast to other nodes
        if (this.broadcastChannel && this.broadcastChannelReady) {
            try {
                await this.broadcastChannelReady;
                await this.broadcastChannel.send({
                    type: 'broadcast',
                    event: 'user_notification',
                    payload: { userId, message: payload }
                });
                return true;
            } catch (e) {
                socketLogger.error('socket_registry.realtime_broadcast_failed', { actor_id: userId }, e);
            }
        }

        if (this.valkeyPublisher && this.broadcastChannelReady) {
            try {
                await this.broadcastChannelReady;
                await this.valkeyPublisher.publish(
                    broadcastTopic,
                    JSON.stringify({ userId, message: payload }),
                );
                return true;
            } catch (e) {
                socketLogger.error('socket_registry.valkey_broadcast_failed', { actor_id: userId }, e);
            }
        }
        return false;
    }

    private sendLocal(userId: string, payload: any): boolean {
        const clients = this.clients.get(userId);
        if (!clients || clients.size == 0) {
            return false;
        }

        let delivered = false;
        for (const client of [...clients]) {
            if (client.readyState !== WebSocket.OPEN) {
                clients.delete(client);
                continue;
            }

            try {
                client.send(JSON.stringify(payload));
                delivered = true;
            } catch (e) {
                socketLogger.error('socket_registry.local_send_failed', { actor_id: userId }, e);
                clients.delete(client);
            }
        }

        if (clients.size === 0) {
            this.clients.delete(userId);
        }

        return delivered;
    }

    public broadcast(payload: any) {
        this.clients.forEach((clients, userId) => {
            for (const client of [...clients]) {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify(payload));
                } else {
                    clients.delete(client);
                }
            }
            if (clients.size === 0) {
                this.clients.delete(userId);
            }
        });
    }

    /**
     * Notifies a user that their balance has changed.
     */
    public notifyBalanceUpdate(userId: string, walletId: string, newBalance: number) {
        return this.send(userId, {
            type: 'BALANCE_UPDATE',
            payload: { walletId, balance: newBalance, timestamp: Date.now() }
        });
    }

    /**
     * Notifies a user about a transaction status change.
     */
    public notifyTransactionUpdate(userId: string, transaction: any) {
        return this.send(userId, {
            type: 'TRANSACTION_UPDATE',
            payload: { ...transaction, timestamp: Date.now() }
        });
    }
}

export const SocketRegistry = new SocketRegistryService();
