import { getAdminSupabase } from '../supabaseClient.js';
import { MoneyOperation, RailType } from '../../types.js';

const upper = (value?: string | null) => String(value || '').trim().toUpperCase();

export type PaymentRailCapabilityStatus = 'ACTIVE' | 'INACTIVE' | 'MAINTENANCE';

export type PaymentRailCapability = {
  id: string;
  switch_partner_id: string;
  capability_code: string;
  display_name: string;
  rail: RailType;
  country_code: string;
  currency: string;
  operation_codes: MoneyOperation[] | string[];
  status: PaymentRailCapabilityStatus;
  priority: number;
  min_amount?: number | null;
  max_amount?: number | null;
  fee_profile_code?: string | null;
  pay_gateway_provider_code?: string | null;
  pay_gateway_capability_code?: string | null;
  icon?: string | null;
  color?: string | null;
  requires?: Record<string, unknown> | null;
  metadata?: Record<string, unknown> | null;
  financial_partners?: any;
};

export type CapabilityListInput = {
  countryCode?: string;
  currency?: string;
  rail?: RailType;
  operation?: MoneyOperation;
  amount?: number;
  includeInactive?: boolean;
};

export type ResolvedRailCapability = {
  capability: PaymentRailCapability;
  switchPartner: any;
};

export class PaymentRailCapabilityService {
  async listAvailable(input: CapabilityListInput = {}) {
    const sb = getAdminSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const capabilities = await this.queryCapabilities(input);
    return capabilities
      .filter((capability) => this.amountAllowed(capability, input.amount))
      .map((capability) => this.toPublicOption(capability));
  }

  async resolveCapability(
    capabilityCode: string,
    input: CapabilityListInput = {},
  ): Promise<ResolvedRailCapability | null> {
    const code = upper(capabilityCode);
    if (!code) return null;
    const capabilities = await this.queryCapabilities({
      ...input,
      includeInactive: false,
    });
    const capability = capabilities.find((candidate) => upper(candidate.capability_code) === code);
    if (!capability || !this.amountAllowed(capability, input.amount)) return null;
    return {
      capability,
      switchPartner: capability.financial_partners,
    };
  }

  toPublicOption(capability: PaymentRailCapability) {
    const partner = capability.financial_partners || {};
    const metadata = capability.metadata || {};
    return {
      id: capability.capability_code,
      capabilityCode: capability.capability_code,
      label: capability.display_name,
      rail: capability.rail,
      countryCode: capability.country_code,
      currency: capability.currency,
      operations: capability.operation_codes || [],
      status: capability.status,
      priority: capability.priority,
      minAmount: capability.min_amount ?? null,
      maxAmount: capability.max_amount ?? null,
      icon: capability.icon || metadata.icon || null,
      color: capability.color || metadata.color || null,
      requires: capability.requires || {},
      feeProfileCode: capability.fee_profile_code || null,
      switchPartner: {
        id: capability.switch_partner_id,
        name: partner.name,
        status: partner.status,
        registryKind: partner.provider_metadata?.registry_kind,
        clearingNetwork: partner.provider_metadata?.clearing_network,
        messageStandard: partner.provider_metadata?.message_standard,
      },
      payGateway: {
        providerCode:
          capability.pay_gateway_provider_code ||
          partner.provider_metadata?.pay_gateway_provider_code ||
          partner.provider_metadata?.switch_profile_code ||
          null,
        capabilityCode: capability.pay_gateway_capability_code || capability.capability_code,
      },
      metadata: {
        category: metadata.category || null,
        serviceLevel: metadata.service_level || null,
      },
    };
  }

  private async queryCapabilities(input: CapabilityListInput): Promise<PaymentRailCapability[]> {
    const sb = getAdminSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    let query = sb
      .from('payment_rail_capabilities')
      .select('*, financial_partners(*)')
      .order('priority', { ascending: true })
      .order('display_name', { ascending: true });

    if (!input.includeInactive) query = query.eq('status', 'ACTIVE');
    if (input.countryCode) query = query.eq('country_code', upper(input.countryCode));
    if (input.currency) query = query.eq('currency', upper(input.currency));
    if (input.rail) query = query.eq('rail', upper(input.rail));
    if (input.operation) query = query.contains('operation_codes', [upper(input.operation)]);

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    return ((data || []) as PaymentRailCapability[]).filter((capability) => {
      const partner = capability.financial_partners || {};
      if (!input.includeInactive && partner.status !== 'ACTIVE') return false;
      return true;
    });
  }

  private amountAllowed(capability: PaymentRailCapability, amount?: number) {
    if (amount === undefined || amount === null || !Number.isFinite(Number(amount))) return true;
    const numeric = Number(amount);
    if (capability.min_amount !== undefined && capability.min_amount !== null && numeric < Number(capability.min_amount)) {
      return false;
    }
    if (capability.max_amount !== undefined && capability.max_amount !== null && numeric > Number(capability.max_amount)) {
      return false;
    }
    return true;
  }
}

export const paymentRailCapabilityService = new PaymentRailCapabilityService();
