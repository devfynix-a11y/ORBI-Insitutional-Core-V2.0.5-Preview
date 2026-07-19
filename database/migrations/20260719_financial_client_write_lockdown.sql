-- Prevent client-side direct financial writes.
--
-- Mobile/web clients must mutate balances only through Core API flows that
-- enforce idempotency, risk checks, and double-entry ledger invariants.
-- Direct public writes to balances or transaction rows are intentionally
-- disabled; service_role retains the engine/admin path.

BEGIN;

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_vaults ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users create transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users view own transactions" ON public.transactions;
CREATE POLICY "Users view own transactions"
ON public.transactions
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role transaction bypass" ON public.transactions;
CREATE POLICY "Service role transaction bypass"
ON public.transactions
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Users manage own wallets" ON public.wallets;
DROP POLICY IF EXISTS "Users view own wallets" ON public.wallets;
CREATE POLICY "Users view own wallets"
ON public.wallets
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own vaults" ON public.platform_vaults;
DROP POLICY IF EXISTS "Users view own vaults" ON public.platform_vaults;
CREATE POLICY "Users view own vaults"
ON public.platform_vaults
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role vault bypass" ON public.platform_vaults;
CREATE POLICY "Service role vault bypass"
ON public.platform_vaults
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

COMMIT;
