-- Canonical PaySafe escrow lifecycle.
-- Financial movement and lifecycle state changes remain SQL-authoritative.

ALTER TABLE public.escrow_agreements
    ADD COLUMN IF NOT EXISTS reference_id TEXT,
    ADD COLUMN IF NOT EXISTS source_vault_id UUID REFERENCES public.platform_vaults(id),
    ADD COLUMN IF NOT EXISTS escrow_vault_id UUID REFERENCES public.platform_vaults(id),
    ADD COLUMN IF NOT EXISTS receiver_vault_id UUID REFERENCES public.platform_vaults(id),
    ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES public.merchants(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS service_code TEXT,
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS release_requested_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS release_requested_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS receiver_accepted_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS receiver_accepted_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS released_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS disputed_at TIMESTAMP WITH TIME ZONE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'escrow_agreements_status_check'
          AND conrelid = 'public.escrow_agreements'::regclass
    ) THEN
        ALTER TABLE public.escrow_agreements
            DROP CONSTRAINT escrow_agreements_status_check;
    END IF;
END $$;

ALTER TABLE public.escrow_agreements
    ADD CONSTRAINT escrow_agreements_status_check
    CHECK (status IN ('HELD', 'RELEASE_PENDING', 'RELEASED', 'DISPUTED', 'REFUNDED'));

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'escrow_agreements_merchant_id_fkey'
          AND conrelid = 'public.escrow_agreements'::regclass
    ) THEN
        ALTER TABLE public.escrow_agreements
            ADD CONSTRAINT escrow_agreements_merchant_id_fkey
            FOREIGN KEY (merchant_id) REFERENCES public.merchants(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_escrow_agreements_reference
    ON public.escrow_agreements(reference_id)
    WHERE reference_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_escrow_agreements_transaction
    ON public.escrow_agreements(transaction_id);

CREATE INDEX IF NOT EXISTS idx_escrow_agreements_merchant_status
    ON public.escrow_agreements(merchant_id, status, created_at DESC);

CREATE OR REPLACE FUNCTION public.apply_transaction_currency_from_metadata()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NULLIF(BTRIM(COALESCE(NEW.metadata->>'currency', '')), '') IS NOT NULL THEN
        NEW.currency := UPPER(BTRIM(NEW.metadata->>'currency'));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_transaction_currency_from_metadata ON public.transactions;
CREATE TRIGGER trg_apply_transaction_currency_from_metadata
BEFORE INSERT ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.apply_transaction_currency_from_metadata();

CREATE OR REPLACE FUNCTION public.create_escrow_agreement_from_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_receiver_id UUID;
    v_amount NUMERIC;
    v_source_vault_id UUID;
    v_escrow_vault_id UUID;
    v_merchant_id UUID;
BEGIN
    IF LOWER(COALESCE(NEW.type, '')) <> 'escrow'
       OR COALESCE((NEW.metadata->>'is_conditional_escrow')::BOOLEAN, FALSE) IS NOT TRUE THEN
        RETURN NEW;
    END IF;

    v_receiver_id := NULLIF(NEW.metadata->>'recipient_id', '')::UUID;
    v_amount := NULLIF(NEW.metadata->>'escrow_amount_plain', '')::NUMERIC;
    v_source_vault_id := COALESCE(
        NULLIF(NEW.metadata->>'source_vault_id', '')::UUID,
        NEW.wallet_id
    );
    v_escrow_vault_id := NULLIF(NEW.metadata->>'escrow_vault_id', '')::UUID;
    v_merchant_id := NULLIF(NEW.metadata->>'merchant_id', '')::UUID;

    IF v_receiver_id IS NULL OR v_amount IS NULL OR v_amount <= 0
       OR v_source_vault_id IS NULL OR v_escrow_vault_id IS NULL THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_METADATA_INVALID: canonical escrow metadata is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_receiver_id) THEN
        RAISE EXCEPTION 'PAYSAFE_RECEIVER_NOT_FOUND: receiver % does not exist', v_receiver_id;
    END IF;

    INSERT INTO public.escrow_agreements (
        transaction_id,
        reference_id,
        sender_id,
        receiver_id,
        source_vault_id,
        escrow_vault_id,
        merchant_id,
        service_code,
        amount,
        currency,
        conditions,
        status,
        expires_at,
        metadata
    )
    VALUES (
        NEW.id,
        NEW.reference_id,
        NEW.user_id,
        v_receiver_id,
        v_source_vault_id,
        v_escrow_vault_id,
        v_merchant_id,
        NULLIF(NEW.metadata->>'service_code', ''),
        v_amount,
        UPPER(COALESCE(NULLIF(NEW.currency, ''), 'TZS')),
        COALESCE(NEW.metadata->'conditions', '{}'::jsonb),
        'HELD',
        NULLIF(NEW.metadata->>'expires_at', '')::TIMESTAMP WITH TIME ZONE,
        jsonb_build_object(
            'created_from', 'post_transaction_v2',
            'created_at', NOW(),
            'idempotency_reference', NEW.reference_id
        )
    )
    ON CONFLICT (transaction_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_escrow_agreement_from_transaction ON public.transactions;
CREATE TRIGGER trg_create_escrow_agreement_from_transaction
AFTER INSERT ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.create_escrow_agreement_from_transaction();

CREATE OR REPLACE FUNCTION public.transition_paysafe_escrow_v1(
    p_reference_id TEXT,
    p_actor_id UUID,
    p_action TEXT,
    p_receiver_vault_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_action TEXT := UPPER(BTRIM(COALESCE(p_action, '')));
    v_now TIMESTAMP WITH TIME ZONE := NOW();
    v_agreement public.escrow_agreements%ROWTYPE;
    v_tx public.transactions%ROWTYPE;
    v_escrow_vault public.platform_vaults%ROWTYPE;
    v_target_vault public.platform_vaults%ROWTYPE;
    v_target_vault_id UUID;
    v_target_user_id UUID;
    v_next_escrow_balance NUMERIC;
    v_next_target_balance NUMERIC;
    v_append_key TEXT;
BEGIN
    IF NULLIF(BTRIM(COALESCE(p_reference_id, '')), '') IS NULL THEN
        RAISE EXCEPTION 'PAYSAFE_REFERENCE_REQUIRED';
    END IF;

    IF v_action NOT IN ('RELEASE', 'ACCEPT', 'DISPUTE', 'REFUND') THEN
        RAISE EXCEPTION 'PAYSAFE_ACTION_INVALID: %', v_action;
    END IF;

    SELECT ea.* INTO v_agreement
    FROM public.escrow_agreements ea
    WHERE ea.reference_id = p_reference_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_NOT_FOUND';
    END IF;

    SELECT t.* INTO v_tx
    FROM public.transactions t
    WHERE t.id = v_agreement.transaction_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_TRANSACTION_NOT_FOUND';
    END IF;

    IF v_action = 'DISPUTE' THEN
        IF p_actor_id NOT IN (v_agreement.sender_id, v_agreement.receiver_id) THEN
            RAISE EXCEPTION 'PAYSAFE_ACTOR_UNAUTHORIZED';
        END IF;
        IF v_agreement.status = 'DISPUTED' THEN
            RETURN jsonb_build_object(
                'referenceId', p_reference_id,
                'transactionId', v_agreement.transaction_id,
                'status', v_agreement.status,
                'idempotent', TRUE
            );
        END IF;
        IF v_agreement.status NOT IN ('HELD', 'RELEASE_PENDING') THEN
            RAISE EXCEPTION 'PAYSAFE_STATE_INVALID: cannot dispute escrow in state %', v_agreement.status;
        END IF;
        IF NULLIF(BTRIM(COALESCE(p_reason, '')), '') IS NULL THEN
            RAISE EXCEPTION 'PAYSAFE_DISPUTE_REASON_REQUIRED';
        END IF;

        UPDATE public.escrow_agreements
        SET
            status = 'DISPUTED',
            disputed_at = v_now,
            dispute_metadata = COALESCE(dispute_metadata, '{}'::jsonb) || jsonb_build_object(
                'reason', p_reason,
                'actor_id', p_actor_id,
                'disputed_at', v_now
            ),
            updated_at = v_now
        WHERE id = v_agreement.id;

        UPDATE public.transactions
        SET
            status = 'held_for_review',
            status_notes = p_reason,
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                'escrow_status', 'DISPUTED',
                'dispute_reason', p_reason,
                'disputed_by', p_actor_id,
                'disputed_at', v_now
            ),
            updated_at = v_now
        WHERE id = v_tx.id;

        INSERT INTO public.transaction_events (transaction_id, old_state, new_state, actor, metadata)
        VALUES (v_tx.id, v_tx.status, 'held_for_review', p_actor_id::TEXT, jsonb_build_object('reason', p_reason));

        RETURN jsonb_build_object(
            'referenceId', p_reference_id,
            'transactionId', v_tx.id,
            'status', 'DISPUTED',
            'idempotent', FALSE
        );
    END IF;

    IF v_action = 'RELEASE' THEN
        IF p_actor_id <> v_agreement.sender_id THEN
            RAISE EXCEPTION 'PAYSAFE_ACTOR_UNAUTHORIZED';
        END IF;
        IF v_agreement.status IN ('RELEASE_PENDING', 'RELEASED') THEN
            RETURN jsonb_build_object(
                'referenceId', p_reference_id,
                'transactionId', v_agreement.transaction_id,
                'status', v_agreement.status,
                'idempotent', TRUE
            );
        END IF;
        IF v_agreement.status <> 'HELD' THEN
            RAISE EXCEPTION 'PAYSAFE_STATE_INVALID: cannot release escrow in state %', v_agreement.status;
        END IF;
        UPDATE public.escrow_agreements
        SET
            status = 'RELEASE_PENDING',
            release_requested_at = v_now,
            release_requested_by = p_actor_id,
            expires_at = COALESCE(
                CASE
                    WHEN expires_at IS NOT NULL AND expires_at > v_now THEN expires_at
                    ELSE NULL
                END,
                v_now + make_interval(hours => GREATEST(1, LEAST(168, COALESCE((metadata->>'hold_window_hours')::INT, 24))))
            ),
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                'escrow_status', 'RELEASE_PENDING',
                'release_requested_at', v_now,
                'release_requested_by', p_actor_id
            ),
            updated_at = v_now
        WHERE id = v_agreement.id;

        UPDATE public.transactions
        SET
            status = 'awaiting_receiver_acceptance',
            status_notes = 'PaySafe release requested and waiting for receiver acceptance.',
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                'escrow_status', 'RELEASE_PENDING',
                'release_requested_at', v_now,
                'release_requested_by', p_actor_id
            ),
            updated_at = v_now
        WHERE id = v_tx.id;

        INSERT INTO public.transaction_events (transaction_id, old_state, new_state, actor, metadata)
        VALUES (
            v_tx.id,
            v_tx.status,
            'awaiting_receiver_acceptance',
            p_actor_id::TEXT,
            jsonb_build_object('paysafe_action', v_action)
        );

        RETURN jsonb_build_object(
            'referenceId', p_reference_id,
            'transactionId', v_tx.id,
            'status', 'RELEASE_PENDING',
            'releaseRequestedAt', v_now,
            'expiresAt', (
                SELECT ea.expires_at
                FROM public.escrow_agreements ea
                WHERE ea.id = v_agreement.id
            ),
            'idempotent', FALSE
        );
    ELSIF v_action = 'ACCEPT' THEN
        IF p_actor_id <> v_agreement.receiver_id THEN
            RAISE EXCEPTION 'PAYSAFE_ACTOR_UNAUTHORIZED';
        END IF;
        IF v_agreement.status = 'RELEASED' THEN
            RETURN jsonb_build_object(
                'referenceId', p_reference_id,
                'transactionId', v_agreement.transaction_id,
                'status', v_agreement.status,
                'idempotent', TRUE
            );
        END IF;
        IF v_agreement.status <> 'RELEASE_PENDING' THEN
            RAISE EXCEPTION 'PAYSAFE_STATE_INVALID: cannot accept escrow in state %', v_agreement.status;
        END IF;
        IF v_agreement.expires_at IS NOT NULL AND v_agreement.expires_at < v_now THEN
            RAISE EXCEPTION 'PAYSAFE_RELEASE_WINDOW_EXPIRED';
        END IF;
        v_target_user_id := v_agreement.receiver_id;
        v_target_vault_id := COALESCE(p_receiver_vault_id, v_agreement.receiver_vault_id);
    ELSE
        IF v_agreement.status = 'REFUNDED' THEN
            RETURN jsonb_build_object(
                'referenceId', p_reference_id,
                'transactionId', v_agreement.transaction_id,
                'status', v_agreement.status,
                'idempotent', TRUE
            );
        END IF;
        IF p_actor_id <> v_agreement.sender_id THEN
            RAISE EXCEPTION 'PAYSAFE_ACTOR_UNAUTHORIZED';
        END IF;
        IF v_agreement.status NOT IN ('HELD', 'RELEASE_PENDING', 'DISPUTED') THEN
            RAISE EXCEPTION 'PAYSAFE_STATE_INVALID: cannot refund escrow in state %', v_agreement.status;
        END IF;
        IF NULLIF(BTRIM(COALESCE(p_reason, '')), '') IS NULL THEN
            RAISE EXCEPTION 'PAYSAFE_REFUND_REASON_REQUIRED';
        END IF;
        v_target_user_id := v_agreement.sender_id;
        v_target_vault_id := COALESCE(p_receiver_vault_id, v_agreement.source_vault_id);
    END IF;

    SELECT pv.* INTO v_escrow_vault
    FROM public.platform_vaults pv
    WHERE pv.id = v_agreement.escrow_vault_id
      AND pv.user_id = v_agreement.sender_id
      AND pv.vault_role = 'INTERNAL_TRANSFER'
      AND NOT COALESCE(pv.is_locked, FALSE)
      AND LOWER(COALESCE(pv.status, 'active')) NOT IN ('locked', 'frozen', 'blocked', 'suspended')
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_VAULT_UNAVAILABLE';
    END IF;

    IF v_target_vault_id IS NULL THEN
        SELECT pv.id INTO v_target_vault_id
        FROM public.platform_vaults pv
        WHERE pv.user_id = v_target_user_id
          AND pv.vault_role = 'OPERATING'
          AND UPPER(COALESCE(pv.currency, 'TZS')) = UPPER(v_agreement.currency)
          AND NOT COALESCE(pv.is_locked, FALSE)
          AND LOWER(COALESCE(pv.status, 'active')) NOT IN ('locked', 'frozen', 'blocked', 'suspended')
        ORDER BY pv.created_at
        LIMIT 1;
    END IF;

    SELECT pv.* INTO v_target_vault
    FROM public.platform_vaults pv
    WHERE pv.id = v_target_vault_id
      AND pv.user_id = v_target_user_id
      AND pv.vault_role = 'OPERATING'
      AND UPPER(COALESCE(pv.currency, 'TZS')) = UPPER(v_agreement.currency)
      AND NOT COALESCE(pv.is_locked, FALSE)
      AND LOWER(COALESCE(pv.status, 'active')) NOT IN ('locked', 'frozen', 'blocked', 'suspended')
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_TARGET_VAULT_UNAVAILABLE';
    END IF;

    IF UPPER(COALESCE(v_escrow_vault.currency, 'TZS')) <> UPPER(v_agreement.currency) THEN
        RAISE EXCEPTION 'PAYSAFE_CURRENCY_MISMATCH';
    END IF;

    IF COALESCE(v_escrow_vault.balance, 0) < v_agreement.amount THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_BALANCE_INSUFFICIENT';
    END IF;

    v_append_key := 'paysafe:' || v_agreement.id::TEXT || ':' || LOWER(v_action) || ':v1';
    INSERT INTO public.ledger_append_markers (transaction_id, append_key, append_phase, metadata)
    VALUES (
        v_tx.id,
        v_append_key,
        'PAYSAFE_' || v_action,
        jsonb_build_object('actor_id', p_actor_id, 'reference_id', p_reference_id)
    );

    v_next_escrow_balance := ROUND((COALESCE(v_escrow_vault.balance, 0) - v_agreement.amount)::NUMERIC, 4);
    v_next_target_balance := ROUND((COALESCE(v_target_vault.balance, 0) + v_agreement.amount)::NUMERIC, 4);

    UPDATE public.platform_vaults
    SET balance = v_next_escrow_balance, updated_at = v_now
    WHERE id = v_escrow_vault.id;

    UPDATE public.platform_vaults
    SET balance = v_next_target_balance, updated_at = v_now
    WHERE id = v_target_vault.id;

    INSERT INTO public.financial_ledger (
        transaction_id, user_id, wallet_id, entry_type, amount, balance_after, description
    )
    VALUES
        (
            v_tx.id,
            v_agreement.sender_id,
            v_escrow_vault.id,
            'DEBIT',
            v_tx.amount,
            v_next_escrow_balance::TEXT,
            'PaySafe ' || INITCAP(LOWER(v_action)) || ': ' || p_reference_id
        ),
        (
            v_tx.id,
            v_target_user_id,
            v_target_vault.id,
            'CREDIT',
            v_tx.amount,
            v_next_target_balance::TEXT,
            'PaySafe ' || INITCAP(LOWER(v_action)) || ': ' || p_reference_id
        );

    UPDATE public.escrow_agreements
    SET
        status = CASE WHEN v_action = 'ACCEPT' THEN 'RELEASED' ELSE 'REFUNDED' END,
        receiver_vault_id = CASE WHEN v_action = 'ACCEPT' THEN v_target_vault.id ELSE receiver_vault_id END,
        receiver_accepted_at = CASE WHEN v_action = 'ACCEPT' THEN v_now ELSE receiver_accepted_at END,
        receiver_accepted_by = CASE WHEN v_action = 'ACCEPT' THEN p_actor_id ELSE receiver_accepted_by END,
        released_at = CASE WHEN v_action = 'ACCEPT' THEN v_now ELSE released_at END,
        refunded_at = CASE WHEN v_action = 'REFUND' THEN v_now ELSE refunded_at END,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'last_action', v_action,
            'last_actor_id', p_actor_id,
            'last_action_at', v_now,
            'target_vault_id', v_target_vault.id,
            'reason', p_reason,
            'escrow_status', CASE WHEN v_action = 'ACCEPT' THEN 'RELEASED' ELSE 'REFUNDED' END
        ),
        updated_at = v_now
    WHERE id = v_agreement.id;

    UPDATE public.transactions
    SET
        status = CASE WHEN v_action = 'ACCEPT' THEN 'completed' ELSE 'refunded' END,
        status_notes = COALESCE(NULLIF(BTRIM(p_reason), ''), 'PaySafe ' || LOWER(v_action) || ' completed.'),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'escrow_status', CASE WHEN v_action = 'ACCEPT' THEN 'RELEASED' ELSE 'REFUNDED' END,
            'escrow_action_at', v_now,
            'escrow_action_by', p_actor_id,
            'escrow_target_vault_id', v_target_vault.id
        ),
        updated_at = v_now
    WHERE id = v_tx.id;

    INSERT INTO public.transaction_events (transaction_id, old_state, new_state, actor, metadata)
    VALUES (
        v_tx.id,
        v_tx.status,
        CASE WHEN v_action = 'ACCEPT' THEN 'completed' ELSE 'refunded' END,
        p_actor_id::TEXT,
        jsonb_build_object('paysafe_action', v_action, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'referenceId', p_reference_id,
        'transactionId', v_tx.id,
        'status', CASE WHEN v_action = 'ACCEPT' THEN 'RELEASED' ELSE 'REFUNDED' END,
        'amount', v_agreement.amount,
        'currency', v_agreement.currency,
        'targetVaultId', v_target_vault.id,
        'idempotent', FALSE
    );
EXCEPTION
    WHEN unique_violation THEN
        IF v_append_key IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.ledger_append_markers WHERE append_key = v_append_key
        ) THEN
            RAISE EXCEPTION 'PAYSAFE_ACTION_ALREADY_APPLIED';
        END IF;
        RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.create_escrow_agreement_from_transaction() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_transaction_currency_from_metadata() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transition_paysafe_escrow_v1(TEXT, UUID, TEXT, UUID, TEXT) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.transition_paysafe_escrow_v1(TEXT, UUID, TEXT, UUID, TEXT) FROM anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.transition_paysafe_escrow_v1(TEXT, UUID, TEXT, UUID, TEXT) FROM authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.transition_paysafe_escrow_v1(TEXT, UUID, TEXT, UUID, TEXT) TO service_role';
    END IF;
END $$;
