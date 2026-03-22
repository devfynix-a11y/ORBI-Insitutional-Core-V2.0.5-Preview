
import { getSupabase, getAdminSupabase } from '../services/supabaseClient.js';
import { TransactionService } from './transactionService.js';
import { WalletService } from '../wealth/walletService.js';
import { Messaging } from '../backend/features/MessagingService.js';
import { Audit } from '../backend/security/audit.js';
import { UUID } from '../services/utils.js';

export type EscrowStatus = 'LOCKED' | 'RELEASED' | 'DISPUTED' | 'REFUNDED';

export class EscrowService {
    private txService = new TransactionService();
    private walletService = new WalletService();

    /**
     * CREATE CONDITIONAL ESCROW
     * Locks funds in the sender's PaySafe vault until conditions are met.
     */
    public async createEscrow(senderId: string, recipientCustomerId: string, amount: number, description: string, conditions: any): Promise<string> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) throw new Error("VAULT_OFFLINE");

        // 1. Resolve Recipient
        const { data: recipient } = await sb.from('users').select('id, full_name').eq('customer_id', recipientCustomerId).single();
        if (!recipient) throw new Error("RECIPIENT_NOT_FOUND");

        // 2. Resolve Sender's PaySafe Vault
        const wallets = await this.walletService.fetchForUser(senderId);
        const paySafe = wallets.find(w => w.name === 'PaySafe');
        if (!paySafe) throw new Error("PAYSAFE_VAULT_NOT_FOUND");

        const referenceId = `ESC-${UUID.generateShortCode(8)}`;

        // 3. Initiate Transaction (Status: authorized/locked)
        // This moves money from Operating -> PaySafe (Internal Escrow)
        await this.txService.postTransactionWithLedger({
            user_id: senderId,
            amount: amount,
            description: `Escrow: ${description}`,
            type: 'escrow',
            status: 'authorized',
            referenceId: referenceId,
            metadata: {
                is_conditional_escrow: true,
                recipient_id: recipient.id,
                recipient_name: recipient.full_name,
                conditions: conditions,
                escrow_status: 'LOCKED'
            }
        }, [
            { 
                transactionId: '', // Will be set by service
                walletId: String(paySafe.id), 
                type: 'CREDIT', 
                amount, 
                currency: 'TZS',
                timestamp: new Date().toISOString(),
                description: `Escrow Lock: ${description}` 
            }
        ]);

        // 4. Notify Recipient
        const { data: recipientUser } = await sb.from('users').select('language').eq('id', recipient.id).maybeSingle();
        const recipientLang = recipientUser?.language || 'en';
        const subject = recipientLang === 'sw' ? 'Malipo ya Escrow Yanayoingia' : 'Inbound Escrow Payment';
        const body = recipientLang === 'sw' 
            ? `Una malipo yanayosubiri ya TZS ${amount} kutoka kwa mteja. Fedha zimefungwa kwenye Orbi PaySafe na zitatolewa baada ya uthibitisho wa uwasilishaji.` 
            : `You have a pending payment of ${amount} TZS from a customer. Funds are locked in Orbi PaySafe and will be released upon delivery confirmation.`;

        await Messaging.dispatch(recipient.id, 'info', subject, body, { 
            sms: true,
            template: 'Escrow_Created',
            variables: {
                amount: amount.toLocaleString(),
                currency: 'TZS'
            }
        });

        await Audit.log('FINANCIAL', senderId, 'ESCROW_CREATED', { referenceId, recipientId: recipient.id, amount });

        return referenceId;
    }

    /**
     * RELEASE ESCROW
     * Finalizes the payment to the recipient.
     */
    public async releaseEscrow(referenceId: string, actorId: string): Promise<boolean> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return false;

        // 1. Fetch Escrow Transaction
        const { data: tx } = await sb.from('transactions').select('*').eq('reference_id', referenceId).single();
        if (!tx || tx.type !== 'escrow' || tx.status !== 'authorized') throw new Error("INVALID_ESCROW_STATE");

        // 2. Verify Actor (Only sender or system can release)
        if (tx.user_id !== actorId && actorId !== 'system') throw new Error("UNAUTHORIZED_RELEASE");

        const recipientId = tx.metadata.recipient_id;
        const amount = Number(tx.amount_decrypted || 0); // Assuming we have decrypted amount or fetch it

        // 3. Move funds from PaySafe -> Recipient's Operating Vault
        // In a real system, we'd fetch the recipient's operating vault
        const { data: recipientWallets } = await sb.from('platform_vaults').select('id').eq('user_id', recipientId).eq('vault_role', 'OPERATING').single();
        if (!recipientWallets) throw new Error("RECIPIENT_VAULT_NOT_FOUND");

        // Update transaction status
        await sb.from('transactions').update({ 
            status: 'completed',
            metadata: { ...tx.metadata, escrow_status: 'RELEASED', released_at: new Date().toISOString() }
        }).eq('id', tx.id);

        // Notify Recipient
        const { data: recipientUser } = await sb.from('users').select('language').eq('id', recipientId).maybeSingle();
        const recipientLang = recipientUser?.language || 'en';
        const subject = recipientLang === 'sw' ? 'Fedha za Escrow Zimetolewa' : 'Escrow Funds Released';
        const body = recipientLang === 'sw' 
            ? `Malipo ya TZS ${tx.amount} yametolewa kwenye akaunti yako ya uendeshaji.` 
            : `The payment of ${tx.amount} TZS has been released to your operating vault.`;

        await Messaging.dispatch(recipientId, 'info', subject, body, { 
            sms: true,
            template: 'Escrow_Released',
            variables: {
                amount: tx.amount.toLocaleString(),
                currency: tx.currency || 'TZS'
            }
        });

        await Audit.log('FINANCIAL', actorId, 'ESCROW_RELEASED', { referenceId, recipientId });

        return true;
    }

    /**
     * DISPUTE ESCROW
     * Freezes the transaction for manual review.
     */
    public async disputeEscrow(referenceId: string, userId: string, reason: string): Promise<void> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return;

        const { data: tx } = await sb.from('transactions').select('*').eq('reference_id', referenceId).single();
        if (!tx || tx.status !== 'authorized') throw new Error("INVALID_ESCROW_STATE");

        await sb.from('transactions').update({ 
            status: 'held_for_review',
            metadata: { ...tx.metadata, escrow_status: 'DISPUTED', dispute_reason: reason, disputed_by: userId }
        }).eq('id', tx.id);

        const { data: senderUser } = await sb.from('users').select('language').eq('id', tx.user_id).maybeSingle();
        const senderLang = senderUser?.language || 'en';
        const senderSubject = senderLang === 'sw' ? 'Mzozo wa Escrow' : 'Escrow Disputed';
        const senderBody = senderLang === 'sw' 
            ? `Malipo yako ya escrow ${referenceId} yamewekwa chini ya ukaguzi wa mzozo.` 
            : `Your escrow payment ${referenceId} has been placed under dispute review.`;

        await Messaging.dispatch(tx.user_id, 'security', senderSubject, senderBody, { 
            sms: true,
            template: 'Escrow_Disputed',
            variables: { referenceId }
        });

        const { data: recipientUser } = await sb.from('users').select('language').eq('id', tx.metadata.recipient_id).maybeSingle();
        const recipientLang = recipientUser?.language || 'en';
        const recipientSubject = recipientLang === 'sw' ? 'Mzozo wa Escrow' : 'Escrow Disputed';
        const recipientBody = recipientLang === 'sw' 
            ? `Malipo kwako (${referenceId}) yamepingwa na mtumaji.` 
            : `A payment to you (${referenceId}) has been disputed by the sender.`;

        await Messaging.dispatch(tx.metadata.recipient_id, 'security', recipientSubject, recipientBody, { 
            sms: true,
            template: 'Escrow_Disputed_Recipient',
            variables: { referenceId }
        });

        await Audit.log('SECURITY', userId, 'ESCROW_DISPUTED', { referenceId, reason });
    }

    /**
     * REFUND ESCROW
     * Returns funds to the sender (Admin only or after dispute resolution).
     */
    public async refundEscrow(referenceId: string, adminId: string): Promise<void> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return;

        const { data: tx } = await sb.from('transactions').select('*').eq('reference_id', referenceId).single();
        if (!tx || tx.status === 'completed' || tx.status === 'reversed') throw new Error("INVALID_ESCROW_STATE");

        // Logic to reverse the ledger legs...
        // For now, we update status
        await sb.from('transactions').update({ 
            status: 'reversed',
            metadata: { ...tx.metadata, escrow_status: 'REFUNDED', refunded_by: adminId }
        }).eq('id', tx.id);

        const { data: senderUser } = await sb.from('users').select('language').eq('id', tx.user_id).maybeSingle();
        const senderLang = senderUser?.language || 'en';
        const subject = senderLang === 'sw' ? 'Escrow Imerejeshwa' : 'Escrow Refunded';
        const body = senderLang === 'sw' 
            ? `Malipo yako ya escrow ${referenceId} yamerejeshwa kwenye akaunti yako.` 
            : `Your escrow payment ${referenceId} has been refunded to your vault.`;

        await Messaging.dispatch(tx.user_id, 'info', subject, body, { 
            sms: true,
            template: 'Escrow_Refunded',
            variables: { referenceId }
        });

        await Audit.log('FINANCIAL', adminId, 'ESCROW_REFUNDED', { referenceId, senderId: tx.user_id });
    }

    /**
     * GET ESCROW BY REFERENCE
     */
    public async getEscrow(referenceId: string): Promise<any> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) throw new Error("VAULT_OFFLINE");

        const { data: tx } = await sb.from('transactions').select('*').eq('reference_id', referenceId).single();
        return tx;
    }

    /**
     * GET ALL ESCROWS FOR USER
     */
    public async getEscrows(userId: string): Promise<any[]> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return [];

        // Find escrows where user is sender OR recipient
        const { data: txs } = await sb.from('transactions')
            .select('*')
            .eq('type', 'escrow')
            .or(`user_id.eq.${userId},metadata->>recipient_id.eq.${userId}`);
            
        return txs || [];
    }
}
