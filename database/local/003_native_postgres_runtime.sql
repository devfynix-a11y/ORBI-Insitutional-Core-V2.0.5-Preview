CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version TEXT PRIMARY KEY,
    description TEXT,
    checksum TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.schema_migrations (
    version,
    description,
    metadata
)
VALUES (
    '20260622_native_postgres_runtime',
    'Native PostgreSQL roles, request claims, and self-hosted schema bootstrap',
    jsonb_build_object(
        'provider', 'postgresql',
        'auth_provider', 'keycloak',
        'source', 'database/local/003_native_postgres_runtime.sql'
    )
)
ON CONFLICT (version) DO UPDATE
SET
    description = EXCLUDED.description,
    metadata = EXCLUDED.metadata;

REVOKE ALL ON public.schema_migrations FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON public.schema_migrations TO service_role;
