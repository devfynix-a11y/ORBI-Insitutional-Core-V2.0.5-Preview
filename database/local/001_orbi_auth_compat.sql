CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS orbi_auth;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id UUID,
    aud TEXT DEFAULT 'authenticated',
    role TEXT DEFAULT 'authenticated',
    email TEXT UNIQUE,
    phone TEXT UNIQUE,
    encrypted_password TEXT NOT NULL,
    email_confirmed_at TIMESTAMPTZ,
    phone_confirmed_at TIMESTAMPTZ,
    confirmation_sent_at TIMESTAMPTZ,
    recovery_sent_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ,
    raw_app_meta_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_user_meta_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    token_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.role', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
        'anon'
    )
$$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb,
        jsonb_strip_nulls(jsonb_build_object(
            'sub', NULLIF(current_setting('request.jwt.claim.sub', true), ''),
            'role', NULLIF(current_setting('request.jwt.claim.role', true), '')
        )),
        '{}'::jsonb
    )
$$;

CREATE OR REPLACE FUNCTION orbi_auth.set_request_context(
    p_user_id UUID,
    p_role TEXT DEFAULT 'authenticated',
    p_claims JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_claims JSONB;
BEGIN
    v_claims := COALESCE(p_claims, '{}'::jsonb)
        || jsonb_build_object(
            'sub', CASE WHEN p_user_id IS NULL THEN NULL ELSE p_user_id::text END,
            'role', COALESCE(NULLIF(p_role, ''), 'authenticated')
        );

    PERFORM set_config(
        'request.jwt.claim.sub',
        COALESCE(p_user_id::text, ''),
        true
    );
    PERFORM set_config(
        'request.jwt.claim.role',
        COALESCE(NULLIF(p_role, ''), 'authenticated'),
        true
    );
    PERFORM set_config('request.jwt.claims', v_claims::text, true);
END
$$;

CREATE TABLE IF NOT EXISTS orbi_auth.refresh_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    family_id UUID NOT NULL,
    device_fingerprint TEXT,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    replaced_by_session_id UUID REFERENCES orbi_auth.refresh_sessions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orbi_refresh_sessions_user_active
ON orbi_auth.refresh_sessions(user_id, expires_at)
WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_orbi_refresh_sessions_family
ON orbi_auth.refresh_sessions(family_id);

CREATE TABLE IF NOT EXISTS orbi_auth.revoked_access_tokens (
    jti UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orbi_revoked_access_tokens_expiry
ON orbi_auth.revoked_access_tokens(expires_at);

REVOKE ALL ON SCHEMA auth FROM PUBLIC;
REVOKE ALL ON SCHEMA orbi_auth FROM PUBLIC;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA orbi_auth TO service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.role() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.jwt() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION orbi_auth.set_request_context(UUID, TEXT, JSONB) TO service_role;
