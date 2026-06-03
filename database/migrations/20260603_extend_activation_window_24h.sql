-- Extend incomplete registration support window to 24 hours.
-- This gives support/customer-care enough time to contact users before
-- unconfirmed identities are terminated by backend cleanup.

ALTER TABLE public.users
    ALTER COLUMN activation_expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

ALTER TABLE public.staff
    ALTER COLUMN activation_expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

UPDATE public.users
SET activation_expires_at = created_at + INTERVAL '24 hours'
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive')
  AND auth_confirmed_at IS NULL
  AND created_at IS NOT NULL
  AND (
    activation_expires_at IS NULL
    OR activation_expires_at < created_at + INTERVAL '24 hours'
  );

UPDATE public.staff
SET activation_expires_at = created_at + INTERVAL '24 hours'
WHERE account_status IN ('pending_confirmation', 'unconfirmed', 'inactive')
  AND auth_confirmed_at IS NULL
  AND created_at IS NOT NULL
  AND (
    activation_expires_at IS NULL
    OR activation_expires_at < created_at + INTERVAL '24 hours'
  );
