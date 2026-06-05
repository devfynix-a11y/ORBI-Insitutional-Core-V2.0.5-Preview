CREATE TABLE IF NOT EXISTS public.payment_rail_capabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    switch_partner_id UUID NOT NULL REFERENCES public.financial_partners(id) ON DELETE CASCADE,
    capability_code TEXT NOT NULL,
    display_name TEXT NOT NULL,
    rail TEXT NOT NULL,
    country_code TEXT NOT NULL,
    currency TEXT NOT NULL,
    operation_codes TEXT[] NOT NULL DEFAULT ARRAY['COLLECTION_REQUEST','DISBURSEMENT_REQUEST']::TEXT[],
    status TEXT NOT NULL DEFAULT 'INACTIVE',
    priority INTEGER NOT NULL DEFAULT 100,
    min_amount NUMERIC,
    max_amount NUMERIC,
    fee_profile_code TEXT,
    pay_gateway_provider_code TEXT,
    pay_gateway_capability_code TEXT,
    icon TEXT,
    color TEXT,
    requires JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT payment_rail_capabilities_unique_code_per_partner UNIQUE (switch_partner_id, capability_code),
    CONSTRAINT payment_rail_capabilities_rail_check CHECK (rail IN ('MOBILE_MONEY','BANK','CARD_GATEWAY','CRYPTO','WALLET')),
    CONSTRAINT payment_rail_capabilities_status_check CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE'))
);

CREATE INDEX IF NOT EXISTS idx_payment_rail_capabilities_lookup
    ON public.payment_rail_capabilities(country_code, currency, rail, status, priority);

CREATE INDEX IF NOT EXISTS idx_payment_rail_capabilities_operations
    ON public.payment_rail_capabilities USING GIN (operation_codes);

CREATE INDEX IF NOT EXISTS idx_payment_rail_capabilities_partner
    ON public.payment_rail_capabilities(switch_partner_id, status, priority);

COMMENT ON TABLE public.payment_rail_capabilities IS
    'Consumer-visible rail/provider capabilities exposed through a partner bank or sponsored switch profile. Credentials and execution remain in ORBI Pay Gateway.';

ALTER TABLE public.payment_rail_capabilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read active payment rail capabilities" ON public.payment_rail_capabilities;
CREATE POLICY "Authenticated read active payment rail capabilities" ON public.payment_rail_capabilities
    FOR SELECT TO authenticated
    USING (status = 'ACTIVE');

DROP POLICY IF EXISTS "Admin manage payment rail capabilities" ON public.payment_rail_capabilities;
CREATE POLICY "Admin manage payment rail capabilities" ON public.payment_rail_capabilities
    FOR ALL TO authenticated
    USING ((auth.jwt() ->> 'role') IN ('ADMIN','SUPER_ADMIN','IT'))
    WITH CHECK ((auth.jwt() ->> 'role') IN ('ADMIN','SUPER_ADMIN','IT'));

DROP POLICY IF EXISTS "Service role payment rail capability bypass" ON public.payment_rail_capabilities;
CREATE POLICY "Service role payment rail capability bypass" ON public.payment_rail_capabilities
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);
