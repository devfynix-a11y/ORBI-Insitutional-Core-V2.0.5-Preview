-- Merchant PaySafe settlement and fee lifecycle.
-- Fee values are snapshotted at escrow authorization and consumed atomically.

INSERT INTO public.platform_fee_configs (
    name,
    flow_code,
    transaction_model,
    transaction_type,
    operation_type,
    direction,
    rail,
    channel,
    percentage_rate,
    fixed_amount,
    minimum_fee,
    tax_rate,
    gov_fee_rate,
    stamp_duty_fixed,
    priority,
    status,
    metadata
)
SELECT
    'Base PaySafe merchant release fee policy',
    'MERCHANT_PAYMENT',
    'MERCHANT_PAYMENT',
    'MERCHANT_PAYMENT',
    'PAYSAFE_RELEASE',
    'INBOUND',
    'WALLET',
    'PAYSAFE',
    0,
    0,
    0,
    0,
    0,
    0,
    1000,
    'ACTIVE',
    jsonb_build_object(
        'seeded_by', 'database/migrations/20260618_merchant_paysafe_settlement.sql',
        'purpose', 'safe zero-rate baseline; configure commercial PaySafe merchant fees before monetized launch'
    )
WHERE NOT EXISTS (
    SELECT 1
    FROM public.platform_fee_configs existing
    WHERE existing.flow_code = 'MERCHANT_PAYMENT'
      AND existing.operation_type = 'PAYSAFE_RELEASE'
      AND existing.rail = 'WALLET'
      AND existing.channel = 'PAYSAFE'
      AND existing.status = 'ACTIVE'
);

CREATE TABLE IF NOT EXISTS public.merchant_paysafe_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    escrow_agreement_id UUID NOT NULL UNIQUE REFERENCES public.escrow_agreements(id) ON DELETE RESTRICT,
    transaction_id UUID NOT NULL UNIQUE REFERENCES public.transactions(id) ON DELETE RESTRICT,
    merchant_id UUID NOT NULL REFERENCES public.merchants(id) ON DELETE RESTRICT,
    owner_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    merchant_wallet_id UUID NOT NULL REFERENCES public.merchant_wallets(id) ON DELETE RESTRICT,
    fee_collector_wallet_id UUID REFERENCES public.fee_collector_wallets(id) ON DELETE RESTRICT,
    fee_config_id UUID REFERENCES public.platform_fee_configs(id) ON DELETE SET NULL,
    gross_amount NUMERIC NOT NULL CHECK (gross_amount > 0),
    fee_amount NUMERIC NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    tax_amount NUMERIC NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    net_amount NUMERIC NOT NULL CHECK (net_amount > 0),
    currency TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'SETTLED'
        CHECK (status IN ('SETTLED', 'REVERSED', 'HELD_FOR_REVIEW')),
    settled_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    reversed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT merchant_paysafe_settlement_amounts_balance
        CHECK (ABS(gross_amount - (fee_amount + tax_amount + net_amount)) <= 0.01)
);

CREATE INDEX IF NOT EXISTS idx_merchant_paysafe_settlements_merchant_period
    ON public.merchant_paysafe_settlements(merchant_id, settled_at DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_paysafe_settlements_status
    ON public.merchant_paysafe_settlements(status, settled_at DESC);

ALTER TABLE public.merchant_paysafe_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS merchant_paysafe_settlements_service_role
    ON public.merchant_paysafe_settlements;
CREATE POLICY merchant_paysafe_settlements_service_role
    ON public.merchant_paysafe_settlements
    FOR ALL TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

CREATE OR REPLACE FUNCTION public.settle_merchant_paysafe_v1(
    p_reference_id TEXT,
    p_actor_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMP WITH TIME ZONE := NOW();
    v_agreement public.escrow_agreements%ROWTYPE;
    v_tx public.transactions%ROWTYPE;
    v_merchant public.merchants%ROWTYPE;
    v_escrow_vault public.platform_vaults%ROWTYPE;
    v_merchant_wallet public.merchant_wallets%ROWTYPE;
    v_fee_collector public.fee_collector_wallets%ROWTYPE;
    v_fee_vault public.platform_vaults%ROWTYPE;
    v_settlement_config_id UUID;
    v_fee_snapshot JSONB;
    v_fee_config_id UUID;
    v_gross NUMERIC;
    v_service_fee NUMERIC;
    v_tax NUMERIC;
    v_total_fee NUMERIC;
    v_net NUMERIC;
    v_next_escrow_balance NUMERIC;
    v_next_merchant_balance NUMERIC;
    v_next_fee_balance NUMERIC;
    v_append_key TEXT;
    v_existing public.merchant_paysafe_settlements%ROWTYPE;
BEGIN
    IF NULLIF(BTRIM(COALESCE(p_reference_id, '')), '') IS NULL THEN
        RAISE EXCEPTION 'PAYSAFE_REFERENCE_REQUIRED';
    END IF;

    SELECT ea.* INTO v_agreement
    FROM public.escrow_agreements ea
    WHERE ea.reference_id = p_reference_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_NOT_FOUND';
    END IF;

    IF v_agreement.merchant_id IS NULL THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_CONTEXT_REQUIRED';
    END IF;

    IF p_actor_id <> v_agreement.sender_id THEN
        RAISE EXCEPTION 'PAYSAFE_ACTOR_UNAUTHORIZED';
    END IF;

    SELECT * INTO v_existing
    FROM public.merchant_paysafe_settlements
    WHERE escrow_agreement_id = v_agreement.id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'referenceId', p_reference_id,
            'transactionId', v_existing.transaction_id,
            'settlementId', v_existing.id,
            'merchantId', v_existing.merchant_id,
            'status', v_existing.status,
            'grossAmount', v_existing.gross_amount,
            'feeAmount', v_existing.fee_amount,
            'taxAmount', v_existing.tax_amount,
            'netAmount', v_existing.net_amount,
            'currency', v_existing.currency,
            'idempotent', TRUE
        );
    END IF;

    IF v_agreement.status <> 'HELD' THEN
        RAISE EXCEPTION 'PAYSAFE_STATE_INVALID: cannot settle merchant escrow in state %', v_agreement.status;
    END IF;

    SELECT t.* INTO v_tx
    FROM public.transactions t
    WHERE t.id = v_agreement.transaction_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_TRANSACTION_NOT_FOUND';
    END IF;

    SELECT m.* INTO v_merchant
    FROM public.merchants m
    WHERE m.id = v_agreement.merchant_id
      AND LOWER(COALESCE(m.status, '')) = 'active'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_NOT_ACTIVE';
    END IF;

    IF v_merchant.owner_user_id IS NULL
       OR v_merchant.owner_user_id <> v_agreement.receiver_id THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_RECIPIENT_MISMATCH';
    END IF;

    SELECT mw.* INTO v_merchant_wallet
    FROM public.merchant_wallets mw
    WHERE mw.merchant_id = v_merchant.id
      AND LOWER(COALESCE(mw.status, 'active')) = 'active'
      AND LOWER(COALESCE(mw.wallet_type, 'operating')) IN ('settlement', 'operating')
      AND UPPER(COALESCE(mw.currency, 'TZS')) = UPPER(v_agreement.currency)
    ORDER BY
      CASE WHEN LOWER(COALESCE(mw.wallet_type, '')) = 'settlement' THEN 0 ELSE 1 END,
      mw.is_primary DESC,
      mw.created_at
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_SETTLEMENT_WALLET_UNAVAILABLE';
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

    IF UPPER(COALESCE(v_escrow_vault.currency, 'TZS')) <> UPPER(v_agreement.currency) THEN
        RAISE EXCEPTION 'PAYSAFE_CURRENCY_MISMATCH';
    END IF;

    v_fee_snapshot := COALESCE(
        v_agreement.metadata->'merchant_fee_snapshot',
        v_tx.metadata->'merchant_fee_snapshot'
    );
    IF v_fee_snapshot IS NULL OR jsonb_typeof(v_fee_snapshot) <> 'object' THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_FEE_SNAPSHOT_REQUIRED';
    END IF;

    v_gross := ROUND(v_agreement.amount::NUMERIC, 2);
    v_service_fee := ROUND(COALESCE(NULLIF(v_fee_snapshot->>'serviceFee', '')::NUMERIC, 0), 2);
    v_tax := ROUND((
        COALESCE(NULLIF(v_fee_snapshot->>'taxAmount', '')::NUMERIC, 0)
        + COALESCE(NULLIF(v_fee_snapshot->>'govFeeAmount', '')::NUMERIC, 0)
        + COALESCE(NULLIF(v_fee_snapshot->>'stampDutyFixed', '')::NUMERIC, 0)
    )::NUMERIC, 2);
    v_total_fee := ROUND(COALESCE(NULLIF(v_fee_snapshot->>'totalFee', '')::NUMERIC, 0), 2);
    v_net := ROUND(COALESCE(NULLIF(v_fee_snapshot->>'netAmount', '')::NUMERIC, 0), 2);
    v_fee_config_id := NULLIF(v_fee_snapshot->>'configId', '')::UUID;

    IF UPPER(COALESCE(v_fee_snapshot->>'currency', '')) <> UPPER(v_agreement.currency)
       OR v_gross <= 0
       OR v_service_fee < 0
       OR v_tax < 0
       OR v_total_fee < 0
       OR v_net <= 0
       OR ABS(v_total_fee - (v_service_fee + v_tax)) > 0.01
       OR ABS(v_gross - (v_total_fee + v_net)) > 0.01 THEN
        RAISE EXCEPTION 'PAYSAFE_MERCHANT_FEE_SNAPSHOT_INVALID';
    END IF;

    IF COALESCE(v_escrow_vault.balance, 0) < v_gross THEN
        RAISE EXCEPTION 'PAYSAFE_ESCROW_BALANCE_INSUFFICIENT';
    END IF;

    IF v_total_fee > 0 THEN
        SELECT fcw.* INTO v_fee_collector
        FROM public.fee_collector_wallets fcw
        WHERE UPPER(COALESCE(fcw.currency, 'TZS')) = UPPER(v_agreement.currency)
          AND LOWER(fcw.fee_type) IN ('platform_fee', 'service_fee', 'merchant_fee')
        ORDER BY
          CASE LOWER(fcw.fee_type)
            WHEN 'merchant_fee' THEN 0
            WHEN 'platform_fee' THEN 1
            ELSE 2
          END,
          fcw.created_at
        LIMIT 1
        FOR UPDATE;

        IF NOT FOUND OR v_fee_collector.vault_id IS NULL THEN
            RAISE EXCEPTION 'PAYSAFE_FEE_COLLECTOR_UNAVAILABLE';
        END IF;

        SELECT pv.* INTO v_fee_vault
        FROM public.platform_vaults pv
        WHERE pv.id = v_fee_collector.vault_id
          AND UPPER(COALESCE(pv.currency, 'TZS')) = UPPER(v_agreement.currency)
          AND NOT COALESCE(pv.is_locked, FALSE)
          AND LOWER(COALESCE(pv.status, 'active')) NOT IN ('locked', 'frozen', 'blocked', 'suspended')
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PAYSAFE_FEE_COLLECTOR_UNAVAILABLE';
        END IF;
    END IF;

    v_append_key := 'paysafe:' || v_agreement.id::TEXT || ':merchant_settlement:v1';
    INSERT INTO public.ledger_append_markers (
        transaction_id,
        append_key,
        append_phase,
        metadata
    ) VALUES (
        v_tx.id,
        v_append_key,
        'PAYSAFE_MERCHANT_SETTLEMENT',
        jsonb_build_object(
            'merchant_id', v_merchant.id,
            'merchant_wallet_id', v_merchant_wallet.id,
            'actor_id', p_actor_id,
            'reference_id', p_reference_id
        )
    );

    v_next_escrow_balance := ROUND((COALESCE(v_escrow_vault.balance, 0) - v_gross)::NUMERIC, 2);
    v_next_merchant_balance := ROUND((COALESCE(v_merchant_wallet.balance, 0) + v_net)::NUMERIC, 2);

    UPDATE public.platform_vaults
    SET balance = v_next_escrow_balance, updated_at = v_now
    WHERE id = v_escrow_vault.id;

    UPDATE public.merchant_wallets
    SET balance = v_next_merchant_balance, updated_at = v_now
    WHERE id = v_merchant_wallet.id;

    INSERT INTO public.financial_ledger (
        transaction_id, user_id, wallet_id, entry_type, amount, balance_after, description
    ) VALUES
        (
            v_tx.id, v_agreement.sender_id, v_escrow_vault.id, 'DEBIT',
            v_gross::TEXT, v_next_escrow_balance::TEXT,
            'PaySafe merchant settlement debit: ' || p_reference_id
        ),
        (
            v_tx.id, v_merchant.owner_user_id, v_merchant_wallet.id, 'CREDIT',
            v_net::TEXT, v_next_merchant_balance::TEXT,
            'PaySafe merchant net settlement: ' || p_reference_id
        );

    IF v_total_fee > 0 THEN
        v_next_fee_balance := ROUND((COALESCE(v_fee_vault.balance, 0) + v_total_fee)::NUMERIC, 2);

        UPDATE public.platform_vaults
        SET balance = v_next_fee_balance, updated_at = v_now
        WHERE id = v_fee_vault.id;

        UPDATE public.fee_collector_wallets
        SET balance = ROUND((COALESCE(balance, 0) + v_total_fee)::NUMERIC, 2),
            updated_at = v_now
        WHERE id = v_fee_collector.id;

        INSERT INTO public.financial_ledger (
            transaction_id, user_id, wallet_id, entry_type, amount, balance_after, description
        ) VALUES (
            v_tx.id, v_fee_vault.user_id, v_fee_vault.id, 'CREDIT',
            v_total_fee::TEXT, v_next_fee_balance::TEXT,
            'PaySafe merchant fee settlement: ' || p_reference_id
        );
    END IF;

    INSERT INTO public.merchant_paysafe_settlements (
        escrow_agreement_id,
        transaction_id,
        merchant_id,
        owner_user_id,
        merchant_wallet_id,
        fee_collector_wallet_id,
        fee_config_id,
        gross_amount,
        fee_amount,
        tax_amount,
        net_amount,
        currency,
        status,
        settled_at,
        metadata
    ) VALUES (
        v_agreement.id,
        v_tx.id,
        v_merchant.id,
        v_merchant.owner_user_id,
        v_merchant_wallet.id,
        CASE WHEN v_total_fee > 0 THEN v_fee_collector.id ELSE NULL END,
        v_fee_config_id,
        v_gross,
        v_service_fee,
        v_tax,
        v_net,
        UPPER(v_agreement.currency),
        'SETTLED',
        v_now,
        jsonb_build_object(
            'reference_id', p_reference_id,
            'fee_snapshot', v_fee_snapshot,
            'settled_by', p_actor_id
        )
    )
    RETURNING * INTO v_existing;

    INSERT INTO public.merchant_transactions (
        transaction_id,
        merchant_id,
        owner_user_id,
        merchant_wallet_id,
        customer_user_id,
        direction,
        amount,
        currency,
        status,
        service_type,
        metadata
    ) VALUES (
        v_tx.id,
        v_merchant.id,
        v_merchant.owner_user_id,
        v_merchant_wallet.id,
        v_agreement.sender_id,
        'inbound',
        v_gross,
        UPPER(v_agreement.currency),
        'completed',
        'paysafe',
        jsonb_build_object(
            'reference_id', p_reference_id,
            'settlement_id', v_existing.id,
            'gross_amount', v_gross,
            'fee_amount', v_service_fee,
            'tax_amount', v_tax,
            'net_amount', v_net
        )
    )
    ON CONFLICT (transaction_id) DO UPDATE
    SET
        merchant_wallet_id = EXCLUDED.merchant_wallet_id,
        status = 'completed',
        amount = EXCLUDED.amount,
        currency = EXCLUDED.currency,
        metadata = COALESCE(merchant_transactions.metadata, '{}'::jsonb)
            || EXCLUDED.metadata,
        updated_at = v_now;

    SELECT ms.id INTO v_settlement_config_id
    FROM public.merchant_settlements ms
    WHERE ms.merchant_id = v_merchant.id;

    INSERT INTO public.settlement_lifecycle (
        transaction_id,
        merchant_settlement_id,
        lifecycle_key,
        settlement_batch_id,
        rail,
        direction,
        operation_type,
        currency,
        gross_amount,
        fee_amount,
        tax_amount,
        net_amount,
        stage,
        status,
        initiated_at,
        provider_confirmed_at,
        settled_at,
        metadata
    ) VALUES (
        v_tx.id,
        v_settlement_config_id,
        'merchant-paysafe:' || v_agreement.id::TEXT,
        'PAYSAFE-' || TO_CHAR(v_now, 'YYYYMMDD'),
        'WALLET',
        'INBOUND',
        'PAYSAFE_MERCHANT_SETTLEMENT',
        UPPER(v_agreement.currency),
        v_gross,
        v_service_fee,
        v_tax,
        v_net,
        'SETTLED',
        'COMPLETED',
        COALESCE(v_tx.created_at, v_now),
        v_now,
        v_now,
        jsonb_build_object(
            'merchant_id', v_merchant.id,
            'escrow_agreement_id', v_agreement.id,
            'merchant_paysafe_settlement_id', v_existing.id,
            'fee_snapshot', v_fee_snapshot
        )
    )
    ON CONFLICT (lifecycle_key) DO NOTHING;

    UPDATE public.escrow_agreements
    SET
        status = 'RELEASED',
        released_at = v_now,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'last_action', 'MERCHANT_SETTLEMENT',
            'last_actor_id', p_actor_id,
            'last_action_at', v_now,
            'merchant_wallet_id', v_merchant_wallet.id,
            'merchant_paysafe_settlement_id', v_existing.id,
            'merchant_fee_snapshot', v_fee_snapshot
        ),
        updated_at = v_now
    WHERE id = v_agreement.id;

    UPDATE public.transactions
    SET
        status = 'completed',
        status_notes = 'PaySafe merchant settlement completed.',
        settlement_status = 'SETTLED',
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'escrow_status', 'RELEASED',
            'merchant_settlement_id', v_existing.id,
            'merchant_wallet_id', v_merchant_wallet.id,
            'gross_amount', v_gross,
            'fee_amount', v_service_fee,
            'tax_amount', v_tax,
            'net_amount', v_net,
            'settled_at', v_now
        ),
        updated_at = v_now
    WHERE id = v_tx.id;

    INSERT INTO public.transaction_events (
        transaction_id, old_state, new_state, actor, metadata
    ) VALUES (
        v_tx.id,
        v_tx.status,
        'completed',
        p_actor_id::TEXT,
        jsonb_build_object(
            'paysafe_action', 'MERCHANT_SETTLEMENT',
            'merchant_id', v_merchant.id,
            'settlement_id', v_existing.id
        )
    );

    RETURN jsonb_build_object(
        'referenceId', p_reference_id,
        'transactionId', v_tx.id,
        'settlementId', v_existing.id,
        'merchantId', v_merchant.id,
        'merchantWalletId', v_merchant_wallet.id,
        'status', 'SETTLED',
        'grossAmount', v_gross,
        'feeAmount', v_service_fee,
        'taxAmount', v_tax,
        'netAmount', v_net,
        'currency', UPPER(v_agreement.currency),
        'idempotent', FALSE
    );
EXCEPTION
    WHEN unique_violation THEN
        SELECT * INTO v_existing
        FROM public.merchant_paysafe_settlements
        WHERE escrow_agreement_id = v_agreement.id;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'referenceId', p_reference_id,
                'transactionId', v_existing.transaction_id,
                'settlementId', v_existing.id,
                'merchantId', v_existing.merchant_id,
                'status', v_existing.status,
                'grossAmount', v_existing.gross_amount,
                'feeAmount', v_existing.fee_amount,
                'taxAmount', v_existing.tax_amount,
                'netAmount', v_existing.net_amount,
                'currency', v_existing.currency,
                'idempotent', TRUE
            );
        END IF;
        RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.settle_merchant_paysafe_v1(TEXT, UUID) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.settle_merchant_paysafe_v1(TEXT, UUID) FROM anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.settle_merchant_paysafe_v1(TEXT, UUID) FROM authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.settle_merchant_paysafe_v1(TEXT, UUID) TO service_role';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
