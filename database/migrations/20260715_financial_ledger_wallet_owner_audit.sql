-- Financial ledger audit ownership hardening.
--
-- Ledger balances are computed by wallet_id. This migration ensures
-- financial_ledger.user_id also reflects the owner of wallet_id, not merely
-- the actor who initiated the parent transaction. Actor identity remains on
-- transactions.user_id and audit_trail.

CREATE OR REPLACE FUNCTION public.resolve_financial_ledger_wallet_owner(
    p_wallet_id UUID,
    p_fallback_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_owner UUID;
BEGIN
    IF p_wallet_id IS NULL THEN
        RETURN p_fallback_user_id;
    END IF;

    SELECT COALESCE(w.user_id, pv.user_id, g.user_id, p_fallback_user_id)
      INTO v_owner
      FROM (SELECT p_wallet_id AS id) x
      LEFT JOIN public.wallets w ON w.id = x.id
      LEFT JOIN public.platform_vaults pv ON pv.id = x.id
      LEFT JOIN public.goals g ON g.id = x.id;

    RETURN COALESCE(v_owner, p_fallback_user_id);
END;
$$ LANGUAGE plpgsql STABLE SET search_path = public;

COMMENT ON FUNCTION public.resolve_financial_ledger_wallet_owner(UUID, UUID)
IS 'Resolves the owner of a financial ledger wallet/vault/goal. Used for audit ownership only; balances remain wallet_id based.';

CREATE OR REPLACE FUNCTION public.set_financial_ledger_wallet_owner()
RETURNS trigger AS $$
BEGIN
    NEW.user_id := public.resolve_financial_ledger_wallet_owner(NEW.wallet_id, NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS trg_financial_ledger_wallet_owner ON public.financial_ledger;
CREATE TRIGGER trg_financial_ledger_wallet_owner
BEFORE INSERT OR UPDATE OF wallet_id, user_id ON public.financial_ledger
FOR EACH ROW
EXECUTE FUNCTION public.set_financial_ledger_wallet_owner();

UPDATE public.financial_ledger fl
   SET user_id = public.resolve_financial_ledger_wallet_owner(fl.wallet_id, fl.user_id)
 WHERE fl.wallet_id IS NOT NULL
   AND fl.user_id IS DISTINCT FROM public.resolve_financial_ledger_wallet_owner(fl.wallet_id, fl.user_id);
