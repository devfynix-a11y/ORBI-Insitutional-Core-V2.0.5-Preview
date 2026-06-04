import type { PaymentProviderAdapter } from '../types.js';
import { MockProviderAdapter } from './mock/MockProviderAdapter.js';
import { MpesaTanzaniaAdapter } from './mpesa-tanzania/MpesaTanzaniaAdapter.js';
import { SelcomAdapter } from './selcom/SelcomAdapter.js';

export class AdapterRegistry {
  private readonly adapters = new Map<string, PaymentProviderAdapter>();

  constructor() {
    [new MockProviderAdapter(), new SelcomAdapter(), new MpesaTanzaniaAdapter()].forEach((adapter) => {
      this.adapters.set(adapter.code, adapter);
    });
  }

  list() {
    return [...this.adapters.values()].map((adapter) => ({
      code: adapter.code,
      displayName: adapter.displayName,
    }));
  }

  get(providerCode: string): PaymentProviderAdapter {
    const adapter = this.adapters.get(String(providerCode || '').trim().toLowerCase());
    if (!adapter) {
      throw new Error('PAYMENT_PROVIDER_NOT_SUPPORTED');
    }
    return adapter;
  }
}

export const adapterRegistry = new AdapterRegistry();
