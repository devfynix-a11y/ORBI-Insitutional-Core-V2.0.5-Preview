-- Organization governance for organization-owned Fungu and enterprise member administration.

ALTER TABLE public.organizations
    ADD COLUMN IF NOT EXISTS creator_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS primary_admin_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS owner_type TEXT NOT NULL DEFAULT 'ORGANIZATION',
    ADD COLUMN IF NOT EXISTS owner_label TEXT;

DO $$
BEGIN
    ALTER TABLE public.organizations
        DROP CONSTRAINT IF EXISTS organizations_owner_type_check,
        ADD CONSTRAINT organizations_owner_type_check
            CHECK (owner_type IN ('ORGANIZATION', 'GROUP', 'COMPANY'));
END $$;

CREATE TABLE IF NOT EXISTS public.organization_role_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    role_key TEXT NOT NULL,
    role_name TEXT NOT NULL,
    permissions JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_system BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (organization_id, role_key)
);

CREATE TABLE IF NOT EXISTS public.organization_role_change_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('ADD_ADMIN', 'REMOVE_ADMIN', 'TRANSFER_PRIMARY_ADMIN')),
    from_role TEXT,
    to_role TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXECUTED', 'CANCELLED')),
    required_approvals INTEGER NOT NULL DEFAULT 3 CHECK (required_approvals >= 3),
    approvals JSONB NOT NULL DEFAULT '[]'::jsonb,
    reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_org_role_defs_org
    ON public.organization_role_definitions(organization_id, role_key);

CREATE INDEX IF NOT EXISTS idx_org_role_change_requests_org
    ON public.organization_role_change_requests(organization_id, status, created_at DESC);

ALTER TABLE public.organization_role_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_role_change_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organization_role_definitions_service_role ON public.organization_role_definitions;
CREATE POLICY organization_role_definitions_service_role ON public.organization_role_definitions
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS organization_role_change_requests_service_role ON public.organization_role_change_requests;
CREATE POLICY organization_role_change_requests_service_role ON public.organization_role_change_requests
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
