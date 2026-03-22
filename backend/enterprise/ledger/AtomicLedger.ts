import { getSupabase } from '../../supabaseClient.js';

/**
 * Enterprise Atomic Ledger
 * Interfaces with the PostgreSQL RPC to guarantee ACID-compliant double-entry commits.
 */
export class AtomicLedger {
    
    /**
     * Commits a transaction atomically using the database RPC.
     * Guarantees that the transaction, journal entries, and wallet balances are updated together.
     */
    public static async commit(payload: {
        idempotencyKey: string;
        referenceId: string;
        amount: number;
        currency: string;
        sourceWalletId: string;
        targetWalletId: string;
        metadata: any;
    }): Promise<{ success: boolean, transactionId?: string, error?: string }> {
        
        const sb = getSupabase();
        if (!sb) throw new Error("DB_OFFLINE");

        try {
            // Call the atomic RPC defined in enterprise_schema.sql
            const { data, error } = await sb.rpc('enterprise_commit_transaction', {
                p_idempotency_key: payload.idempotencyKey,
                p_reference_id: payload.referenceId,
                p_amount: payload.amount,
                p_currency: payload.currency,
                p_source_wallet_id: payload.sourceWalletId,
                p_target_wallet_id: payload.targetWalletId,
                p_metadata: payload.metadata
            });

            if (error) {
                console.error("[AtomicLedger] RPC Execution Error:", error);
                return { success: false, error: error.message };
            }

            if (!data.success) {
                console.error("[AtomicLedger] Commit Rejected:", data.error);
                return { success: false, error: data.error };
            }

            return { success: true, transactionId: data.transaction_id };

        } catch (err: any) {
            console.error("[AtomicLedger] Fatal Commit Error:", err);
            return { success: false, error: err.message };
        }
    }
}
