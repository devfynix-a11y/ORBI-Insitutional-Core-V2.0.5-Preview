import assert from 'node:assert/strict';
import test from 'node:test';

import {
    assertPartnerActivationReady,
    normalizeFinancialPartnerInput,
} from '../backend/payments/providers/ProviderRegistryValidator.js';

test('inactive provider may be saved without full activation metadata', () => {
    const payload = normalizeFinancialPartnerInput({
        name: 'Draft Provider',
        type: 'mobile_money',
        logic_type: 'REGISTRY',
        status: 'INACTIVE',
        mapping_config: {
            service_root: 'https://api.example.com',
            operations: {
                COLLECTION_REQUEST: {
                    method: 'POST',
                    url: '/collect',
                },
            },
        },
    });

    assert.doesNotThrow(() => assertPartnerActivationReady(payload));
});

test('active provider requires routing metadata and operation coverage', () => {
    const payload = normalizeFinancialPartnerInput({
        name: 'Broken Active Provider',
        type: 'mobile_money',
        logic_type: 'REGISTRY',
        status: 'ACTIVE',
        mapping_config: {
            service_root: 'https://api.example.com',
            operations: {
                COLLECTION_REQUEST: {
                    method: 'POST',
                    url: '/collect',
                },
            },
        },
        provider_metadata: {
            rail: 'MOBILE_MONEY',
        },
    });

    assert.throws(
        () => assertPartnerActivationReady(payload),
        /PROVIDER_ACTIVATION_PROVIDER_CODE_REQUIRED/,
    );
});

test('active webhook provider requires callback fields', () => {
    const payload = normalizeFinancialPartnerInput({
        name: 'Webhook Active Provider',
        type: 'mobile_money',
        logic_type: 'REGISTRY',
        status: 'ACTIVE',
        mapping_config: {
            service_root: 'https://api.example.com',
            operations: {
                COLLECTION_REQUEST: {
                    method: 'POST',
                    url: '/collect',
                },
            },
            callback: {
                reference_field: 'data.reference',
            },
        },
        provider_metadata: {
            provider_code: 'WEBHOOKPAY',
            rail: 'MOBILE_MONEY',
            operations: ['COLLECTION_REQUEST'],
            supports_webhooks: true,
        },
    });

    assert.throws(
        () => assertPartnerActivationReady(payload),
        /PROVIDER_ACTIVATION_CALLBACK_STATUS_REQUIRED/,
    );
});

test('active provider with complete registry passes activation guard', () => {
    const payload = normalizeFinancialPartnerInput({
        name: 'Ready Provider',
        type: 'mobile_money',
        logic_type: 'REGISTRY',
        status: 'ACTIVE',
        mapping_config: {
            service_root: 'https://api.example.com',
            operations: {
                COLLECTION_REQUEST: {
                    method: 'POST',
                    url: '/collect',
                },
            },
            callback: {
                reference_field: 'data.reference',
                status_field: 'data.status',
            },
        },
        provider_metadata: {
            provider_code: 'READYMONEY',
            rail: 'MOBILE_MONEY',
            operations: ['COLLECTION_REQUEST', 'WEBHOOK_VERIFY'],
            supports_webhooks: true,
        },
    });

    assert.doesNotThrow(() => assertPartnerActivationReady(payload));
});

test('active universal ISO 20022 switch profile passes without direct provider webhook secret', () => {
    const payload = normalizeFinancialPartnerInput({
        name: 'TIPS Universal Switch',
        type: 'bank',
        logic_type: 'REGISTRY',
        status: 'ACTIVE',
        api_base_url: 'https://pay.orbifinancial.com',
        mapping_config: {
            service_root: 'https://pay.orbifinancial.com',
            operations: {
                COLLECTION_REQUEST: {
                    method: 'POST',
                    url: '/v1/collections',
                },
                DISBURSEMENT_REQUEST: {
                    method: 'POST',
                    url: '/v1/payouts',
                },
            },
        },
        provider_metadata: {
            registry_kind: 'UNIVERSAL_SWITCH',
            message_standard: 'ISO20022',
            clearing_network: 'TIPS',
            switch_profile_code: 'tips-neighbor-bank',
            pay_gateway_provider_code: 'tips-neighbor-bank',
            iso20022_profile: 'tips-iso20022-pacs-v1',
            provider_code: 'tips-neighbor-bank',
            rail: 'BANK',
            operations: ['COLLECTION_REQUEST', 'DISBURSEMENT_REQUEST'],
            countries: ['TZ'],
        },
    });

    assert.doesNotThrow(() => assertPartnerActivationReady(payload));
});
