import { WebSocket } from 'ws';
import { getAdminSupabase } from '../../services/supabaseClient.js';

class SocketRegistryService {
    private clients: Map<string, WebSocket> = new Map();
    private isListening = false;

    constructor() {
        this.setupRealtime();
    }

    private setupRealtime() {
        if (this.isListening) return;
        const sb = getAdminSupabase();
        if (!sb) {
            console.warn("[SocketRegistry] Supabase client not available. Cross-node broadcast disabled.");
            return;
        }

        sb.channel('system_broadcasts')
            .on('broadcast', { event: 'user_notification' }, (payload) => {
                const { userId, message } = payload.payload;
                this.sendLocal(userId, message);
            })
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    this.isListening = true;
                    console.info("[SocketRegistry] Subscribed to Supabase Realtime for cross-node broadcasts.");
                }
            });
    }

    public register(userId: string, ws: WebSocket) {
        this.clients.set(userId, ws);
        console.info(`[SocketRegistry] Registered client for user: ${userId}`);
    }

    public remove(userId: string) {
        if (this.clients.has(userId)) {
            this.clients.delete(userId);
            console.info(`[SocketRegistry] Removed client for user: ${userId}`);
        }
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
        const sb = getAdminSupabase();
        if (sb) {
            try {
                await sb.channel('system_broadcasts').send({
                    type: 'broadcast',
                    event: 'user_notification',
                    payload: { userId, message: payload }
                });
                return true;
            } catch (e) {
                console.error(`[SocketRegistry] Failed to broadcast to ${userId} via Realtime`, e);
            }
        }
        return false;
    }

    private sendLocal(userId: string, payload: any): boolean {
        const client = this.clients.get(userId);
        if (client && client.readyState === WebSocket.OPEN) {
            try {
                client.send(JSON.stringify(payload));
                return true;
            } catch (e) {
                console.error(`[SocketRegistry] Failed to send locally to ${userId}`, e);
                this.remove(userId);
            }
        }
        return false;
    }

    public broadcast(payload: any) {
        this.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(payload));
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
