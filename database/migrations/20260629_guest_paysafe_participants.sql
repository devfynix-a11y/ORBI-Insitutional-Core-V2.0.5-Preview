CREATE TABLE IF NOT EXISTS public.guest_escrow_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_code TEXT NOT NULL,
    reference TEXT NOT NULL,
    payment_intent_id TEXT,
    shop_order_id TEXT,
    merchant_id UUID REFERENCES public.merchants(id) ON DELETE SET NULL,
    merchant_wallet_id UUID REFERENCES public.merchant_wallets(id) ON DELETE SET NULL,
    display_name TEXT,
    email_hash TEXT,
    phone_hash TEXT,
    email_hint TEXT,
    phone_hint TEXT,
    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN ('unverified', 'verified', 'linked', 'blocked')),
    linked_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    refund_policy TEXT NOT NULL DEFAULT 'original_payment_method_only'
        CHECK (refund_policy IN ('original_payment_method_only')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE (service_code, reference)
);

CREATE INDEX IF NOT EXISTS idx_guest_escrow_participants_intent
    ON public.guest_escrow_participants(payment_intent_id);

CREATE INDEX IF NOT EXISTS idx_guest_escrow_participants_order
    ON public.guest_escrow_participants(shop_order_id);

CREATE INDEX IF NOT EXISTS idx_guest_escrow_participants_merchant
    ON public.guest_escrow_participants(merchant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_guest_escrow_participants_email_hash
    ON public.guest_escrow_participants(email_hash)
    WHERE email_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_guest_escrow_participants_phone_hash
    ON public.guest_escrow_participants(phone_hash)
    WHERE phone_hash IS NOT NULL;

ALTER TABLE public.guest_escrow_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "guest_escrow_participants_service_role_only" ON public.guest_escrow_participants;
CREATE POLICY "guest_escrow_participants_service_role_only" ON public.guest_escrow_participants
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');
