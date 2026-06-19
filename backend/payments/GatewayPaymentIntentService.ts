import crypto from 'crypto';

import { getAdminSupabase } from '../supabaseClient.js';

type PersistIntentInput = {
  intentId: string;
  serviceCode: string;
  reference: string;
  operation: string;
  customerUserId?: string | null;
  merchantId?: string | null;
  amount: number;
  currency: string;
  requestPayload: Record<string, unknown>;
  responsePayload: Record<string, unknown>;
  status: string;
  challenge?: {
    challengeId: string;
    type: string;
    expiresAt?: string;
    metadata?: Record<string, unknown>;
  };
};

const stableSerialize = (value: unknown): string => {
  if (value === null || value === undefined) return '';
  if (typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableSerialize).join(',')}]`;
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, entryValue]) => entryValue !== undefined)
    .sort(([left], [right]) => left.localeCompare(right));
  return `{${entries.map(([key, entryValue]) => `${JSON.stringify(key)}:${stableSerialize(entryValue)}`).join(',')}}`;
};

export class GatewayPaymentIntentService {
  hashRequest(payload: Record<string, unknown>): string {
    return crypto.createHash('sha256').update(stableSerialize(payload)).digest('hex');
  }

  async persist(input: PersistIntentInput) {
    const sb = getAdminSupabase();
    if (!sb) throw new Error('SERVICE_ROLE_REQUIRED');

    const { data, error } = await sb.rpc('persist_gateway_payment_intent_v1', {
      p_intent_id: input.intentId,
      p_service_code: input.serviceCode,
      p_reference: input.reference,
      p_operation: input.operation,
      p_request_hash: this.hashRequest(input.requestPayload),
      p_customer_user_id: input.customerUserId || null,
      p_merchant_id: input.merchantId || null,
      p_amount: input.amount,
      p_currency: input.currency,
      p_status: input.status,
      p_request_payload: input.requestPayload,
      p_response_payload: input.responsePayload,
      p_challenge_id: input.challenge?.challengeId || null,
      p_challenge_type: input.challenge?.type || null,
      p_challenge_expires_at: input.challenge?.expiresAt || null,
      p_challenge_metadata: input.challenge?.metadata || {},
    });

    if (error) {
      const domainError = String(error.message || '').match(/GATEWAY_[A-Z0-9_]+/)?.[0];
      throw new Error(domainError || 'GATEWAY_INTENT_PERSIST_FAILED');
    }
    return (data || {}) as Record<string, any>;
  }

  async recordDelivery(eventKey: string, delivered: boolean, errorMessage?: string) {
    const sb = getAdminSupabase();
    if (!sb || !eventKey) return;
    const { error } = await sb.rpc('record_gateway_payment_event_delivery_v1', {
      p_event_key: eventKey,
      p_delivered: delivered,
      p_error: errorMessage || null,
    });
    if (error) throw new Error('GATEWAY_EVENT_DELIVERY_RECORD_FAILED');
  }
}

export const gatewayPaymentIntentService = new GatewayPaymentIntentService();
