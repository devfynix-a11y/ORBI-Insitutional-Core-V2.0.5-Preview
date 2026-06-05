import assert from 'node:assert/strict';
import test from 'node:test';

import { AdminConfigBootstrapService } from '../backend/admin/AdminConfigBootstrapService.js';

test('admin config bootstrap converts partner bank into universal switch provider', async () => {
  const result = await AdminConfigBootstrapService.apply({
    mode: 'preview',
    partnerBanks: [
      {
        partnerCode: 'NMB_SPONSORED_TIPS',
        name: 'NMB Sponsored TIPS Access',
        status: 'INACTIVE',
        payGatewayProviderCode: 'nmb-obp-sandbox',
        clearingNetwork: 'tips',
        messageStandard: 'PROVIDER_NATIVE',
        settlementModel: 'SANDBOX',
        supportedCurrencies: ['tzs'],
        countries: ['tz'],
        operations: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST', 'REVERSAL_REQUEST'],
        priority: 40,
      },
    ],
  }, 'test-admin');

  assert.equal(result.mode, 'preview');
  assert.equal(result.committed, false);

  const normalized = result.normalized;
  assert.equal(normalized.providers.length, 1);

  const provider = normalized.providers[0];
  assert.equal(provider.providerCode, 'NMB_SPONSORED_TIPS');
  assert.equal(provider.type, 'bank');
  assert.equal(provider.logicType, 'REGISTRY');
  assert.equal(provider.apiBaseUrl, 'https://pay.orbifinancial.com');
  assert.deepEqual(provider.supportedCurrencies, ['TZS']);

  assert.equal(provider.providerMetadata.registry_kind, 'UNIVERSAL_SWITCH');
  assert.equal(provider.providerMetadata.message_standard, 'PROVIDER_NATIVE');
  assert.equal(provider.providerMetadata.clearing_network, 'TIPS');
  assert.equal(provider.providerMetadata.pay_gateway_provider_code, 'nmb-obp-sandbox');
  assert.equal(provider.providerMetadata.provider_code, 'NMB_SPONSORED_TIPS');
  assert.equal(provider.providerMetadata.settlement_model, 'SANDBOX');
  assert.equal(Array.isArray(provider.providerMetadata.downstream_capabilities), true);
  assert.equal((provider.providerMetadata.downstream_capabilities as unknown[]).length, 5);
  assert.deepEqual(
    (provider.providerMetadata.downstream_capabilities as any[]).slice(0, 2).map((capability) => [capability.capabilityCode, capability.status]),
    [
      ['M_PESA_TZ', 'INACTIVE'],
      ['AIRTEL_MONEY_TZ', 'INACTIVE'],
    ],
  );

  assert.equal(provider.mappingConfig.service_root, 'https://pay.orbifinancial.com');
  assert.deepEqual(provider.mappingConfig.operations, {
    COLLECTION_REQUEST: {
      method: 'POST',
      url: '/v1/collections',
      payload_template: {
        providerCode: 'nmb-obp-sandbox',
        reference: '{{reference}}',
        amount: '{{amount}}',
        currency: '{{currency}}',
        accountNumber: '{{recipient.accountNumber}}',
        description: '{{description}}',
        metadata: {
          clearingNetwork: 'TIPS',
          messageStandard: 'PROVIDER_NATIVE',
        },
      },
      response_mapping: {
        providerRef: 'data.providerReference',
        status: 'data.status',
        message: 'data.message',
      },
    },
    DISBURSEMENT_REQUEST: {
      method: 'POST',
      url: '/v1/payouts',
      payload_template: {
        providerCode: 'nmb-obp-sandbox',
        reference: '{{reference}}',
        amount: '{{amount}}',
        currency: '{{currency}}',
        accountNumber: '{{recipient.accountNumber}}',
        description: '{{description}}',
        metadata: {
          clearingNetwork: 'TIPS',
          messageStandard: 'PROVIDER_NATIVE',
        },
      },
      response_mapping: {
        providerRef: 'data.providerReference',
        status: 'data.status',
        message: 'data.message',
      },
    },
    REVERSAL_REQUEST: {
      method: 'POST',
      url: '/v1/refunds',
      payload_template: {
        providerCode: 'nmb-obp-sandbox',
        reference: '{{reference}}',
        amount: '{{amount}}',
        currency: '{{currency}}',
        accountNumber: '{{recipient.accountNumber}}',
        description: '{{description}}',
        metadata: {
          clearingNetwork: 'TIPS',
          messageStandard: 'PROVIDER_NATIVE',
        },
      },
      response_mapping: {
        providerRef: 'data.providerReference',
        status: 'data.status',
        message: 'data.message',
      },
    },
  });

  assert.equal(provider.routingRules.length, 3);
  assert.deepEqual(
    provider.routingRules.map((rule) => [rule.rail, rule.countryCode, rule.currency, rule.operationCode, rule.priority, rule.status]),
    [
      ['BANK', 'TZ', 'TZS', 'COLLECTION_REQUEST', 40, 'INACTIVE'],
      ['BANK', 'TZ', 'TZS', 'DISBURSEMENT_REQUEST', 40, 'INACTIVE'],
      ['BANK', 'TZ', 'TZS', 'REVERSAL_REQUEST', 40, 'INACTIVE'],
    ],
  );

  assert.equal(result.plan.length, 1);
  assert.equal(result.plan[0].target, 'financial_partners.NMB_SPONSORED_TIPS');
});

test('admin config bootstrap supports production ISO 20022 partner bank profile', async () => {
  const result = await AdminConfigBootstrapService.apply({
    mode: 'preview',
    partnerBanks: [
      {
        partnerCode: 'ORBI_TIPS_PARTNER',
        name: 'ORBI Partner Bank TIPS Switch',
        status: 'ACTIVE',
        payGatewayProviderCode: 'tips-partner-bank',
        clearingNetwork: 'TIPS',
        messageStandard: 'ISO20022',
        iso20022Profile: 'tips-iso20022-pacs-v1',
        settlementModel: 'REALTIME_GROSS',
        participantId: 'ORBI',
        sponsoredParticipantId: 'PARTNER_BANK',
        supportedCurrencies: ['TZS'],
        countries: ['TZ'],
        operations: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST', 'BENEFICIARY_VALIDATE'],
      },
    ],
  }, 'test-admin');

  const provider = result.normalized.providers[0];
  assert.equal(provider.status, 'ACTIVE');
  assert.equal(provider.providerMetadata.message_standard, 'ISO20022');
  assert.equal(provider.providerMetadata.iso20022_profile, 'tips-iso20022-pacs-v1');
  assert.equal(provider.providerMetadata.participant_id, 'ORBI');
  assert.equal(provider.providerMetadata.sponsored_participant_id, 'PARTNER_BANK');
  assert.equal(provider.routingRules.every((rule) => rule.status === 'ACTIVE'), true);
  assert.equal((provider.providerMetadata.downstream_capabilities as any[]).every((capability) => capability.status === 'ACTIVE'), true);
  assert.equal((provider.mappingConfig.operations as Record<string, any>).BENEFICIARY_VALIDATE.url, '/v1/provider-operations/beneficiary-validate');
});
