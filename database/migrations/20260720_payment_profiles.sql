-- ORBI payment profiles for external merchant/platform infrastructure.
-- Merchants store profile references; Core keeps consent and financial identity linkage.

CREATE TABLE IF NOT EXISTS public.payment_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id TEXT NOT NULL UNIQUE,
    service_code TEXT NOT NULL,
    external_customer_id TEXT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    customer_id TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'revoked', 'expired')),
    scopes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    consent_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_by_worker_id TEXT,
    idempotency_key TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CHECK (array_length(scopes, 1) IS NOT NULL AND array_length(scopes, 1) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_profiles_service_idempotency
    ON public.payment_profiles(service_code, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_profiles_service_external_customer
    ON public.payment_profiles(service_code, external_customer_id)
    WHERE external_customer_id IS NOT NULL AND status <> 'revoked';

CREATE INDEX IF NOT EXISTS idx_payment_profiles_user
    ON public.payment_profiles(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_profiles_service_status
    ON public.payment_profiles(service_code, status, updated_at DESC);

ALTER TABLE public.payment_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_profiles_service_role
    ON public.payment_profiles;
CREATE POLICY payment_profiles_service_role
    ON public.payment_profiles
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS payment_profiles_user_read_own
    ON public.payment_profiles;
CREATE POLICY payment_profiles_user_read_own
    ON public.payment_profiles
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
