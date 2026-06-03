ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS status_reason TEXT,
    ADD COLUMN IF NOT EXISTS status_reason_code TEXT,
    ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS status_changed_by TEXT;

ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS status_reason TEXT,
    ADD COLUMN IF NOT EXISTS status_reason_code TEXT,
    ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS status_changed_by TEXT;

ALTER TABLE public.wallets
    ADD COLUMN IF NOT EXISTS lock_reason TEXT,
    ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.platform_vaults
    ADD COLUMN IF NOT EXISTS lock_reason TEXT,
    ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_users_account_status_reason
ON public.users(account_status, status_reason_code, status_changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_staff_account_status_reason
ON public.staff(account_status, status_reason_code, status_changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_wallets_lock_reason
ON public.wallets(status, is_locked, locked_at DESC);

CREATE INDEX IF NOT EXISTS idx_platform_vaults_lock_reason
ON public.platform_vaults(status, is_locked, locked_at DESC);
