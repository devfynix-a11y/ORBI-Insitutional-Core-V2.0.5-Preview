-- Atomic Shared Pot lifecycle hardening.
-- Financial and membership mutations are service-role-only and database authoritative.

ALTER TABLE public.shared_pots
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_shared_pots_owner_idempotency
    ON public.shared_pots(owner_user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.shared_pot_invitations
    ADD COLUMN IF NOT EXISTS response_idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_shared_pot_invitation_response_idempotency
    ON public.shared_pot_invitations(invitee_user_id, response_idempotency_key)
    WHERE response_idempotency_key IS NOT NULL;

ALTER TABLE public.shared_pots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_pot_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_pot_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shared_pots_service_role ON public.shared_pots;
CREATE POLICY shared_pots_service_role ON public.shared_pots
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS shared_pot_members_service_role ON public.shared_pot_members;
CREATE POLICY shared_pot_members_service_role ON public.shared_pot_members
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS shared_pot_invitations_service_role ON public.shared_pot_invitations;
CREATE POLICY shared_pot_invitations_service_role ON public.shared_pot_invitations
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP FUNCTION IF EXISTS public.shared_pot_contribute_v1(
    UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB
);
DROP FUNCTION IF EXISTS public.shared_pot_withdraw_v1(
    UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION public.create_shared_pot_v1(
    p_actor_user_id UUID,
    p_name TEXT,
    p_purpose TEXT DEFAULT NULL,
    p_currency TEXT DEFAULT 'TZS',
    p_target_amount NUMERIC DEFAULT 0,
    p_access_model TEXT DEFAULT 'INVITE',
    p_idempotency_key TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor UUID := COALESCE(auth.uid(), p_actor_user_id);
    v_pot public.shared_pots%ROWTYPE;
    v_currency TEXT := UPPER(BTRIM(COALESCE(p_currency, 'TZS')));
    v_access_model TEXT := UPPER(BTRIM(COALESCE(p_access_model, 'INVITE')));
    v_key TEXT := NULLIF(BTRIM(COALESCE(p_idempotency_key, '')), '');
BEGIN
    IF v_actor IS NULL OR (auth.uid() IS NOT NULL AND auth.uid() <> p_actor_user_id) THEN
        RAISE EXCEPTION 'SHARED_POT_ACTOR_INVALID';
    END IF;
    IF NULLIF(BTRIM(COALESCE(p_name, '')), '') IS NULL THEN
        RAISE EXCEPTION 'SHARED_POT_NAME_REQUIRED';
    END IF;
    IF COALESCE(p_target_amount, 0) < 0 THEN
        RAISE EXCEPTION 'SHARED_POT_TARGET_INVALID';
    END IF;
    IF v_access_model NOT IN ('INVITE', 'PRIVATE', 'ORG') THEN
        RAISE EXCEPTION 'SHARED_POT_ACCESS_MODEL_INVALID';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_actor AND LOWER(COALESCE(account_status, '')) = 'active'
    ) THEN
        RAISE EXCEPTION 'SHARED_POT_ACTOR_NOT_ACTIVE';
    END IF;

    IF v_key IS NOT NULL THEN
        SELECT * INTO v_pot
        FROM public.shared_pots
        WHERE owner_user_id = v_actor AND idempotency_key = v_key
        FOR UPDATE;

        IF FOUND THEN
            IF v_pot.name <> BTRIM(p_name)
               OR UPPER(COALESCE(v_pot.currency, '')) <> v_currency
               OR COALESCE(v_pot.target_amount, 0) <> COALESCE(p_target_amount, 0) THEN
                RAISE EXCEPTION 'SHARED_POT_CREATE_REPLAY_MISMATCH';
            END IF;
            RETURN jsonb_build_object('pot', to_jsonb(v_pot), 'idempotent', TRUE);
        END IF;
    END IF;

    INSERT INTO public.shared_pots (
        owner_user_id, name, purpose, currency, target_amount, current_amount,
        status, access_model, idempotency_key, metadata
    ) VALUES (
        v_actor,
        BTRIM(p_name),
        NULLIF(BTRIM(COALESCE(p_purpose, '')), ''),
        v_currency,
        COALESCE(p_target_amount, 0),
        0,
        'ACTIVE',
        v_access_model,
        v_key,
        COALESCE(p_metadata, '{}'::jsonb)
            || jsonb_build_object('created_by', v_actor, 'created_atomically', TRUE)
    )
    RETURNING * INTO v_pot;

    INSERT INTO public.shared_pot_members (
        pot_id, user_id, role, contributed_amount, metadata
    ) VALUES (
        v_pot.id, v_actor, 'OWNER', 0,
        jsonb_build_object('owner_membership', TRUE, 'created_atomically', TRUE)
    );

    RETURN jsonb_build_object('pot', to_jsonb(v_pot), 'idempotent', FALSE);
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_shared_pot_invitation_v1(
    p_actor_user_id UUID,
    p_invitation_id UUID,
    p_action TEXT,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor UUID := COALESCE(auth.uid(), p_actor_user_id);
    v_action TEXT := UPPER(BTRIM(COALESCE(p_action, '')));
    v_key TEXT := NULLIF(BTRIM(COALESCE(p_idempotency_key, '')), '');
    v_invite public.shared_pot_invitations%ROWTYPE;
    v_member public.shared_pot_members%ROWTYPE;
BEGIN
    IF v_actor IS NULL OR (auth.uid() IS NOT NULL AND auth.uid() <> p_actor_user_id) THEN
        RAISE EXCEPTION 'SHARED_POT_ACTOR_INVALID';
    END IF;
    IF v_action NOT IN ('ACCEPT', 'REJECT') THEN
        RAISE EXCEPTION 'SHARED_POT_INVITE_ACTION_INVALID';
    END IF;

    SELECT * INTO v_invite
    FROM public.shared_pot_invitations
    WHERE id = p_invitation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SHARED_POT_INVITE_NOT_FOUND';
    END IF;
    IF v_invite.invitee_user_id <> v_actor THEN
        RAISE EXCEPTION 'SHARED_POT_INVITE_ACCESS_DENIED';
    END IF;

    IF v_invite.status IN ('ACCEPTED', 'REJECTED')
       AND ((v_action = 'ACCEPT' AND v_invite.status = 'ACCEPTED')
         OR (v_action = 'REJECT' AND v_invite.status = 'REJECTED')) THEN
        SELECT * INTO v_member
        FROM public.shared_pot_members
        WHERE pot_id = v_invite.pot_id AND user_id = v_actor;
        RETURN jsonb_build_object(
            'invitation', to_jsonb(v_invite),
            'member', CASE WHEN v_member.id IS NULL THEN NULL ELSE to_jsonb(v_member) END,
            'idempotent', TRUE
        );
    END IF;

    IF v_invite.status <> 'PENDING' THEN
        RAISE EXCEPTION 'SHARED_POT_INVITE_NOT_PENDING';
    END IF;
    IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at <= NOW() THEN
        UPDATE public.shared_pot_invitations
        SET status = 'EXPIRED', responded_at = NOW(), updated_at = NOW()
        WHERE id = v_invite.id
        RETURNING * INTO v_invite;
        RAISE EXCEPTION 'SHARED_POT_INVITE_EXPIRED';
    END IF;

    IF v_action = 'ACCEPT' THEN
        INSERT INTO public.shared_pot_members (
            pot_id, user_id, role, contributed_amount, metadata
        ) VALUES (
            v_invite.pot_id,
            v_actor,
            v_invite.role,
            0,
            jsonb_build_object(
                'joined_via_invitation', v_invite.id,
                'invited_by', v_invite.inviter_user_id,
                'created_atomically', TRUE
            )
        )
        ON CONFLICT (pot_id, user_id) DO NOTHING
        RETURNING * INTO v_member;

        IF v_member.id IS NULL THEN
            RAISE EXCEPTION 'SHARED_POT_MEMBER_ALREADY_EXISTS';
        END IF;
    END IF;

    UPDATE public.shared_pot_invitations
    SET
        status = CASE WHEN v_action = 'ACCEPT' THEN 'ACCEPTED' ELSE 'REJECTED' END,
        response_idempotency_key = v_key,
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = v_invite.id
    RETURNING * INTO v_invite;

    RETURN jsonb_build_object(
        'invitation', to_jsonb(v_invite),
        'member', CASE WHEN v_member.id IS NULL THEN NULL ELSE to_jsonb(v_member) END,
        'idempotent', FALSE
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.shared_pot_contribute_v1(
    p_user_id UUID,
    p_pot_id UUID,
    p_source_wallet_id UUID,
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
    v_source_wallet public.wallets%ROWTYPE;
    v_source_vault public.platform_vaults%ROWTYPE;
    v_existing public.transactions%ROWTYPE;
    v_source_table TEXT;
    v_source_currency TEXT;
    v_source_balance NUMERIC;
    v_source_balance_after NUMERIC;
    v_pot_balance_after NUMERIC;
    v_tx_id UUID := gen_random_uuid();
    v_reference_id TEXT := NULLIF(BTRIM(COALESCE(p_reference_id, '')), '');
BEGIN
    IF v_actor IS NULL OR (auth.uid() IS NOT NULL AND auth.uid() <> p_user_id) THEN
        RAISE EXCEPTION 'SHARED_POT_ACTOR_INVALID';
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT';
    END IF;
    IF v_reference_id IS NULL THEN
        RAISE EXCEPTION 'SHARED_POT_IDEMPOTENCY_REQUIRED';
    END IF;

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
        RAISE EXCEPTION 'SHARED_POT_CONTRIBUTION_DENIED';
    END IF;

    SELECT * INTO v_existing
    FROM public.transactions
    WHERE reference_id = v_reference_id
    FOR UPDATE;
    IF FOUND THEN
        IF v_existing.user_id <> v_actor
           OR v_existing.wallet_id <> p_source_wallet_id
           OR v_existing.amount::NUMERIC <> p_amount
           OR v_existing.allocation_source <> 'SHARED_POT_CONTRIBUTION'
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

    SELECT * INTO v_source_vault
    FROM public.platform_vaults
    WHERE id = p_source_wallet_id AND user_id = v_actor
    FOR UPDATE;
    IF FOUND THEN
        IF COALESCE(v_source_vault.is_locked, FALSE)
           OR LOWER(COALESCE(v_source_vault.status, 'active')) <> 'active' THEN
            RAISE EXCEPTION 'SOURCE_WALLET_UNAVAILABLE';
        END IF;
        v_source_table := 'platform_vaults';
        v_source_balance := COALESCE(v_source_vault.balance, 0);
        v_source_currency := UPPER(COALESCE(v_source_vault.currency, 'TZS'));
    ELSE
        SELECT * INTO v_source_wallet
        FROM public.wallets
        WHERE id = p_source_wallet_id AND user_id = v_actor
        FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'NO_OPERATING_WALLET'; END IF;
        IF COALESCE(v_source_wallet.is_locked, FALSE)
           OR LOWER(COALESCE(v_source_wallet.status, 'active')) <> 'active' THEN
            RAISE EXCEPTION 'SOURCE_WALLET_UNAVAILABLE';
        END IF;
        v_source_table := 'wallets';
        v_source_balance := COALESCE(v_source_wallet.balance, 0);
        v_source_currency := UPPER(COALESCE(v_source_wallet.currency, 'TZS'));
    END IF;

    IF v_source_currency <> UPPER(COALESCE(v_pot.currency, 'TZS'))
       OR UPPER(BTRIM(COALESCE(p_currency, v_pot.currency, 'TZS'))) <> UPPER(COALESCE(v_pot.currency, 'TZS')) THEN
        RAISE EXCEPTION 'SHARED_POT_CURRENCY_MISMATCH';
    END IF;
    IF v_source_balance < p_amount THEN RAISE EXCEPTION 'INSUFFICIENT_FUNDS'; END IF;

    v_source_balance_after := v_source_balance - p_amount;
    v_pot_balance_after := COALESCE(v_pot.current_amount, 0) + p_amount;

    INSERT INTO public.transactions (
        id, reference_id, user_id, wallet_id, amount, currency, description,
        type, status, date, wealth_impact_type, protection_state, allocation_source, metadata
    ) VALUES (
        v_tx_id, v_reference_id, v_actor, p_source_wallet_id, p_amount::TEXT,
        UPPER(v_pot.currency),
        COALESCE(NULLIF(BTRIM(COALESCE(p_description, '')), ''), 'Shared pot contribution'),
        'internal_transfer', 'completed', CURRENT_DATE, 'GROWING', 'OPEN',
        'SHARED_POT_CONTRIBUTION',
        COALESCE(p_metadata, '{}'::jsonb)
            || jsonb_build_object('shared_pot_id', p_pot_id, 'actor_user_id', v_actor)
    );

    IF v_source_table = 'wallets' THEN
        UPDATE public.wallets SET balance = v_source_balance_after, updated_at = NOW()
        WHERE id = p_source_wallet_id AND user_id = v_actor;
    ELSE
        UPDATE public.platform_vaults SET balance = v_source_balance_after, updated_at = NOW()
        WHERE id = p_source_wallet_id AND user_id = v_actor;
    END IF;

    UPDATE public.shared_pots
    SET current_amount = v_pot_balance_after, updated_at = NOW()
    WHERE id = p_pot_id;

    UPDATE public.shared_pot_members
    SET contributed_amount = COALESCE(contributed_amount, 0) + p_amount
    WHERE id = v_member.id;

    INSERT INTO public.financial_ledger (
        transaction_id, user_id, wallet_id, shared_pot_id, bucket_type,
        entry_side, entry_type, amount, balance_after, description
    ) VALUES
    (
        v_tx_id, v_actor, p_source_wallet_id, p_pot_id, 'OPERATING',
        'DEBIT', 'DEBIT', p_amount::TEXT, v_source_balance_after::TEXT,
        'Shared pot contribution debit: ' || v_pot.name
    ),
    (
        v_tx_id, v_actor, p_source_wallet_id, p_pot_id, 'GROWING',
        'CREDIT', 'CREDIT', p_amount::TEXT, v_pot_balance_after::TEXT,
        'Shared pot contribution credit: ' || v_pot.name
    );

    RETURN jsonb_build_object(
        'transaction_id', v_tx_id,
        'reference_id', v_reference_id,
        'source_balance_after', v_source_balance_after,
        'pot_balance_after', v_pot_balance_after,
        'source_table', v_source_table,
        'idempotent', FALSE
    );
END;
$$;

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
    v_existing public.transactions%ROWTYPE;
    v_target_table TEXT;
    v_target_currency TEXT;
    v_target_balance NUMERIC;
    v_target_balance_after NUMERIC;
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
    IF NOT FOUND OR v_member.role NOT IN ('OWNER', 'MANAGER') THEN
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

    SELECT * INTO v_target_vault
    FROM public.platform_vaults
    WHERE id = p_target_wallet_id AND user_id = v_actor
    FOR UPDATE;
    IF FOUND THEN
        IF COALESCE(v_target_vault.is_locked, FALSE)
           OR LOWER(COALESCE(v_target_vault.status, 'active')) <> 'active' THEN
            RAISE EXCEPTION 'TARGET_WALLET_UNAVAILABLE';
        END IF;
        v_target_table := 'platform_vaults';
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
        v_target_table := 'wallets';
        v_target_balance := COALESCE(v_target_wallet.balance, 0);
        v_target_currency := UPPER(COALESCE(v_target_wallet.currency, 'TZS'));
    END IF;

    IF v_target_currency <> UPPER(COALESCE(v_pot.currency, 'TZS'))
       OR UPPER(BTRIM(COALESCE(p_currency, v_pot.currency, 'TZS'))) <> UPPER(COALESCE(v_pot.currency, 'TZS')) THEN
        RAISE EXCEPTION 'SHARED_POT_CURRENCY_MISMATCH';
    END IF;

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
            || jsonb_build_object('shared_pot_id', p_pot_id, 'actor_user_id', v_actor)
    );

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
        v_tx_id, v_actor, p_target_wallet_id, p_pot_id, 'GROWING',
        'DEBIT', 'DEBIT', p_amount::TEXT, v_pot_balance_after::TEXT,
        'Shared pot withdrawal debit: ' || v_pot.name
    ),
    (
        v_tx_id, v_actor, p_target_wallet_id, p_pot_id, 'OPERATING',
        'CREDIT', 'CREDIT', p_amount::TEXT, v_target_balance_after::TEXT,
        'Shared pot withdrawal credit: ' || v_pot.name
    );

    RETURN jsonb_build_object(
        'transaction_id', v_tx_id,
        'reference_id', v_reference_id,
        'target_balance_after', v_target_balance_after,
        'pot_balance_after', v_pot_balance_after,
        'target_table', v_target_table,
        'idempotent', FALSE
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_shared_pot_v1(
    UUID, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_shared_pot_invitation_v1(UUID, UUID, TEXT, TEXT)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shared_pot_contribute_v1(
    UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(
    UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.create_shared_pot_v1(UUID, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB) FROM anon';
        EXECUTE 'REVOKE ALL ON FUNCTION public.respond_shared_pot_invitation_v1(UUID, UUID, TEXT, TEXT) FROM anon';
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_contribute_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM anon';
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.create_shared_pot_v1(UUID, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB) FROM authenticated';
        EXECUTE 'REVOKE ALL ON FUNCTION public.respond_shared_pot_invitation_v1(UUID, UUID, TEXT, TEXT) FROM authenticated';
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_contribute_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM authenticated';
        EXECUTE 'REVOKE ALL ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.create_shared_pot_v1(UUID, TEXT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.respond_shared_pot_invitation_v1(UUID, UUID, TEXT, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.shared_pot_contribute_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.shared_pot_withdraw_v1(UUID, UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, JSONB) TO service_role';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
