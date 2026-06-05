import assert from 'node:assert/strict';
import test from 'node:test';

import { PaymentRailCapabilityService } from '../backend/payments/PaymentRailCapabilityService.js';

test('payment rail capability public option exposes selection data without secrets', () => {
  const service = new PaymentRailCapabilityService();
  const option = service.toPublicOption({
    id: 'cap-id',
    switch_partner_id: 'partner-id',
    capability_code: 'M_PESA_TZ',
    display_name: 'M-Pesa Tanzania',
    rail: 'MOBILE_MONEY',
    country_code: 'TZ',
    currency: 'TZS',
    operation_codes: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
    status: 'ACTIVE',
    priority: 20,
    min_amount: 100,
    max_amount: 5000000,
    fee_profile_code: 'TZ_MOBILE_MONEY_STANDARD',
    pay_gateway_provider_code: 'nmb-obp-sandbox',
    pay_gateway_capability_code: 'M_PESA_TZ',
    icon: 'mpesa',
    color: '#13A538',
    requires: { msisdn: true },
    metadata: { category: 'mobile_money', service_level: 'sponsored_switch' },
    financial_partners: {
      id: 'partner-id',
      name: 'NMB Sponsored TIPS Access',
      status: 'ACTIVE',
      client_secret: 'must-not-leak',
      api_key: 'must-not-leak',
      provider_metadata: {
        registry_kind: 'UNIVERSAL_SWITCH',
        clearing_network: 'TIPS',
        message_standard: 'PROVIDER_NATIVE',
      },
    },
  });

  assert.equal(option.id, 'M_PESA_TZ');
  assert.equal(option.label, 'M-Pesa Tanzania');
  assert.equal(option.rail, 'MOBILE_MONEY');
  assert.equal(option.requires.msisdn, true);
  assert.equal(option.switchPartner.name, 'NMB Sponsored TIPS Access');
  assert.equal(option.payGateway.providerCode, 'nmb-obp-sandbox');
  assert.equal(JSON.stringify(option).includes('must-not-leak'), false);
});
