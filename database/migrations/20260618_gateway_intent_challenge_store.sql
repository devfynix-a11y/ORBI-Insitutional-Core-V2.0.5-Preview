-- Durable ORBI Pay Gateway intent, challenge, and result-event outbox.
-- Authorization evidence must be verified by ORBI Core before challenges are consumed.

CREATE TABLE IF NOT EXISTS public.gateway_payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intent_id TEXT NOT NULL UNIQUE,
    service_code TEXT NOT NULL,
    reference TEXT NOT NULL,
    operation TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    customer_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    merchant_id UUID REFERENCES public.merchants(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL DEFAULT 0 CHECK (amount >= 0),
    currency TEXT NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN (
            'RECEIVED',
            'REQUIRES_ACTION',
            'AUTHORIZED',
            'PROCESSING',
            'COMPLETED',
            'FAILED',
            'CANCELLED',
            'EXPIRED'
        )),
    request_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    authorized_at TIMESTAMP WITH TIME ZONE,
    processing_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gateway_payment_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id TEXT NOT NULL UNIQUE,
    intent_id UUID NOT NULL REFERENCES public.gateway_payment_intents(id) ON DELETE CASCADE,
    customer_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    challenge_type TEXT NOT NULL
        CHECK (challenge_type IN ('PIN', 'OTP', 'PASSKEY', 'BIOMETRIC', '3DS')),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 3 CHECK (max_attempts > 0),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejected_at TIMESTAMP WITH TIME ZONE,
    consumed_at TIMESTAMP WITH TIME ZONE,
    authorization_method TEXT,
    authorization_reference TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(intent_id, challenge_type)
);

CREATE TABLE IF NOT EXISTS public.gateway_payment_event_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_key TEXT NOT NULL UNIQUE,
    intent_id UUID NOT NULL REFERENCES public.gateway_payment_intents(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL DEFAULT 'SERVICE_PAYMENT_RESULT',
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'DELIVERING', 'DELIVERED', 'FAILED')),
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    next_attempt_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_error TEXT,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gateway_payment_intents_status
    ON public.gateway_payment_intents(status, updated_at);
CREATE INDEX IF NOT EXISTS idx_gateway_payment_intents_customer
    ON public.gateway_payment_intents(customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gateway_payment_challenges_pending
    ON public.gateway_payment_challenges(status, expires_at);
CREATE INDEX IF NOT EXISTS idx_gateway_payment_event_outbox_pending
    ON public.gateway_payment_event_outbox(status, next_attempt_at);

ALTER TABLE public.gateway_payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gateway_payment_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gateway_payment_event_outbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS gateway_payment_intents_service_role
    ON public.gateway_payment_intents;
CREATE POLICY gateway_payment_intents_service_role
    ON public.gateway_payment_intents
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS gateway_payment_challenges_service_role
    ON public.gateway_payment_challenges;
CREATE POLICY gateway_payment_challenges_service_role
    ON public.gateway_payment_challenges
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS gateway_payment_event_outbox_service_role
    ON public.gateway_payment_event_outbox;
CREATE POLICY gateway_payment_event_outbox_service_role
    ON public.gateway_payment_event_outbox
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE OR REPLACE FUNCTION public.persist_gateway_payment_intent_v1(
    p_intent_id TEXT,
    p_service_code TEXT,
    p_reference TEXT,
    p_operation TEXT,
    p_request_hash TEXT,
    p_customer_user_id UUID,
    p_merchant_id UUID,
    p_amount NUMERIC,
    p_currency TEXT,
    p_status TEXT,
    p_request_payload JSONB,
    p_response_payload JSONB,
    p_challenge_id TEXT DEFAULT NULL,
    p_challenge_type TEXT DEFAULT NULL,
    p_challenge_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_challenge_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_intent public.gateway_payment_intents%ROWTYPE;
    v_status TEXT := UPPER(BTRIM(COALESCE(p_status, '')));
    v_event_key TEXT;
BEGIN
    IF NULLIF(BTRIM(COALESCE(p_intent_id, '')), '') IS NULL
       OR NULLIF(BTRIM(COALESCE(p_request_hash, '')), '') IS NULL THEN
        RAISE EXCEPTION 'GATEWAY_INTENT_IDEMPOTENCY_REQUIRED';
    END IF;

    SELECT * INTO v_intent
    FROM public.gateway_payment_intents
    WHERE intent_id = p_intent_id
    FOR UPDATE;

    IF FOUND THEN
        IF v_intent.request_hash <> p_request_hash THEN
            RAISE EXCEPTION 'GATEWAY_INTENT_REPLAY_MISMATCH';
        END IF;
        SELECT event_key INTO v_event_key
        FROM public.gateway_payment_event_outbox
        WHERE intent_id = v_intent.id
        ORDER BY created_at DESC
        LIMIT 1;
        RETURN jsonb_build_object(
            'intentId', v_intent.intent_id,
            'status', v_intent.status,
            'response', v_intent.response_payload,
            'outboxEventKey', v_event_key,
            'replayed', TRUE
        );
    END IF;

    IF v_status NOT IN ('REQUIRES_ACTION', 'FAILED', 'PENDING', 'PROCESSING', 'COMPLETED') THEN
        RAISE EXCEPTION 'GATEWAY_INTENT_STATUS_INVALID';
    END IF;

    INSERT INTO public.gateway_payment_intents (
        intent_id,
        service_code,
        reference,
        operation,
        request_hash,
        customer_user_id,
        merchant_id,
        amount,
        currency,
        status,
        request_payload,
        response_payload,
        expires_at,
        failed_at,
        completed_at,
        metadata
    ) VALUES (
        p_intent_id,
        p_service_code,
        p_reference,
        UPPER(p_operation),
        p_request_hash,
        p_customer_user_id,
        p_merchant_id,
        ROUND(COALESCE(p_amount, 0)::NUMERIC, 2),
        UPPER(p_currency),
        CASE v_status
            WHEN 'REQUIRES_ACTION' THEN 'REQUIRES_ACTION'
            WHEN 'FAILED' THEN 'FAILED'
            WHEN 'COMPLETED' THEN 'COMPLETED'
            WHEN 'PROCESSING' THEN 'PROCESSING'
            ELSE 'RECEIVED'
        END,
        COALESCE(p_request_payload, '{}'::jsonb),
        COALESCE(p_response_payload, '{}'::jsonb),
        p_challenge_expires_at,
        CASE WHEN v_status = 'FAILED' THEN NOW() ELSE NULL END,
        CASE WHEN v_status = 'COMPLETED' THEN NOW() ELSE NULL END,
        jsonb_build_object('persisted_by', 'persist_gateway_payment_intent_v1')
    )
    RETURNING * INTO v_intent;

    IF v_status = 'REQUIRES_ACTION' THEN
        IF p_customer_user_id IS NULL
           OR NULLIF(BTRIM(COALESCE(p_challenge_id, '')), '') IS NULL
           OR NULLIF(BTRIM(COALESCE(p_challenge_type, '')), '') IS NULL
           OR p_challenge_expires_at IS NULL THEN
            RAISE EXCEPTION 'GATEWAY_CHALLENGE_DETAILS_REQUIRED';
        END IF;

        INSERT INTO public.gateway_payment_challenges (
            challenge_id,
            intent_id,
            customer_user_id,
            challenge_type,
            status,
            expires_at,
            metadata
        ) VALUES (
            p_challenge_id,
            v_intent.id,
            p_customer_user_id,
            UPPER(p_challenge_type),
            'PENDING',
            p_challenge_expires_at,
            COALESCE(p_challenge_metadata, '{}'::jsonb)
        );
    END IF;

    v_event_key := 'service-payment-result:' || p_intent_id || ':' || LOWER(v_status);
    INSERT INTO public.gateway_payment_event_outbox (
        event_key,
        intent_id,
        payload,
        status
    ) VALUES (
        v_event_key,
        v_intent.id,
        COALESCE(p_response_payload, '{}'::jsonb),
        'PENDING'
    );

    RETURN jsonb_build_object(
        'intentId', v_intent.intent_id,
        'status', v_intent.status,
        'response', v_intent.response_payload,
        'outboxEventKey', v_event_key,
        'replayed', FALSE
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.record_gateway_payment_event_delivery_v1(
    p_event_key TEXT,
    p_delivered BOOLEAN,
    p_error TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.gateway_payment_event_outbox
    SET
        status = CASE WHEN p_delivered THEN 'DELIVERED' ELSE 'FAILED' END,
        attempt_count = attempt_count + 1,
        delivered_at = CASE WHEN p_delivered THEN NOW() ELSE delivered_at END,
        next_attempt_at = CASE
            WHEN p_delivered THEN next_attempt_at
            ELSE NOW() + (LEAST(POWER(2, attempt_count + 1), 60)::TEXT || ' minutes')::INTERVAL
        END,
        last_error = CASE WHEN p_delivered THEN NULL ELSE LEFT(COALESCE(p_error, 'DELIVERY_FAILED'), 1000) END,
        updated_at = NOW()
    WHERE event_key = p_event_key;
END;
$$;

REVOKE ALL ON FUNCTION public.persist_gateway_payment_intent_v1(
    TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID, NUMERIC, TEXT, TEXT,
    JSONB, JSONB, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, JSONB
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_gateway_payment_event_delivery_v1(TEXT, BOOLEAN, TEXT)
    FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.persist_gateway_payment_intent_v1(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID, NUMERIC, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, JSONB) FROM anon';
        EXECUTE 'REVOKE ALL ON FUNCTION public.record_gateway_payment_event_delivery_v1(TEXT, BOOLEAN, TEXT) FROM anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.persist_gateway_payment_intent_v1(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID, NUMERIC, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, JSONB) FROM authenticated';
        EXECUTE 'REVOKE ALL ON FUNCTION public.record_gateway_payment_event_delivery_v1(TEXT, BOOLEAN, TEXT) FROM authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.persist_gateway_payment_intent_v1(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID, NUMERIC, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, JSONB) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_gateway_payment_event_delivery_v1(TEXT, BOOLEAN, TEXT) TO service_role';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
