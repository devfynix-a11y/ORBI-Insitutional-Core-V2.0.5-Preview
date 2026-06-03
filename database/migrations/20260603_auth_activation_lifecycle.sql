-- ORBI auth activation lifecycle hardening.
-- New consumer/staff identities are quarantined until OTP-confirmed.

ALTER TABLE public.users
    ALTER COLUMN email DROP NOT NULL,
    ALTER COLUMN account_status SET DEFAULT 'pending_confirmation';

ALTER TABLE public.staff
    ALTER COLUMN account_status SET DEFAULT 'pending_confirmation';

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS auth_confirmed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS activation_expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    ADD COLUMN IF NOT EXISTS activation_method TEXT;

ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS auth_confirmed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS activation_expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    ADD COLUMN IF NOT EXISTS activation_method TEXT;

CREATE INDEX IF NOT EXISTS idx_users_pending_activation_expiry
ON public.users (activation_expires_at)
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive');

CREATE INDEX IF NOT EXISTS idx_staff_pending_activation_expiry
ON public.staff (activation_expires_at)
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive');

-- Expired identity termination is intentionally handled by the backend through
-- Supabase Admin deleteUser(), so auth.users and public profile rows are
-- removed together through the existing ON DELETE CASCADE relationship.
