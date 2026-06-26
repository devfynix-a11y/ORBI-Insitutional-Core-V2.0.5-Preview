-- DEVELOPMENT AND TEST ONLY.
-- Deterministic fixtures for native PostgreSQL financial integration tests.

DELETE FROM public.transactions
WHERE COALESCE(metadata->>'integration_test', 'false') = 'true'
   OR reference_id LIKE 'ITEST-%';

INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data
)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'local-financial-test@orbifinancial.invalid',
    'disabled-local-test-password',
    NOW(),
    '{"provider":"local_test"}'::jsonb,
    '{
      "customer_id":"ORBI-LOCAL-ITEST",
      "full_name":"ORBI Local Financial Test",
      "nationality":"Tanzania",
      "registry_type":"CONSUMER",
      "role":"SUPER_ADMIN",
      "app_origin":"ORBI_LOCAL_INTEGRATION"
    }'::jsonb
)
ON CONFLICT (id) DO UPDATE
SET
    email_confirmed_at = EXCLUDED.email_confirmed_at,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = NOW();

UPDATE public.users
SET
    account_status = 'active',
    auth_confirmed_at = COALESCE(auth_confirmed_at, NOW()),
    role = 'SUPER_ADMIN',
    currency = 'TZS',
    metadata = COALESCE(metadata, '{}'::jsonb)
      || '{"local_integration_fixture":true}'::jsonb
WHERE id = '11111111-1111-4111-8111-111111111111';

INSERT INTO public.wallets (
    id,
    user_id,
    name,
    balance,
    currency,
    type,
    is_primary,
    status,
    is_locked,
    lock_reason,
    metadata
)
VALUES
    (
        '22222222-2222-4222-8222-222222222201',
        '11111111-1111-4111-8111-111111111111',
        'Integration Source',
        100000,
        'TZS',
        'operating',
        TRUE,
        'active',
        FALSE,
        NULL,
        '{"local_integration_fixture":true,"purpose":"source"}'::jsonb
    ),
    (
        '22222222-2222-4222-8222-222222222202',
        '11111111-1111-4111-8111-111111111111',
        'Integration Target',
        1000,
        'TZS',
        'operating',
        FALSE,
        'active',
        FALSE,
        NULL,
        '{"local_integration_fixture":true,"purpose":"target"}'::jsonb
    ),
    (
        '22222222-2222-4222-8222-222222222203',
        '11111111-1111-4111-8111-111111111111',
        'Integration Low Balance',
        0,
        'TZS',
        'operating',
        FALSE,
        'active',
        FALSE,
        NULL,
        '{"local_integration_fixture":true,"purpose":"insufficient_funds"}'::jsonb
    ),
    (
        '22222222-2222-4222-8222-222222222204',
        '11111111-1111-4111-8111-111111111111',
        'Integration Locked',
        100,
        'TZS',
        'operating',
        FALSE,
        'locked',
        TRUE,
        'Local integration locked-wallet fixture',
        '{"local_integration_fixture":true,"purpose":"locked"}'::jsonb
    ),
    (
        '22222222-2222-4222-8222-222222222205',
        '11111111-1111-4111-8111-111111111111',
        'Integration Drift Repair',
        0,
        'TZS',
        'operating',
        FALSE,
        'active',
        FALSE,
        NULL,
        '{"local_integration_fixture":true,"purpose":"drift_repair"}'::jsonb
    )
ON CONFLICT (id) DO UPDATE
SET
    user_id = EXCLUDED.user_id,
    name = EXCLUDED.name,
    currency = EXCLUDED.currency,
    type = EXCLUDED.type,
    is_primary = EXCLUDED.is_primary,
    status = EXCLUDED.status,
    is_locked = EXCLUDED.is_locked,
    lock_reason = EXCLUDED.lock_reason,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

INSERT INTO public.platform_vaults (
    id,
    user_id,
    vault_role,
    name,
    balance,
    currency,
    status,
    is_locked,
    metadata
)
VALUES
    (
        '33333333-3333-4333-8333-333333333301',
        '11111111-1111-4111-8111-111111111111',
        'INTERNAL_TRANSFER',
        'Integration PaySafe Vault',
        0,
        'TZS',
        'active',
        FALSE,
        '{"local_integration_fixture":true,"is_secure_escrow":true}'::jsonb
    ),
    (
        '33333333-3333-4333-8333-333333333302',
        '11111111-1111-4111-8111-111111111111',
        'OPERATING',
        'Integration Operating Vault',
        0,
        'TZS',
        'active',
        FALSE,
        '{"local_integration_fixture":true}'::jsonb
    ),
    (
        '33333333-3333-4333-8333-333333333303',
        '11111111-1111-4111-8111-111111111111',
        'ESCROW_VAULT',
        'Integration Escrow Vault',
        0,
        'TZS',
        'active',
        FALSE,
        '{"local_integration_fixture":true,"is_secure_escrow":true}'::jsonb
    )
ON CONFLICT (id) DO UPDATE
SET
    user_id = EXCLUDED.user_id,
    vault_role = EXCLUDED.vault_role,
    name = EXCLUDED.name,
    currency = EXCLUDED.currency,
    status = EXCLUDED.status,
    is_locked = EXCLUDED.is_locked,
    metadata = EXCLUDED.metadata,
    updated_at = NOW();

INSERT INTO public.financial_partners (
    id,
    name,
    type,
    status,
    webhook_secret,
    provider_metadata,
    mapping_config
)
VALUES
    (
        '44444444-4444-4444-8444-444444444401',
        'Local Webhook Provider',
        'mobile_money',
        'INACTIVE',
        'local-integration-webhook-secret',
        '{"environment":"sandbox","local_integration_fixture":true}'::jsonb,
        '{}'::jsonb
    ),
    (
        '44444444-4444-4444-8444-444444444402',
        'Local Withdrawal Provider',
        'mobile_money',
        'INACTIVE',
        'local-integration-withdrawal-secret',
        '{"environment":"sandbox","local_integration_fixture":true}'::jsonb,
        '{}'::jsonb
    )
ON CONFLICT (id) DO UPDATE
SET
    name = EXCLUDED.name,
    type = EXCLUDED.type,
    status = EXCLUDED.status,
    webhook_secret = EXCLUDED.webhook_secret,
    provider_metadata = EXCLUDED.provider_metadata,
    mapping_config = EXCLUDED.mapping_config,
    updated_at = NOW();

INSERT INTO public.categories (
    id,
    user_id,
    name,
    budget,
    budget_period,
    budget_interval
)
VALUES (
    '55555555-5555-4555-8555-555555555501',
    '11111111-1111-4111-8111-111111111111',
    'Local Integration Budget',
    '50',
    'MONTHLY',
    'MONTHLY'
)
ON CONFLICT (id) DO UPDATE
SET
    user_id = EXCLUDED.user_id,
    name = EXCLUDED.name,
    budget = EXCLUDED.budget,
    budget_period = EXCLUDED.budget_period,
    budget_interval = EXCLUDED.budget_interval;

INSERT INTO public.system_nodes (node_type, vault_id, updated_at)
VALUES
    ('INTERNAL_TRANSFER', '33333333-3333-4333-8333-333333333301', NOW()),
    ('OPERATING', '33333333-3333-4333-8333-333333333302', NOW()),
    ('ESCROW_VAULT', '33333333-3333-4333-8333-333333333303', NOW())
ON CONFLICT (node_type) DO UPDATE
SET vault_id = EXCLUDED.vault_id, updated_at = NOW();
