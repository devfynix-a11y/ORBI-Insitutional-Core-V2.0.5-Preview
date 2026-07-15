-- Shared Pot enterprise governance: access-model policy, withdrawal approvals, and audit-ready controls.

ALTER TABLE public.shared_pots
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS governance_model TEXT NOT NULL DEFAULT 'OWNER_CONTROLLED',
    ADD COLUMN IF NOT EXISTS withdrawal_policy TEXT NOT NULL DEFAULT 'OWNER_OR_MANAGER',
    ADD COLUMN IF NOT EXISTS min_withdrawal_approvals INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS withdrawal_limit_amount NUMERIC,
    ADD COLUMN IF NOT EXISTS maturity_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS require_withdrawal_reason BOOLEAN NOT NULL DEFAULT false;

DO $$
BEGIN
    ALTER TABLE public.shared_pots
        DROP CONSTRAINT IF EXISTS shared_pots_governance_model_check,
        ADD CONSTRAINT shared_pots_governance_model_check
            CHECK (governance_model IN ('OWNER_CONTROLLED', 'MEMBER_APPROVAL', 'ORG_APPROVAL'));

    ALTER TABLE public.shared_pots
        DROP CONSTRAINT IF EXISTS shared_pots_withdrawal_policy_check,
        ADD CONSTRAINT shared_pots_withdrawal_policy_check
            CHECK (withdrawal_policy IN ('OWNER_ONLY', 'OWNER_OR_MANAGER', 'APPROVAL_REQUIRED'));

    ALTER TABLE public.shared_pots
        DROP CONSTRAINT IF EXISTS shared_pots_min_withdrawal_approvals_check,
        ADD CONSTRAINT shared_pots_min_withdrawal_approvals_check
            CHECK (min_withdrawal_approvals >= 1 AND min_withdrawal_approvals <= 10);
END $$;

UPDATE public.shared_pots
SET
    governance_model = CASE
        WHEN access_model = 'ORG' THEN 'ORG_APPROVAL'
        ELSE 'OWNER_CONTROLLED'
    END,
    withdrawal_policy = CASE
        WHEN access_model = 'ORG' THEN 'APPROVAL_REQUIRED'
        WHEN access_model = 'PRIVATE' THEN 'OWNER_ONLY'
        ELSE 'OWNER_OR_MANAGER'
    END,
    min_withdrawal_approvals = CASE
        WHEN access_model = 'ORG' THEN GREATEST(min_withdrawal_approvals, 2)
        ELSE min_withdrawal_approvals
    END
WHERE governance_model = 'OWNER_CONTROLLED'
  AND withdrawal_policy = 'OWNER_OR_MANAGER';

CREATE TABLE IF NOT EXISTS public.shared_pot_withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pot_id UUID NOT NULL REFERENCES public.shared_pots(id) ON DELETE CASCADE,
    requester_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_wallet_id UUID NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    currency TEXT NOT NULL DEFAULT 'TZS',
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXECUTED')),
    required_approvals INTEGER NOT NULL DEFAULT 1 CHECK (required_approvals >= 1 AND required_approvals <= 10),
    approvals JSONB NOT NULL DEFAULT '[]'::jsonb,
    rejection_reason TEXT,
    transaction_id UUID,
    idempotency_key TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.shared_pot_delete_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pot_id UUID NOT NULL REFERENCES public.shared_pots(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'PENDING_APPROVAL'
        CHECK (status IN ('PENDING_APPROVAL', 'SCHEDULED', 'CANCELLED', 'REJECTED', 'ARCHIVED')),
    required_approvals INTEGER NOT NULL DEFAULT 3 CHECK (required_approvals >= 3),
    approvals JSONB NOT NULL DEFAULT '[]'::jsonb,
    reason TEXT,
    otp_verified_at TIMESTAMPTZ,
    scheduled_archive_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_shared_pot_withdrawal_request_idempotency
    ON public.shared_pot_withdrawal_requests(requester_user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shared_pot_withdrawal_requests_pot
    ON public.shared_pot_withdrawal_requests(pot_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_shared_pot_withdrawal_requests_requester
    ON public.shared_pot_withdrawal_requests(requester_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shared_pot_delete_requests_pot
    ON public.shared_pot_delete_requests(pot_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shared_pot_delete_requests_due
    ON public.shared_pot_delete_requests(status, scheduled_archive_at);

ALTER TABLE public.shared_pot_withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_pot_delete_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shared_pot_withdrawal_requests_service_role ON public.shared_pot_withdrawal_requests;
CREATE POLICY shared_pot_withdrawal_requests_service_role ON public.shared_pot_withdrawal_requests
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS shared_pot_delete_requests_service_role ON public.shared_pot_delete_requests;
CREATE POLICY shared_pot_delete_requests_service_role ON public.shared_pot_delete_requests
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
