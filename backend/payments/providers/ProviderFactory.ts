
import { IPaymentProvider } from './types.js';
import { AirtelProvider } from './AirtelProvider.js';
import { MpesaProvider } from './MpesaProvider.js';
import { GenericRestProvider } from './GenericRestProvider.js';
import { FinancialPartner } from '../../../types.js';

export class ProviderFactory {
    private static instances: Map<string, IPaymentProvider> = new Map();

    /**
     * DYNAMIC PROVIDER RESOLVER
     * Priority:
     * 1. Specialized Class (Matched by name keywords)
     * 2. Manual Logic Type Definition
     * 3. Fallback to Generic REST
     */
    public static getProvider(partner: FinancialPartner): IPaymentProvider {
        const name = partner.name.toLowerCase();
        
        // 1. Specialized Routing
        if (name.includes('airtel')) {
            if (!this.instances.has('airtel')) this.instances.set('airtel', new AirtelProvider());
            return this.instances.get('airtel')!;
        }

        if (name.includes('mpesa') || name.includes('m-pesa')) {
            if (!this.instances.has('mpesa')) this.instances.set('mpesa', new MpesaProvider());
            return this.instances.get('mpesa')!;
        }

        // 2. Metadata-Driven Logic Type
        if (partner.logic_type === 'GENERIC_REST') {
            if (!this.instances.has('generic')) this.instances.set('generic', new GenericRestProvider());
            return this.instances.get('generic')!;
        }

        // 3. Absolute Fallback
        if (!this.instances.has('generic')) this.instances.set('generic', new GenericRestProvider());
        return this.instances.get('generic')!;
    }
}
