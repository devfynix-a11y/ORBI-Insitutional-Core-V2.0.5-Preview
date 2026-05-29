-- Align provider registry and routing schema with Admin Portal production controls.

ALTER TABLE public.financial_partners
  ADD COLUMN IF NOT EXISTS api_key TEXT,
  ADD COLUMN IF NOT EXISTS merchant_id TEXT,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS updated_by UUID,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_financial_partners_provider_code
  ON public.financial_partners ((LOWER(provider_metadata->>'provider_code')));

CREATE INDEX IF NOT EXISTS idx_financial_partners_status_type
  ON public.financial_partners(status, type, logic_type);

CREATE INDEX IF NOT EXISTS idx_financial_partners_rail
  ON public.financial_partners ((provider_metadata->>'rail'));

CREATE INDEX IF NOT EXISTS idx_provider_routing_rules_scope
  ON public.provider_routing_rules(
    rail,
    operation_code,
    COALESCE(country_code, ''),
    COALESCE(currency, ''),
    provider_id,
    COALESCE(status, 'ACTIVE')
  );

CREATE INDEX IF NOT EXISTS idx_provider_routing_rules_provider_status
  ON public.provider_routing_rules(provider_id, status, priority);

CREATE INDEX IF NOT EXISTS idx_provider_routing_rules_country_currency
  ON public.provider_routing_rules(country_code, currency, status, priority);

COMMENT ON COLUMN public.financial_partners.api_key IS
  'Provider API key wrapped by provider secret vault when submitted through backend admin APIs.';

COMMENT ON COLUMN public.financial_partners.merchant_id IS
  'External provider merchant/account identifier used for collections, payouts, and gateway settlement.';

COMMENT ON COLUMN public.financial_partners.mapping_config IS
  'Production provider registry config. Includes service_root/service_roots, operations, auth, callback, and endpoint mappings.';

COMMENT ON TABLE public.provider_routing_rules IS
  'Runtime provider routing coverage by rail, operation, country, currency, provider, priority, status, and optional JSON conditions.';
