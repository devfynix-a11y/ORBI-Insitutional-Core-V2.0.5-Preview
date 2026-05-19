-- Base platform fee policies.
-- These are explicit zero-rate production defaults so transaction preview can
-- price flows from configuration before commercial fees are configured.

WITH base_fee_configs(flow_code, transaction_model, operation_type, direction, rail) AS (
  VALUES
    ('CORE_TRANSACTION', 'CORE_LEDGER', 'CORE_TRANSACTION', 'INTERNAL_TO_INTERNAL', 'WALLET'),
    ('INTERNAL_TRANSFER', 'WALLET_TRANSFER', 'LEDGER_TRANSFER', 'INTERNAL_TO_INTERNAL', 'WALLET'),
    ('EXTERNAL_PAYMENT', 'EXTERNAL_MOBILE_MONEY', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('BILL_PAYMENT', 'BILL_PAYMENT', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('WITHDRAWAL', 'EXTERNAL_MOBILE_MONEY', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('DEPOSIT', 'EXTERNAL_MOBILE_MONEY', 'COLLECTION_REQUEST', 'EXTERNAL_TO_INTERNAL', 'MOBILE_MONEY'),
    ('EXTERNAL_TO_INTERNAL', 'EXTERNAL_MOBILE_MONEY', 'COLLECTION_REQUEST', 'EXTERNAL_TO_INTERNAL', 'MOBILE_MONEY'),
    ('INTERNAL_TO_EXTERNAL', 'EXTERNAL_MOBILE_MONEY', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('EXTERNAL_TO_EXTERNAL', 'EXTERNAL_MOBILE_MONEY', 'TRANSFER_REQUEST', 'EXTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('MERCHANT_PAYMENT', 'MERCHANT_PAYMENT', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('AGENT_CASH_DEPOSIT', 'AGENT_CASH', 'COLLECTION_REQUEST', 'EXTERNAL_TO_INTERNAL', 'MOBILE_MONEY'),
    ('AGENT_CASH_WITHDRAWAL', 'AGENT_CASH', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'MOBILE_MONEY'),
    ('AGENT_REFERRAL_COMMISSION', 'SERVICE_COMMISSION', 'COMMISSION_POSTING', 'INTERNAL_TO_INTERNAL', 'WALLET'),
    ('AGENT_CASH_COMMISSION', 'SERVICE_COMMISSION', 'COMMISSION_POSTING', 'INTERNAL_TO_INTERNAL', 'WALLET'),
    ('CARD_SETTLEMENT', 'CARD_SETTLEMENT', 'SETTLEMENT', 'EXTERNAL_TO_INTERNAL', 'CARD_GATEWAY'),
    ('GATEWAY_SETTLEMENT', 'GATEWAY_SETTLEMENT', 'SETTLEMENT', 'EXTERNAL_TO_INTERNAL', 'WALLET'),
    ('FX_CONVERSION', 'FX_CONVERSION', 'FX_CONVERSION', 'INTERNAL_TO_INTERNAL', 'WALLET'),
    ('TENANT_SETTLEMENT_PAYOUT', 'TENANT_SETTLEMENT_PAYOUT', 'DISBURSEMENT_REQUEST', 'INTERNAL_TO_EXTERNAL', 'BANK'),
    ('SYSTEM_OPERATION', 'SYSTEM_OPERATION', 'SYSTEM_OPERATION', 'INTERNAL_TO_INTERNAL', 'WALLET')
)
INSERT INTO public.platform_fee_configs (
  name,
  flow_code,
  transaction_model,
  operation_type,
  direction,
  rail,
  percentage_rate,
  fixed_amount,
  minimum_fee,
  tax_rate,
  gov_fee_rate,
  stamp_duty_fixed,
  priority,
  status,
  metadata
)
SELECT
  'Base ' || flow_code || ' fee policy',
  flow_code,
  transaction_model,
  operation_type,
  direction,
  rail,
  0,
  0,
  0,
  0,
  0,
  0,
  1000,
  'ACTIVE',
  jsonb_build_object(
    'seeded_by', 'database/migrations/20260519_base_platform_fee_configs.sql',
    'purpose', 'base production fee policy; update rates in admin/config before monetized launch'
  )
FROM base_fee_configs seed
WHERE NOT EXISTS (
  SELECT 1
  FROM public.platform_fee_configs existing
  WHERE existing.flow_code = seed.flow_code
    AND existing.name = 'Base ' || seed.flow_code || ' fee policy'
);
