-- Ensure signup profile data is persisted from auth metadata into public.users.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS nationality TEXT DEFAULT 'Tanzania';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'TZS';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS preferred_currency TEXT DEFAULT 'TZS';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS country_code TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS country_name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS dial_code TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'en';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    new_user_id UUID;
    new_customer_id TEXT;
    encrypted_zero TEXT;
    wallet1_id UUID;
    wallet2_id UUID;
    meta_customer_id TEXT;
    profile_currency TEXT;
    profile_language TEXT;
BEGIN
    new_user_id := NEW.id;
    meta_customer_id := NEW.raw_user_meta_data->>'customer_id';
    profile_currency := COALESCE(NULLIF(UPPER(TRIM(NEW.raw_user_meta_data->>'currency')), ''), 'TZS');
    profile_language := COALESCE(NULLIF(NEW.raw_user_meta_data->>'language', ''), 'en');

    IF meta_customer_id IS NOT NULL THEN
        new_customer_id := meta_customer_id;
    ELSE
        new_customer_id := 'OB' || to_char(NOW(), 'YY') || '-' ||
                           (floor(random() * 9000 + 1000)::text) || '-' ||
                           (floor(random() * 9000 + 1000)::text);
    END IF;

    encrypted_zero := 'enc_v2_eyJ2ZXJzaW9uIjoxLCJpdiI6IkFBQUFBQUFBQUFBQSIsImNpcGhlcnRleHQiOiJBQUFBQUFBQUFBQUEiLCJ0YWciOiJBQUFBQUFBQUFBQUEiLCJ0aW1lc3RhbXAiOjAsImtleUlkIjoicC1ub2RlLWFjdGl2ZSIsImFsZ29yaXRobSI6IkFFUy1HQ00tMjU2In0=';

    wallet1_id := md5(new_user_id::text || 'Orbi')::uuid;
    wallet2_id := md5(new_user_id::text || 'PaySafe')::uuid;

    INSERT INTO public.users (
        id, email, full_name, customer_id, phone, nationality, address, currency, preferred_currency,
        country_code, country_name, dial_code, language,
        registry_type, role, app_origin, fcm_token, metadata
    )
    VALUES (
        new_user_id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        new_customer_id,
        NEW.raw_user_meta_data->>'phone',
        COALESCE(NEW.raw_user_meta_data->>'nationality', 'Tanzania'),
        NEW.raw_user_meta_data->>'address',
        profile_currency,
        COALESCE(NULLIF(UPPER(TRIM(NEW.raw_user_meta_data->>'preferred_currency')), ''), profile_currency),
        NEW.raw_user_meta_data->>'country_code',
        NEW.raw_user_meta_data->>'country_name',
        NEW.raw_user_meta_data->>'dial_code',
        profile_language,
        COALESCE(NEW.raw_user_meta_data->>'registry_type', 'CONSUMER'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'USER'),
        COALESCE(NEW.raw_user_meta_data->>'app_origin', 'OBI_INSTITUTIONAL_CORE_V25'),
        NEW.raw_user_meta_data->>'fcm_token',
        jsonb_build_object('transfer_card', jsonb_build_object(
            'holder_name', NEW.raw_user_meta_data->>'full_name',
            'card_number_masked', new_customer_id,
            'brand', 'mastercard_style',
            'status', 'ready',
            'provisioned_at', NOW(),
            'product_name', 'Orbi'
        )) || COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
        customer_id = COALESCE(public.users.customer_id, EXCLUDED.customer_id),
        phone = COALESCE(EXCLUDED.phone, public.users.phone),
        nationality = COALESCE(EXCLUDED.nationality, public.users.nationality),
        address = COALESCE(EXCLUDED.address, public.users.address),
        currency = COALESCE(EXCLUDED.currency, public.users.currency),
        preferred_currency = COALESCE(EXCLUDED.preferred_currency, public.users.preferred_currency),
        country_code = COALESCE(EXCLUDED.country_code, public.users.country_code),
        country_name = COALESCE(EXCLUDED.country_name, public.users.country_name),
        dial_code = COALESCE(EXCLUDED.dial_code, public.users.dial_code),
        language = COALESCE(EXCLUDED.language, public.users.language),
        registry_type = COALESCE(EXCLUDED.registry_type, public.users.registry_type),
        role = COALESCE(EXCLUDED.role, public.users.role),
        app_origin = COALESCE(EXCLUDED.app_origin, public.users.app_origin),
        fcm_token = COALESCE(EXCLUDED.fcm_token, public.users.fcm_token),
        metadata = COALESCE(public.users.metadata, '{}'::jsonb) || EXCLUDED.metadata;

    INSERT INTO public.platform_vaults (
        id, user_id, vault_role, name, balance, encrypted_balance, currency, color, icon, metadata
    )
    VALUES (
        wallet1_id, new_user_id, 'OPERATING', 'Orbi', 0, encrypted_zero, profile_currency, '#10B981', 'credit-card',
        jsonb_build_object(
            'linked_customer_id', new_customer_id,
            'account_number', new_customer_id,
            'display_name', NEW.raw_user_meta_data->>'full_name',
            'card_type', 'Virtual Master'
        )
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.platform_vaults (
        id, user_id, vault_role, name, balance, encrypted_balance, currency, color, icon, metadata
    )
    VALUES (
        wallet2_id, new_user_id, 'INTERNAL_TRANSFER', 'PaySafe', 0, encrypted_zero, profile_currency, '#6366F1', 'shield-check',
        jsonb_build_object(
            'is_secure_escrow', true,
            'slogan', 'Secure Internal Transfers',
            'display_mode', 'mask',
            'account_number', 'ESC-' || new_customer_id
        )
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
