
import { TransactionService } from '../../ledger/transactionService.js';
import { Audit } from '../security/audit.js';
import { getSupabase } from '../../services/supabaseClient.js';
import { RegulatoryService } from '../ledger/regulatoryService.js';
import { UUID } from '../../services/utils.js';
import { ProviderFactory } from './providers/ProviderFactory.js';
import crypto from 'crypto';

/**
 * SOVEREIGN WEBHOOK LISTENER (V4.0)
 * -------------------------
 */
class WebhookHandler {
    private ledger = new TransactionService();

    /**
     * VERIFY HMAC SIGNATURE
     */
    private verifySignature(payload: any, signature: string, secret: string): boolean {
        if (!signature || !secret) return false;
        const payloadString = typeof payload === 'string' ? payload : JSON.stringify(payload);
        const expectedSignature = crypto
            .createHmac('sha256', secret)
            .update(payloadString)
            .digest('hex');
        // Use timingSafeEqual to prevent timing attacks
        return crypto.timingSafeEqual(Buffer.from(expectedSignature), Buffer.from(signature));
    }

    /**
     * PROCESS PROVIDER CALLBACK
     */
    public async handleCallback(payload: any, partnerId: string, signature?: string) {
        const sb = getSupabase();
        if (!sb) return;

        // 1. Resolve Partner Metadata for Parsing Logic
        const { data: partner } = await sb.from('financial_partners').select('*').eq('id', partnerId).single();
        if (!partner) {
            console.error(`[Webhook] PARTNER_UNKNOWN: id ${partnerId}`);
            return;
        }

        // 2. Verify Signature (CRITICAL FOR BANKING)
        if (partner.webhook_secret && signature) {
            const isValid = this.verifySignature(payload, signature, partner.webhook_secret);
            if (!isValid) {
                console.error(`[Webhook] SECURITY_ALERT: Invalid signature for partner ${partner.name}`);
                await Audit.log('SECURITY', 'SYSTEM', 'WEBHOOK_SIGNATURE_FAILED', { partnerId, payload });
                throw new Error('INVALID_SIGNATURE');
            }
        }

        const providerNode = ProviderFactory.getProvider(partner);
        const { reference, status, message } = providerNode.parseCallback(payload);
        
        console.info(`[Webhook] Signal for ${reference} from ${partner.name}: ${status}`);

        // 2. Fetch the pending transaction
        const { data: tx } = await sb.from('transactions')
            .select('*')
            .or(`id.eq.${reference},reference_id.eq.${reference}`)
            .single();
        
        if (!tx) {
            console.error(`[Webhook] TRACE_LOST: Unknown tx ${reference}`);
            return;
        }

        const txId = tx.id;

        // 3. Finalize Ledger Update
        if (status === 'completed') {
            await this.ledger.updateTransactionStatus(txId, 'completed', `Verified by ${partner.name}: ${message}`);
        } else {
            await this.ledger.updateTransactionStatus(txId, 'failed', message || 'Provider rejection.');
        }

        await Audit.log('FINANCIAL', 'SYSTEM', 'WEBHOOK_PROCESSED', { 
            provider: partner.name, reference, status, traceId: UUID.generate() 
        });
    }
}

export const Webhooks = new WebhookHandler();
