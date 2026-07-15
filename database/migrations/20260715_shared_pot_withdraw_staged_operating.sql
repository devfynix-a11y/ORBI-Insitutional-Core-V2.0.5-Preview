-- Shared Pot withdrawal staging hardening.
-- Enforces Fungu -> PaySafe/Internal Transfer staging -> Operating wallet credit.
-- This keeps shared-pot withdrawals auditable without treating them as external income.

CREATE OR REPLACE FUNCTION public.shared_pot_withdraw_v1(
    p_user_id UUID,
    p_pot_id UUID,
    p_target_wallet_id UUID,
    p_amount NUMERIC,
    p_currency TEXT DEFAULT 'TZS',
    p_description TEXT DEFAULT NULL,
    p_reference_id TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor UUID := COALESCE(auth.uid(), p_user_id);
    v_pot public.shared_pots%ROWTYPE;
    v_member public.shared_pot_members%ROWTYPE;
    v_target_wallet public.wallets%ROWTYPE;
    v_target_vault public.platform_vaults%ROWTYPE;
    v_staging_vault public.platform_vaults%ROWTYPE;
    v_existing public.transactions%ROWTYPE;
    v_target_table TEXT;
    v_target_role TEXT;
    v_target_currency TEXT;
    v_target_balance NUMERIC;
    v_target_balance_after NUMERIC;
    v_staging_balance NUMERIC;
    v_staging_balance_after_hold NUMERIC;
    v_staging_balance_after_release NUMERIC;
    v_pot_balance_after NUMERIC;
    v_tx_id UUID := gen_random_uuid();
    v_reference_id TEXT := NULLIF(BTRIM(COALESCE(p_reference_id, '')), '');
BEGIN
    IF v_actor IS NULL OR (auth.uid() IS NOT NULL AND auth.uid() <> p_user_id) THEN
        RAISE EXCEPTION 'SHARED_POT_ACTOR_INVALID';
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'INVALID_AMOUNT'; END IF;
    IF v_reference_id IS NULL THEN RAISE EXCEPTION 'SHARED_POT_IDEMPOTENCY_REQUIRED'; END IF;

    SELECT * INTO v_pot
    FROM public.shared_pots
    WHERE id = p_pot_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'SHARED_POT_NOT_FOUND'; END IF;
    IF v_pot.status <> 'ACTIVE' THEN RAISE EXCEPTION 'SHARED_POT_NOT_ACTIVE'; END IF;

    SELECT * INTO v_member
    FROM public.shared_pot_members
    WHERE pot_id = p_pot_id AND user_id = v_actor
    FOR UPDATE;
    IF NOT FOUND OR v_member.role NOT IN ('OWNER', 'MANAGER', 'CONTRIBUTOR') THEN
        RAISE EXCEPTION 'SHARED_POT_WITHDRAW_DENIED';
    END IF;

    SELECT * INTO v_existing
    FROM public.transactions
    WHERE reference_id = v_reference_id
    FOR UPDATE;
    IF FOUND THEN
        IF v_existing.user_id <> v_actor
           OR v_existing.wallet_id <> p_target_wallet_id
           OR v_existing.amount::NUMERIC <> p_amount
           OR v_existing.allocation_source <> 'SHARED_POT_WITHDRAWAL'
           OR v_existing.metadata->>'shared_pot_id' <> p_pot_id::TEXT THEN
            RAISE EXCEPTION 'SHARED_POT_REPLAY_MISMATCH';
        END IF;
        RETURN jsonb_build_object(
            'transaction_id', v_existing.id,
            'reference_id', v_reference_id,
            'pot_balance_after', v_pot.current_amount,
            'idempotent', TRUE
        );
    END IF;

    IF COALESCE(v_pot.current_amount, 0) < p_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_POT_FUNDS';
    END IF;

    SELECT * INTO v_staging_vault
    FROM public.platform_vaults
    WHERE user_id = v_actor
      AND vault_role = 'INTERNAL_TRANSFER'
      AND LOWER(COALESCE(status, 'active')) = 'active'
      AND COALESCE(is_locked, FALSE) IS FALSE
    ORDER BY created_at ASC NULLS LAST
    LIMIT 1
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SHARED_POT_STAGING_VAULT_UNAVAILABLE';
    END IF;

    SELECT * INTO v_target_vault
    FROM public.platform_vaults
    WHERE id = p_target_wallet_id AND user_id = v_actor
    FOR UPDATE;
    IF FOUND THEN
        IF COALESCE(v_target_vault.is_locked, FALSE)
           OR LOWER(COALESCE(v_target_vault.status, 'active')) <> 'active' THEN
            RAISE EXCEPTION 'TARGET_WALLET_UNAVAILABLE';
        END IF;
        IF v_target_vault.vault_role <> 'OPERATING' THEN
            RAISE EXCEPTION 'SHARED_POT_TARGET_MUST_BE_OPERATING';
        END IF;
        v_target_table := 'platform_vaults';
        v_target_role := v_target_vault.vault_role;
        v_target_balance := COALESCE(v_target_vault.balance, 0);
        v_target_currency := UPPER(COALESCE(v_target_vault.currency, 'TZS'));
    ELSE
        SELECT * INTO v_target_wallet
        FROM public.wallets
        WHERE id = p_target_wallet_id AND user_id = v_actor
        FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'NO_OPERATING_WALLET'; END IF;
        IF COALESCE(v_target_wallet.is_locked, FALSE)
           OR LOWER(COALESCE(v_target_wallet.status, 'active')) <> 'active' THEN
            RAISE EXCEPTION 'TARGET_WALLET_UNAVAILABLE';
        END IF;
        IF UPPER(COALESCE(v_target_wallet.type, '')) <> 'OPERATING' THEN
            RAISE EXCEPTION 'SHARED_POT_TARGET_MUST_BE_OPERATING';
        END IF;
        v_target_table := 'wallets';
        v_target_role := v_target_wallet.type;
        v_target_balance := COALESCE(v_target_wallet.balance, 0);
        v_target_currency := UPPER(COALESCE(v_target_wallet.currency, 'TZS'));
    END IF;

    IF UPPER(COALESCE(v_staging_vault.currency, 'TZS')) <> UPPER(COALESCE(v_pot.currency, 'TZS'))
       OR v_target_currency <> UPPER(COALESCE(v_pot.currency, 'TZS'))
       OR UPPER(BTRIM(COALESCE(p_currency, v_pot.currency, 'TZS'))) <> UPPER(COALESCE(v_pot.currency, 'TZS')) THEN
        RAISE EXCEPTION 'SHARED_POT_CURRENCY_MISMATCH';
    END IF;

    v_staging_balance := COALESCE(v_staging_vault.balance, 0);
    v_staging_balance_after_hold := v_staging_balance + p_amount;
    v_staging_balance_after_release := v_staging_balance;
    v_target_balance_after := v_target_balance + p_amount;
    v_pot_balance_after := COALESCE(v_pot.current_amount, 0) - p_amount;

    INSERT INTO public.transactions (
        id, reference_id, user_id, wallet_id, amount, currency, description,
        type, status, date, wealth_impact_type, protection_state, allocation_source, metadata
    ) VALUES (
        v_tx_id, v_reference_id, v_actor, p_target_wallet_id, p_amount::TEXT,
        UPPER(v_pot.currency),
        COALESCE(NULLIF(BTRIM(COALESCE(p_description, '')), ''), 'Shared pot withdrawal'),
        'internal_transfer', 'completed', CURRENT_DATE, 'GROWING', 'OPEN',
        'SHARED_POT_WITHDRAWAL',
        COALESCE(p_metadata, '{}'::jsonb)
            || jsonb_build_object(
                'shared_pot_id', p_pot_id,
                'actor_user_id', v_actor,
                'shared_pot_withdrawal_flow', 'POT_TO_PAYSAFE_TO_OPERATING',
                'staging_vault_id', v_staging_vault.id,
                'staging_vault_role', v_staging_vault.vault_role,
                'target_table', v_target_table,
                'target_wallet_role', v_target_role,
                'movement_family', 'INTERNAL_SS',
                'movement_code', 'SS_SHARED_POT_WITHDRAWAL'
            )
    );

    UPDATE public.platform_vaults
    SET balance = v_staging_balance_after_release, updated_at = NOW()
    WHERE id = v_staging_vault.id AND user_id = v_actor;

    IF v_target_table = 'wallets' THEN
        UPDATE public.wallets SET balance = v_target_balance_after, updated_at = NOW()
        WHERE id = p_target_wallet_id AND user_id = v_actor;
    ELSE
        UPDATE public.platform_vaults SET balance = v_target_balance_after, updated_at = NOW()
        WHERE id = p_target_wallet_id AND user_id = v_actor;
    END IF;

    UPDATE public.shared_pots
    SET current_amount = v_pot_balance_after, updated_at = NOW()
    WHERE id = p_pot_id;

    INSERT INTO public.financial_ledger (
        transaction_id, user_id, wallet_id, shared_pot_id, bucket_type,
        entry_side, entry_type, amount, balance_after, description
    ) VALUES
    (
        v_tx_id, v_actor, v_staging_vault.id, p_pot_id, 'GROWING',
        'DEBIT', 'DEBIT', p_amount::TEXT, v_pot_balance_after::TEXT,
        'Shared pot withdrawal debit: ' || v_pot.name
    ),
    (
        v_tx_id, v_actor, v_staging_vault.id, p_pot_id, 'INTERNAL_TRANSFER',
        'CREDIT', 'CREDIT', p_amount::TEXT, v_staging_balance_after_hold::TEXT,
        'Shared pot withdrawal staging hold: ' || v_pot.name
    ),
    (
        v_tx_id, v_actor, v_staging_vault.id, p_pot_id, 'INTERNAL_TRANSFER',
        'DEBIT', 'DEBIT', p_amount::TEXT, v_staging_balance_after_release::TEXT,
        'Shared pot withdrawal staging release: ' || v_pot.name
    ),
    (
        v_tx_id, v_actor, p_target_wallet_id, p_pot_id, 'OPERATING',
        'CREDIT', 'CREDIT', p_amount::TEXT, v_target_balance_after::TEXT,
        'Shared pot withdrawal operating credit: ' || v_pot.name
    );

    RETURN jsonb_build_object(
        'transaction_id', v_tx_id,
        'reference_id', v_reference_id,
        'target_balance_after', v_target_balance_after,
        'staging_balance_after', v_staging_balance_after_release,
        'pot_balance_after', v_pot_balance_after,
        'target_table', v_target_table,
        'staging_vault_id', v_staging_vault.id,
        'flow', 'POT_TO_PAYSAFE_TO_OPERATING',
        'idempotent', FALSE
    );
END;
$$;

REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(
    UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) TO service_role';
    END IF;
END $$;
