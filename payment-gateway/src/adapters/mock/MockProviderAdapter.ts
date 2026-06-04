import crypto from 'crypto';
import type {
  GatewayPaymentRequest,
  GatewayPaymentResponse,
  NormalizedProviderEvent,
  PaymentProviderAdapter,
  ProviderHealth,
} from '../../types.js';

export class MockProviderAdapter implements PaymentProviderAdapter {
  code = 'mock';
  displayName = 'ORBI Mock Payment Rail';

  async collect(request: GatewayPaymentRequest): Promise<GatewayPaymentResponse> {
    return this.accept(request, 'processing', 'Mock collection accepted for provider simulation.');
  }

  async payout(request: GatewayPaymentRequest): Promise<GatewayPaymentResponse> {
    return this.accept(request, 'processing', 'Mock payout accepted for provider simulation.');
  }

  async refund(request: GatewayPaymentRequest): Promise<GatewayPaymentResponse> {
    return this.accept(request, 'processing', 'Mock refund accepted for provider simulation.');
  }

  async parseWebhook(payload: unknown): Promise<NormalizedProviderEvent> {
    const event = payload as Record<string, unknown>;
    return {
      providerId: this.code,
      reference: String(event.reference || event.transactionId || event.externalReference || ''),
      status: this.normalizeStatus(event.status),
      message: String(event.message || 'Mock provider webhook received.'),
      providerEventId: String(event.providerEventId || event.eventId || crypto.randomUUID()),
      rawStatus: event.status ? String(event.status) : undefined,
      payload: event,
    };
  }

  async health(): Promise<ProviderHealth> {
    return {
      providerCode: this.code,
      status: 'UP',
      message: 'Mock provider is available for sandbox callbacks.',
    };
  }

  private accept(
    request: GatewayPaymentRequest,
    status: GatewayPaymentResponse['status'],
    message: string,
  ): GatewayPaymentResponse {
    return {
      providerCode: this.code,
      reference: request.reference,
      providerReference: `mock_${request.reference}_${Date.now()}`,
      status,
      message,
      raw: {
        amount: request.amount,
        currency: request.currency,
        direction: request.metadata?.direction || null,
      },
    };
  }

  private normalizeStatus(value: unknown): NormalizedProviderEvent['status'] {
    const status = String(value || '').toLowerCase();
    if (['success', 'successful', 'completed', 'paid'].includes(status)) return 'completed';
    if (['failed', 'failure', 'cancelled', 'rejected'].includes(status)) return 'failed';
    if (['pending'].includes(status)) return 'pending';
    return 'processing';
  }
}
