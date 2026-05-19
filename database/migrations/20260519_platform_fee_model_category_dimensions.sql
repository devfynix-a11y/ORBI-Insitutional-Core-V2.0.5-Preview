ALTER TABLE public.platform_fee_configs
  ADD COLUMN IF NOT EXISTS transaction_model TEXT,
  ADD COLUMN IF NOT EXISTS category_code TEXT,
  ADD COLUMN IF NOT EXISTS category_id TEXT;

CREATE INDEX IF NOT EXISTS idx_platform_fee_configs_model
  ON public.platform_fee_configs(flow_code, transaction_model, status, priority);

CREATE INDEX IF NOT EXISTS idx_platform_fee_configs_category_code
  ON public.platform_fee_configs(flow_code, category_code, status, priority);

CREATE INDEX IF NOT EXISTS idx_platform_fee_configs_category_id
  ON public.platform_fee_configs(flow_code, category_id, status, priority);

COMMENT ON COLUMN public.platform_fee_configs.transaction_model IS
  'Canonical fee model resolved from transaction type, rail, and service context, e.g. WALLET_TRANSFER, BILL_PAYMENT, EXTERNAL_MOBILE_MONEY, AGENT_CASH.';

COMMENT ON COLUMN public.platform_fee_configs.category_code IS
  'Optional normalized business category code for fee specialization, e.g. ELECTRICITY, AIRTIME, SCHOOL_FEES, MERCHANT_GROCERY.';

COMMENT ON COLUMN public.platform_fee_configs.category_id IS
  'Optional application category id for exact category-level fee specialization.';
