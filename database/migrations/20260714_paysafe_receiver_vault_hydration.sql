-- Ensure PaySafe escrow agreements persist the receiver vault selected at creation.

CREATE OR REPLACE FUNCTION public.create_escrow_agreement_from_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_receiver_id UUID;
    v_amount NUMERIC;
    v_source_vault_id UUID;
    v_escrow_vault_id UUID;
    v_receiver_vault_id UUID;
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
    v_receiver_vault_id := NULLIF(NEW.metadata->>'receiver_vault_id', '')::UUID;
    v_merchant_id := NULLIF(NEW.metadata->>'merchant_id', '')::UUID;

    IF v_receiver_id IS NULL OR v_amount IS NULL OR v_amount <= 0
       OR v_source_vault_id IS NULL OR v_escrow_vault_id IS NULL OR v_receiver_vault_id IS NULL THEN
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
        receiver_vault_id,
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
        v_receiver_vault_id,
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

UPDATE public.escrow_agreements ea
SET receiver_vault_id = NULLIF(t.metadata->>'receiver_vault_id', '')::UUID
FROM public.transactions t
WHERE ea.transaction_id = t.id
  AND ea.receiver_vault_id IS NULL
  AND NULLIF(t.metadata->>'receiver_vault_id', '') IS NOT NULL;
