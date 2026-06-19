-- SANDBOX ONLY.
-- Creates an auditable TZS demo clearing opening balance, then posts balanced
-- deposits of TZS 100,000 to the two named demo customer accounts.
-- Do not include this file in production migrations or production reset flows.

DO $$
DECLARE
    v_source_vault_id CONSTANT UUID := '00000000-0000-0000-0000-000000000101';
    v_equity_vault_id CONSTANT UUID := '00000000-0000-0000-0000-000000000102';
    v_opening_tx_id CONSTANT UUID := '00000000-0000-0000-0000-000000000200';
    v_opening_reference CONSTANT TEXT := 'DEMO-OPENING-TZS-20260618';
    v_customer RECORD;
    v_target_vault_id UUID;
    v_tx_id UUID;
    v_reference_id TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.financial_partners fp
        WHERE fp.status = 'ACTIVE'
          AND (
              LOWER(COALESCE(fp.provider_metadata->>'environment', '')) = 'sandbox'
              OR UPPER(COALESCE(fp.provider_metadata->>'settlement_model', '')) = 'SANDBOX'
          )
    ) THEN
        RAISE EXCEPTION 'DEMO_SEED_SANDBOX_PROVIDER_REQUIRED';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM public.users u
        WHERE u.customer_id IN ('OB26-2531-8566', 'OB26-2980-5415')
          AND LOWER(COALESCE(u.account_status, '')) = 'active'
          AND UPPER(COALESCE(u.currency, '')) = 'TZS'
    ) <> 2 THEN
        RAISE EXCEPTION 'DEMO_SEED_TARGET_USERS_INVALID';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.transactions
        WHERE reference_id = v_opening_reference
    ) THEN
        INSERT INTO public.platform_vaults (
            id,
            user_id,
            vault_role,
            name,
            balance,
            currency,
            status,
            is_locked,
            metadata
        )
        VALUES
            (
                v_source_vault_id,
                NULL,
                'DEMO_CLEARING_SOURCE',
                'Sandbox Demo TZS Clearing Source',
                200000,
                'TZS',
                'active',
                FALSE,
                jsonb_build_object(
                    'sandbox_only', TRUE,
                    'seed_reference', v_opening_reference,
                    'reversible', TRUE
                )
            ),
            (
                v_equity_vault_id,
                NULL,
                'DEMO_OPENING_EQUITY',
                'Sandbox Demo Opening Equity',
                -200000,
                'TZS',
                'active',
                FALSE,
                jsonb_build_object(
                    'sandbox_only', TRUE,
                    'seed_reference', v_opening_reference,
                    'contra_account', TRUE,
                    'reversible', TRUE
                )
            )
        ON CONFLICT (id) DO NOTHING;

        IF NOT EXISTS (
            SELECT 1
            FROM public.platform_vaults
            WHERE id = v_source_vault_id
              AND vault_role = 'DEMO_CLEARING_SOURCE'
              AND currency = 'TZS'
              AND balance = 200000
        ) OR NOT EXISTS (
            SELECT 1
            FROM public.platform_vaults
            WHERE id = v_equity_vault_id
              AND vault_role = 'DEMO_OPENING_EQUITY'
              AND currency = 'TZS'
              AND balance = -200000
        ) THEN
            RAISE EXCEPTION 'DEMO_SEED_OPENING_ACCOUNTS_CONFLICT';
        END IF;

        INSERT INTO public.transactions (
            id,
            reference_id,
            user_id,
            wallet_id,
            to_wallet_id,
            amount,
            description,
            type,
            status,
            date,
            metadata
        )
        VALUES (
            v_opening_tx_id,
            v_opening_reference,
            NULL,
            v_equity_vault_id,
            v_source_vault_id,
            '200000',
            'Sandbox demo opening balance',
            'system_funding',
            'completed',
            CURRENT_DATE,
            jsonb_build_object(
                'sandbox_only', TRUE,
                'opening_balance', TRUE,
                'reversible', TRUE,
                'target_customer_ids', jsonb_build_array(
                    'OB26-2531-8566',
                    'OB26-2980-5415'
                )
            )
        );

        INSERT INTO public.financial_ledger (
            transaction_id,
            user_id,
            wallet_id,
            entry_type,
            amount,
            balance_after,
            description
        )
        VALUES
            (
                v_opening_tx_id,
                NULL,
                v_equity_vault_id,
                'DEBIT',
                '200000',
                '-200000',
                'Sandbox demo opening equity'
            ),
            (
                v_opening_tx_id,
                NULL,
                v_source_vault_id,
                'CREDIT',
                '200000',
                '200000',
                'Sandbox demo TZS clearing funding'
            );
    END IF;

    FOR v_customer IN
        SELECT u.id, u.customer_id
        FROM public.users u
        WHERE u.customer_id IN ('OB26-2531-8566', 'OB26-2980-5415')
        ORDER BY u.customer_id
    LOOP
        SELECT pv.id
        INTO v_target_vault_id
        FROM public.platform_vaults pv
        WHERE pv.user_id = v_customer.id
          AND pv.vault_role = 'OPERATING'
          AND UPPER(COALESCE(pv.currency, '')) = 'TZS'
          AND NOT COALESCE(pv.is_locked, FALSE)
          AND LOWER(COALESCE(pv.status, 'active')) = 'active'
        ORDER BY pv.created_at
        LIMIT 1;

        IF v_target_vault_id IS NULL THEN
            RAISE EXCEPTION 'DEMO_SEED_OPERATING_VAULT_REQUIRED:%', v_customer.customer_id;
        END IF;

        v_reference_id := 'DEMO-DEPOSIT-' || v_customer.customer_id || '-100000';

        IF NOT EXISTS (
            SELECT 1
            FROM public.transactions
            WHERE reference_id = v_reference_id
        ) THEN
            v_tx_id := gen_random_uuid();

            PERFORM public.post_transaction_v2(
                v_tx_id,
                v_customer.id,
                v_source_vault_id,
                v_target_vault_id,
                '100000',
                'Sandbox demo deposit of TZS 100,000',
                'deposit',
                'completed',
                CURRENT_DATE,
                jsonb_build_object(
                    'sandbox_only', TRUE,
                    'demo_funding', TRUE,
                    'customer_id', v_customer.customer_id,
                    'source_opening_reference', v_opening_reference,
                    'reversible', TRUE
                ),
                NULL,
                jsonb_build_array(
                    jsonb_build_object(
                        'wallet_id', v_source_vault_id,
                        'entry_type', 'DEBIT',
                        'amount', '100000',
                        'amount_plain', 100000,
                        'description', 'Sandbox demo clearing debit'
                    ),
                    jsonb_build_object(
                        'wallet_id', v_target_vault_id,
                        'entry_type', 'CREDIT',
                        'amount', '100000',
                        'amount_plain', 100000,
                        'description', 'Sandbox demo operating credit'
                    )
                ),
                v_reference_id
            );

            INSERT INTO public.transaction_events (
                transaction_id,
                old_state,
                new_state,
                actor,
                metadata
            )
            VALUES (
                v_tx_id,
                NULL,
                'completed',
                'sandbox-demo-seed',
                jsonb_build_object(
                    'customer_id', v_customer.customer_id,
                    'amount', 100000,
                    'currency', 'TZS',
                    'seed_reference', v_opening_reference
                )
            );
        END IF;
    END LOOP;
END;
$$;

SELECT
    u.customer_id,
    u.full_name,
    pv.id AS operating_vault_id,
    pv.currency,
    pv.balance
FROM public.users u
JOIN public.platform_vaults pv
  ON pv.user_id = u.id
 AND pv.vault_role = 'OPERATING'
WHERE u.customer_id IN ('OB26-2531-8566', 'OB26-2980-5415')
ORDER BY u.customer_id;
