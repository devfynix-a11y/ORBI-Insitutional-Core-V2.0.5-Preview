-- Compatibility guard for databases that applied activation-window updates
-- before the original activation lifecycle migration.

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS auth_confirmed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS activation_expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    ADD COLUMN IF NOT EXISTS activation_method TEXT;

ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS auth_confirmed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS activation_expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    ADD COLUMN IF NOT EXISTS activation_method TEXT;

ALTER TABLE public.users
    ALTER COLUMN activation_expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

ALTER TABLE public.staff
    ALTER COLUMN activation_expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

CREATE INDEX IF NOT EXISTS idx_users_pending_activation_expiry
ON public.users (activation_expires_at)
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive');

CREATE INDEX IF NOT EXISTS idx_staff_pending_activation_expiry
ON public.staff (activation_expires_at)
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive');
