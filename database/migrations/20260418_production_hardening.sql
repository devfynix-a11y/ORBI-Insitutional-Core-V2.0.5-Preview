-- ORBI production hardening additive migration
-- Adds migration tracking, provider configuration versioning, provider SLA metrics,
-- and offline SMS dedupe keys without rewriting existing data.

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version TEXT PRIMARY KEY,
    description TEXT,
    checksum TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.provider_config_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.financial_partners(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    mapping_config JSONB NOT NULL,
    provider_metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'CANARY', 'ACTIVE', 'ARCHIVED', 'ROLLBACK')),
    canary_percentage NUMERIC NOT NULL DEFAULT 0 CHECK (canary_percentage >= 0 AND canary_percentage <= 100),
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(provider_id, version)
);

CREATE INDEX IF NOT EXISTS idx_provider_config_versions_provider_status
    ON public.provider_config_versions(provider_id, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_provider_config_versions_one_active
    ON public.provider_config_versions(provider_id)
    WHERE status = 'ACTIVE';

CREATE TABLE IF NOT EXISTS public.provider_performance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.financial_partners(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
    operation_code TEXT NOT NULL DEFAULT 'ALL',
    total_requests INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    avg_latency_ms NUMERIC NOT NULL DEFAULT 0,
    p95_latency_ms NUMERIC NOT NULL DEFAULT 0,
    p99_latency_ms NUMERIC NOT NULL DEFAULT 0,
    error_rate NUMERIC NOT NULL DEFAULT 0,
    sla_violations INTEGER NOT NULL DEFAULT 0,
    cost_per_transaction NUMERIC NOT NULL DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(provider_id, metric_date, operation_code)
);

CREATE INDEX IF NOT EXISTS idx_provider_performance_provider_date
    ON public.provider_performance_metrics(provider_id, metric_date DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_inbound_sms_gateway_carrier_ref
    ON public.inbound_sms_messages(gateway_id, carrier_ref)
    WHERE carrier_ref IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_inbound_sms_gateway_request
    ON public.inbound_sms_messages(gateway_id, request_id)
    WHERE request_id IS NOT NULL;

ALTER TABLE public.provider_config_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin manage provider config versions" ON public.provider_config_versions;
CREATE POLICY "Admin manage provider config versions" ON public.provider_config_versions
    FOR ALL USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'IT', 'FINANCE'))
    WITH CHECK ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'IT', 'FINANCE'));

DROP POLICY IF EXISTS "Service role provider config version bypass" ON public.provider_config_versions;
CREATE POLICY "Service role provider config version bypass" ON public.provider_config_versions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admin view provider performance metrics" ON public.provider_performance_metrics;
CREATE POLICY "Admin view provider performance metrics" ON public.provider_performance_metrics
    FOR SELECT USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'IT', 'FINANCE', 'AUDIT'));

DROP POLICY IF EXISTS "Service role provider performance bypass" ON public.provider_performance_metrics;
CREATE POLICY "Service role provider performance bypass" ON public.provider_performance_metrics
    FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admin manage schema migrations" ON public.schema_migrations;
CREATE POLICY "Admin manage schema migrations" ON public.schema_migrations
    FOR ALL USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'IT', 'AUDIT'))
    WITH CHECK ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'IT', 'AUDIT'));

DROP POLICY IF EXISTS "Service role schema migrations bypass" ON public.schema_migrations;
CREATE POLICY "Service role schema migrations bypass" ON public.schema_migrations
    FOR ALL TO service_role USING (true) WITH CHECK (true);

INSERT INTO public.schema_migrations(version, description, checksum, metadata)
VALUES (
    '20260418_production_hardening',
    'Provider versioning, provider SLA metrics, SMS dedupe, and migration tracking.',
    NULL,
    jsonb_build_object('source', 'database/migrations/20260418_production_hardening.sql')
)
ON CONFLICT (version) DO NOTHING;
