-- ORBI in-process API Gateway security persistence:
-- durable forensic events and active quarantine records.

CREATE TABLE IF NOT EXISTS public.api_gateway_security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id TEXT,
    actor_ref TEXT,
    route TEXT NOT NULL,
    method TEXT NOT NULL,
    route_group TEXT NOT NULL,
    operation_class TEXT NOT NULL,
    action TEXT NOT NULL,
    risk_score NUMERIC NOT NULL DEFAULT 0,
    ip_hash TEXT,
    device_hash TEXT,
    app_id TEXT,
    trace_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT api_gateway_security_events_action_check
        CHECK (action IN (
            'API_GATEWAY_ALLOWED',
            'API_GATEWAY_THROTTLED',
            'API_GATEWAY_ATTEMPT_LOCKED',
            'API_GATEWAY_QUARANTINED',
            'API_GATEWAY_AI_SCORE_APPLIED'
        ))
);

CREATE INDEX IF NOT EXISTS idx_api_gateway_security_events_created
    ON public.api_gateway_security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_gateway_security_events_actor_created
    ON public.api_gateway_security_events(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_gateway_security_events_route_group_created
    ON public.api_gateway_security_events(route_group, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_gateway_security_events_action_created
    ON public.api_gateway_security_events(action, created_at DESC);

CREATE TABLE IF NOT EXISTS public.api_gateway_quarantines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id TEXT,
    actor_ref TEXT,
    route_group TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    released_at TIMESTAMP WITH TIME ZONE,
    released_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT api_gateway_quarantines_status_check
        CHECK (status IN ('active', 'released', 'expired'))
);

CREATE INDEX IF NOT EXISTS idx_api_gateway_quarantines_active
    ON public.api_gateway_quarantines(status, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_gateway_quarantines_actor_created
    ON public.api_gateway_quarantines(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_gateway_quarantines_scope_key
    ON public.api_gateway_quarantines(scope_key);

ALTER TABLE public.api_gateway_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_gateway_quarantines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "API gateway security event read" ON public.api_gateway_security_events;
CREATE POLICY "API gateway security event read" ON public.api_gateway_security_events
    FOR SELECT USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT'));

DROP POLICY IF EXISTS "API gateway security event system write" ON public.api_gateway_security_events;
CREATE POLICY "API gateway security event system write" ON public.api_gateway_security_events
    FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "API gateway quarantine read" ON public.api_gateway_quarantines;
CREATE POLICY "API gateway quarantine read" ON public.api_gateway_quarantines
    FOR SELECT USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT'));

DROP POLICY IF EXISTS "API gateway quarantine system write" ON public.api_gateway_quarantines;
CREATE POLICY "API gateway quarantine system write" ON public.api_gateway_quarantines
    FOR ALL TO service_role USING (true) WITH CHECK (true);
