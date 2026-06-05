import { z } from 'zod';
import { getAdminSupabase, getSupabase } from '../supabaseClient.js';
import { RulesConfigClient } from '../infrastructure/RulesConfigClient.js';
import { platformFeeService } from '../payments/PlatformFeeService.js';
import { PartnerRegistry } from './partnerRegistry.js';

const upperCode = (value: string) => value.trim().toUpperCase();

const FxRateSchema = z.record(z.string().min(3).max(8), z.coerce.number().positive());

const FxFeeSchema = z.object({
  name: z.string().min(1).default('FX conversion fee'),
  percentageRate: z.coerce.number().min(0).default(0),
  fixedAmount: z.coerce.number().min(0).default(0),
  minimumFee: z.coerce.number().min(0).default(0),
  maximumFee: z.coerce.number().min(0).optional(),
  taxRate: z.coerce.number().min(0).default(0),
  govFeeRate: z.coerce.number().min(0).default(0),
  stampDutyFixed: z.coerce.number().min(0).default(0),
  currency: z.string().length(3).optional(),
  countryCode: z.string().min(2).max(3).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const RoutingRuleSchema = z.object({
  rail: z.enum(['MOBILE_MONEY', 'BANK', 'CARD_GATEWAY', 'CRYPTO', 'WALLET']),
  countryCode: z.string().min(2).max(3).optional(),
  currency: z.string().length(3).optional(),
  operationCode: z.enum([
    'AUTH',
    'ACCOUNT_LOOKUP',
    'COLLECTION_REQUEST',
    'COLLECTION_STATUS',
    'DISBURSEMENT_REQUEST',
    'DISBURSEMENT_STATUS',
    'PAYOUT_REQUEST',
    'PAYOUT_STATUS',
    'REVERSAL_REQUEST',
    'REVERSAL_STATUS',
    'BALANCE_INQUIRY',
    'TRANSACTION_LOOKUP',
    'WEBHOOK_VERIFY',
    'BENEFICIARY_VALIDATE',
  ]),
  priority: z.coerce.number().int().min(1).default(100),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
  conditions: z.record(z.string(), z.unknown()).optional(),
});

const ProviderSchema = z.object({
  providerCode: z.string().min(2),
  name: z.string().min(1),
  type: z.enum(['mobile_money', 'bank', 'card', 'crypto']),
  status: z.enum(['ACTIVE', 'INACTIVE', 'MAINTENANCE']).default('INACTIVE'),
  logicType: z.enum(['REGISTRY', 'GENERIC_REST', 'SPECIALIZED']).default('GENERIC_REST'),
  apiBaseUrl: z.string().url().optional(),
  clientId: z.string().optional(),
  clientSecret: z.string().optional(),
  apiKey: z.string().optional(),
  merchantId: z.string().optional(),
  webhookSecret: z.string().optional(),
  connectionSecret: z.string().optional(),
  supportedCurrencies: z.array(z.string().length(3)).default([]),
  providerMetadata: z.record(z.string(), z.unknown()).default({}),
  mappingConfig: z.record(z.string(), z.unknown()).default({}),
  routingRules: z.array(RoutingRuleSchema).default([]),
});

const RailCapabilitySchema = z.object({
  capabilityCode: z.string().min(2),
  displayName: z.string().min(1),
  rail: z.enum(['MOBILE_MONEY', 'BANK', 'CARD_GATEWAY', 'CRYPTO', 'WALLET']),
  status: z.enum(['ACTIVE', 'INACTIVE', 'MAINTENANCE']).optional(),
  countryCode: z.string().min(2).max(3).default('TZ'),
  currency: z.string().length(3).default('TZS'),
  operationCodes: z.array(RoutingRuleSchema.shape.operationCode).default(['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST']),
  priority: z.coerce.number().int().min(1).default(100),
  minAmount: z.coerce.number().min(0).optional(),
  maxAmount: z.coerce.number().min(0).optional(),
  feeProfileCode: z.string().optional(),
  payGatewayCapabilityCode: z.string().optional(),
  icon: z.string().optional(),
  color: z.string().optional(),
  requires: z.record(z.string(), z.unknown()).default({}),
  metadata: z.record(z.string(), z.unknown()).default({}),
});

const PartnerBankSchema = z.object({
  partnerCode: z.string().min(2),
  name: z.string().min(1),
  status: z.enum(['ACTIVE', 'INACTIVE', 'MAINTENANCE']).default('INACTIVE'),
  payGatewayProviderCode: z.string().min(2),
  clearingNetwork: z.string().min(2).default('TIPS'),
  messageStandard: z.enum(['PROVIDER_NATIVE', 'ISO20022', 'ISO8583', 'CUSTOM']).default('ISO20022'),
  iso20022Profile: z.string().optional(),
  settlementModel: z.enum(['REALTIME_GROSS', 'DEFERRED_NET', 'BATCH', 'HYBRID', 'SANDBOX']).default('REALTIME_GROSS'),
  participantId: z.string().optional(),
  sponsoredParticipantId: z.string().optional(),
  apiBaseUrl: z.string().url().optional(),
  supportedCurrencies: z.array(z.string().length(3)).default(['TZS']),
  countries: z.array(z.string().min(2).max(3)).default(['TZ']),
  operations: z.array(z.enum([
    'COLLECTION_REQUEST',
    'DISBURSEMENT_REQUEST',
    'REVERSAL_REQUEST',
    'BALANCE_INQUIRY',
    'TRANSACTION_LOOKUP',
    'BENEFICIARY_VALIDATE',
  ])).default(['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST', 'REVERSAL_REQUEST']),
  downstreamCapabilities: z.array(RailCapabilitySchema).default([
    {
      capabilityCode: 'M_PESA_TZ',
      displayName: 'M-Pesa Tanzania',
      rail: 'MOBILE_MONEY',
      countryCode: 'TZ',
      currency: 'TZS',
      operationCodes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
      priority: 20,
      icon: 'mpesa',
      color: '#13A538',
      requires: { msisdn: true },
      metadata: { category: 'mobile_money', service_level: 'sponsored_switch' },
    },
    {
      capabilityCode: 'AIRTEL_MONEY_TZ',
      displayName: 'Airtel Money Tanzania',
      rail: 'MOBILE_MONEY',
      countryCode: 'TZ',
      currency: 'TZS',
      operationCodes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
      priority: 30,
      icon: 'airtel',
      color: '#E60000',
      requires: { msisdn: true },
      metadata: { category: 'mobile_money', service_level: 'sponsored_switch' },
    },
    {
      capabilityCode: 'TIGO_PESA_TZ',
      displayName: 'Tigo Pesa Tanzania',
      rail: 'MOBILE_MONEY',
      countryCode: 'TZ',
      currency: 'TZS',
      operationCodes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
      priority: 40,
      icon: 'tigopesa',
      color: '#005BAA',
      requires: { msisdn: true },
      metadata: { category: 'mobile_money', service_level: 'sponsored_switch' },
    },
    {
      capabilityCode: 'HALOPESA_TZ',
      displayName: 'HaloPesa Tanzania',
      rail: 'MOBILE_MONEY',
      countryCode: 'TZ',
      currency: 'TZS',
      operationCodes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
      priority: 50,
      icon: 'halopesa',
      color: '#F58220',
      requires: { msisdn: true },
      metadata: { category: 'mobile_money', service_level: 'sponsored_switch' },
    },
    {
      capabilityCode: 'TIPS_BANK_TRANSFER_TZ',
      displayName: 'TIPS Bank Transfer Tanzania',
      rail: 'BANK',
      countryCode: 'TZ',
      currency: 'TZS',
      operationCodes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST', 'BENEFICIARY_VALIDATE'],
      priority: 25,
      icon: 'bank',
      color: '#1D4ED8',
      requires: { accountNumber: true, bankCode: true },
      metadata: { category: 'bank_transfer', service_level: 'sponsored_switch' },
    },
  ]),
  priority: z.coerce.number().int().min(1).default(50),
  metadata: z.record(z.string(), z.unknown()).default({}),
});

export const AdminConfigBootstrapPayloadSchema = z.object({
  mode: z.enum(['preview', 'commit']).default('preview'),
  fx: z.object({
    rates: FxRateSchema.optional(),
    fee: FxFeeSchema.optional(),
  }).optional(),
  providers: z.array(ProviderSchema).default([]),
  partnerBanks: z.array(PartnerBankSchema).default([]),
});

type AdminConfigBootstrapPayload = z.infer<typeof AdminConfigBootstrapPayloadSchema>;

type BootstrapPlanItem = {
  action: string;
  target: string;
  detail: Record<string, unknown>;
};

export class AdminConfigBootstrapService {
  static async apply(rawPayload: unknown, actorId: string) {
    const payload = AdminConfigBootstrapPayloadSchema.parse(rawPayload);
    const normalized = this.normalize(payload);
    const warnings = this.validateConfiguration(normalized);
    const plan = this.buildPlan(normalized);

    if (normalized.mode === 'preview') {
      return {
        mode: 'preview',
        committed: false,
        warnings,
        plan,
        normalized,
      };
    }

    const results = await this.commit(normalized, actorId);
    return {
      mode: 'commit',
      committed: true,
      warnings,
      plan,
      results,
    };
  }

  private static normalize(payload: AdminConfigBootstrapPayload) {
    const partnerBankProviders = payload.partnerBanks.map((partnerBank) => this.partnerBankToProvider(partnerBank));
    const allProviders = [...payload.providers, ...partnerBankProviders];

    return {
      ...payload,
      fx: payload.fx
        ? {
            rates: payload.fx.rates
              ? Object.fromEntries(Object.entries(payload.fx.rates).map(([code, rate]) => [upperCode(code), Number(rate)]))
              : undefined,
            fee: payload.fx.fee
              ? {
                  ...payload.fx.fee,
                  currency: payload.fx.fee.currency ? upperCode(payload.fx.fee.currency) : undefined,
                  countryCode: payload.fx.fee.countryCode ? upperCode(payload.fx.fee.countryCode) : undefined,
                }
              : undefined,
          }
        : undefined,
      providers: allProviders.map((provider) => ({
        ...provider,
        providerCode: upperCode(provider.providerCode),
        supportedCurrencies: provider.supportedCurrencies.map(upperCode),
        providerMetadata: {
          ...provider.providerMetadata,
          provider_code: upperCode(provider.providerCode),
        },
        routingRules: provider.routingRules.map((rule) => ({
          ...rule,
          countryCode: rule.countryCode ? upperCode(rule.countryCode) : undefined,
          currency: rule.currency ? upperCode(rule.currency) : undefined,
        })),
      })),
    };
  }

  private static partnerBankToProvider(partnerBank: z.infer<typeof PartnerBankSchema>): z.infer<typeof ProviderSchema> {
    const payGatewayBaseUrl = process.env.ORBI_PAY_GATEWAY_BASE_URL || 'https://pay.orbifinancial.com';
    const operationContract: Record<string, { method: 'GET' | 'POST'; url: string }> = {
      COLLECTION_REQUEST: { method: 'POST', url: '/v1/collections' },
      DISBURSEMENT_REQUEST: { method: 'POST', url: '/v1/payouts' },
      REVERSAL_REQUEST: { method: 'POST', url: '/v1/refunds' },
      BALANCE_INQUIRY: { method: 'POST', url: '/v1/provider-operations/balance-inquiry' },
      TRANSACTION_LOOKUP: { method: 'POST', url: '/v1/provider-operations/transaction-lookup' },
      BENEFICIARY_VALIDATE: { method: 'POST', url: '/v1/provider-operations/beneficiary-validate' },
    };
    const rail = 'BANK' as const;
    const providerCode = upperCode(partnerBank.partnerCode);
    const countries = partnerBank.countries.map(upperCode);
    const supportedCurrencies = partnerBank.supportedCurrencies.map(upperCode);
    const downstreamCapabilities = partnerBank.downstreamCapabilities.map((capability) => ({
      capabilityCode: upperCode(capability.capabilityCode),
      displayName: capability.displayName,
      rail: capability.rail,
      status: capability.status || (partnerBank.status === 'ACTIVE' ? 'ACTIVE' : 'INACTIVE'),
      countryCode: upperCode(capability.countryCode),
      currency: upperCode(capability.currency),
      operationCodes: capability.operationCodes.map(upperCode),
      priority: capability.priority,
      minAmount: capability.minAmount,
      maxAmount: capability.maxAmount,
      feeProfileCode: capability.feeProfileCode,
      payGatewayCapabilityCode: capability.payGatewayCapabilityCode || upperCode(capability.capabilityCode),
      icon: capability.icon,
      color: capability.color,
      requires: capability.requires,
      metadata: capability.metadata,
    }));

    return {
      providerCode,
      name: partnerBank.name,
      type: 'bank',
      status: partnerBank.status,
      logicType: 'REGISTRY',
      apiBaseUrl: partnerBank.apiBaseUrl || payGatewayBaseUrl,
      supportedCurrencies,
      providerMetadata: {
        ...partnerBank.metadata,
        registry_kind: 'UNIVERSAL_SWITCH',
        message_standard: partnerBank.messageStandard,
        clearing_network: upperCode(partnerBank.clearingNetwork),
        switch_profile_code: partnerBank.payGatewayProviderCode,
        pay_gateway_provider_code: partnerBank.payGatewayProviderCode,
        provider_code: partnerBank.payGatewayProviderCode,
        rail,
        countries,
        operations: partnerBank.operations,
        iso20022_profile: partnerBank.iso20022Profile,
        settlement_model: partnerBank.settlementModel,
        participant_id: partnerBank.participantId,
        sponsored_participant_id: partnerBank.sponsoredParticipantId,
        group: 'Bank',
        checkout_mode: 'server_to_server',
        channels: ['bank_transfer', 'bank_account'],
        downstream_capabilities: downstreamCapabilities,
      },
      mappingConfig: {
        service_root: partnerBank.apiBaseUrl || payGatewayBaseUrl,
        operations: Object.fromEntries(partnerBank.operations.map((operationCode) => [
          operationCode,
          {
            method: operationContract[operationCode]?.method || 'POST',
            url: operationContract[operationCode]?.url || '/v1/collections',
            payload_template: {
              providerCode: partnerBank.payGatewayProviderCode,
              reference: '{{reference}}',
              amount: '{{amount}}',
              currency: '{{currency}}',
              accountNumber: '{{recipient.accountNumber}}',
              description: '{{description}}',
              metadata: {
                clearingNetwork: upperCode(partnerBank.clearingNetwork),
                messageStandard: partnerBank.messageStandard,
              },
            },
            response_mapping: {
              providerRef: 'data.providerReference',
              status: 'data.status',
              message: 'data.message',
            },
          },
        ])),
      },
      routingRules: partnerBank.operations.flatMap((operationCode) =>
        countries.flatMap((countryCode) =>
          supportedCurrencies.map((currency) => ({
            rail,
            countryCode,
            currency,
            operationCode,
            priority: partnerBank.priority,
            status: partnerBank.status === 'ACTIVE' ? 'ACTIVE' as const : 'INACTIVE' as const,
            conditions: {
              registry_kind: 'UNIVERSAL_SWITCH',
              clearing_network: upperCode(partnerBank.clearingNetwork),
              pay_gateway_provider_code: partnerBank.payGatewayProviderCode,
            },
          })),
        ),
      ),
    };
  }

  private static validateConfiguration(payload: ReturnType<typeof AdminConfigBootstrapService.normalize>) {
    const warnings: string[] = [];
    const rates = payload.fx?.rates;
    if (rates && rates.USD !== 1) {
      warnings.push('FX_RATES_USD_BASE_SHOULD_BE_1');
    }
    for (const provider of payload.providers) {
      if (provider.status === 'ACTIVE' && !provider.apiBaseUrl) {
        warnings.push(`PROVIDER_${provider.providerCode}_ACTIVE_WITHOUT_API_BASE_URL`);
      }
      if (provider.status === 'ACTIVE' && provider.routingRules.length === 0) {
        warnings.push(`PROVIDER_${provider.providerCode}_ACTIVE_WITHOUT_ROUTING_RULES`);
      }
    }
    return warnings;
  }

  private static buildPlan(payload: ReturnType<typeof AdminConfigBootstrapService.normalize>): BootstrapPlanItem[] {
    const plan: BootstrapPlanItem[] = [];
    if (payload.fx?.rates) {
      plan.push({
        action: 'UPSERT',
        target: 'infra_system_matrix.FX_RATES',
        detail: { currencies: Object.keys(payload.fx.rates).sort() },
      });
    }
    if (payload.fx?.fee) {
      plan.push({
        action: 'UPSERT',
        target: 'platform_fee_configs.FX_CONVERSION',
        detail: {
          percentageRate: payload.fx.fee.percentageRate,
          fixedAmount: payload.fx.fee.fixedAmount,
          currency: payload.fx.fee.currency || 'ANY',
          countryCode: payload.fx.fee.countryCode || 'ANY',
        },
      });
    }
    for (const provider of payload.providers) {
      plan.push({
        action: 'UPSERT',
        target: `financial_partners.${provider.providerCode}`,
        detail: {
          name: provider.name,
          type: provider.type,
          status: provider.status,
          routingRules: provider.routingRules.length,
          downstreamCapabilities: Array.isArray((provider.providerMetadata as any).downstream_capabilities)
            ? ((provider.providerMetadata as any).downstream_capabilities as unknown[]).length
            : 0,
        },
      });
    }
    return plan;
  }

  private static async commit(payload: ReturnType<typeof AdminConfigBootstrapService.normalize>, actorId: string) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const results: Record<string, unknown> = {};

    if (payload.fx?.rates) {
      const { error } = await sb.from('infra_system_matrix').upsert({
        config_key: 'FX_RATES',
        config_data: payload.fx.rates,
        updated_at: new Date().toISOString(),
        updated_by: actorId,
      });
      if (error) throw new Error(error.message);
      RulesConfigClient.getInstance().invalidateCache();
      results.fxRates = { saved: true, currencies: Object.keys(payload.fx.rates).length };
    }

    if (payload.fx?.fee) {
      const fee = payload.fx.fee;
      const saved = await platformFeeService.upsertConfig({
        name: fee.name,
        flowCode: 'FX_CONVERSION',
        percentageRate: fee.percentageRate,
        fixedAmount: fee.fixedAmount,
        minimumFee: fee.minimumFee,
        maximumFee: fee.maximumFee,
        taxRate: fee.taxRate,
        govFeeRate: fee.govFeeRate,
        stampDutyFixed: fee.stampDutyFixed,
        currency: fee.currency,
        countryCode: fee.countryCode,
        status: fee.status,
        priority: 10,
        metadata: {
          ...(fee.metadata || {}),
          source: 'admin_config_bootstrap',
        },
      }, actorId);
      results.fxFee = saved;
    }

    const providerResults = [];
    for (const provider of payload.providers) {
      providerResults.push(await this.upsertProvider(provider, actorId));
    }
    results.providers = providerResults;

    return results;
  }

  private static async upsertProvider(provider: ReturnType<typeof AdminConfigBootstrapService.normalize>['providers'][number], actorId: string) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const { data: partners, error: listError } = await sb
      .from('financial_partners')
      .select('*')
      .order('created_at', { ascending: false });
    if (listError) throw new Error(listError.message);

    const existing = (partners || []).find((row: any) => {
      const metadata = row.provider_metadata || {};
      return String(metadata.provider_code || metadata.providerCode || row.name || '').toUpperCase() === provider.providerCode;
    });

    const partnerPayload = {
      name: provider.name,
      type: provider.type,
      status: provider.status,
      logic_type: provider.logicType,
      api_base_url: provider.apiBaseUrl,
      client_id: provider.clientId,
      client_secret: provider.clientSecret,
      api_key: provider.apiKey,
      merchant_id: provider.merchantId,
      webhook_secret: provider.webhookSecret,
      connection_secret: provider.connectionSecret,
      supported_currencies: provider.supportedCurrencies.length ? provider.supportedCurrencies : undefined,
      provider_metadata: {
        ...provider.providerMetadata,
        admin_audit: {
          updated_by: actorId,
          updated_at: new Date().toISOString(),
        },
      },
      mapping_config: provider.mappingConfig,
    };

    const { data: partner, error } = existing
      ? await PartnerRegistry.updatePartner(existing.id, partnerPayload as any)
      : await PartnerRegistry.addPartner(partnerPayload as any);
    if (error) throw new Error(error.message);

    await this.saveProviderConfigVersion(partner.id, provider.mappingConfig, provider.providerMetadata, actorId, provider.status === 'ACTIVE' ? 'ACTIVE' : 'DRAFT');
    await this.saveRoutingRules(partner.id, provider.routingRules, actorId);
    const capabilityCount = await this.saveRailCapabilities(partner.id, provider, actorId);

    return {
      providerCode: provider.providerCode,
      providerId: partner.id,
      action: existing ? 'updated' : 'created',
      routingRules: provider.routingRules.length,
      downstreamCapabilities: capabilityCount,
    };
  }

  private static async saveRailCapabilities(
    providerId: string,
    provider: ReturnType<typeof AdminConfigBootstrapService.normalize>['providers'][number],
    actorId: string,
  ) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const capabilities = Array.isArray((provider.providerMetadata as any).downstream_capabilities)
      ? (provider.providerMetadata as any).downstream_capabilities as any[]
      : [];
    if (capabilities.length === 0) return 0;

    let saved = 0;
    for (const capability of capabilities) {
      const capabilityCode = upperCode(String(capability.capabilityCode || capability.capability_code || ''));
      if (!capabilityCode) continue;

      const row = {
        switch_partner_id: providerId,
        capability_code: capabilityCode,
        display_name: String(capability.displayName || capability.display_name || capabilityCode).trim(),
        rail: upperCode(String(capability.rail || 'BANK')),
        country_code: upperCode(String(capability.countryCode || capability.country_code || 'TZ')),
        currency: upperCode(String(capability.currency || 'TZS')),
        operation_codes: Array.isArray(capability.operationCodes || capability.operation_codes)
          ? (capability.operationCodes || capability.operation_codes).map((value: unknown) => upperCode(String(value)))
          : ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
        status: upperCode(String(capability.status || (provider.status === 'ACTIVE' ? 'ACTIVE' : 'INACTIVE'))),
        priority: Number(capability.priority || 100),
        min_amount: capability.minAmount ?? capability.min_amount ?? null,
        max_amount: capability.maxAmount ?? capability.max_amount ?? null,
        fee_profile_code: capability.feeProfileCode ?? capability.fee_profile_code ?? null,
        pay_gateway_provider_code: (provider.providerMetadata as any).pay_gateway_provider_code || null,
        pay_gateway_capability_code: capability.payGatewayCapabilityCode || capability.pay_gateway_capability_code || capabilityCode,
        icon: capability.icon || null,
        color: capability.color || null,
        requires: capability.requires || {},
        metadata: {
          ...(capability.metadata || {}),
          admin_audit: {
            updated_by: actorId,
            updated_at: new Date().toISOString(),
          },
        },
        updated_at: new Date().toISOString(),
      };

      const { data: existing, error: findError } = await sb
        .from('payment_rail_capabilities')
        .select('id')
        .eq('switch_partner_id', providerId)
        .eq('capability_code', capabilityCode)
        .maybeSingle();
      if (findError) throw new Error(findError.message);

      const write = existing
        ? sb.from('payment_rail_capabilities').update(row).eq('id', existing.id)
        : sb.from('payment_rail_capabilities').insert({ ...row, created_at: new Date().toISOString() });
      const { error } = await write;
      if (error) throw new Error(error.message);
      saved += 1;
    }

    return saved;
  }

  private static async saveProviderConfigVersion(
    providerId: string,
    mappingConfig: Record<string, unknown>,
    providerMetadata: Record<string, unknown>,
    actorId: string,
    status: 'ACTIVE' | 'DRAFT',
  ) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    const { data: versions, error: versionError } = await sb
      .from('provider_config_versions')
      .select('version')
      .eq('provider_id', providerId)
      .order('version', { ascending: false })
      .limit(1);
    if (versionError) throw new Error(versionError.message);

    if (status === 'ACTIVE') {
      const { error: archiveError } = await sb
        .from('provider_config_versions')
        .update({ status: 'ARCHIVED' })
        .eq('provider_id', providerId)
        .eq('status', 'ACTIVE');
      if (archiveError) throw new Error(archiveError.message);
    }

    const nextVersion = Number((versions || [])[0]?.version || 0) + 1;
    const { error } = await sb.from('provider_config_versions').insert({
      provider_id: providerId,
      version: nextVersion,
      mapping_config: mappingConfig,
      provider_metadata: providerMetadata,
      status,
      canary_percentage: status === 'ACTIVE' ? 100 : 0,
      created_by: actorId,
      activated_at: status === 'ACTIVE' ? new Date().toISOString() : null,
      metadata: {
        source: 'admin_config_bootstrap',
      },
    });
    if (error) throw new Error(error.message);
  }

  private static async saveRoutingRules(providerId: string, rules: z.infer<typeof RoutingRuleSchema>[], actorId: string) {
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) throw new Error('DB_OFFLINE');

    for (const rule of rules) {
      const row = {
        rail: rule.rail,
        country_code: rule.countryCode || null,
        currency: rule.currency || null,
        operation_code: rule.operationCode,
        provider_id: providerId,
        priority: rule.priority,
        status: rule.status,
        conditions: {
          ...(rule.conditions || {}),
          admin_audit: {
            updated_by: actorId,
            updated_at: new Date().toISOString(),
          },
        },
        updated_at: new Date().toISOString(),
      };

      let query = sb
        .from('provider_routing_rules')
        .select('id')
        .eq('provider_id', providerId)
        .eq('rail', rule.rail)
        .eq('operation_code', rule.operationCode);

      query = rule.countryCode ? query.eq('country_code', rule.countryCode) : query.is('country_code', null);
      query = rule.currency ? query.eq('currency', rule.currency) : query.is('currency', null);

      const { data: existing, error: findError } = await query.maybeSingle();
      if (findError) throw new Error(findError.message);

      const write = existing
        ? sb.from('provider_routing_rules').update(row).eq('id', existing.id)
        : sb.from('provider_routing_rules').insert({ ...row, created_at: new Date().toISOString() });
      const { error } = await write;
      if (error) throw new Error(error.message);
    }
  }
}
