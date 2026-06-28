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

CREATE TABLE IF NOT EXISTS public.ops_action_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_type TEXT NOT NULL CHECK (action_type IN ('DEPLOY_APPROVED_COMMIT', 'RUN_MANUAL_BACKUP', 'RESTORE_BACKUP_DRILL')),
    status TEXT NOT NULL DEFAULT 'PENDING_APPROVAL' CHECK (status IN ('PENDING_APPROVAL', 'READY', 'QUEUED_FOR_AGENT', 'COMPLETED', 'FAILED', 'CANCELLED')),
    requested_by TEXT NOT NULL,
    requested_reason TEXT NOT NULL,
    target_environment TEXT NOT NULL DEFAULT 'staging',
    command_plan JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    approvals JSONB NOT NULL DEFAULT '[]'::jsonb,
    required_approvals INTEGER NOT NULL DEFAULT 2 CHECK (required_approvals >= 2),
    executed_by TEXT,
    execution_result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ops_action_requests_status_created ON public.ops_action_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ops_action_requests_type_created ON public.ops_action_requests(action_type, created_at DESC);
